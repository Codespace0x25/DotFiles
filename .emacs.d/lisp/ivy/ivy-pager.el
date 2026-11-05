;;; ivy-pager.el --- Less-like file pager -*- lexical-binding: t; -*-

(require 'ansi-color)

(defgroup ivy/pager nil
  "A less-like pager."
  :group 'tools)

(defcustom ivy/pager-buffer-suffix " *pager*"
  "Suffix appended to pager buffer names."
  :type 'string
  :group 'ivy/pager)

(defun ivy/pager-buffer-name (filename)
  "Generate a pager buffer name for FILENAME."
  (concat (file-name-nondirectory filename)
          ivy/pager-buffer-suffix))

(define-derived-mode ivy/pager-mode special-mode "Pager"
  "Major mode for read-only pager buffers."
  (setq-local truncate-lines t)
  (setq-local cursor-type nil)
  (setq-local scroll-conservatively 101))

(defun ivy/pager-quit ()
  "Close the pager."
  (interactive)
  (quit-window t))

(defun ivy/pager-file (filename)
  "Open FILENAME in pager mode."
  (interactive "fFile: ")
  (let* ((filename (expand-file-name filename))
         (buffer (get-buffer-create
                  (ivy/pager-buffer-name filename))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert-file-contents filename))
      (ivy/pager-mode)
      (setq-local buffer-file-name nil)
      (setq-local default-directory
                  (file-name-directory filename))
      (ansi-color-apply-on-region (point-min) (point-max)))
    (pop-to-buffer buffer)))

(defun ivy/pager-buffer (buffer)
  "Display BUFFER in pager mode."
  (interactive "bBuffer: ")
  (with-current-buffer buffer
    (ivy/pager-mode)
    (ansi-color-apply-on-region (point-min) (point-max)))
  (pop-to-buffer buffer))

(provide 'ivy-pager)
;;; ivy-pager.el ends here
