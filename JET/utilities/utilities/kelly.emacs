(defvar running-epoch (boundp 'epoch::version))
(defvar running-under-x (boundp 'x-synchronize))

(quietly-read-abbrev-file "~kelly/.abbrev_defs")

(setq-default comment-column 70)

; Supercite setup
(autoload 'sc-cite-original "supercite" "Supercite 3.1" t)
(autoload 'sc-submit-bug-report "supercite" "Supercite 3.1" t)
(add-hook 'mail-citation-hook 'sc-cite-original)
(setq news-reply-header-hook nil)

(setq c-mode-hook
      '(lambda () (kill-local-variable 'comment-column)
                  (abbrev-mode 1)))
;(setq load-path (cons (expand-file-name "/usr/local/lib/emacs/epoch-lisp") load-path))
(setq load-path (cons (expand-file-name "~/.elisp") load-path))

(add-hook 'mail-setup-hook 'mail-abbrevs-setup)
(setq rmail-file-name (expand-file-name "~/.mail/RMAIL"))

(autoload 'html-mode "html-mode" "HTML major mode." t)

;(set-variable 'c-tab-always-indent nil)
;(setq c-indent-level 6
;      c-continued-statement-offset 6
;      c-brace-offset 0
;      c-brace-imaginary-offset 0
;      c-argdecl-indent 0
;      c-label-offset -3
;      comment-multi-line t)


(load "init-cc-mode")

;(autoload 'c++-mode "c++-mode" nil t nil)

(if running-epoch (load-file "~/.elisp/epoch-setup.elc"))

(setq auto-mode-alist
  (append '(
            ("-help"    . text-mode)
            ("\\.C$"    . c++-mode)
            ("\\.cc$"   . c++-mode)
            ("\\.l$"    . c-mode)
            ("\\.nr$"   . nroff-mode)
            ("\\.x$"    . c-mode)
            ("\\.html$" . html-mode)
            )
          auto-mode-alist))

; (setq default-mode-line-format
;   (append nil
;         '("%1*-Emacs: %b // "
;           global-mode-string
;           "   %[("
;           mode-name
;           minor-mode-alist
;           "%n"
;           mode-line-process
;           ")%]-"
;           (-3 . "%p")
;           "-%-"
;           )))


(setq shell-prompt-pattern      "^[^})]*[})] *")
(setq fundamental-mode-hook     'turn-on-auto-fill)
(setq text-mode-hook            'turn-on-auto-fill)


(cond ((boundp 'x-display-name)
       (add-hook 'emacs-lisp-mode-hook (function
                                        (lambda () (font-lock-mode 1))))
       (add-hook 'c-mode-hook (function (lambda () (font-lock-mode 1))))
       (setq lisp-mode-hook '(lambda () (font-lock-mode 1)))
       (setq c++-mode-hook '(lambda () (font-lock-mode 1)))
       (setq perl-mode-hook '(lambda () (font-lock-mode 1)))
       (setq tex-mode-hook '(lambda () (font-lock-mode 1)))
       (setq texinfo-mode-hook '(lambda () (font-lock-mode 1)))
       (setq postscript-mode-hook '(lambda () (font-lock-mode 1)))
       (setq dired-mode-hook '(lambda () (font-lock-mode 1)))
       (setq ada-mode-hook '(lambda () (font-lock-mode 1)))
       (setq rmail-mode-hook '(lambda () (font-lock-mode 1)))
       (setq mail-mode-hook '(lambda () (font-lock-mode 1)))
       (setq makefile-mode-hook '(lambda () (font-lock-mode 1)))
       (setq tcl-mode-hook '(lambda () (font-lock-mode 1)))       
       (setq html-mode-hook '(lambda () (font-lock-mode 1)))

       (setq mouse-yank-at-point t)

       (set-face-foreground 'bold-italic          "Red")
       (set-face-background 'secondary-selection  "yellow")

       (make-face 'string-constants)
       (make-face 'func-names)
       (make-face 'datatypes)
       (make-face 'docstrings)

       (set-face-foreground 'string-constants "green4")
       (set-face-foreground 'func-names "Blue")
       (set-face-foreground 'datatypes "violetred2")
       (set-face-background 'docstrings "PaleTurquoise")

       (set-face-background 'region "lightgray")

       (make-face-bold 'string-constants)
       (make-face-bold 'func-names)
;       (set-face-font 'bold-italic "-b&h-lucidatypewriter-bold-r-normal-sans-13-*-*-*-*-*-*-*")
       (setq font-lock-comment-face         'bold)
       (setq font-lock-string-face          'string-constants)
       (setq font-lock-function-name-face   'func-names)
       (setq font-lock-keyword-face         'bold-italic)
       (setq font-lock-doc-string-face      'docstrings)
       (setq font-lock-type-face            'datatypes)
       ))

(setq backup-by-copying         t)
(setq backup-by-copying-when-linked t)

(global-set-key [f4]            'next-error)
(global-set-key [?\C-2]         'set-mark-command)
(global-set-key [?\M-s]         'center-line)
(global-set-key [?\C-x?\C-q]    'toggle-read-only)
(define-key global-map "       "   'indent-relative)
(define-key global-map ";"    'kill-comment)
(define-key global-map ""   'set-mark-command)
(define-key global-map "\eg"    'goto-line)
(define-key global-map "\e="    'what-line)
(define-key global-map "\b"     'backward-delete-char-untabify)
(define-key global-map "\eh"    'help-for-help)
(define-key global-map "\ei"    'indent-region)
(define-key global-map "\ee"    'eval-current-buffer)
(define-key global-map "\eP"    'set-target-marker)
(define-key global-map "\ep"    'goto-target-marker)
(define-key global-map "\ek"    'kill-compilation)
(define-key global-map "\em"    'compile)
(define-key global-map "r"     'rmail)
(define-key mail-mode-map "\C-n" 'mail-abbrev-next-line)
(define-key mail-mode-map "\M->" 'mail-abbrev-end-of-buffer)


(setq auto-mode-alist
      (append '(("\\.C$"  . c++-mode)
                ("\\.cc$" . c++-mode)
                ("\\.H$" . c++-mode)
                ("\\.hh$" . c++-mode)
                ("[Mm]akefile" . makefile-mode)
                ("\\.c$"  . c-mode)
                ("\\.h$"  . c-mode))
              auto-mode-alist))


(require 'dired)
(require 'ange-ftp)

(setq minibuffer-max-depth nil)

(put 'eval-expression 'disabled nil)
(server-start)
