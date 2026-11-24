;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

(defpackage #:lw-acl2-tests
  (:use #:cl)
  (:export #:run))

(in-package #:lw-acl2-tests)

(defun test-concurrent-callers ()
  ;; Never start or stop multiprocessing on behalf of the host.
  (when mp:*current-process*
    (let* ((answers (make-array 4 :initial-element nil))
           (workers
             (loop for i below (length answers)
                   collect (mp:process-run-function
                            "ACL2 test caller" nil
                            #'(lambda (n)
                                (setf (aref answers n)
                                      (handler-case
                                          (loop repeat 5 always
                                                         (= (1+ n) (lw-acl2:submit `(+ 1 ,n))))
                                        (error (c) c))))
                            i))))
      (dolist (worker workers)
        (assert (mp:process-join worker :timeout 30)))
      (assert (every #'(lambda (answer) (eq answer t)) answers) () "~S" answers))))

(defun run ()
  ;; Use Lisp objects, not printed output, to test success and rejection.
  (assert (= 42 (lw-acl2:submit '(+ 40 2))))
  (assert (equal '(1 2) (lw-acl2:submit '(acl2::mv 1 2))))
  (assert (eq :done (lw-acl2:submit '(acl2::value-triple :done))))
  (lw-acl2:submit '(defun acl2::embedding-pair (acl2::x) (cons acl2::x acl2::x)))
  (assert (equal '(3 . 3) (lw-acl2:submit '(acl2::embedding-pair 3))))
  (lw-acl2:submit '(acl2::defthm acl2::car-of-embedding-pair
                    (equal (car (acl2::embedding-pair acl2::x)) acl2::x)))
  (flet ((rejected-p (form)
           (handler-case (progn (lw-acl2:submit form) nil)
             (lw-acl2:acl2-error (c) (eq form (lw-acl2:rejected-form c))))))
    (let ((diagnostics (with-output-to-string (*standard-output*)
                         (assert (rejected-p '(acl2::thm (equal 1 2)))))))
      (assert (search "ACL2 Error" diagnostics :test #'char-equal)))
    (assert (rejected-p '(acl2::quit 7))))
  (assert (null (lw-acl2:submit '(car nil))))
  (assert (equal '(4 . 4) (lw-acl2:submit '(acl2::embedding-pair 4))))

  ;; Both a guard-verified ACL2 function and the host must retain their own
  ;; character semantics. STRING-UPCASE must still accept CL designators and keys.
  (lw-acl2:submit '(defun acl2::embedding-upcase (acl2::c)
                    (declare (acl2::xargs :guard (characterp acl2::c)))
                    (char-code (char-upcase acl2::c))))
  (lw-acl2:submit '(acl2::comp 'acl2::embedding-upcase))
  (dolist (code '(223 255))
    (assert (= code (lw-acl2:submit `(acl2::embedding-upcase ,(code-char code)))))
    (assert (= code (lw-acl2:with-acl2 (acl2::embedding-upcase (code-char code))))))
  (assert (string= "aBc" (funcall (symbol-function 'string-upcase) "abc" :start 1 :end 2)))
  (assert (string= "FOO" (funcall (symbol-function 'string-upcase) :foo)))
  (test-concurrent-callers)
  (format t "~&ACL2 embedding tests passed.~%"))
