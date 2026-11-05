# Disable access control for the current user.
xhost +SI:localuser:$USER

# Make Java applications aware this is a non-reparenting window manager.
export _JAVA_AWT_WM_NONREPARENTING=1

# Set default cursor.
xsetroot -cursor_name left_ptr

# Set keyboard repeat rate.
xset r rate 200 60

export QT_QPA_PLATFORMTHEME="qt5ct"
export GTK_THEME="Hackerer"
export GTK_ICON_THEME="Adwaita"
export GDK_SCALE=0.5
export GDK_DPI_SCALE=1
export NIXPKGS_ALLOW_UNFREE=1
export EDITOR="emacsclient -r''"
export VISUAL="emacsclient -r''"
export XCURSOR_THEME=macOS
export XCURSOR_SIZE=24

exec emacs --fullscreen
# exec jwm
