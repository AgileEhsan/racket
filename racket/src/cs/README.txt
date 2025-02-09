The implementation of Racket on Chez Scheme in this directory is
organized into two layers:

 * The immediate directory contains Scheme sources to implement Racket
   functionality on top of Chez Scheme. It references sibling
   directories like "expander" and "io", which contain Racket code
   that is compiled to Chez Scheme to implement Racket.

 * The "c" subdirectory contains C sources and build scripts to create
   wrapper executables that combine Chez Scheme with the Racket
   functionality implemented in this immediate directory.

In addition, "bootstrap" implements a simulation of Chez Scheme in
Racket that can be used to bootstrap Chez Scheme from source (i.e.,
using an existing Racket build, but without an existing Chez Scheme
build).


========================================================================
 Requirements
========================================================================

Building Racket-on-Chez requires both an existing Racket build and
Chez Scheme build.

The existing Racket must be "new enough" to build the current
Racket-on-Chez version. In the worst case, it must be exactly the same
version (using the traditional Racket implementation) as the one
you're trying to build.

When you use `configure --enable-cs` or similar as described in
"../README.txt", then a bootstrapping variant of Racket is built
automatically. You can select a different Racket excutable by
supplying `--enable-racket=...` to `configure`.

The Chez Scheme build must also be sufficiently new. See
"../README.txt" for information on obtaining Chez Scheme (when not
using a source Racket distribution that includes Chez Scheme's source
already).


========================================================================
 Development versus Build
========================================================================

The Racket-on-Chez implementation can be built and run in two
different ways: development mode for running directly using a Chez
Scheme installation, and build mode for creating a `racket` or
`racketcs` executable that combines Chez Scheme and Racket
functionality into a single executable.

Development Mode
----------------

The makefile in this directory is set up for modifying the
implementation of Racket functionality and testing it out on a Chez
Scheme installation.

For this development mode, either Chez Scheme needs to be installed as
`scheme`, or you must use `make SCHEME=...` to set the command for
`scheme`.

Development mode also needs a Racket installation with at least the
"compiler-lib" package installed. By default, the makefile looks for
Racket installed as "../../bin/racket"; if this directory is in a
clone of the Git repository for Racket, you can get "../../bin/racket"
with

      make PKGS="compiler-lib"

