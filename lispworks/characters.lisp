;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

(in-package #:lw-acl2)

;; The standalone image replaces these CL functions process-wide. In a shared
;; image ACL2 needs the same 8-bit results, but only while this thread runs
;; ACL2. Outside that scope, use the application's original functions.
(lw:defadvice (lower-case-p acl2-case :around) (c)
  (if *inside-acl2* (acl2::lower-case-p-new c) (lw:call-next-advice c)))

(lw:defadvice (char-upcase acl2-case :around) (c)
  (if *inside-acl2* (acl2::char-upcase-new c) (lw:call-next-advice c)))

(lw:defadvice (string-upcase acl2-case :around) (s &rest keys)
  (if (and *inside-acl2* (stringp s) (null keys))
      (acl2::string-upcase-new s)
      (apply #'lw:call-next-advice s keys)))

;; Run the same suitability tests as make, without deleting make's status file.
(call-with-build-context
 #'(lambda () (load "acl2-check.lisp")) t)
