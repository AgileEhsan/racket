#lang racket/base
(require "match.rkt"
         "wrap.rkt"
         "struct-type-info.rkt"
         "mutated-state.rkt"
         "find-definition.rkt")

(provide struct-convert
         struct-convert-local)

(define (struct-convert form prim-knowns knowns imports mutated
                        schemify no-prompt?)
  (match form
    [`(define-values (,struct:s ,make-s ,s? ,acc/muts ...)
        (let-values (((,struct: ,make ,?1 ,-ref ,-set!) ,mk))
          (values ,struct:2
                  ,make2
                  ,?2
                  ,make-acc/muts ...)))
     ;; Convert a `make-struct-type` binding into a 
     ;; set of bindings that Chez's cp0 recognizes,
     ;; and push the struct-specific extra work into
     ;; `struct-type-install-properties!`
     (define sti (and (wrap-eq? struct: struct:2)
                      (wrap-eq? make make2)
                      (wrap-eq? ?1 ?2)
                      (for/and ([acc/mut (in-list acc/muts)]
                                [make-acc/mut (in-list make-acc/muts)])
                        (match make-acc/mut
                          [`(make-struct-field-accessor ,ref-id ,pos ',field-name)
                           (and (wrap-eq? ref-id -ref)
                                (symbol? field-name)
                                (exact-nonnegative-integer? pos))]
                          [`(make-struct-field-mutator ,set-id ,pos ',field-name)
                           (and (wrap-eq? set-id -set!)
                                (symbol? field-name)
                                (exact-nonnegative-integer? pos))]
                          [`,_ #f]))
                      (make-struct-type-info mk prim-knowns knowns imports mutated)))
     (cond
       [(and sti
             ;; make sure all accessor/mutator positions are in range:
             (for/and ([make-acc/mut (in-list make-acc/muts)])
               (match make-acc/mut
                 [`(,_ ,_ ,pos ,_) (pos . < . (struct-type-info-immediate-field-count sti))]))
             ;; make sure `struct:` isn't used too early, since we're
             ;; reordering it's definition with respect to some arguments
             ;; of `make-struct-type`:
             (simple-mutated-state? (hash-ref mutated (unwrap struct:) #f))
             ;; If any properties, need the first LHS to be non-set!ed, because that will
             ;; let us reject multi-return from continuation capture in property expressions
             (or no-prompt?
                 (null? (struct-type-info-rest sti))
                 (not (set!ed-mutated-state? (hash-ref mutated (unwrap struct:s) #f)))))
        (define can-impersonate? (not (struct-type-info-authentic? sti)))
        (define raw-s? (if can-impersonate? (gensym (unwrap s?)) s?))
        `(begin
           (define ,struct:s (make-record-type-descriptor ',(struct-type-info-name sti)
                                                          ,(schemify (struct-type-info-parent sti) knowns)
                                                          ,(if (not (struct-type-info-prefab-immutables sti))
                                                               #f
                                                               `(structure-type-lookup-prefab-uid
                                                                 ',(struct-type-info-name sti)
                                                                 ,(schemify (struct-type-info-parent sti) knowns)
                                                                 ,(struct-type-info-immediate-field-count sti)
                                                                 0 #f
                                                                 ',(struct-type-info-prefab-immutables sti)))
                                                          #f
                                                          #f
                                                          ',(for/vector ([i (in-range (struct-type-info-immediate-field-count sti))])
                                                              `(mutable ,(string->symbol (format "f~a" i))))))
           ,@(if (null? (struct-type-info-rest sti))
                 null
                 `((define ,(gensym)
                     (struct-type-install-properties! ,struct:s
                                                      ',(struct-type-info-name sti)
                                                      ,(struct-type-info-immediate-field-count sti)
                                                      0
                                                      ,(schemify (struct-type-info-parent sti) knowns)
                                                      ,@(schemify-body schemify knowns (struct-type-info-rest sti))))))
           (define ,make-s ,(let ([ctr `(record-constructor
                                         (make-record-constructor-descriptor ,struct:s #f #f))])
                              (define ctr-expr
                                (if (struct-type-info-pure-constructor? sti)
                                    ctr
                                    `(struct-type-constructor-add-guards ,ctr ,struct:s ',(struct-type-info-name sti))))
                              (define name-expr (struct-type-info-constructor-name-expr sti))
                              (match name-expr
                                [`#f
                                 (wrap-property-set ctr-expr 'inferred-name (struct-type-info-name sti))]
                                [`',sym
                                 (if (symbol? sym)
                                     (wrap-property-set ctr-expr 'inferred-name sym)
                                     `(procedure-rename ,ctr-expr ,name-expr))]
                                [`,_
                                 `(procedure-rename ,ctr-expr ,name-expr)])))
           (define ,raw-s? (record-predicate ,struct:s))
           ,@(if can-impersonate?
                 `((define ,s? ,(name-procedure
                                 "" (struct-type-info-name sti) "" '|| "?"
                                 `(lambda (v) (if (,raw-s? v) #t ($value (if (impersonator? v) (,raw-s? (impersonator-val v)) #f)))))))
                 null)
           ,@(for/list ([acc/mut (in-list acc/muts)]
                        [make-acc/mut (in-list make-acc/muts)])
               (define raw-acc/mut (if can-impersonate? (gensym (unwrap acc/mut)) acc/mut))
               (match make-acc/mut
                 [`(make-struct-field-accessor ,(? (lambda (v) (wrap-eq? v -ref))) ,pos ',field-name)
                  (define raw-def `(define ,raw-acc/mut (record-accessor ,struct:s ,pos)))
                  (if can-impersonate?
                      `(begin
                         ,raw-def
                         (define ,acc/mut
                           ,(name-procedure
                             "" (struct-type-info-name sti) "-" field-name ""
                             `(lambda (s) (if (,raw-s? s)
                                              (,raw-acc/mut s)
                                              ($value (impersonate-ref ,raw-acc/mut ,struct:s ,pos s
                                                                       ',(struct-type-info-name sti) ',field-name)))))))
                      raw-def)]
                 [`(make-struct-field-mutator ,(? (lambda (v) (wrap-eq? v -set!))) ,pos ',field-name)
                  (define raw-def `(define ,raw-acc/mut (record-mutator ,struct:s ,pos)))
                  (define abs-pos (+ pos (- (struct-type-info-field-count sti)
                                            (struct-type-info-immediate-field-count sti))))
                  (if can-impersonate?
                      `(begin
                         ,raw-def
                         (define ,acc/mut
                           ,(name-procedure
                             "set-" (struct-type-info-name sti) "-" field-name "!"
                             `(lambda (s v) (if (,raw-s? s)
                                                (,raw-acc/mut s v)
                                                ($value (impersonate-set! ,raw-acc/mut ,struct:s ,pos ,abs-pos s v
                                                                          ',(struct-type-info-name sti) ',field-name)))))))
                      raw-def)]
                 [`,_ (error "oops")]))
           (define ,(gensym)
             (begin
               (register-struct-constructor! ,make-s)
               (register-struct-predicate! ,s?)
               ,@(for/list ([acc/mut (in-list acc/muts)]
                            [make-acc/mut (in-list make-acc/muts)])
                   (match make-acc/mut
                     [`(make-struct-field-accessor ,_ ,pos ,_)
                      `(register-struct-field-accessor! ,acc/mut ,struct:s ,pos)]
                     [`(make-struct-field-mutator ,_ ,pos ,_)
                      `(register-struct-field-mutator! ,acc/mut ,struct:s ,pos)]
                     [`,_ (error "oops")]))
               (void))))]
       [else #f])]
    [`,_ #f]))

(define (struct-convert-local form #:letrec? [letrec? #f]
                              prim-knowns knowns imports mutated simples
                              schemify
                              #:unsafe-mode? unsafe-mode?)
  (match form
    [`(,_ ([,ids ,rhs]) ,bodys ...)
     (define defn `(define-values ,ids ,rhs))
     (define new-seq
       (struct-convert defn
                       prim-knowns knowns imports mutated
                       schemify #t))
     (and new-seq
          (match new-seq
            [`(begin . ,new-seq)
             (define-values (new-knowns info)
               (find-definitions defn prim-knowns knowns imports mutated simples unsafe-mode?
                                 #:optimize? #f))
             (cond
               [letrec?
                `(letrec* ,(let loop ([new-seq new-seq])
                             (match new-seq
                               [`() null]
                               [`((begin ,forms ...) . ,rest)
                                (loop (append forms rest))]
                               [`((define ,id ,rhs) . ,rest)
                                (cons `[,id ,rhs] (loop rest))]))
                   ,@(schemify-body schemify new-knowns bodys))]
               [else
                (let loop ([new-seq new-seq])
                  (match new-seq
                    [`()
                     (define exprs (schemify-body schemify new-knowns bodys))
                     (if (and (pair? exprs) (null? (cdr exprs)))
                         (car exprs)
                         `(begin ,@exprs))]
                    [`((begin ,forms ...) . ,rest)
                     (loop (append forms rest))]
                    [`((define ,id ,rhs) . ,rest)
                     `(let ([,id ,rhs])
                        ,(loop rest))]))])]))]
    [`,_ #f]))

(define (schemify-body schemify knowns l)
  (for/list ([e (in-list l)])
    (schemify e knowns)))

(define (name-procedure pre st sep fld post proc-expr)
  (wrap-property-set proc-expr
                     'inferred-name
                     (string->symbol
                      (string-append pre
                                     (symbol->string st)
                                     sep
                                     (symbol->string fld)
                                     post))))
