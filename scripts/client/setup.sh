#!/bin/bash
#
# Installs the core system
# @author Kevin Veen-Birkenbach [aka. Frantz]
#
# shellcheck source=/dev/null # Deactivate SC1090
source "$(dirname "$(readlink -f "${0}")")/../base.sh" || (echo "Loading base.sh failed." && exit 1)
SYSTEM_MEMORY_KB="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
info "Start setup of customized core software..."
info "Copying templates to home folder..."
exit
cp -rfv "$TEMPLATE_PATH/." "$HOME"
echo "Synchronising packages..."
sudo pacman -Syyu
FSTAB_SWAP_ENTRY="/swapfile none swap defaults 0 0"
SWAP_FILE="/swapfile"
FSTAB_FILE="/etc/fstab"
if grep -q "$FSTAB_SWAP_ENTRY" "$FSTAB_FILE"; then
	echo "Skipping creation of swap partion because entry allready exists in <<$FSTAB_FILE>>!"
else
	echo "Creating swap partition..."
	sudo fallocate -l 16G "$SWAP_FILE"
	sudo chmod 600 "$SWAP_FILE"
	sudo mkswap "$SWAP_FILE"
	sudo swapon "$SWAP_FILE"
	sudo sh -c "echo \"$FSTAB_SWAP_ENTRY\">>\"$FSTAB_FILE\""
fi
echo "Synchronizing programing language interpreters..."
sudo pacman --needed -S jdk11-openjdk python php
echo "Synchronizing other interpreters..."
sudo pacman --needed -S texlive-most
echo "Synchronizing compression tools..."
sudo pacman --needed -S p7zip
echo "Synchronizing administration tools..."
sudo pacman --needed -S htop tree git base-devel yay make gcc cmake
echo "Synchronizing network analyze tools..."
sudo pacman --needed -S traceroute wireshark-qt wireshark-cli
echo "Synchronizing security tools..."
sudo pacman --needed -S ecryptfs-utils encfs keepassxc
echo "Setup SSH key..."
ssh_key_path="$HOME/.ssh/id_rsa"
if [ ! -f "$ssh_key_path" ]; then
	echo "->SSH key $ssh_key_path doesn't exists!"
	if [ ! -f "./data$ssh_key_path" ]; then
		echo "->Importing ssh key from data..."
		bash ./scripts/export-data-to-system.sh
	else
		echo "->Generating ssh key..."
		ssh-keygen -t rsa -b 4096 -C "$USER@$HOSTNAME"
	fi
fi
if [[ "$(sudo lshw -C display)" == *"NVIDIA"* ]]; then
	echo "Install NVIDIA drivers..."
	sudo mhwd -a pci nonfree 0300
fi
echo "Synchronizing web tools..."
sudo pacman --needed -S chromium firefox firefox-ublock-origin firefox-extension-https-everywhere firefox-dark-reader
echo "Synchronizing office tools..."
sudo pacman --needed -S ttf-liberation libreoffice-fresh \
	libreoffice-fresh-de libreoffice-fresh-eo libreoffice-fresh-es libreoffice-fresh-nl \
	hunspell \
	hunspell-de hunspell-es_es hunspell-en_US hunspell-nl
echo "Synchronizing grafic tools..."
sudo pacman --needed -S gimp blender
obs_requirements_memory_kb="4000000"
if [ "$SYSTEM_MEMORY_KB" -gt "$obs_requirements_memory_kb" ]; then
	echo "Synchronizing obs studio..."
	sudo pacman -S obs-studio
fi
echo "Synchronizing communication tools..."
yay -S slack-desktop skypeforlinux-stable-bin
sudo pacman -S base-devel git cmake pidgin libpurple mxml libxml2 sqlite libgcrypt #Optimize later
sudo pacman -Syyu pidgin
yay -S libpurple-lurch libpurple-carbons
sudo pacman -Syyu purple-facebook
echo "Synchronizing development tools..."
echo "->Synchronizing code quality tools..."
sudo pacman --needed -S shellcheck
echo "-Synchronizing language servers..."
yay -S ccls
echo "->Synchronizing visualization tools..."
sudo pacman --needed -S dia
echo "->Synchronizing IDE's..."
sudo pacman --needed -S eclipse-java atom arduino arduino-docs
echo "-->Add user to arduino relevant groups..."
sudo usermod -a -G uucp "$USER" || echo "Couldn't add <<$USER>> to group <<uucp>>. Try to add manually later!"
sudo usermod -a -G lock "$USER" || echo "Couldn't add <<$USER>> to group <<lock>>. Try to add manually later!"
echo "-->Installing atom packages..."
apm install -c \
	atom-ide-ui\
	ide-bash\
	ide-python\
	ide-c-cpp\
	ide-java\
	ide-yaml\
	atom-autocomplete-php\
	es6-snippets\
	javascript-snippets\
	emmet\
	git-blame\
	git-plus\
	script\
	ask-stack\
	atom-beautify\
	highlight-selected\
	autocomplete-paths\
	todo-show\
	linter\
	linter-ui-default\
	linter-spell\
	intentions\
	busy-signal\
	language-latex\
	linter-spell-latex\
	docblockr