in the clone's root directory. Alternatively, use use `make
RACKET=...` to set the command for `racket`.

The use of development mode is described in more detail further below.

Development mode currently doesn't work on Windows, because the
makefile makes too many Unix-ish assumptions.

Build Mode
----------

To build a Racket-on-Chez executable, the `configure` script and
makefile in "c" subdirectory are normally used via `configure` and
`make` in the parent directory of this one, as described in
"../README.txt". However, you can use them directly with something
like

   cd [build]
   mkdir cs
   cd cs
   [here]/c/configure
   make
   make install

where [here] is the directory containing this "README.txt" and [build]
is a build directory (usually "../build" relative to [here]).

The `configure` script accepts flags like `--enable-racket=...` and
`--enable-scheme=...` to select an existing Racket and a Chez Scheme
build directory to use for building Racket-on-Chez:

 * By default, the build uses Racket as "[build]/racket/racket3m" and
   bootstraps bytecode from "[here]/../../collects".

   If you supply `--enable-racket=...` to specify a Racket executable,
   then it must be part of a (minimal) installation.

 * By default, the build looks for a Chez Scheme build directory as
   "build/ChezScheme".

   Building Racket-on-Chez requires a Chez Scheme build directory, not
   just a Chez Scheme installation that is accessible as `scheme`.

The resulting Racket-on-Chez executable has the suffix "cs". To
generate an executable without the "cs" suffix, supply
`--enable-csdefault` to `configure`. The precense or absence of "cs"
affects the location of ".zo" files.

Compilation on Windows does not use the `configure` script in "c".
Instead, from the directory "[here]\..\worksp", run "csbuild.rkt"
using an installed (minimal) Racket --- perhaps one created by running
"[here]\..\build.bat". The "csbuild.rkt" script puts intermediate
files in "[here]\..\build", including a Chez Scheme checkout if it's
not already present (in which case `git` must be available).


========================================================================
 Machine Code versus JIT
========================================================================

Racket-on-Chez currently supports two compilation modes:

 * Machine-code mode --- The compiled form of a module is machine code
   generated by compiling either whole linklets (for small enough
   linklets) or functions within linklets (with a "bytecode"
   interpreter around the compiled parts).

   Select this mode by seting the `PLT_CS_MACH` environment variable,
   but it's currently the default.

   In development mode or when the "cs" suffix is used for build mode,
   compiled ".zo" files in this mode are written to a subdirectory of
   "compiled" using the Chez Scheme platform name (e.g., "a6osx").

   Set `PLT_CS_COMPILE_LIMIT` to set the maximum size of forms to
   compile before falling back to interpreted "bytecode". The default
   is 10000. Setting `PLT_CS_COMPILE_LIMIT` to 0 effectively turns
   the implementation into a pure interpreter.

 * JIT mode --- The compiled form of a module is an S-expression where
   individual `lambda`s are compiled on demand.

   Select this mode by seting the `PLT_CS_JIT` environment variable.

   In development mode or when the "cs" suffix is used for build mode,
   compiled ".zo" files in this mode are written to a "cs"
   subdirectory of "compiled".

   S-expressions fragments are hashed at compilation time, so that the
   hash for each fragment is stored in the ".zo" file. At JIT time,
   the hash is used to consult and/or update a cache (implemented as
   an SQLite database) of machine-code forms. Set the `PLT_JIT_CACHE`
   environment variable to change the cache file, or set the
   environment variable to empty to disable the cache.

In development mode or when the "cs" suffix is used for build mode,
set the `PLT_ZO_PATH` environment variable to override the path used
for ".zo" files. For example, you may want to preserve a normal build
while also building in machine-code mode with `PLT_CS_DEBUG` set, in
which case setting `PLT_ZO_PATH` to something like "a6osx-debug" could
be a good idea.


========================================================================
 Development Mode
========================================================================

Development mode is driven by the makefile in this directory.

Building
--------

Running `make` will build the Racket-on-Chez implementation. Use `make
expander-demo` to run a demo that loads `racket/base` from source.

Use `make setup` (or `make setup-v` for a verbose version) to build
".zo" files for collection-based libraries.

If you want to control the `raco setup` that `make setup` runs, supply
an `ARGS` variable to make, such as

   make setup ARGS="-l typed/racket"  # only sets up TR
   make setup ARGS="--clean -Dd"      # clears ".zo" files
   make setup ARGS="--fail-fast"      # stop at the first error

Running
-------

Use `make run ARGS="..."` to run Racket on Chez Scheme analogous to
running plain `racket`, where command-line arguments are supplied in
`ARGS`.

Structure
---------

The Racket-on-Chez implementation is in layers. The immediate layer
over Chez Scheme is called "Rumble", and it implements delimited
continuations, structures, chaperones and impersonators, engines (for                                          
threads), and similar base functionality. The Rumble layer is
implemented in Chez Scheme.

The rest of the layers are implemented in Racket:

   thread
   io
   regexp
   schemify
   expander

Each of those layers is implemented in a sibling directory of this
one. Each layer is expanded (using "expander", of course) and then
compiled to Chez Scheme (using "schemify") to implement Racket.

The fully expanded form of each layer must not refer to any
functionality of previous layers. For example, the expander "thread"
must not refer to functionality implemented by "io", "regexp", or
"expander", while the expanded form of "io" must not refer to "regexp"
or "expander" functionality. Each layer can use `racket/base`
functionality, but beware that code from `racket/base` will be
duplicated in each layer.

The "io" layer relies on a shared library, rktio, to provide a uniform
interface to OS resources. The rktio source is in a "rktio" sibling
directory to this one.

Files in this directory:

 *.sls - Chez Scheme libraries that provide implementations of Racket
         primitives, building up to the Racket expander. The
         "rumble.sls" library is implemented directly in Chez Scheme.
         For most other cases, a corresponding "compiled/*.scm" file
         contains the implementation extracted from from expanded and
         flattened Racket code. Each "*.sls" file is built to "*.so".

 rumble/*.ss - Parts of "rumble.sls" (via `include`) to implement data
         structures, immutable hash tables, structs, delimited
         continuations, engines, impersonators, etc.

 linklet/*.ss - Parts of "linklet.sls" (via `include`).

 compiled/*.rktl (generated) - A Racket library (e.g., to implement
         regexps) that has been fully macro expanded and flattened
         into a linklet from its source in "../*". A linklet's only
         free variables are primitives that will be implemented by
         various ".sls" libraries in lower layers.

         For example, "../thread" contains the implementation (in
         Racket) of the thread and event subsystem.

 compiled/*.scm (generated) - A conversion from a ".rktl" file to be
         `included`d into an ".sls" library.

 ../build/so-rktio/rktio.rktl (generated) and
 ../../lib/librktio.{so,dylib,dll} (generated) - Created when building
         the "io" layer, the "rktio.rktl" file contains FFI descriptions
         that are `included` by "io.sls" and "librktio.{so,dylib,dll}"
         is the shared library that implements rktio.

         CAUTION: The makefile here doesn't track dependencies for
         rktio, so use `make rktio` if you change its implementation.

 primitive/*.ss - for "expander.sls", tables of bindings for
         primitive linklet instances; see "From primitives to modules"
         below for more information.

 convert.rkt - A "schemify"-based linklet-to-library-body compiler,
         which is used to convert a ".rktl" file to a ".scm" file to
         inclusion in an ".sls" library.

 demo/*.ss - Chez Scheme scripts to check that a library basically
         works. For example "demo/regexp.ss" runs the regexp matcher
         on a few examples. To run "demo/*.ss", use `make *-demo`.

 other *.rkt - Racket scripts like "convert.rkt" or comparisions like
         "demo/regexp.rkt". For example, you can run "demo/regexp.rkt"
         and compare the reported timing to "demo/regexp.ss".

From Primitives to Modules
--------------------------

The "expander" layer, as turned into a Chez Scheme library by
"expander.sls", synthesizes primitive Racket modules such as
`'#%kernel` and `'#%network`. The content of those primitive _modules_
at the expander layer is based on primitve _instances_ (which are just
hash tables) as populated by tables in the "primitive" directory. For
example, "primitive/network.scm" defines the content of the
`'#network` primitive instance, which is turned into the primitive
`'#%network` module by the expander layer, which is reexported by the
`racket/network` module that is implemented as plain Racket code. The
Racket implementation in "../racket" provides those same primitive
instances to the macro expander.

