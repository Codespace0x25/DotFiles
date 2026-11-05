;;; ivy-exwm-headline.el --- System information header -*- lexical-binding: t; -*-

;;; Code:

(defvar ivy-exwm-headline-format
  '(:eval (ivy-exwm-headline--format))
  "System information displayed in the header line.")

(defun ivy-exwm-headline--format ()
  "Generate system information for the header line."
  "CPU ... | RAM ... | SWAP ... | DISK ... | NET ...")

;;;###autoload
(define-minor-mode ivy-exwm-headline-mode
  "Display system information in the header line."
  :global t
  (if ivy-exwm-headline-mode
      (setq-default header-line-format ivy-exwm-headline-format)
    (setq-default header-line-format nil)))

(provide 'ivy-exwm-headline)

;;; ivy-exwm-headline.el ends here
