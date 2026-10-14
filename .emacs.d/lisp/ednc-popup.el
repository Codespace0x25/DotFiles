;;; ednc-popup.el --- Show EDNC notifications using child frame popups  -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2025 Akib Azmain Turja.

;; Author: Akib Azmain Turja <akib@disroot.org>
;; Created: 2024-07-09
;; Version: 0.0.1
;; Package-Requires: ((emacs "26.1") (posframe "1.4.3"))
;; Keywords: unix frames
;; URL: https://codeberg.org/akib/emacs-ednc-popup

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Show EDNC notifications using child frame popups.

;; Add the following to your init file:

;;     (add-hook 'ednc-notification-presentation-functions
;;               #'ednc-popup-presentation-function)


;;; Code:

(require 'ednc)
(require 'posframe)

(defgroup ednc-popup nil
  "Show desktop notifications using child frame popups."
  :group 'unix
  :group 'frames
  :link '(url-link "https://codeberg.org/akib/emacs-ednc-popup")
  :prefix "ednc-popup-")

(defcustom ednc-popup-width 40
  "Width of notification popups."
  :type 'natnum)

(defcustom ednc-popup-max-height 5
  "Maximum height of notification popups."
  :type 'natnum)

(defcustom ednc-popup-timeout 10
  "Timeout of non-critical notification popups."
  :type 'number)

(defcustom ednc-popup-max-count 4
  "Maximum count of notifications to show at a time."
  :type 'natnum)

(defcustom ednc-popup-border-width 1
  "Border width of popup."
  :type 'natnum)

(defvar ednc-popup-frame-parameters-overrides nil
  "Popup frame parameter overrides.")

(defface ednc-popup '((t :inherit default))
  "Default face for EDNC notification popup.")

(defface ednc-popup-app-name '((t :inherit bold))
  "Face used to display app name in popup.")

(defface ednc-popup-summary nil
  "Face used to display summary text in popup.")

(defface ednc-popup-body '((t :inherit shadow))
  "Face used to display body text in popup.")

(defface ednc-popup-border '((t :foreground "white"))
  "Border face.  Only foreground is used, others are ignored.")

(defface ednc-popup-hide '((t :inherit warning))
  "Face to use for hide button.")

(defface ednc-popup-dismiss '((t :inherit error))
  "Face to use for dismiss button.")

(defface ednc-popup-critical '((t :inherit error))
  "Face to use for app name in critical notifications.")

(defvar ednc-popup--notification nil
  "The notification object this buffer corresponds to.")

(defvar ednc-popup--active-notifications nil
  "List of notifications being displayed.")

(defvar ednc-popup--frame nil
  "Popup frame displaying current buffer.")

(defvar ednc-popup--parent-frame nil
  "Popup frame displaying current buffer.")

(defvar ednc-popup--truncation-frame nil
  "Popup frame used when notifications are truncated.")

(define-minor-mode ednc-popup--buffer-mode "."
  :keymap (let ((map (make-sparse-keymap)))
            (dotimes (i 7)
              (dolist (k '(mouse down-mouse drag-mouse
                                 double-mouse triple-mouse))
                (keymap-set map (format "<%s-%s>" k (1+ i))
                            #'ignore)))
            (keymap-set map "<wheel-left>" #'ignore)
            (keymap-set map "<wheel-right>" #'ignore)
            (keymap-set map "<wheel-up>" #'ednc-popup-scroll)
            (keymap-set map "<wheel-down>" #'ednc-popup-scroll)
            (keymap-set map "<mouse-1>" #'ednc-popup-invoke)
            map))

(defun ednc-popup--setup-buffer ()
  "Setup current buffer for being displayed in a popup."
  (setq-local display-line-numbers nil)
  (setq-local frame-title-format "")
  (setq-local left-margin-width nil)
  (setq-local right-margin-width nil)
  (setq-local left-fringe-width nil)
  (setq-local right-fringe-width nil)
  (setq-local fringes-outside-margins 0)
  (setq-local fringe-indicator-alist nil)
  (setq-local show-trailing-whitespace nil)
  (setq-local mode-line-format nil)
  (setq-local header-line-format nil)
  (setq-local cursor-type nil)
  (setq-local cursor-in-non-selected-windows nil)
  (setq-local mouse-1-click-follows-link t)
  (visual-line-mode +1)
  (face-remap-add-relative 'default 'ednc-popup)
  (ednc-popup--buffer-mode +1))

(defun ednc-popup--make-buffer (notif)
  "Make buffer for notification NOTIF."
  (let ((buffer (generate-new-buffer
                 (format " *ednc-popup: %i*"
                         (ednc-notification-id notif)))))
    (setf (alist-get 'ednc-popup--buffer
                     (ednc-notification-amendments notif))
          buffer)
    (with-current-buffer buffer
      (setq-local ednc-popup--notification notif)
      (ednc-popup--setup-buffer)
      (let* ((title (ednc-notification-app-name notif))
             (hints (ednc-notification-hints notif))
             (critical-p (eq 2 (caadr (assoc "urgency" hints))))
             (maxlen (- ednc-popup-width
                        (if critical-p 15 4)))
             (face (if critical-p
                       'ednc-popup-critical
                     'ednc-popup-app-name)))
        (if (<= (string-width title) maxlen)
            (insert (propertize title 'face face)
                    (make-string (- maxlen (string-width title)) ?\s))
          (let ((l (1- maxlen)))
            (while (< (string-width title 0 l) (1- maxlen))
              (cl-incf l))
            (while (> (string-width title 0 l) (1- maxlen))
              (cl-decf l))
            (insert (propertize (substring title 0 l) 'face face)
                    "…\n")))
        (when critical-p
          (insert " " (propertize "[CRITICAL]" 'face face))))
      (insert " ")
      (insert-button
       "━"
       'face 'ednc-popup-hide
       'action (lambda (_)
                 (select-frame ednc-popup--parent-frame)
                 (ednc-popup--hide notif))
       'help-echo "mouse-1: Hide notification"
       'follow-link t)
      (insert " ")
      (insert-button
       "X"
       'face 'ednc-popup-dismiss
       'action (lambda (_)
                 (select-frame ednc-popup--parent-frame)
                 (ednc-dismiss-notification notif))
       'help-echo "mouse-1: Dismiss notification"
       'follow-link t)
      (insert "\n")
      (insert (propertize (ednc-notification-summary notif)
                          'face 'ednc-popup-summary)
              "\n")
      (insert (propertize (ednc-notification-body notif)
                          'face 'ednc-popup-body)
              "\n"))))

(defun ednc-popup--make-truncation-buffer (count)
  "Make buffer to be shown when COUNT notifications are truncated."
  (let ((buffer (get-buffer-create " *ednc-popup-truncation*")))
    (with-current-buffer buffer
      (erase-buffer)
      (ednc-popup--setup-buffer)
      (if (zerop count)
          (insert (make-string (/ (- ednc-popup-width 8) 2) ?\s))
        (let ((str (unless (zerop count) (format "+%i more" count))))
          (insert (format (format "%%-%is " (- ednc-popup-width 9))
                          str))))
      (insert-button
       "hide all"
       'face 'ednc-popup-hide
       'action (lambda (_)
                 (select-frame ednc-popup--parent-frame)
                 (ednc-popup--hide-all))
       'help-echo "mouse-1: Hide all notifications"
       'follow-link t)
      buffer)))

(defun ednc-popup--make-frame (buffer)
  "Make child frame for displaying BUFFER."
  (with-current-buffer buffer
    (setq-local ednc-popup--frame
                (make-frame
                 `(,@ednc-popup-frame-parameters-overrides
                   (title . ,(buffer-name buffer))
                   (parent-frame . nil)
                   (fullscreen . nil)
                   (no-accept-focus . t)
                   (min-width . 0)
                   (min-height . 0)
                   (border-width . 0)
                   (internal-border-width . ,ednc-popup-border-width)
                   (vertical-scroll-bars . nil)
                   (horizontal-scroll-bars . nil)
                   (left-fringe . nil)
                   (right-fringe . nil)
                   (menu-bar-lines . 0)
                   (tool-bar-lines . 0)
                   (tab-bar-lines . 0)
                   (line-spacing . 0)
                   (unsplittable . t)
                   (no-other-frame . t)
                   (undecorated . t)
                   (visibility . nil)
                   (cursor-type . nil)
                   (minibuffer . nil)
                   (left . 0)
                   (top . 0)
                   (width . ,ednc-popup-width)
                   (height . 1)
                   (no-special-glyphs . t)
                   (skip-taskbar . t)
                   (inhibit-double-buffering . nil)
                   (desktop-dont-save . t))))
    (set-face-background
     'internal-border (face-foreground 'ednc-popup-border nil t)
     ednc-popup--frame)
    (let ((frame-window (frame-root-window ednc-popup--frame)))
      (set-window-parameter frame-window 'mode-line-format 'none)
      (set-window-parameter frame-window 'header-line-format 'none)
      (set-window-buffer frame-window buffer)
      (set-window-point frame-window (point-min))
      (set-window-fringes frame-window 0 0)
      (set-window-margins frame-window 1 1)
      (set-window-dedicated-p frame-window t))
    (fit-frame-to-buffer ednc-popup--frame ednc-popup-max-height 2
                         nil nil 'vertically)
    (setq-local ednc-popup--parent-frame
                (or (bound-and-true-p exwm-workspace--current)
                    (selected-frame)))
    ednc-popup--frame))

(defun ednc-notif--delete-notification (notif)
  "Delete notfication NOTIF."
  (let ((buffer (alist-get 'ednc-popup--buffer
                           (ednc-notification-amendments notif))))
    (with-current-buffer buffer
      (delete-frame ednc-popup--frame))
    (kill-buffer buffer)))

(defun ednc-popup--update-frames ()
  "Update all popup frames."
  (dolist (notif ednc-popup--active-notifications)
    (make-frame-invisible
     (buffer-local-value
      'ednc-popup--frame
      (alist-get 'ednc-popup--buffer
                 (ednc-notification-amendments notif)))))
  (unless (frame-live-p ednc-popup--truncation-frame)
    (setq ednc-popup--truncation-frame
          (ednc-popup--make-frame
           (ednc-popup--make-truncation-buffer 0))))
  (when (frame-live-p ednc-popup--truncation-frame)
    (make-frame-invisible ednc-popup--truncation-frame))
  (let* ((frame (or (bound-and-true-p exwm-workspace--current)
                    (selected-frame)))
         (y (- (frame-pixel-height frame) 10))
         (x (- (frame-pixel-width frame) 10))
         (cnt 0)
         (pair ednc-popup--active-notifications))
    (while (and pair (< cnt ednc-popup-max-count)
                (>= (- y (frame-pixel-height
                          (buffer-local-value
                           'ednc-popup--frame
                           (alist-get 'ednc-popup--buffer
                                      (ednc-notification-amendments
                                       (car pair))))))
                    (+ 20 (frame-pixel-height
                           ednc-popup--truncation-frame))))
      (let ((frame (buffer-local-value
                    'ednc-popup--frame
                    (alist-get 'ednc-popup--buffer
                               (ednc-notification-amendments
                                (car pair))))))
        (set-frame-position frame (- x (frame-pixel-width frame))
                            (- y (frame-pixel-height frame)))
        (make-frame-visible frame)
        (cl-decf y (+ 10 (frame-pixel-height frame)))
        (cl-incf cnt)
        (setq pair (cdr pair))))
    (when (or (/= cnt (length ednc-popup--active-notifications))
              (> cnt 1))
      (ednc-popup--make-truncation-buffer
       (- (length ednc-popup--active-notifications) cnt))
      (set-frame-position
       ednc-popup--truncation-frame
       (- x (frame-pixel-width ednc-popup--truncation-frame))
       (- y (frame-pixel-height ednc-popup--truncation-frame)))
      (make-frame-visible ednc-popup--truncation-frame))))

(defun ednc-popup--hide (notif)
  "Hide notification NOTIF."
  (when (and notif (memq notif ednc-popup--active-notifications))
    (ednc-notif--delete-notification notif)
    (setq ednc-popup--active-notifications
          (delq notif ednc-popup--active-notifications))
    (ednc-popup--update-frames)))

(defun ednc-popup--hide-all ()
  "Hide all notifications."
  (dolist (notif ednc-popup--active-notifications)
    (ednc-notif--delete-notification notif))
  (setq ednc-popup--active-notifications nil)
  (ednc-popup--update-frames))

(defun ednc-popup-scroll (event)
  "Scroll up/down popup at EVENT."
  (interactive "e")
  (if (eq (event-basic-type event) 'wheel-up)
      (scroll-down 1)
    (scroll-up 1))
  (select-frame ednc-popup--parent-frame))

(defun ednc-popup-invoke (event)
  "Invoke popup notification at EVENT."
  (interactive "e")
  (let ((notif ednc-popup--notification))
    (select-frame ednc-popup--parent-frame)
    (ednc-invoke-action notif)
    (unless (caadr (assoc "resident" (ednc-notification-hints notif)))
      (ednc-dismiss-notification notif))))

;;;###autoload
(defun ednc-popup-presentation-function (old-notif new-notif)
  "Delete notification OLD-NOTIF and add notification NEW-NOTIF."
  (when (and old-notif
             (memq old-notif ednc-popup--active-notifications))
    (ednc-notif--delete-notification old-notif)
    (setq ednc-popup--active-notifications
          (delq old-notif ednc-popup--active-notifications)))
  (when new-notif
    (ednc-popup--make-buffer new-notif)
    (ednc-popup--make-frame
     (alist-get 'ednc-popup--buffer
                (ednc-notification-amendments new-notif)))
    (unless (eq 1 (caadr (assoc "urgency" (ednc-notification-hints
                                           new-notif))))
      (run-with-timer ednc-popup-timeout nil #'ednc-popup--hide
                      new-notif))
    (push new-notif ednc-popup--active-notifications))
  (ednc-popup--update-frames))

(provide 'ednc-popup)
;;; ednc-popup.el ends here
