;; init.el --- EXWM setup -*- lexical-binding: t; -*-

;; ----------------------------
;; Theme
;; ----------------------------

(load-theme 'naga t)



;; ----------------------------
;; Local files
;; ----------------------------

(add-to-list 'load-path (expand-file-name "~/.emacs.d/lisp/qemuel"))
(add-to-list 'load-path (expand-file-name "~/.emacs.d/lisp/ivy"))
(add-to-list 'load-path (expand-file-name "~/.emacs.d/lisp/"))
(add-to-list 'load-path (expand-file-name "~/lisp"))
(load-file "~/lisp/init.el")

(require 'ivy-menu)
(require 'ivy-vterm)
(require 'ednc-popup)
(require 'ivy-exwm-modeline)
(require 'ivy-pager)

;; ----------------------------
;; Core requires
;; ----------------------------

(require 'evil)
(require 'which-key)
(require 'ivy)
(require 'company)
(require 'lsp-mode)
(require 'lsp-ui)
(require 'smartparens-config)
(require 'pipewire)
(require 'undo-tree)
(require 'beacon)
(require 'projectile)
(require 'buffer-move)
(require 'exwm)
(require 'exwm-randr)
(require 'ednc)
(require 'qemuel)


;; ----------------------------
;; Modeline
;; ----------------------------

(ivy-exwm-modeline-mode 1)


(add-hook 'ednc-notification-presentation-functions
          #'ednc-popup-presentation-function)



;; ----------------------------
;; UI sanity
;; ----------------------------
(set-face-attribute 'default nil
  :family "OpenDyslexic3"
  :height 100) ;; 140 = 14pt

(setq ring-bell-function 'ignore
      visible-bell t
      initial-scratch-message nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(global-display-line-numbers-mode 1)
(setq-default line-spacing 2)

(add-hook 'vterm-mode-hook  (lambda () (display-line-numbers-mode 0)))
(add-hook 'dired-mode-hook  (lambda () (display-line-numbers-mode 0)))
(add-hook 'eshell-mode-hook (lambda () (display-line-numbers-mode 0)))
(add-hook 'exwm-mode-hook   (lambda () (display-line-numbers-mode 0)))

(add-hook 'image-minor-mode-hook   (lambda () (evil-mode-enable-in-buffer 0)))
;; ----------------------------
;; Evil
;; ----------------------------

(evil-mode 1)


(define-key evil-normal-state-map (kbd "C-c f") #'lsp-format-buffer)
(define-key evil-normal-state-map (kbd "C-c a") #'lsp-execute-code-action)
;;(define-key evil-normal-state-map (kbd "C-c C-c") #'company-complete)
(defun ivy/no-delete-last-frame (orig-fun &rest args)
  (if (<= (length (frame-list)) 1)
      (message "Refusing to delete the last EXWM frame.")
    (apply orig-fun args)))

(advice-add 'delete-frame :around #'ivy/no-delete-last-frame)


;; ----------------------------
;; Which-key / Ivy
;; ----------------------------

(which-key-mode 1)


(ivy-mode 1)

;; ----------------------------
;; System Packages
;; ----------------------------

(setq system-packages-package-manager 'pacman)
(setq system-packages-use-sudo t)

;; ----------------------------
;; Company / Flycheck
;; ----------------------------

(global-company-mode 1)
(global-flycheck-mode 1)

;;(add-hook 'company-mode-hook #'company-box-mode)

(setq company-idle-delay 0.2
      company-minimum-prefix-length 2
      company-tooltip-align-annotations t
      company-tooltip-flip-when-above t
      company-backends '(company-capf))



(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
;; ----------------------------
;; LSP
;; ----------------------------


(setq lsp-prefer-capf t
      lsp-diagnostic-package :flycheck
      lsp-clients-clangd-executable "clangd"
      lsp-clients-clangd-args '("--clang-tidy")
      lsp-clients-clangd-formatting-options
      '(:PointerAlignment "Left"))



(add-hook 'c-mode-hook #'lsp-deferred)
(add-hook 'c++-mode-hook #'lsp-deferred)
(add-hook 'lsp-mode-hook #'lsp-ui-mode)

(setq lsp-ui-sideline-enable t
      lsp-ui-sideline-show-diagnostics t
      lsp-ui-sideline-show-hover nil
      lsp-ui-doc-enable t)

(with-eval-after-load 'lsp-mode
  (define-key lsp-mode-map (kbd "s-l") nil)
  (define-key lsp-mode-map (kbd "s-h") nil)
  (define-key lsp-mode-map (kbd "s-j") nil)
  (define-key lsp-mode-map (kbd "s-k") nil))

(defun ivy/format-if-lsp ()
  (when lsp-mode
    (lsp-format-buffer)))

(add-hook 'before-save-hook #'ivy/format-if-lsp)
;; ----------------------------
;; Smartparens
;; ----------------------------

(add-hook 'prog-mode-hook #'smartparens-mode)
(add-hook 'text-mode-hook #'smartparens-mode)

(show-paren-mode 1)

;; ----------------------------
;; Projectile
;; ----------------------------

(projectile-mode 1)
(setq projectile-keymap-prefix (kbd "C-c p"))

;; ----------------------------
;; Dired icons
;; ----------------------------

(setq make-backup-files nil)


(add-hook 'dired-mode-hook #'nerd-icons-dired-mode)
(add-hook 'dired-mode-hook #'dired-hide-details-mode)

;; ----------------------------
;; EXWM configuration
;; ----------------------------

(setq exwm-floating-border-color "green"
      exwm-floating-border-width 2
      exwm-systemtray-height 17)

(setq exwm-workspace-number 1)

(setq exwm-input-simulation-keys
      '(([?\C-b] . left)
        ([?\C-f] . right)
        ([?\C-p] . up)
        ([?\C-n] . down)
        ([?\C-a] . home)
        ([?\C-e] . end)
        ([?\C-v] . next)
        ([?\M-v] . prior)
        ([?\C-w] . C-x)
        ([?\M-w] . C-c)
        ([?\C-y] . C-v)))

(exwm-systemtray-mode 1)

(defun ivy/exwm-rename ()
  (exwm-workspace-rename-buffer exwm-title))

(add-hook 'exwm-update-title-hook #'ivy/exwm-rename)

;; ----------------------------
;; EXWM key-binds
;; ----------------------------
(exwm-input-set-key (kbd "M-x") #'ivy/M-x)
(exwm-input-set-key (kbd "s-M-<return>") #'eshell)
(exwm-input-set-key (kbd "s-<return>") #'ivy/new-vterm)
(exwm-input-set-key (kbd "s-b") #'ivy-switch-buffer)
(exwm-input-set-key (kbd "s-p") #'(lambda () (interactive) (message "no you don't")))
(exwm-input-set-key (kbd "s-c") #'exwm-input-release-keyboard)

;; window fockase change
(exwm-input-set-key (kbd "s-h") #'windmove-left)
(exwm-input-set-key (kbd "s-l") #'windmove-right)
(exwm-input-set-key (kbd "s-j") #'windmove-down)
(exwm-input-set-key (kbd "s-k") #'windmove-up)

;; buffer move
(exwm-input-set-key (kbd "s-M-h") #'buf-move-left)
(exwm-input-set-key (kbd "s-M-l") #'buf-move-right)
(exwm-input-set-key (kbd "s-M-j") #'buf-move-down)
(exwm-input-set-key (kbd "s-M-k") #'buf-move-up)


;; window management
(exwm-input-set-key (kbd "C-x 0") #'delete-window)
(exwm-input-set-key (kbd "C-x 1") #'delete-other-windows)
(exwm-input-set-key (kbd "C-x 2") #'split-window-below)
(exwm-input-set-key (kbd "C-x 3") #'split-window-right)

(defvar ivy/register-map (make-sparse-keymap)
  "Register commands under Super+r.")

(exwm-input-set-key (kbd "s-r") ivy/register-map)

(define-key ivy/register-map (kbd "s") #'burly-bookmark-windows)
(define-key ivy/register-map (kbd "l") #'burly-open-last-bookmark)
(define-key ivy/register-map (kbd "b") #'burly-open-bookmark)
(define-key ivy/register-map (kbd "d") #'bookmark-delete)


;; resizing
(defun ivy/resize-left  () (interactive) (window-resize nil -5 t))
(defun ivy/resize-right () (interactive) (window-resize nil  5 t))
(defun ivy/resize-up    () (interactive) (window-resize nil -3))
(defun ivy/resize-down  () (interactive) (window-resize nil  3))

(exwm-input-set-key (kbd "s-C-h") #'ivy/resize-left)
(exwm-input-set-key (kbd "s-C-l") #'ivy/resize-right)
(exwm-input-set-key (kbd "s-C-j") #'ivy/resize-down)
(exwm-input-set-key (kbd "s-C-k") #'ivy/resize-up)

;; volume (safe)
(defun ivy/vol-up   () (interactive) (when (fboundp 'pipewire-increase-volume) (pipewire-increase-volume)))
(defun ivy/vol-down () (interactive) (when (fboundp 'pipewire-decrease-volume) (pipewire-decrease-volume)))
(defun ivy/vol-mute () (interactive) (when (fboundp 'pipewire-toggle-muted)   (pipewire-toggle-muted)))

(exwm-input-set-key (kbd "s-=") #'ivy/vol-up)
(exwm-input-set-key (kbd "s--") #'ivy/vol-down)
(exwm-input-set-key (kbd "s-0") #'ivy/vol-mute)

(exwm-input-set-key (kbd "s-f") #'exwm-layout-set-fullscreen)

(defun coomer_sh ()
  (interactive)
  (call-process-shell-command "coomer" nil 0))

(when (file-regular-p "/bin/coomer")
  (exwm-input-set-key (kbd "s-e") #'coomer_sh))

(defvar screen-max-x 1366)
(defvar screen-max-y 768)

(defun ivy/mouse-move (dx dy)
  "Move the mouse cursor by DX and DY pixels."
  (interactive)
  (let* ((pos (string-split (shell-command-to-string "xdotool getmouselocation --shell")))
         (x (string-to-number (substring (nth 0 pos) 2)))
         (y (string-to-number (substring (nth 1 pos) 2)))
         (new-x (max 0 (min screen-max-x (+ x dx))))
         (new-y (max 0 (min screen-max-y (+ y dy)))))
    (call-process "xdotool" nil nil nil
                  "mousemove" "--sync"
                  (number-to-string new-x)
                  (number-to-string new-y))))

(defun ivy/mouse-left-click ()
  (interactive)
  (call-process "xdotool" nil nil nil "click" "1"))

(defun ivy/mouse-right-click ()
  (interactive)
  (call-process "xdotool" nil nil nil "click" "3"))

(exwm-input-set-key (kbd "C-<return>") #'ivy/mouse-left-click)
(exwm-input-set-key (kbd "M-<return>") #'ivy/mouse-right-click)

(defun ivy/mouse-up ()
  (interactive)
  (ivy/mouse-move 0 -10))

(defun ivy/mouse-down ()
  (interactive)
  (ivy/mouse-move 0 10))

(defun ivy/mouse-left ()
  (interactive)
  (ivy/mouse-move -10 0))

(defun ivy/mouse-right ()
  (interactive)
  (ivy/mouse-move 10 0))

(exwm-input-set-key (kbd "s-<up>") #'ivy/mouse-up)
(exwm-input-set-key (kbd "s-<down>") #'ivy/mouse-down)
(exwm-input-set-key (kbd "s-<left>") #'ivy/mouse-left)
(exwm-input-set-key (kbd "s-<right>") #'ivy/mouse-right)

;; ----------------------------
;; notifications
;; ----------------------------
(ednc-mode t)

(defun clear-notify ()
  "Clear the notification center."
  (interactive)
  (ednc-popup--hide-all))

(defun popup-notify-center ()
  "Pop up the notification center."
  (interactive)
  (switch-to-buffer "*ednc-log*"))


(exwm-input-set-key (kbd "s-n") #'clear-notify)
(exwm-input-set-key (kbd "s-N") #'popup-notify-center)

;; ----------------------------
;; Startup programs
;; ----------------------------

(dolist (cmd '(("setxkbmap" "setxkbmap" "-option" "caps:super")
               ("nm-applet" "nm-applet")))
  (when (executable-find (cadr cmd))
    (apply #'start-process (car cmd) nil (cdr cmd))))
(start-process
 "polkit-gnome-authentication-agent-1"
 nil
 "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

;; ----------------------------
;; GC tuning
;; ----------------------------

(setq gc-cons-threshold (* 50 1000 1000))








;; ----------------------------
;; EXWM START (always)
;; ----------------------------


(exwm-wm-mode 1)

(transparency 99)
;; ----------------------------
;; QEMUEL
;; ----------------------------

(qemuel-init)

(find-file "~")



;;(olivia/M-x)





;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("131e0902a346cbd3cb1f944cdd6bd9bf0a3c5270528741ac8b303bd9b2819af5"
     "deb645f30fd25191b6e8d0f397cc1dd172a352f22094747be2ff527394cc9f57"
     "d44b39527b22d5afe361d35bf894893a21ba4279a14fd1037a909150f5f74a3a"
     "07db9f711e1a2980b8a865f1f9f58cb7f0125b8b11929bcc7502f5e7930ba9a7"
     "98fa2c2a5c9cc2e3fa435a42727f604b1dea5b4cad4aaef47942f2f9ee1e0a1b"
     "e363798cd73212f929b3c184410a60c78961c789c38f363280937ce811704c44"
     default))
 '(package-selected-packages
   '(2048-game basic-mode beacon buffer-move burly company company-box
	       company-glsl crystal-mode cuda-mode
	       dashboard-hackernews docker-cli ednc enotify evil exwm
	       exwm-modeline firefox-javascript-repl flycheck
	       flycheck-ocaml gradle-mode hackernews hackernews-modern
	       helm ivy ivy-todo keycast lsp-mode lsp-python-ms lsp-ui
	       naga-theme nasm-mode nerd-icons nerd-icons-dired
	       nix-ts-mode objed ocaml-ts-mode on-screen pager
	       pdf-view-restore pipewire plan9-theme projectile python
	       smartparens system-packages system-specific-settings
	       systemd theme-buffet tramp-theme tron-legacy-theme
	       undo-tree vterm vterm-toggle web-server year-1984-theme
	       zk-desktop)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
