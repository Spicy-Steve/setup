#!/bin/bash
set -e  # Stop on any error
set -u  # Treat unset vars as errors

# === CONFIG ===
GITHUB_USER="Spicy-Steve"
DOTFILES_REPO="dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"

CURSOR_NAME="Bibata-6bcde"             # Use from plasma-apply-cursortheme --list-themes
ICON_THEME="Papirus-Dark"              # Choose: Papirus, Papirus-Dark, Papirus-Light
ACCENT_COLOR="#ff0000"                 # Example: orange accent; use your hex color
PLASMA_THEME="Breeze-Dark"             # Your preferred Plasma look & feel theme
WALLPAPER_PATH="$DOTFILES_DIR/wallpapers"

echo "=== Starting setup for $USER ==="

# === Detect distro ===
if [ -f /etc/fedora-release ]; then
    PKG_INSTALL="sudo dnf install -y"
elif [ -f /etc/arch-release ]; then
    PKG_INSTALL="sudo pacman -Syu --noconfirm"
elif [ -f /etc/debian_version ]; then
    PKG_INSTALL="sudo apt install -y"
else
    echo "Unsupported distro. Please edit script to add support."
    exit 1
fi

# === Update the system ===
if [ -f /etc/fedora-release ]; then
    sudo dnf update
elif [ -f /etc/arch-release ]; then
    sudo pacman -Syu
elif [ -f /etc/debian_version ]; then
    sudo apt update && sudo apt upgrade
else
    echo "Unsupported distro. Please edit script to add support."
    exit 1
fi

# === Install dependencies ===
echo "Installing dependencies..."
$PKG_INSTALL git zsh curl wget cowsay

# === Install GPU Drivers (ARCH ONLY) ===
if [ -f /etc/arch-release ]; then    
    echo "What is the GPU Vendor? (amd/nvidia/intel)"
    read gpu
    if [ $gpu = "amd" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu
    elif [ $gpu = "intel" ]; then
        $PKG_INSTALL mesa lib32-mesa vulkan-intel lib32-vulkan-intel xf86-video-intel
    elif [ $gpu = "nvidia" ]; then
        $PKG_INSTALL nvidia nvidia-dkms nvidia-utils lib32-nvidia-utils
    else
        echo "Invalid GPU Vendor, skipping..."
    fi
else
    echo "GPU Driver Installation only works on Arch Linux, skipping..."
fi


# === Clone dotfiles repo ===
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles from GitHub..."
    git clone "https://github.com/$GITHUB_USER/$DOTFILES_REPO.git" "$DOTFILES_DIR"
else
    echo "Dotfiles already cloned — pulling latest changes..."
    git -C "$DOTFILES_DIR" pull
fi

# === Install Oh My Zsh ===
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed."
fi

# === Copy Zsh config ===
if [ -f "$DOTFILES_DIR/.zshrc" ]; then
    echo "Applying .zshrc from dotfiles..."
    cp -f "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
fi

# === Copy Oh My Zsh custom configs if they exist ===
if [ -d "$DOTFILES_DIR/oh-my-zsh-custom" ]; then
    echo "Copying custom Oh My Zsh configuration..."
    mkdir -p "$HOME/.oh-my-zsh/custom/"
    cp -r "$DOTFILES_DIR/oh-my-zsh-custom/"* "$HOME/.oh-my-zsh/custom/"
fi


# === KDE Appearance ===
echo "Applying KDE customization..."

# === Apply cursor from dotfiles ===
if [ -d "$DOTFILES_DIR/cursors" ]; then
    echo "Installing and applying custom cursor..."
    mkdir -p ~/.icons
    cp -r "$DOTFILES_DIR/cursors"/* ~/.icons/

    # Assuming your cursor folder name matches the theme name
    CURSOR_NAME=$(ls "$DOTFILES_DIR/cursors" | head -n 1)

    # Apply cursor (KDE or GNOME based)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_NAME"
    elif command -v plasma-apply-cursortheme &>/dev/null; then
        plasma-apply-cursortheme "$CURSOR_NAME"
    else
        echo "Could not automatically apply cursor — please select it manually in system settings."
    fi
else
    echo "No cursor directory found in dotfiles."
fi

# === Install Papirus Icon Theme ===
echo "Installing Papirus icons..."
$PKG_INSTALL papirus-icon-theme

# Icon theme
lookandfeeltool --apply org.kde.breeze.desktop || true
kwriteconfig5 --file kdeglobals --group Icons --key Theme "$ICON_THEME"

# Color scheme
kwriteconfig5 --file kdeglobals --group General --key AccentColor "$ACCENT_COLOR"
plasma-apply-colorscheme BreezeDark

# Wallpaper
if [ -d "$WALLPAPER_PATH" ]; then
    echo "Copying wallpapers..."
    mkdir -p ~/Pictures/wallpapers/
    cp -r "$WALLPAPER_PATH"/* ~/Pictures/wallpapers/
fi

# === Fonts ===
if [ -d "$DOTFILES_DIR/fonts" ]; then
    echo "Installing custom fonts..."
    mkdir -p ~/.local/share/fonts/
    cp -r "$DOTFILES_DIR/fonts/"* ~/.local/share/fonts/
    fc-cache -fv
fi

# === KWin & Global KDE Config ===
if [ -d "$DOTFILES_DIR/kde-config" ]; then
    echo "Applying KDE window manager and Plasma configs..."
    cp -r "$DOTFILES_DIR/kde-config/"* ~/.config/
fi

# === Konsole config ===
if [ -d "$DOTFILES_DIR/konsole" ]; then
    echo "Applying Konsole profiles and color schemes..."
    mkdir -p ~/.local/share/konsole/
    cp -r "$DOTFILES_DIR/konsole/"* ~/.local/share/konsole/
fi

# Restart Plasma shell to apply changes (optional)
if pgrep plasmashell &>/dev/null; then
    echo "Restarting Plasma shell..."
    kquitapp5 plasmashell && kstart5 plasmashell &
fi

# === Change default shell to zsh ===
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi

echo "=== Setup complete! ==="
echo "Restart your terminal or log out/in for changes to apply."
