;; -*- lexical-binding: nil; -*-
;; ----------------------------
;; Server Starter
;; i like this fretcher.
;; ----------------------------

(require 'server)
(unless (server-running-p)
  (server-start))

;; ----------------------------
;; Package system
;; ----------------------------

(require 'package)

(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("gnu"   . "https://elpa.gnu.org/packages/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(dolist (pkg '(exwm evil which-key ivy naga-theme
                    lsp-mode lsp-ui company smartparens company-box
                    pipewire undo-tree vterm vterm-toggle
                    beacon ednc flycheck projectile
                    nerd-icons nerd-icons-dired
                    buffer-move system-packages burly))
  (unless (package-installed-p pkg)
    (package-install pkg)))


