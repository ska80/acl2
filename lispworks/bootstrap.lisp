;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

;;; ASDF loads this file before compiling or loading any ACL2 implementation file.
(in-package #:cl-user)

#-lispworks
(eval-when (:compile-toplevel :load-toplevel :execute)
  (error "The ACL2 ASDF library requires LispWorks. Use make for other hosts."))

;; ACL2 reserves package names beginning with the four letters ACL2.
(defpackage #:lw-acl2
  (:use #:cl)
  (:export #:submit
           #:acl2-error
           #:rejected-form
           #:with-acl2))

(in-package #:lw-acl2)

(defvar *world-lock* (mp:make-lock :name "ACL2 world"))

(defvar *inside-acl2* nil)

(defvar *world-ready* nil)

(defvar *build-features* nil)

(declaim (special cl-user::*acl2-exit-lisp-hook*))

(defun reject-exit (status)
  (error "Embedded ACL2 requested process exit (status ~D)." status))

(defun call-with-context (thunk directory readtable)
  (mp:with-lock (*world-lock*)
    (let ((*inside-acl2* t)
          (*features* (or *build-features* (cons :acl2-asdf (copy-list *features*))))
          (*package* (or (find-package "ACL2") (find-package "CL-USER")))
          (*readtable* readtable)
          (*read-base* 10)
          (*read-default-float-format* 'double-float)
          (*default-pathname-defaults* directory)
          (*debugger-hook* *debugger-hook*)
          (cl-user::*acl2-exit-lisp-hook* 'reject-exit)
          (stream::*default-external-format* '(:latin-1 :eol-style :lf))
          (sys:*file-encoding-detection-algorithm*
            (if *build-features* '(cl-user::our-file-encoding)
                sys:*file-encoding-detection-algorithm*)))
      (compiler:with-optimization-level
        (when *build-features*
          (uiop:symbol-call :acl2 :proclaim-optimize))
        (funcall thunk)))))

(defun source-directory ()
  (asdf:system-source-directory "acl2"))

;; Do not read make's acl2r.lisp or load the user's ACL2 customization files.
;; These ASDF artifacts describe the standard serial logic, independent of the
;; last executable built in the source tree.
(when (or (find-package "BIB")
          (some #'(lambda (pkg)
                    (some #'(lambda (name)
                              (uiop:string-prefix-p "ACL2" name))
                          (cons (package-name pkg) (package-nicknames pkg))))
                (list-all-packages))
          (some #'(lambda (f)
                    (uiop:string-prefix-p "ACL2" (symbol-name f)))
                *features*)
          (intersection
           '(:non-standard-analysis :static-hons :write-arithmetic-goals)
           *features*))
  (error "The serial ACL2 library needs an image without ACL2 build features or existing ACL2* or BIB packages."))
(call-with-context #'(lambda ()
                       (load "acl2-init.lisp")
                       (setf *build-features* *features*))
                   (source-directory) (copy-readtable nil))

;; This file is loaded as source: ACL2 and its macros now exist.
(defun call-with-build-context (thunk &optional host-reader-p)
  (when *world-ready*
    (error "Cannot reload the ACL2 implementation into a live world. Use a fresh image."))
  (let ((*compile-print* nil))
    (call-with-context #'(lambda ()
                           (acl2::with-warnings-suppressed (funcall thunk)))
                       (source-directory)
                       (if host-reader-p acl2::*host-readtable* acl2::*acl2-readtable*))))
