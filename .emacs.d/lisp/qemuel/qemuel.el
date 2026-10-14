;;; qemuel.el --- QEMU VM manager for Emacs -*- lexical-binding: t; -*-

(require 'cl-lib)

;;; ---------------------------------------------------------------------------
;;; Customization
;;; ---------------------------------------------------------------------------

(defgroup qemuel nil
  "Manage QEMU virtual machines from Emacs."
  :group 'external)

(defcustom qemuel-pool-directory
  "~/.qemuel/drives/"
  "Directory containing qemuel virtual drives."
  :type 'directory
  :group 'qemuel)

(defvar qemuel-processes nil
  "Running qemuel VM processes.

Each entry is (VM-NAME . PROCESS).")


(defun qemuel-process-get (name)
  "Return the running process for VM NAME, or nil."
  (let* ((name (if (symbolp name)
                   (symbol-name name)
                 name))
         (process (cdr (assoc name qemuel-processes))))
    (when (and process
               (process-live-p process))
      process)))


(defun qemuel-process-remove (name)
  "Remove VM NAME from the qemuel process table."
  (setq qemuel-processes
        (assoc-delete-all name qemuel-processes)))


(defun qemuel-process-sentinel (process _event)
  "Clean up qemuel state when PROCESS exits."
  (when (memq (process-status process)
              '(exit signal))
    (let ((name
           (cl-loop for entry in qemuel-processes
                    when (eq (cdr entry) process)
                    return (car entry))))
      (when name
        (qemuel-process-remove name)))))


(defun qemuel-start (name)
  "Start VM NAME asynchronously."
  (interactive
   (list
    (completing-read
     "Start VM: "
     (qemuel-vm-list)
     nil
     t)))

  (when (qemuel-process-get name)
    (user-error "VM %s is already running" name))

  ;; Remove any stale process entry.
  (qemuel-process-remove name)

  (let* ((args (qemuel-qemu-build-command name))
         (program (car args))
         (arguments (cdr args))
         (buffer (get-buffer-create
                  (format "*qemuel-%s*" name)))
         (process
          (apply #'start-process
                 (format "qemuel-%s" name)
                 buffer
                 program
                 arguments)))

    (set-process-query-on-exit-flag process nil)

    (set-process-sentinel
     process
     #'qemuel-process-sentinel)

    (push (cons name process)
          qemuel-processes)

    (message "Started VM %s" name)

    process))


(defun qemuel-stop (name)
  "Stop VM NAME."
  (interactive
   (list
    (completing-read
     "Stop VM: "
     (mapcar #'car qemuel-processes)
     nil
     t)))

  (let ((process (qemuel-process-get name)))
    (unless process
      (qemuel-process-remove name)
      (user-error "VM %s is not running" name))

    (delete-process process)

    ;; The sentinel normally handles this, but explicitly removing it
    ;; makes qemuel-stop deterministic.
    (qemuel-process-remove name)

    (message "Stopped VM %s" name)))


(defun qemuel-running-p (name)
  "Return non-nil if VM NAME is currently running."
  (not (null (qemuel-process-get name))))

;;; ---------------------------------------------------------------------------
;;; VM storage
;;; ---------------------------------------------------------------------------

(defvar qemuel-vms nil
  "Registered qemuel virtual machines.")


(defun qemuel-vm-register (name configuration)
  "Register NAME with CONFIGURATION."
  (setq qemuel-vms
        (cons (cons name configuration)
              (assq-delete-all name qemuel-vms)))
  name)


(defun qemuel-vm-get (name)
  "Return the configuration of VM NAME.

NAME may be a string or symbol."
  (let ((name (if (symbolp name)
                  (symbol-name name)
                name)))
    (cdr
     (cl-assoc name
               qemuel-vms
               :test #'string=))))

(defun qemuel-vm-list ()
  "Return names of all registered VMs."
  (mapcar #'car qemuel-vms))

(defun qemuel-vm-exists-p (name)
  "Return non-nil if VM NAME exists."
  (not (null (qemuel-vm-get name))))


(defmacro defvm (name &rest configuration)
  "Define a qemuel VM named NAME.

Defining a VM does not start it or modify the system."
  `(qemuel-vm-register
    ,(symbol-name name)
    ',configuration))


;;; ---------------------------------------------------------------------------
;;; Drive handling
;;; ---------------------------------------------------------------------------

(defun qemuel-pool-directory ()
  "Return the expanded qemuel pool directory."
  (file-name-as-directory
   (expand-file-name qemuel-pool-directory)))


(defun qemuel-drive-filename (drive)
  "Return the filename for pool DRIVE."
  (let ((name (plist-get drive :name))
        (size (plist-get drive :size)))
    (unless name
      (error "Pool drive is missing :name"))

    (unless size
      (error "Pool drive %s is missing :size" name))

    (format "%s_%s.qcow"
            name
            size)))


(defun qemuel-pool-drive-path (drive)
  "Return the path to pool DRIVE."
  (expand-file-name
   (qemuel-drive-filename drive)
   (qemuel-pool-directory)))


(defun qemuel-pool-ensure ()
  "Ensure the qemuel drive pool exists."
  (make-directory (qemuel-pool-directory) t))


(defun qemuel-pool-drive-exists-p (drive)
  "Return non-nil if DRIVE exists in the pool."
  (file-exists-p
   (qemuel-pool-drive-path drive)))


(defun qemuel-pool-create-drive (drive)
  "Create pool DRIVE if it does not already exist.

Return the path to DRIVE."
  (qemuel-pool-ensure)

  (let ((path (qemuel-pool-drive-path drive))
        (size (plist-get drive :size)))

    (unless (file-exists-p path)
      (unless (executable-find "qemu-img")
        (error "qemu-img was not found in PATH"))

      (let ((status
             (call-process
              "qemu-img"
              nil
              "*qemuel-qemu-img*"
              nil
              "create"
              "-f"
              "qcow2"
              path
              size)))

        (unless (zerop status)
          (error "qemu-img failed while creating %s"
                 path))))

    path))


(defun qemuel-pool-get-drive (drive)
  "Resolve DRIVE through the qemuel pool.

Create the drive if it does not exist.

Return its path."
  (qemuel-pool-create-drive drive))


;;; ---------------------------------------------------------------------------
;;; QEMU
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-binary (arch)
  "Return the QEMU system binary for ARCH."
  (pcase arch
    ("x86_64"  "qemu-system-x86_64")
    ("i386"    "qemu-system-i386")
    ("aarch64" "qemu-system-aarch64")
    ("arm"     "qemu-system-arm")
    ("riscv64" "qemu-system-riscv64")
    ("ppc64"   "qemu-system-ppc64")
    ("s390x"   "qemu-system-s390x")
    (_
     (error "Unsupported QEMU architecture: %s" arch))))


;;; ---------------------------------------------------------------------------
;;; Storage argument generation
;;; ---------------------------------------------------------------------------


(defun qemuel-qemu-pool-disk-args (disk index)
  "Generate QEMU arguments for pool DISK at INDEX."
  (let ((path (qemuel-pool-get-drive disk))
        (interface (or (plist-get disk :interface)
                       "virtio"))
        (boot-index (plist-get disk :boot_index))
        (id (format "qemuel-disk%d" index)))

    (cond
     ;; IDE
     ((string= interface "ide")
      (list
       "-drive"
       (format "file=%s,if=none,id=%s,format=qcow2"
               path id)
       "-device"
       (concat
        (format "ide-hd,drive=%s" id)
        (when boot-index
          (format ",bootindex=%s" boot-index)))))

     ;; VirtIO
     ((string= interface "virtio")
      (list
       "-drive"
       (format "file=%s,if=none,id=%s,format=qcow2"
               path id)
       "-device"
       (concat
        (format "virtio-blk-pci,drive=%s" id)
        (when boot-index
          (format ",bootindex=%s" boot-index)))))


     ((string= interface "hda")
      (list
       "-hda"
       (format "%s"
               path)
        ))

     ((string= interface "fda")
      (list
       "-fda"
       (format "%s"
               path)
        ))

     (t
      (error "Unsupported pool disk interface: %s"
             interface)))))


(defun qemuel-qemu-iso-args (disk index)
  "Generate QEMU arguments for ISO DISK at INDEX."
  (let ((file (plist-get disk :file))
        (interface (plist-get disk :interface))
        (boot-index (plist-get disk :boot_index))
        (id (format "qemuel-cdrom%d" index)))

    (unless file
      (error "ISO disk is missing :file"))

    (unless (or (null interface)
                (string= interface "cdrom"))
      (error "ISO disk has unsupported :interface: %s"
             interface))

    (if boot-index
        (list
         "-drive"
         (format "file=%s,if=none,id=%s,media=cdrom"
                 (expand-file-name file)
                 id)
         "-device"
         (format "ide-cd,drive=%s,bootindex=%s"
                 id
                 boot-index))

      (list
       "-cdrom"
       (expand-file-name file)))))


(defun qemuel-qemu-self-def-args (device)
  "Return arguments from self-defined DEVICE."
  (let ((args (plist-get device :arg)))

    (unless (listp args)
      (error ":arg must be a list of QEMU arguments"))

    args))



;;; ---------------------------------------------------------------------------
;;; Physical disks
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-physical-args (disk index)
  "Generate QEMU arguments for physical host DISK at INDEX."
  (let ((device (plist-get disk :device))
        (interface (or (plist-get disk :interface)
                       "virtio"))
        (readonly (plist-get disk :readonly))
        (boot-index (plist-get disk :boot_index))
        (id (format "qemuel-physical%d" index)))

    (unless device
      (error "Physical disk is missing :device"))

    (let ((drive
           (format "file=%s,format=raw,if=none,id=%s%s"
                   device
                   id
                   (if readonly
                       ",readonly=on"
                     ""))))

      (pcase interface

        ;; VirtIO
        ("virtio"
         (list
          "-drive"
          drive
          "-device"
          (concat
           (format "virtio-blk-pci,drive=%s" id)
           (when boot-index
             (format ",bootindex=%s" boot-index)))))

        ;; IDE
        ("ide"
         (list
          "-drive"
          drive
          "-device"
          (concat
           (format "ide-hd,drive=%s" id)
           (when boot-index
             (format ",bootindex=%s" boot-index)))))

        ;; SCSI
        ("scsi"
         (list
          "-drive"
          drive
          "-device"
          (concat
           (format "scsi-hd,drive=%s" id)
           (when boot-index
             (format ",bootindex=%s" boot-index)))))

        ;; Raw QEMU drive without automatically adding a device.
        ("none"
         (list
          "-drive"
          drive))

        (_
         (error "Unsupported physical disk interface: %s"
                interface))))))


;;; ---------------------------------------------------------------------------
;;; Physical floppy
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-floppy-args (disk index)
  "Generate QEMU arguments for physical floppy DISK at INDEX."
  (let ((device (plist-get disk :device))
        (readonly (plist-get disk :readonly)))

    (unless device
      (error "Floppy disk is missing :device"))

    (list
     "-drive"
     (format "file=%s,if=floppy,format=raw%s"
             device
             (if readonly
                 ",readonly=on"
               "")))))


;;; ---------------------------------------------------------------------------
;;; Disk argument dispatch
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-disk-args (disk index)
  "Generate QEMU arguments for DISK at INDEX."
  (pcase (plist-get disk :type)

    ("pool"
     (qemuel-qemu-pool-disk-args disk index))

    ("iso"
     (qemuel-qemu-iso-args disk index))

    ("physical"
     (qemuel-qemu-physical-args disk index))

    ("floppy"
     (qemuel-qemu-floppy-args disk index))

    ("self-def"
     (qemuel-qemu-self-def-args disk))

    (_
     (error "Unknown disk type: %s"
            (plist-get disk :type)))))


;;; ---------------------------------------------------------------------------
;;; Network
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-network-args (network)
  "Generate QEMU arguments for NETWORK."
  (pcase (plist-get network :type)

    ("user"
     '("-netdev" "user,id=net0"
       "-device" "virtio-net-pci,netdev=net0"))

    ("e1000"
     '("-netdev" "user,id=net0"
       "-device" "e1000,netdev=net0"))

    ("rtl8139"
     '("-netdev" "user,id=net0"
       "-device" "rtl8139,netdev=net0"))

    ("none"
     '("-nic" "none"))

    (_
     (error "Unknown network type: %s"
            (plist-get network :type)))))


;;; ---------------------------------------------------------------------------
;;; Devices
;;; ---------------------------------------------------------------------------
(defun qemuel-qemu-audio-args (device)
  "Generate QEMU arguments for audio DEVICE."
  (let ((backend (plist-get device :backend))
        (id      (plist-get device :id))
        (audio-device (plist-get device :device)))

    (unless backend
      (error "Audio device is missing :backend"))

    (unless id
      (setq id "audio0"))

    (unless audio-device
      (error "Audio device is missing :device"))

    (pcase audio-device
      ("ich9-intel-hda"
       (list
        "-audiodev"
        (format "%s,id=%s" backend id)
        "-device"
        "ich9-intel-hda"
        "-device"
        (format "hda-output,audiodev=%s" id)))

      ("AC97"
       (list
        "-audiodev"
        (format "%s,id=%s" backend id)
        "-device"
        (format "AC97,audiodev=%s" id)))

      ("sb16"
       (list
        "-audiodev"
        (format "%s,id=%s" backend id)
        "-device"
        (format "sb16,audiodev=%s" id)))

      ("virtio-sound-pci"
       (list
        "-audiodev"
        (format "%s,id=%s" backend id)
        "-device"
        (format "virtio-sound-pci,audiodev=%s" id)))

      (_
       (error "Unknown audio device: %s"
              audio-device)))))



(defun qemuel-qemu-device-args (device)
  "Generate QEMU arguments for DEVICE."
  (pcase (plist-get device :type)
    ("self-def"
     (qemuel-qemu-self-def-args device))

    ("audio"
     (qemuel-qemu-audio-args device))

    (_
     (error "Unknown device type: %s"
            (plist-get device :type)))))


;;; ---------------------------------------------------------------------------
;;; Display
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-display-args (display)
  "Generate QEMU arguments for DISPLAY."
  (cond
   ((null display)
    '())

   ((stringp display)
    (list "-display" display))

   ((listp display)
    (let ((type (plist-get display :type))
          (graphics (plist-get display :graphics))
          (args nil))

      (unless type
        (error "Display configuration is missing :type"))

      ;; -display TYPE
      (setq args
            (list "-display" type))

      ;; -vga GRAPHICS
      (when graphics
        (setq args
              (append args
                      (list "-vga" graphics))))
      args))

   (t
    (error "Invalid display configuration: %S"
           display))))

;;; ---------------------------------------------------------------------------
;;; QEMU command generation
;;; ---------------------------------------------------------------------------

(defun qemuel-qemu-build-command (name)
  "Build, but do not execute, the QEMU command for VM NAME."
  (let* ((vm (qemuel-vm-get name))
         (arch (plist-get vm :arch))
         (machine (plist-get vm :machine))
         (bios (plist-get vm :bios))
         (cpu (plist-get vm :cpu))
         (boot (plist-get vm :boot))
         (memory (plist-get vm :memory))
         (cores (plist-get vm :cores))
         (name (plist-get vm :name))
         (disks (plist-get vm :disk))
         (network (plist-get vm :network))
         (display (plist-get vm :display))
         (devices (plist-get vm :devices))
         (args (list (qemuel-qemu-binary arch))))

    (unless vm
      (error "VM does not exist: %s" name))

    ;; Machine.
    (when machine
      (setq args
            (append args
                    (list "-machine" machine))))

    ;; Bios.
    (when bios
      (setq args
            (append args
                    (list "-bios" bios))))
    ;; CPU.
    (when cpu
      (setq args
            (append args
                    (list "-cpu" cpu))))

    ;; Memory.
    (when memory
      (setq args
            (append args
                    (list "-m" memory))))

    ;; Cores.
    (when cores
      (setq args
            (append args
                    (list "-smp"
                          (number-to-string cores)))))
    (when name
      (setq args
            (append args
                    (list "-name" name))))

    ;; Disks.
    (cl-loop
     for disk in disks
     for index from 0
     do
     (setq args
	   (append args
		   (qemuel-qemu-disk-args disk index))))

    ;; Network.
    (dolist (net network)
      (setq args
            (append args
                    (qemuel-qemu-network-args net))))

    ;; Devices.
    (dolist (device devices)
      (setq args
            (append args
                    (qemuel-qemu-device-args device))))


    ;; Display.
    (setq args
          (append args
                  (qemuel-qemu-display-args display)))

    args))


(defun qemuel-command (name)
  "Display the generated QEMU command for VM NAME.

This does not execute QEMU."
  (interactive
   (list
    (completing-read
     "VM: "
     (mapcar #'car qemuel-vms))))

  (let ((args (qemuel-qemu-build-command name)))
    (message "%s"
             (mapconcat #'shell-quote-argument
                        args
                        " "))
    args))


;;; ---------------------------------------------------------------------------
;;; Pool inspection
;;; ---------------------------------------------------------------------------

(defun qemuel-pool-list ()
  "Return all qcow drives in the qemuel pool."
  (when (file-directory-p (qemuel-pool-directory))
    (directory-files
     (qemuel-pool-directory)
     nil
     "\\.qcow\\'")))


;;; ---------------------------------------------------------------------------
;;; VM listing
;;; ---------------------------------------------------------------------------

(defun qemuel-vm-list ()
  "Return names of all registered VMs."
  (mapcar #'car qemuel-vms))



```elisp
;;; ---------------------------------------------------------------------------
;;; Initialization
;;; ---------------------------------------------------------------------------

(defcustom qemuel-root-directory
  "~/.qemuel/"
  "Root directory for qemuel configuration and data."
  :type 'directory
  :group 'qemuel)


(defun qemuel-root-directory ()
  "Return the expanded qemuel root directory."
  (file-name-as-directory
   (expand-file-name qemuel-root-directory)))


(defun qemuel-vm-directory ()
  "Return the qemuel VM definition directory."
  (file-name-as-directory
   (expand-file-name
    "vms"
    (qemuel-root-directory))))


(defun qemuel-init ()
  "Initialize qemuel.

Create the qemuel root directory if it does not exist.

If the `vms' directory exists inside the qemuel root, load every
Emacs Lisp file contained within it. The `vms' directory itself is
not created automatically."
  (interactive)

  ;; Create the qemuel root directory if necessary.
  (make-directory (qemuel-root-directory) t)

  ;; Load VM definitions if the VM directory exists.
  (let ((vm-directory (qemuel-vm-directory)))
    (when (file-directory-p vm-directory)
      (dolist (file
               (directory-files
                vm-directory
                t
                "\\.el\\'"))
        (load file nil nil t))))

  t)
;;; ---------------------------------------------------------------------------
;;; Package
;;; ---------------------------------------------------------------------------

(provide 'qemuel)

