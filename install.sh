#!/bin/bash

APPS_DIR=/usr/share/applications
BACKGROUND_DIR=/usr/share/backgrounds/linuxmint
PLYMOUTH_DIR=/usr/share/plymouth
RULES_DIR=/etc/udev/rules.d

# Application Download links
CODIUM=https://github.com/VSCodium/vscodium/releases/download/1.103.05312/codium_1.103.05312_amd64.deb
ARDUINO_IDE=https://downloads.arduino.cc/arduino-ide/arduino-ide_2.3.6_Linux_64bit.AppImage
ORCA_SLICER=https://github.com/SoftFever/OrcaSlicer/releases/download/v2.3.0/OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.3.0.AppImage

install_codium() {
    wget $CODIUM -O codium.deb
    dpkg -i ./codium.deb
    rm -f ./codium.deb

    # vscode aliases
    echo "alias code='codium'" >> /root/.profile
    echo "alias code='codium'" >> /home/$SUDO_USER/.bashrc

    echo "Installed VSCodium"
}

install_arduino_ide() {
    # Install AppImage
    wget $ARDUINO_IDE -O $APPS_DIR/arduino-ide.AppImage
    chmod +x $APPS_DIR/arduino-ide.AppImage

    # Create a desktop entry
    INO_SHORTCUT=$APPS_DIR/arduino-ide.desktop
    echo "[Desktop Entry]" > $INO_SHORTCUT
    echo "Type=Application" >> $INO_SHORTCUT
    echo "Name=Arduino IDE" >> $INO_SHORTCUT
    echo "Exec=$APPS_DIR/arduino-ide.AppImage" >> $INO_SHORTCUT
    echo "Icon=arduino-ide" >> $INO_SHORTCUT
    echo "Terminal=false" >> $INO_SHORTCUT
    echo "Categories=Development;IDE;" >> $INO_SHORTCUT
    echo "Comment=Open-source electronics prototyping platform" >> $INO_SHORTCUT

    # Update desktop entries
    update-desktop-database $APPS_DIR

    # USB PERMISSIONS
    echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", GROUP="plugdev", MODE="0666"' > $RULES_DIR/99-arduino.rules
    echo "Installed arduino-ide"
}

install_orca_slicer() {
    wget $ORCA_SLICER -O $APPS_DIR/orca-slicer.AppImage
    chmod +x $APPS_DIR/orca-slicer.AppImage

    # Create a desktop entry
    ORCA_SHORTCUT=$APPS_DIR/orca-slicer.desktop
    echo "[Desktop Entry]" > $ORCA_SHORTCUT
    echo "Type=Application" >> $ORCA_SHORTCUT
    echo "Name=Orca Slicer v2.3.0" >> $ORCA_SHORTCUT
    echo "Exec=$APPS_DIR/orca-slicer.AppImage" >> $ORCA_SHORTCUT
    echo "Icon=orca-slicer" >> $ORCA_SHORTCUT
    echo "Terminal=false" >> $ORCA_SHORTCUT
    echo "Categories=Development;IDE;" >> $ORCA_SHORTCUT
    echo "Comment=Open-source slicer" >> $ORCA_SHORTCUT

    echo $DESKTOP_ENTRY > $APPS_DIR/orca-slicer.desktop

    # Update desktop entries
    update-desktop-database $APPS_DIR
}

setup_microbit() {
    # Allow the microbit device
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", MODE="0666", GROUP="plugdev"' > $RULES_DIR/50-microbit.rules
    udevadm control --reload-rules
    udevadm trigger
}

