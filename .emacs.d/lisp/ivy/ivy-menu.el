;; -*- lexical-binding: nil; menu.el-*-

(require 'ivy)
(require 'exwm)
(require 'url-util)

;; ----------------------------
;; Transparency helper
;; ----------------------------
(defun transparency (value)
  "Sets the transparency of the frame window. 0=transparent/100=opaque"
  (interactive "nTransparency Value 0 - 100 opaque:")
  (set-frame-parameter (selected-frame) 'alpha value))

;; ============================================================
;; 🌐 UNIFIED WEB SYSTEM (FAST + TYPE-FIRST)
;; ============================================================

(defvar ivy/web-default-engine "DuckDuckGo")

(defvar ivy/web-search-history nil
  "Global fallback web history.")

(defvar ivy/web-search-engines (make-hash-table :test 'equal)
  "ENGINE -> plist (:url :history :aliases).")

(defconst ivy/web-search-history-file
  (expand-file-name "ivy/web-history.el" user-emacs-directory))

(defun ivy/save-web-history ()
  (with-temp-file ivy/web-search-history-file
    (prin1
     (list
      :global ivy/web-search-history
      :engines (hash-table-to-alist ivy/web-search-engines))
     (current-buffer))))

(defun ivy/load-web-history ()
  (when (file-exists-p ivy/web-search-history-file)
    (with-temp-buffer
      (insert-file-contents ivy/web-search-history-file)
      (let* ((data (read (current-buffer))))
        (setq ivy/web-search-history (plist-get data :global))
        (setq ivy/web-search-engines (make-hash-table :test 'equal))
        (dolist (e (plist-get data :engines))
          (puthash (car e) (cdr e) ivy/web-search-engines))))))

;;(add-hook 'kill-emacs-hook #'ivy/save-web-history)
(ivy/load-web-history)

(defun ivy/define-web-search-engine (name base-url &optional aliases)
  (puthash name
           (list :url base-url
                 :history nil
                 :aliases aliases)
           ivy/web-search-engines))

(defun ivy/web--engine-by-alias (alias)
  (catch 'found
    (maphash
     (lambda (k v)
       (when (member alias (plist-get v :aliases))
         (throw 'found k)))
     ivy/web-search-engines)
    nil))

(defun ivy/web--looks-like-url-p (s)
  (or (string-match-p "^https?://" s)
      (string-match-p "^[^ ]+\\.[^ ]+" s)
      (string-match-p "^localhost[:/]" s)))

(defun ivy/web--normalize-url (s)
  (if (string-match-p "^https?://" s)
      s
    (concat "https://" s)))

(defun ivy/web ()
  "Unified web entry with working history."
  (interactive)
  (ivy-read
   "Web: "
   (lambda (_) )
   :dynamic-collection t
   :action
   (lambda (input)
     (let* ((parts (split-string input " "))
            (head (car parts))
            (rest (string-join (cdr parts) " "))
            engine query)
       (cond
        ((gethash head ivy/web-search-engines)
         (setq engine head query rest))
        ((setq engine (ivy/web--engine-by-alias head))
         (setq query rest))
        (t
         (setq engine ivy/web-default-engine
               query input)))
       (if (ivy/web--looks-like-url-p input)
           (browse-url (ivy/web--normalize-url input))
         (let* ((data (gethash engine ivy/web-search-engines))
                (url  (plist-get data :url))
                (hist (plist-get data :history)))
           (plist-put data :history
                      (cons query (delete query hist)))
           (puthash engine data ivy/web-search-engines)
           (push query ivy/web-search-history)
           (browse-url
            (concat url (url-hexify-string query)))))))))

;; ============================================================
;; 🔧 MENU REGISTRY SYSTEM
;; ============================================================

(defvar ivy/menu-registry (make-hash-table :test 'equal))

(defmacro ivy/define-menu (name options)
  `(puthash ,name ,options ivy/menu-registry))

(defun ivy/menu (title menu-name prev-fn)
  (let ((opts (gethash menu-name ivy/menu-registry)))
    (ivy-read title
              (append (mapcar #'car opts) '("Back"))
              :action
              (lambda (c)
                (if (string= c "Back")
                    (when prev-fn (funcall prev-fn))
                  (funcall (cdr (assoc c opts))))))))

(defun ivy/M-x ()
  (interactive)
  (ivy/menu (concat (getenv "USER") ":") "root" #'ivy/M-x))

;; ============================================================
;; 📦 PACKAGE MANAGERS
;; ============================================================

(require 'package)

(defvar ivy/package-managers nil
  "Registered package managers.")

(defmacro ivy/define-package-manager (name fn)
  `(add-to-list
    'ivy/package-managers
    (cons ,name ,fn)
    t))


;; ------------------------------------------------------------
;; ELPA
;; ------------------------------------------------------------

(defun ivy/package-elpa-install ()
  "Install an ELPA package using Ivy."
  (interactive)

  ;; Make sure archive information exists.
  (unless package-archive-contents
    (package-refresh-contents))

  (let ((packages
         (mapcar #'car package-archive-contents)))

    (ivy-read
     "ELPA Install: "
     packages
     :action
     (lambda (package)
       (package-install (intern package))))))


(defun ivy/package-elpa-refresh ()
  "Refresh ELPA package information."
  (interactive)
  (package-refresh-contents))


(defun ivy/package-elpa-remove ()
  "Remove an installed ELPA package."
  (interactive)

  (ivy-read
   "ELPA Remove: "
   (mapcar #'car package-alist)
   :action
   (lambda (package)
     (package-delete
      (cadr (assq (intern package) package-alist))))))


(ivy/define-menu
 "package-elpa"
 '(("Install" . ivy/package-elpa-install)
   ("Refresh" . ivy/package-elpa-refresh)
   ("Remove" . ivy/package-elpa-remove)))


;; ------------------------------------------------------------
;; SYSTEM PACKAGES
;; ------------------------------------------------------------

(defun ivy/package-system-install ()
  "Install a system package using system-packages."
  (interactive)

  (call-interactively #'system-packages-install))


(defun ivy/package-system-update ()
  "Update system packages using system-packages."
  (interactive)

  (call-interactively #'system-packages-update))


(defun ivy/package-system-remove ()
  "Remove a system package using system-packages."
  (interactive)

  (call-interactively #'system-packages-uninstall))


(ivy/define-menu
 "packages-system"
 '(("Install" . ivy/package-system-install)
   ("Update" . ivy/package-system-update)
   ("Remove" . ivy/package-system-)))


;; ------------------------------------------------------------
;; PACKAGE MENU
;; ------------------------------------------------------------

(defun ivy/menu-packages ()
  "Select a package manager."
  (interactive)

  (ivy-read
   "Packages: "
   (mapcar #'car ivy/package-managers)
   :action
   (lambda (manager)
     (let ((fn (cdr (assoc manager ivy/package-managers))))
       (when fn
         (funcall fn))))))


(ivy/define-package-manager
 "ELPA"
 (lambda ()
   (ivy/menu
    "ELPA: "
    "package-elpa"
    #'ivy/menu-packages)))


(ivy/define-package-manager
 "System"
 (lambda ()
   (ivy/menu
    "System Packages: "
    "packages-system"
    #'ivy/menu-packages)))


;; ============================================================
;; QEMU
;; ============================================================

(defun ivy/qemu-start ()
  "Select a registered VM and start it."
  (interactive)
  (let ((vms (qemuel-vm-list)))
    (if (null vms)
        (user-error "No QEMU VMs are registered")
      (ivy-read
       "Start QEMU VM: "
       vms
       :action
       (lambda (name)
         (qemuel-start name))))))


(defun ivy/qemu-stop ()
  "Select a running VM and stop it."
  (interactive)
  (let ((vms
         (cl-remove-if-not
          #'qemuel-running-p
          (qemuel-vm-list))))
    (if (null vms)
        (user-error "No QEMU VMs are running")
      (ivy-read
       "Stop QEMU VM: "
       vms
       :action
       (lambda (name)
         (qemuel-stop name))))))




(defun ivy/qemu-running ()
  "Select a running VM and display its process."
  (interactive)
  (let ((vms
         (cl-remove-if-not
          #'qemuel-running-p
          (qemuel-vm-list))))
    (if (null vms)
        (user-error "No QEMU VMs are running")
      (ivy-read
       "Running VM: "
       vms
       :action
       (lambda (name)
         (message "%s" (qemuel-process-get name)))))))


(ivy/define-menu
 "qemu"
 '(("Start" . ivy/qemu-start)
   ("Stop" . ivy/qemu-stop)
   ("Runnin" . ivy/qemu-running)))
;; ============================================================
;; ROOT MENU (STEAM DIRECTLY INSERTED)
;; ============================================================

(ivy/define-menu
 "root"
 '(("M-x" . (lambda () (execute-extended-command 1)))
   ("AppRun" . (lambda ()
                 (ivy-read "APP: "
                           (split-string
                            (shell-command-to-string "compgen -c") "\n" t)
                           :action (lambda (cmd)
                                     (start-process cmd nil cmd)))))
   ("Steam" . (lambda () (ivy/menu "Steam:" "Steam" #'ivy/M-x)))
   ("Web" . ivy/web)
   ("Shell" . (lambda () (ivy/menu "Shell:" "shell" #'ivy/M-x)))
   ("Emacs" . (lambda () (ivy/menu "Emacs:" "emacs" #'ivy/M-x)))
   ("Qemu" . (lambda () (ivy/menu "Qemu:" "qemu" #'ivy/M-x)))
   ("Packages" . ivy/menu-packages)
   ("Git" . (lambda () (ivy/menu "Git:" "git" #'ivy/M-x)))
   ("Projectile" . projectile-command-map)
   ("TTS" . (lambda () (ivy/menu "TTS:" "tts" #'ivy/M-x)))
   ("Close Buffer" . kill-buffer)))

;; ============================================================
;; Shell
;; ============================================================

(ivy/define-menu
 "shell"
 '(("Term past" . term-paste)))

;; ============================================================
;; DEFAULT WEB ENGINES
;; ============================================================

(ivy/define-web-search-engine
 "DuckDuckGo"
 "https://duckduckgo.com/?q="
 '("ddg" "duckduckgo"))
(ivy/define-web-search-engine
 "YouTube"
 "https://www.youtube.com/results?search_query="
 '("yt" "youtube"))
(ivy/define-web-search-engine
 "WikiPedia"
 "https://en.wikipedia.org/wiki/"
 '("wp" "wikipedia"))
(ivy/define-web-search-engine
 "ArchWiki"
 "https://wiki.archlinux.org/index.php?search="
 '("archw" "archwiki"))
(ivy/define-web-search-engine
 "Dictionary"
 "https://www.dictionary.com/browse/"
 '("dict" "dictionary"))
(ivy/define-web-search-engine
 "Osdev_Wiki"
 "https://wiki.osdev.org/index.php?search="
 '("osdw" "OSDEV_WIKI"))



;; ============================================================
;; 🗣 TTS SYSTEM (espeak backend)
;; ============================================================

(defgroup ivy/tts nil
  "ivy/TS settings."
  :group 'applications)

(defcustom ivy/tts-program "espeak"
  "TTS executable."
  :type 'string)

(defcustom ivy/tts-voice "en"
  "Voice used by espeak."
  :type 'string)

(defcustom ivy/tts-speed 250
  "Speech speed (words per minute)."
  :type 'integer)

(defcustom ivy/tts-pitch 50
  "Voice pitch (0–99)."
  :type 'integer)

(defcustom ivy/tts-amplitude 100
  "Amplitude (volume 0–200)."
  :type 'integer)

(defcustom ivy/tts-gap 10
  "Gap between words."
  :type 'integer)

(defvar ivy/tts--process nil
  "Active TTS process.")

(defun ivy/tts--build-args (text)
  "Build argument list for espeak."
  (list
   (format "-v%s" ivy/tts-voice)
   (format "-s%d" ivy/tts-speed)
   (format "-p%d" ivy/tts-pitch)
   (format "-a%d" ivy/tts-amplitude)
   (format "-g%d" ivy/tts-gap)
   text))

(defun ivy/tts-stop ()
  "Stop current speech."
  (interactive)
  (when (process-live-p ivy/tts--process)
    (kill-process ivy/tts--process)
    (setq ivy/tts--process nil)))

(defun ivy/tts-speak (text)
  "Speak TEXT using espeak."
  (ivy/tts-stop)
  (setq ivy/tts--process
        (apply #'start-process
               "ivy/tts"
               nil
               ivy/tts-program
               (ivy/tts--build-args text))))

(defun ivy/tts-read-region ()
  "Read selected region or prompt."
  (interactive)
  (if (use-region-p)
      (ivy/tts-speak
       (buffer-substring-no-properties
        (region-beginning)
        (region-end)))
    (ivy-read "Say: "
              nil
              :action (lambda (input)
                        (ivy/tts-speak input)))))

(defun ivy/tts-set-voice ()
  (interactive)
  (ivy-read "Voice: "
            '("en" "en-us" "en-sc" "en-n" "en-rp" "en-wm")
            :action (lambda (v)
                      (setq ivy/tts-voice v))))

(defun ivy/tts-set-speed ()
  (interactive)
  (setq ivy/tts-speed
        (read-number "Speed (wpm): " ivy/tts-speed)))

(defun ivy/tts-set-pitch ()
  (interactive)
  (setq ivy/tts-pitch
        (read-number "Pitch (0-99): " ivy/tts-pitch)))

(defun ivy/tts-set-amplitude ()
  (interactive)
  (setq ivy/tts-amplitude
        (read-number "Amplitude (0-200): " ivy/tts-amplitude)))

(defun ivy/tts-set-gap ()
  (interactive)
  (setq ivy/tts-gap
        (read-number "Gap: " ivy/tts-gap)))
(ivy/define-menu
 "tts"
 '(("Read Region / Prompt" . ivy/tts-read-region)
   ("Stop" . ivy/tts-stop)
   ("Set Voice" . ivy/tts-set-voice)
   ("Set Speed" . ivy/tts-set-speed)
   ("Set Pitch" . ivy/tts-set-pitch)
   ("Set Amplitude" . ivy/tts-set-amplitude)
   ("Set Gap" . ivy/tts-set-gap)))



;; ============================================================
;; 🗣 Layout
;; ============================================================

;; TODO; make work memory space 0x2093u02290
(ivy/define-menu
 "layout"
 '(("save" . (lambda() ())))
 )


(provide 'ivy-menu)
