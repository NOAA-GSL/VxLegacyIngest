From: mdj@sanscalc.nada.kth.se (Mikael Djurfeldt)
Reply-To: Mikael Djurfeldt <djurfeldt@nada.kth.se>
Newsgroups: gnu.emacs.sources
Subject: find-error.el
Date: 24 Aug 1995 20:03:31 +0200
Organization: Royal Institute of Technology, Stockholm, Sweden
Mime-Version: 1.0
Content-Type: text/plain
Content-Transfer-Encoding: 8bit
Message-ID: <xy7pwhvch71.fsf@sanscalc.nada.kth.se>

;;; NAME:	 find-error.el
;;; SYNOPSIS:	 A GNU Emacs extension which finds an error in an emacs
;;;		 library file and positions point there.
;;; VERSION:	 1.0
;;; LAST CHANGE: Can't remember.
;;; CREATED:	 Ages ago...
;;; AUTHOR:	 Mikael Djurfeldt <djurfeldt@nada.kth.se>
;;; COPYRIGHT:	 (C) Mikael Djurfeldt 1995
;;;
;;;  Verbatim copies of this file may be freely redistributed.
;;;
;;;  Modified versions of this file may be redistributed provided that this
;;;  notice remains unchanged, the file contains prominent notice of
;;;  author and time of modifications, and redistribution of the file
;;;  is not further restricted in any way.
;;;
;;;  This file is distributed `as is', without warranties of any kind.
;;;
;;; USAGE:
;;;  Issue the `find-error' command in a buffer containing erroneous
;;;  emacs lisp code.
;;;
;;; BUGS:
;;;  The code in the buffer is evaluated several times.  This should
;;;  not be any problem since emacs libraries *should* be written
;;;  so that they can be evaluated many times.
;;;

(defun find-error ()
  (interactive)
  (let ((lower-bound 1)	error)
    (save-excursion
      (let (half
	    (low 1)
	    (high (fe-count-sexps)))
	(if error (setq lower-bound (point))
	  (setq high (1+ high))
	  (while (< low high)
	    (if (fe-try-parse lower-bound
			      (fe-sexp-position
			       (setq half (/ (+ low high) 2))))
		(progn (setq low (1+ half))
		       (forward-sexp 2)
		       (backward-sexp)
		       (while (not (bolp))
			 (backward-sexp))
		       (setq lower-bound (point)))
	      (setq high half)))
	  (backward-sexp)
	  (setq lower-bound (point)))))
    (if (not error) (message "No errors found!")
      (goto-char lower-bound)
      (message "%s" error))))

(defun fe-try-parse (from to)
  (condition-case err
      (progn (eval-region from to) t)
    (error (progn (setq error err) nil))))

(defun fe-count-sexps ()
  (goto-char (point-max))
  (condition-case err
      (let ((n 0))
	(while (not (bobp))
	  (backward-sexp)
	  (setq n (1+ n)))
	n)
    (error (setq error err))))

(defun fe-sexp-position (n)
  (goto-char 1)
  (forward-sexp n)
  (if (or (not (eobp))
	  (save-excursion
	    (goto-char 1)
	    (forward-sexp (1- n))
	    (skip-chars-forward " \t\n")
	    (not (eobp))))
      (backward-sexp))
  (point))