Running "demo/expander.ss"
--------------------------

A `make expander-demo` builds and tries the expander on simple
examples, including loading `racket/base` from source.

Dumping Linklets and Schemified Linklets
----------------------------------------

Set the `PLT_LINKLET_SHOW` environment variable to pretty print each
linklet generated by the expander and its schemified form that is
passed on to Chez Scheme.

By default, `PLT_LINKLET_SHOW` does not distinguish gensyms that have
the same base name, so the schemified form is not really accurate. Set
`PLT_LINKLET_SHOW_GENSYM` instead (or in addition) to get more
accurate output.

In JIT mode, the schemified form is shown after a conversion to
support JIT mode. Set `PLT_LINKLET_SHOW_PRE_JIT` to see the
pre-conversion form. Set `PLT_LINKLET_SHOW_JIT_DEMAND` to see forms as
they are compiled on demand.

In machine-code mode, set `PLT_LINKLET_SHOW_LAMBDA` to see individual
compiled terms when a linklet is not compliled whole; set
`PLT_LINKLET_SHOW_POST_LAMBDA` to see the linlet reorganized around
those compiled parts; and/or set `PLT_LINKLET_SHOW_POST_INTERP` to see
the "bytecode" form.

Set `PLT_LINKLET_SHOW_CP0` to see the Schmeified form of a linklet
after expansion and optimization by Chez Scheme's cp0.

Safety and Debugging Mode
-------------------------

If you make changes to files in "rumble", you should turn off
`UNSAFE_COMP` in the makefile.

You may want to turn on `DEBUG_COMP` in the makefile, so that
backtraces provide expression-specific source locations instead of
just procedure-specific source locations. Enabling `DEBUG_COMP` makes
the Racket-on-Chez implementation take up twice as much memory and
take twice as long to load.

Turning on `DEBUG_COMP` affects only the Racket-on-Chez
implementation. To preserve per-expression locations on compiled
Racket code, set `PLT_CS_DEBUG`. See also "JIT versus Machine Code"
for a suggestion on setting `PLT_ZO_PATH`.

When you change "rumble" or other layers, you can continue to use
Racket modules that were previously compiled to ".zo" form... usually,
but inlining optimizations and similar compiler choices can break
compatibility.

FFI Differences
---------------

