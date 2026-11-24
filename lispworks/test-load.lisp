;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

;;; Load in a fresh LispWorks listener to test the host as well as the API.
(in-package #:cl-user)

(require "asdf")

(asdf:load-asd (merge-pathnames "../acl2.asd" *load-truename*))

(let ((package *package*)
      (reader *readtable*)
      (features (copy-list *features*))
      (directory *default-pathname-defaults*)
      (format stream::*default-external-format*)
      (detection sys:*file-encoding-detection-algorithm*)
      (debugger *debugger-hook*)
      (source-debugging (hcl:source-debugging-on-p))
      (def-package (find-package "DEF"))
      (native-upcase (funcall (symbol-function 'char-upcase) (code-char 255))))
  (asdf:test-system "acl2")
  (asdf:load-system "acl2")             ; must reuse the live world
  (assert (eq package *package*))
  (assert (eq reader *readtable*))
  (assert (equal features *features*))
  (assert (equal directory *default-pathname-defaults*))
  (assert (equal format stream::*default-external-format*))
  (assert (equal detection sys:*file-encoding-detection-algorithm*))
  (assert (eq debugger *debugger-hook*))
  (assert (eq source-debugging (hcl:source-debugging-on-p)))
  (assert (eq def-package (find-package "DEF")))
  (assert (char= native-upcase (funcall (symbol-function 'char-upcase) (code-char 255)))))
(format t "~&LispWorks host checks passed.~%")