setup_pinned_apps() {
    # Define your Icing Task Manager config file:
    FILE=$(ls /home/$SUDO_USER/.config/cinnamon/spices/grouped-window-list@cinnamon.org/*.json)

    # New pinned apps list (edit as needed)
    NEW_APPS='[
        "org.gnome.Terminal.desktop",
        "nemo.desktop",
        "chromium-browser.desktop",
        "codium.desktop",
        "arduino-ide.desktop"
    ]'

    gsettings set org.cinnamon favorite-apps "$NEW_APPS"

    # Use jq to update the field in-place
    jq --argjson arr "$NEW_APPS" '.["pinned-apps"].value = $arr' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
    
    chown -R $SUDO_USER:$SUDO_USER "/home/$SUDO_USER/.config/cinnamon"

    echo "Configured pinned applications on panel"
}

setup_wallpapers() {
    IMG=$BACKGROUND_DIR/A03.png

    cp -r ./wallpapers/* $BACKGROUND_DIR

    # Get the Cinnamon session PID for 'student'
    USER_PID=$(pgrep -u $SUDO_USER cinnamon-sess | head -n1)
    if [ -z "$USER_PID" ]; then
        echo "Could not find cinnamon session for user '$SUDO_USER'."
        return 1
    fi

    # Extract the DBUS_SESSION_BUS_ADDRESS for the session
    USER_DBUS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$USER_PID/environ | tr '\0' '\n' | grep ^DBUS_SESSION_BUS_ADDRESS= | cut -d= -f2-)
    if [ -z "$USER_DBUS" ]; then
        echo "Could not find DBUS_SESSION_BUS_ADDRESS for user '$SUDO_USER'."
        return 1
    fi

    # Set the wallpaper for user
    sudo -u $SUDO_USER DBUS_SESSION_BUS_ADDRESS="$USER_DBUS" \
      gsettings set org.cinnamon.desktop.background picture-uri "file://$IMG"

    # Set login screen background for Slick Greeter
    CONF=/etc/lightdm/slick-greeter.conf
    
    echo "[Greeter]" > $CONF
    echo "theme-name=Mint-Y-Orange" >> $CONF
    echo "background=$IMG" >> $CONF
}

config_chromium() {
    cp -fr ./.config/chromium/Default/* /home/$SUDO_USER/.config/chromium/Default/
}

setup_splash_screen() {
    ## LOCAL SOURCE
    cp -fr ./splash/* $PLYMOUTH_DIR/themes/mint-logo/
    
    update-initramfs -u -k all
}

theeming() {
    # Orange Accent
    gsettings set org.cinnamon.desktop.wm.preferences theme "Mint-Y-Orange"
    gsettings set org.cinnamon.desktop.interface gtk-theme "Mint-Y-Orange"
    gsettings set org.cinnamon.theme name "Mint-Y-Orange"
    gsettings set org.cinnamon.desktop.interface icon-theme "Mint-Y"

    # Prefer dark theme
    gsettings set org.x.apps.portal color-scheme 'prefer-dark'
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"

    # Terminal theme
    dconf load /org/gnome/terminal/legacy/profiles:/ < ./terminal.dconf
}

install_various_packages() {
    # Define the path to your packages list
    PACKAGE_FILE=".packages"


    # Check if the package list file exists
    if [[ ! -f "$PACKAGE_FILE" ]]; then
        echo "Package list file '$PACKAGE_FILE' not found!"
        exit 1
    fi

    # Read each line (package name) from the file
    while IFS= read -r package || [[ -n "$package" ]]; do
        # Skip empty lines
        if [[ -z "$package" ]]; then
            continue
        fi
        
        # Install the package
        echo "Installing $package..."
        apt install "$package" -y
    done < "$PACKAGE_FILE"

    echo "All packages installed."
}

# --- MAIN --- #

# Update system
apt update
apt upgrade

# Install apps
install_various_packages
install_codium
install_arduino_ide
install_orca_slicer

# Configuration overwrite
config_chromium

# Post install setup
setup_splash_screen
setup_pinned_apps
setup_wallpapers
setup_microbit
theeming

# Final message and prompt reboot
echo -e "\n\e[92mConfiguration complete!\e[0m\n";
read -p "Do you want to reboot? [y/N]: " answer
case "$answer" in
    [yY])
        echo "Rebooting..."
        reboot
        ;;
    *)
        echo "Reboot cancelled."
        ;;
esac