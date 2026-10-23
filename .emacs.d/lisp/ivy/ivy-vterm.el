;; -*- lexical-binding: nil; -*-

(require 'vterm)

(defun ivy/new-vterm ()
  (interactive)
  (let* ((vterm-name (generate-new-buffer-name "vterm")))
    (vterm vterm-name)))

(provide 'ivy-vterm)