Compared to the traditional Racket implementation, Racket-on-Chez's
FFI behaves in several different ways:

 * The `make-sized-byte-string` function always raises an exception,
   because a foreign address cannot be turned into a byte string whose
   content is stored in the foreign address. The options are to copy
   the foreign content to/from a byte string or use `ptr-ref` and
   `ptr-set!` to read and write at the address.

 * When `_bytes` is used as an argument type, beware that a byte
   string is not implicitly terminated with a NUL byte. When `_bytes`
   is used as a result type, the C result is copied into a fresh byte
   string.

 * The 'atomic-interior allocation mode returns memory that is allowed
   to move after the cpointer returned by allocation becomes
   unreachable.

 * A `_gcpointer` can only refer to the start of an allocated object,
   and never the interior of an 'atomic-interior allocation. Like
   traditional Racket, `_gcpointer` is equivalent to `_pointer` for
   sending values to a foreign procedure, return values from a
   callback that is called from foreign code, or for `ptr-set!`. For
   the other direction (receiving a foreign result, `ptr-ref`, and
   receiving values in a callback), the received pointer must
   correspond to the content of a byte string or vector.

 * Calling a foreign function implicitly uses atomic mode and also
   disables GC. If the foreign function calls back to Racket, the
   callback runs in atomic mode with the GC still disabled.

 * An immobile cell must be modified only through its original pointer
   or a reconstructed `_gcpointer`. If it is cast or reconstructed as
   a `_pointer`, setting the cell will not cooperate correctly with
   the garbage collector.

 * Memory allocated with 'nonatomic works only in limited ways. It
   cannot be usefully passed to foreign functions, since the layout is
   not actually an array of pointers.

Threads, Threads, Atomicity, Atomicity, and Atomicity
-----------------------------------------------------

Racket's thread layer does not use Chez Scheme threads. Chez Scheme
threads correspond to OS threads. Racket threads are implemented in
terms of engines at the Rumble layer. At the same time, futures and
places use Chez Scheme threads, and so parts of Rumble are meant to be
thread-safe with respect to Chez Scheme and OS threads. The FFI also
exposes elements of Chez Scheme / OS threads.

As a result of these layers, there are multiple ways to implement
atomic regions:

 * For critical sections with respect to Chez Scheme / OS threads, use
   a mutex or a spinlock.

   For example, the implementation of `eq?` and `eqv?`-based hash
   tables uses a spinlock to guard hash tables, so they can be
   accessed concurrently from futures. In contrast, `equal?`-based
   hash table operations are not atomic from the Racket perspective,
   so they can't be locked by a mutex or spinlock; they use
   Racket-thread locks, instead. The "rumble/lock.ss" layer skips the
   `eq?`/`eqv?`-table spinlock when threads are not enabled at the
   Chez Scheme level.

   Chez Scheme deactivates a thread that is blocked on a mutex, so you
   don't have to worry about waiting on a mutex blocking GCs. However,
   if a lock guards a value that is also used by a GC callback, then
   interrupts should be disabled before taking the lock to avoid
   deadlock.

 * For critical sections at the Racket level, there are multiple
   possibilities:

     - The Racket "thread" layer provides `start-atomic` and
       `end-atomic` to prevent Racket-thread swaps.

       These are the same opertations as provided by
       `ffi/unsafe/atomic`.

     - Disabling Chez Scheme interrupts will also disable Racket
       thread swaps, since a thread swap via engines depends on a
       timer interrupt --- unless something explicitly blocks via the
       Racket thread scheduler, such as with `(sleep)`.

       Disable interrupts for atomicity only at the Rumble level where
       no Racket-level callbacks are not involved. Also, beware that
       disabling interrupts will prevent GC interrupts.

       The Racket "thread" layer provides `start-atomic/no-interrupts`
       and `end-atomic/no-interrupts` for both declaing atomicity at
       the Racket level and turning off Chez Scheme interrupts. The
       combination is useful for implementing functionality that might
       be called in response to a GC and might also be called by
       normal (non-atomic) code; the implementation of logging at the
       "io" layer might be the only use case.

     - The implementation of engines and continuations uses its own
       flag to protect regions where an engine timeout should not
       happen, such as when the metacontinuation is being manipulated.
       That flag is managed by `start-uninterrupted` and
       `end-uninterrupted` in "rumble/interrupt.ss".

       It may be tempting to use that flag for other purposes, as a
       cheap way to disable thread swaps. For now, don't do that.

Performance Notes
-----------------

The best-case scenario for performance is currently the default
configuration:

 * `UNSAFE_COMP` is enabled in "Makefile" --- currently on by default.

   Effectiveness: Can mean a 10-20% improvement in loading
   `racket/base` from source. Since the implementation is in pretty
   good shape, `UNSAFE_COMP` is enabled by default.

 * `DEBUG_COMP` not enabled --- or, if you enable it, run `make
   strip`.

   Effectiveness: Avoids increasing the load time for the Rumble and
   other layers by 30-50%.

 * `PLT_CS_DEBUG` not set --- an environment variable similar to
   `DEBUG_COMP`, but applies to code compiled by Racket-on-Chez.

   Effectiveness: Avoids improvement to stack traces, but also avoids
   increases load time and memory use of Racket programs by as much as
   50%.
