# ACL2 in LispWorks

## Use ACL2 from another ASDF system

Add `"acl2"` to your application's dependencies. The prover runs in the
same LispWorks image as your application. Loading the library does not start
a prover subprocess or an ACL2 listener, and does not save the image.

Use a LispWorks development image with ASDF 3. The tested host is LispWorks
8.1.2 on 64-bit Linux. Register the checkout in the ASDF source registry, or
register it for the current session:

```lisp
(require "asdf")
(asdf:load-asd #p"/absolute/path/to/acl2/acl2.asd")
```

In your application's `.asd` file:

```lisp
(asdf:defsystem "my-app"
  :depends-on ("acl2")
  :components ((:file "app")))
```

`(asdf:load-system "my-app")` now loads ACL2 before compiling `app.lisp`.
At a LispWorks prompt you can also call `(asdf:load-system "acl2")` directly.
The first load compiles the implementation into the ASDF cache. Each fresh
image initializes its own ACL2 world, the set of admitted definitions and
theorems. Keep the sources available for initialization. No `make` step is
necessary.

## Submit a form

`lw-acl2:submit` takes one Lisp object, not a string. Use ACL2 package names
where needed. Quoting a symbol from your own package does not turn it into an
ACL2 symbol.

```lisp
(lw-acl2:submit '(defun acl2::twice (acl2::x) (+ acl2::x acl2::x)))
(lw-acl2:submit '(acl2::defthm acl2::twice-is-double
                  (equal (acl2::twice acl2::x) (+ acl2::x acl2::x))
                  :rule-classes nil))
(lw-acl2:submit '(acl2::twice 21))  ; => 42

(handler-case (lw-acl2:submit '(acl2::thm (equal 1 2)))
  (lw-acl2:acl2-error (c) (lw-acl2:rejected-form c)))
(lw-acl2:submit '(acl2::twice 3))   ; => 6 in the same world
```

For a successful ACL2 error triple `(nil value state)`, `submit` returns
`value`. Other multiple values come back as a list. Treat returned objects
as read-only because they can share structure with ACL2. A rejected event or
a request to quit signals `lw-acl2:acl2-error`. Bind `*standard-output*` to
capture proof diagnostics. At the start of each outer call, relative book
paths use the directory in `*default-pathname-defaults*`.

All callers share one serial world. Use `lw-acl2:with-acl2` to hold its lock
across several submissions. Inside `with-acl2` you can also call an admitted
raw Lisp function if its arguments satisfy its ACL2 guards (input
requirements). Do not call raw ACL2 functions outside that scope.

Use only trusted forms and books. The library is not a sandbox. ACL2 installs
packages, symbol properties, and definitions in the host image. Leave package
names beginning with `ACL2`, and `BIB`, free for ACL2. Avoid book package
names that the host already owns, such as LispWorks' `DEF`. LispWorks advice
on `lower-case-p`, `char-upcase`, and `string-upcase` gives ACL2 its 8-bit
character behavior during a call. Host calls outside that scope keep their
native behavior.

If initialization fails or you change the ACL2 implementation, use a fresh
image. The system does not support reloading over a live world, ACL2(p), or
ACL2(r). It does not load listener customization files or `acl2r.lisp` from
a standalone build.

## Test the library

In a fresh LispWorks listener, run:

```lisp
(load #p"/absolute/path/to/acl2/lispworks/test-load.lisp")
```

This tests ASDF loading and host settings. If the system is already
registered, `(asdf:test-system "acl2")` runs the API tests. They admit a
theorem, reject a false theorem and a quit request, then call the prover
again. In a multiprocessing listener they also test concurrent callers. Use a
test image: the tests add ACL2 events to its world.

## Build the standalone command (Linux)

From the checkout, run GNU Make with the path to the LispWorks console
executable:

```sh
make full LISP='/path/to/lispworks -build -'
make init LISP='/path/to/lispworks -build -' PREFIX=lw-
./lw-saved_acl2
```

The launcher starts `lw-saved_acl2.lw` at the ACL2 prompt. `-build -` reads
the build from standard input before LispWorks starts multiprocessing. Do not
save the executable from an active listener. For `lw`, `lispworks`, and
`lispworks-*`, Make adds `-build -` if you omit it. If you also build with
SBCL, use separate build directories. `PREFIX` names the executable, not all
intermediate files.

`lw-saved_acl2.lw` is a development image. If your LispWorks edition supports
Delivery, build the console runtime with `make lispworks-deliver PREFIX=lw-`.
Run `./lw-saved_acl2-runtime` directly. Delivery removes `compile-file` and
image saving, even at level 0. Use the development image for book compilation
or `save-exec`. Books are separate files. Before distribution, test on the
target machine and follow your LispWorks license and ACL2's [license](../LICENSE).
