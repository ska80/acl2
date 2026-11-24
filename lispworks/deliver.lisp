;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil; external-format: utf-8; -*-

;;; Run with -no-restart-function -build in the saved ACL2 LispWorks image.
(in-package "ACL2")

;; Delivery removes COMPILE-FILE even at level 0. Keep the evaluator and
;; in-memory compiler for new ACL2 definitions, but don't compile books.
(set-compiler-enabled nil *the-live-state*)

(lw:deliver 'acl2-default-restart (getenv$-raw "ACL2_LW_RUNTIME") 0
            :interface nil)
