# Utilities
* brightnessctl
* connman-runit
* connman-gtk
* opentpd 
`# connman also suppose to have a ntp client, but i could not make it work.
even NetworkManager does not have a ntp client, so its fine.`
> If connman keeps rfkilling the blutooth or the wifi 
> */etc/connman/main.conf*
> `DefaultAutoConnectTechnologies = ethernet,wifi`
> `DefaultEnabledTechnologies = bluetooth,wifi`
> Connman's bluetooth support is mainly for internet tethering over bluetooth
> not for connecting devices. use bluetoothctl for that.
* wpa_supplicant
* efibootmgr
* elogind-runit
* git
* grub
* os-prober
* linux-firmware
* linux-zen
* runit
## Audio stack
* pipewire-alsa
* pipewire-pulse
* wireplumber
## nvim
* neovim
* tree-sitter-cli
* node
* npm
* shellcheck 
*# For sh linting*
## nvidia
* nvidia-open-dkms
* nvidia-utils
* lib32-nvidia-utils 
* linux-zen-headers 
*# Turn on Power Management*
## bluetooth 
* bluez-runnit
* bluez-utils 
> make sure the device is not soft blocked with rfkill: rfkill list
> actually dont use rfkill, enable bluetooth from connman because it resets
> rfkill after every reset.
## asus and power-management
* asusctl `# And the custom service I made` 
* power-profiles-daemon-runit 
> asusctl has support for it: use `asusctl profiles ..` to manage it
> you can also use their `powerprofilesctl` tool.
> asusctl defaults it to,
> `AC profile Performance`
> `Battery profile Quiet`
> Which I think is pretty nice.
## mimetype 
> xdg-open is a part of xdg-utils and it needs this file to pick default applications
> example format:
*~/.config/mimeapps.list*
```
[Default Applications]
application/pdf=org.gnome.Evince.desktop

```
# Rice
* fastfetch
* kitty
* htop
## sway
* sway
* intel-gpu-tools
* intel-media-driver
* intel-ucode
* libva-intel-driver
* vulkan-intel
* xorg-xwayland
## portals
* xdg-desktop-portal `# Backend`
* xdg-desktop-portal-wlr `# Front end from screenshare`
* xdg-desktop-portal-gtk `# Front end for everything else`
*# Portals are suppose to be dbus activated, dont bother starting them manually*
## yazi
* yazi
* ffmpeg
* mediainfo
## zsh
* zsh
* zsh-vi-mode 
* zsh-syntax-highlighting
* zsh-autosuggestions
* bat
## fzf
* fzf 
* fd `# A better find`
* tree `# Better dir view`
## launcher and widgets
* rofi
* eww
* chafa `# For image to ascii` 
* fastfetch
* intel-gpu-utils 
`sudo setcap "CAP_PERFMON=+ep" $(which intel_gpu_top)`
## screenshot and record
* grim 
* slurp 
* gpu-sceen-record
## fonts
* ttf-profont-nerd
* noto-fonts-emoji `# For emoji`
## fonts 
* ttf-profont-nerd
* noto-fonts-emoji
## clipboard
* wl-clipboard
## misc
* jq
* xdg-user-dirs 
*run xdg-user-dirs-update after to initialize the dirs,
this also creates a config file* `~/.config/user-dirs.dirs`

# gameing
* lutris
* wine 
*geko and mono are optional, (geko: .NET replacement, mono: web browser stack)*
* mangohud
* gamemode
* vulkan-icd-loader
* lib32-vulkan-icd-loader
*To run vulkan applications, you will need a loader that 
loads the drivers. and of course the actual drivers from nvidia-utils.*
* vulkan-tools (for vulkaninfo)
* mesa-utils (for glxinfo)
*These are both optional and mainly used for better hardware detection.*
* https://github.com/lutris/docs/blob/master/HowToEsync.md
*Esync runs a huge amount of synchronization objects. You need to increase 
the limits of opened file descriptors.*
