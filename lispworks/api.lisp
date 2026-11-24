;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

(in-package #:lw-acl2)

(define-condition acl2-error (error)
  ((form :initarg :form
         :reader rejected-form))
  (:report (lambda (c stream)
             (format stream "ACL2 did not accept ~S." (rejected-form c)))))

(defun call-with-acl2 (thunk)
  (unless *world-ready* (error "ACL2 initialization did not complete."))
  (if *inside-acl2* (funcall thunk)
      (call-with-context #'(lambda ()
                             (acl2::set-initial-cbd)
                             (funcall thunk))
                         (uiop:pathname-directory-pathname *default-pathname-defaults*)
                         acl2::*acl2-readtable*)))

(defmacro with-acl2 (&body body)
  "Run trusted Lisp code with ACL2 character semantics and exclusive access to its world."
  `(call-with-acl2 #'(lambda () ,@body)))

(defun submit (form)
  "Submit one ACL2 form. Return its value, or signal ACL2-ERROR on rejection."
  (with-acl2
      (let ((acl2::state acl2::*the-live-state*)
            (*features* (cons :acl2-loop-only *features*)))
        (multiple-value-bind (erp result state)
            ;; Handle Lisp errors (including REJECT-EXIT) before the debugger.
            ;; LD can turn the nonlocal exit into its own error result on unwind.
            (handler-case
                (acl2::ld (list form) :ld-error-action :error :ld-error-triples t
                                      :ld-query-control-alist t :ld-pre-eval-filter :all
                                      :ld-verbose nil :ld-prompt nil :ld-post-eval-print nil)
              (error () (error 'acl2-error :form form)))
          (unless (and (null erp) (eq result :eof))
            (error 'acl2-error :form form))
          (let* ((entry (car (acl2::ld-history state)))
                 (value (acl2::ld-history-entry-value entry)))
            (if (member (acl2::ld-history-entry-stobjs-out entry)
                        (list acl2::*error-triple-sig* acl2::*error-triple-df-sig*)
                        :test #'equal)
                (second value)
                value))))))

;; ASDF has already loaded the implementation files and defpkgs, as LOAD-ACL2
;; would. Check INITIALIZE-ACL2's return value, not another build's disk stamp.
(call-with-build-context
 #'(lambda ()
     (set 'acl2::state acl2::*the-live-state*)
     (let ((acl2::*boot-strap-verbose* nil))
       (unless (acl2::initialize-acl2 'acl2::include-book nil)
         (error "ACL2 initialization failed. See the preceding ACL2 diagnostics.")))
     ;; Channel properties normally capture the streams of the standalone LP.
     ;; Follow each caller's bindings instead, including after a host image save.
     (let ((*standard-input* (make-synonym-stream '*standard-input*))
           (*standard-output* (make-synonym-stream '*standard-output*)))
       (acl2::setup-standard-io))
     (setf *world-ready* t))
 t)