sudo npm i -g bash-language-server #Needed by atom-package ide-bash
python -m pip install 'python-language-server[all]' #Needed by atom
echo "->Synchronizing containerization tools..."
echo "-->Installing docker..."
sudo pacman --needed -S docker docker-compose
echo "-->Add current user<<$USER>> to user group docker..."
sudo usermod -a -G docker "$USER"
echo "-->Enable docker service..."
sudo systemctl enable docker --now
echo "->Synchronizing orchestration tools..."
sudo pacman --needed -S ansible
echo "->Synchronizing virtualisation tools..."
pamac install virtualbox $(pacman -Qsq "^linux" | grep "^linux[0-9]*[-rt]*$" | awk '{print $1"-virtualbox-host-modules"}' ORS=' ')
sudo vboxreload
pamac build virtualbox-ext-oracle
sudo gpasswd -a "$USER" vboxusers
echo "Keep in mind to install the guest additions in the virtualized system. See https://wiki.manjaro.org/index.php?title=VirtualBox"
echo "Installing entertainment software..."
echo "->Synchronizing audio software..."
sudo pacman -S rhythmbox
minimum_gaming_memory_kb="4000000"
if [ "$SYSTEM_MEMORY_KB" -gt "$minimum_gaming_memory_kb" ]; then
	echo "->Synchronizing games..."
	sudo pacman --needed -S 0ad warzone2100
	echo "->Synchronizing emulationstation..."
	yay -S emulationstation #retroarch joyutils jstest-gtk-git
	yay -S libretro-snes9x-next-git libretro-quicknes-git libretro-fceumm-git libretro-prosystem-git libretro-gambatte-git libretro-mgba-git
	echo "-->Installing themes..."
	mkdir .emulationstation/themes
	git clone https://github.com/RetroPie/es-theme-carbon .emulationstation/themes/carbon
	echo "More game recomendations you will find here: https://wiki.archlinux.org/index.php/List_of_games..."
fi
if [ "$XDG_SESSION_TYPE" == "x11" ]; then
	echo "->Synchronizing xserver tools..."
	sudo pacman --needed -S xbindkeys
	echo "-->Setting up key bindings..."
	echo "" >> "$HOME/.xbindkeysrc"
	echo "\"gnome-terminal -e '/bin/bash $SCRIPT_PATH/import-data-from-system.sh'\"" >> "$HOME/.xbindkeysrc"
	echo "  control+alt+s" >> "$HOME/.xbindkeysrc"
	xbindkeys --poll-rc
fi
if [ "$DESKTOP_SESSION" == "gnome" ]; then
	echo "->Synchronizing gnome tools..."
	sudo pacman --needed -S gnome-shell-extensions gnome-terminal
	echo "-->Setting up gnome specific software..."
	echo "-->Setting up dash favourites..."
	gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop',
	'org.gnome.Terminal.desktop',
	'org.keepassxc.KeePassXC.desktop',
	'firefox.desktop',
	'chromium.desktop',
	'atom.desktop',
	'arduino.desktop',
	'eclipse.desktop',
	'vlc.desktop',
	'gimp.desktop',
	'blender.desktop',
	'rhythmbox.desktop',
	'org.gnome.Screenshot.desktop']"
	echo "-->Install GNOME extensions..."
	echo "--->Install <<NASA picture of the day>>..."
	git clone https://github.com/Elinvention/gnome-shell-extension-nasa-apod.git "$HOME/.local/share/gnome-shell/extensions/nasa_apod@elinvention.ovh"
	gnome-extensions enable  nasa_apod@elinvention.ovh
	echo "--->Install <<Open Weather>>..."
	git clone https://gitlab.com/jenslody/gnome-shell-extension-openweather "$HOME/.local/share/gnome-shell/extensions/openweather-extension@jenslody.de"
	gnome-extensions enable openweather-extension@jenslody.de
	echo "--->Install <<Dash to Panel>>..."
	git clone https://github.com/home-sweet-gnome/dash-to-panel "$HOME/.local/share/gnome-shell/extensions/openweather-extension@dash-to-panel@jderose9.github.com"
	gnome-extensions enable dash-to-panel@jderose9.github.com
	echo "--->Deaktivating <<Dash to Dock>>"
	gnome-extensions disable dash-to-dock@micxgx.gmail.com
fi
echo "Removing all software from user startup..."
rm ~/.config/autostart/*
echo "More software recomendations you will find here: https://wiki.archlinux.org/index.php/list_of_applications"