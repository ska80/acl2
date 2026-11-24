;;; Native, serial ACL2 for embedding in LispWorks applications.
(in-package #:asdf-user)

(defclass acl2-implementation-file (asdf:cl-source-file)
  ((host-reader-p :initarg :host-reader-p
                  :reader acl2-host-reader-p
                  :initform nil)))

(defclass acl2-package-file (asdf:static-file) ())

;; As in COMPILE-ACL2, macros in a file can call functions defined earlier
;; in that same file. Load its source before compiling it. Let ASDF manage
;; the dependency order, output translations, and compiled-file cache.
(defmethod asdf:perform :around ((op asdf:compile-op) (c acl2-implementation-file))
  (uiop:symbol-call :lw-acl2 :call-with-build-context
                    (lambda ()
                      ;; Bootstrap already loaded acl2-fns with the host reader.
                      (unless (acl2-host-reader-p c) (load (asdf:component-pathname c)))
                      (call-next-method))
                    (acl2-host-reader-p c)))
(defmethod asdf:perform :around ((op asdf:load-op) (c acl2-implementation-file))
  (uiop:symbol-call :lw-acl2 :call-with-build-context (lambda () (call-next-method))
                    (acl2-host-reader-p c)))
(defmethod asdf:perform ((op asdf:load-op) (c acl2-package-file))
  (uiop:symbol-call :lw-acl2 :call-with-build-context
                    (lambda () (load (asdf:component-pathname c)))))

(asdf:defsystem "acl2"
  :description "The ACL2 theorem prover as an in-process LispWorks library"
  :license "BSD-3-Clause"
  :serial t
  :encoding :default
  :components ((:static-file "acl2-files")
               (:static-file "acl2-characters")
               (:static-file "acl2.lisp")
               (:static-file "acl2-fns.lisp")
               (:static-file "acl2-init.lisp")
               (:static-file "acl2-check.lisp")
               ;; Bootstrap creates the ACL2 package before reading its own later forms.
               (:static-file "lispworks/bootstrap.lisp"
                :perform (asdf:load-op (op c) (load (asdf:component-pathname c)))
                :perform (asdf:load-source-op (op c)
                           (error "ACL2 needs its compiled implementation. Use ASDF:LOAD-SYSTEM.")))
               (acl2-implementation-file "acl2-fns" :host-reader-p t)
               (:file "lispworks/characters")
               (:module "implementation" :pathname "" :serial t
                :components
                #.(loop for name in (let ((*features* (remove :acl2-par *features*))
                                          (*read-eval* nil))
                                      (uiop:read-file-form
                                       (merge-pathnames "acl2-files"
                                                        (uiop:pathname-directory-pathname *load-truename*))))
                        unless (equal name "defpkgs")
                          collect (if (equal name "proof-builder-pkg")
                                      `(acl2-package-file ,(concatenate 'string name ".lisp"))
                                      `(acl2-implementation-file ,name))))
               (acl2-package-file "defpkgs.lisp")
               (:file "lispworks/api"))
  :in-order-to ((asdf:test-op (asdf:test-op "acl2/tests"))))

(asdf:defsystem "acl2/tests"
  :depends-on ("acl2")
  :components ((:file "lispworks/tests"))
  :perform (asdf:test-op (op system) (uiop:symbol-call :lw-acl2-tests :run)))
