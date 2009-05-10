;;; completion-ignored-build.el --- some built completion-ignored-extensions

;; Copyright 2008 Kevin Ryde
;;
;; Author: Kevin Ryde <user42@zip.com.au>
;; Version: 1
;; Keywords: convenience
;; URL: http://www.geocities.com/user42_kevin/completion-ignored-build/
;;
;; completion-ignored-build.el is free software; you can redistribute it
;; and/or modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at your
;; option) any later version.
;;
;; completion-ignored-build.el is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
;; Public License for more details.
;;
;; You can get a copy of the GNU General Public License online at
;; <http://www.gnu.org/licenses>.


;;; Commentary:
;;
;; This is some dynamic additions to `completion-ignored-extensions'
;; designed to ignore various built files.  See the
;; `completion-ignored-build-enable' docstring for more.

;;; Emacsen:
;;
;; Designed for Emacs 21 and 22, does nothing in XEmacs 21.

;;; Install:
;;
;; Put completion-ignored-build.el somewhere in your `load-path', and in
;; your .emacs add
;;
;;     (require 'completion-ignored-build)
;;
;; or to defer it until you first use the minibuffer
;;
;;     (add-hook 'minibuffer-setup-hook
;;               (lambda () (require 'completion-ignored-build)))
;;

;;; History:
;;
;; Version 1 - the first version


;;; Code:

;; xemacs21 lacks `minibuffer-completing-file-name',
;; `minibuffer-contents-no-properties' and `file-expand-wildcards'.  The
;; first two can be worked around (looking for `minibuffer-completion-table'
;; equal to `read-directory-name-internal' to recognise a read-file-name,
;; and just `buffer-string' for the contents), but `file-expand-wildcards'
;; is too much to want to copy to here.

;; quieten the byte compile a bit
(require 'advice)

;; In emacs22 `read-file-name' is C code and ignores advice set on
;; `file-name-completion' and `file-name-all-completions', so instead mangle
;; from the command funcs like `minibuffer-complete'.
;;
(defconst completion-ignored-build--advised-functions
  '(minibuffer-complete
    minibuffer-complete-word
    minibuffer-complete-and-exit))

(dolist (func completion-ignored-build--advised-functions)
  (ad-add-advice
   func
   '(completion-ignored-build
     nil  ;; PROTECT
     t    ;; ENABLED
     (advice
      lambda nil
      "Build additions to `completion-ignored-extensions'."
      (if (and (boundp 'minibuffer-completing-file-name) ;; emacs21, emacs22
               minibuffer-completing-file-name)
          (let ((completion-ignored-extensions
                 completion-ignored-extensions))
            (completion-ignored-build-apply)
            ad-do-it)
        ad-do-it)))
   'around
   'first)
  (ad-activate func))

;;;###autoload
(defun completion-ignored-build-enable ()
  "Enable `completion-ignored-build' feature.
This feature uses some slightly hairy setups to generate
additions to `completion-ignored-extensions' to ignore built
files for `read-file-name'.  Currently the setups are

* Ignore Makefile.in if there's a Makefile.am (Automake).

* Ignore Makefile if there's any of Makefile.am (Automake),
  Makefile.in (raw configury), config.status (Autoconf build
  dir), or Makefile.PL (Perl ExtUtils::MakeMaker).

* Ignore configure if there's a config.status (Autoconf build
  dir).

* Ignore Build if there's a Build.PL (Perl Module::Build).

* Ignore .info if there's a .texi (Texinfo).

* Ignore .c if there's a .xs (Perl xsubs).

The suffix rules might not work too well if you've got say a
mixture of generated and manual .c files in one directory.
completion-ignored-build isn't (yet) setup to notice which
individual files are generated.

As usual for `completion-ignored-extensions' you can always type
in a full name explicitly if it's being wrongly ignored by the
completions."

  (interactive)
  (dolist (func completion-ignored-build--advised-functions)
    (ad-enable-advice func 'around 'completion-ignored-build)
    (ad-activate func)))

;;;###autoload
(defun completion-ignored-build-disable ()
  "Disable `completion-ignored-build' feature."
  (interactive)
  (dolist (func completion-ignored-build--advised-functions)
    (ad-disable-advice func 'around 'completion-ignored-build)
    (ad-activate func)))

(defun completion-ignored-build-apply ()
  "Make some additions to `completion-ignored-extensions'.
See `completion-ignored-build-enable'."
  (let ((contents (minibuffer-contents-no-properties))) ;; emacs21,22
    (if (string-match ".*//" contents)
        (setq contents (replace-match "/" t t contents)))
    (let ((dir (file-name-directory contents)))

      ;; perl .xs xsub generates .c
      (if (file-expand-wildcards (concat dir "*.xs"))
          (add-to-list 'completion-ignored-extensions ".c"))

      ;; texinfo .texi generates .info
      (if (file-expand-wildcards (concat dir "*.texi"))
          (add-to-list 'completion-ignored-extensions ".info"))

      ;; automake Makefile.am generates Makefile.in
      (if (file-exists-p (concat dir "Makefile.am"))
          (add-to-list 'completion-ignored-extensions "Makefile.in"))

      ;; various generated Makefile
      (if (or (file-exists-p (concat dir "Makefile.am")) ;; automake
              (file-exists-p (concat dir "Makefile.in")) ;; generic autoconf
              (file-exists-p (concat dir "Makefile.PL")) ;; perl
              (file-exists-p (concat dir "config.status"))) ;; auto* builddir
          (add-to-list 'completion-ignored-extensions "Makefile"))

      ;; autoconf configure script
      (if (or (file-exists-p (concat dir "configure.in")) ;; autoconf srcdir
              (file-exists-p (concat dir "configure.ac")) ;; autoconf srcdir
              (file-exists-p (concat dir "config.status"))) ;;autoconf builddir
          (add-to-list 'completion-ignored-extensions "configure"))

      ;; perl Build.PL (Module::Build) generates Build script
      (if (file-exists-p (concat dir "Build.PL"))
          (add-to-list 'completion-ignored-extensions "Build")))))

(provide 'completion-ignored-build)

;;; completion-ignored-build.el ends here
