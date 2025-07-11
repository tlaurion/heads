#!/bin/bash
# Script to automatically download and add distribution GPG keys for ISO signature verification
# Usage: ./add-distro-keys.sh [distribution-name|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="/etc/distro/keys"

# Ensure we're running as root or with appropriate permissions
if [[ $EUID -ne 0 ]] && [[ ! -w "$KEYS_DIR" ]]; then
    echo "Error: This script requires write access to $KEYS_DIR"
    echo "Please run as root or ensure you have write permissions"
    exit 1
fi

# Create keys directory if it doesn't exist
mkdir -p "$KEYS_DIR"

# Function to download and add a key
add_key() {
    local distro="$1"
    local key_id="$2"
    local key_file="$3"
    local url="$4"
    
    echo "Adding $distro key..."
    
    # Download the key
    if command -v wget >/dev/null 2>&1; then
        wget -O "$KEYS_DIR/$key_file" "$url" || {
            echo "Warning: Failed to download $distro key from $url"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -o "$KEYS_DIR/$key_file" "$url" || {
            echo "Warning: Failed to download $distro key from $url"
            return 1
        }
    else
        echo "Warning: Neither wget nor curl available, cannot download $distro key"
        return 1
    fi
    
    # Verify the key was downloaded successfully
    if [[ -f "$KEYS_DIR/$key_file" ]] && [[ -s "$KEYS_DIR/$key_file" ]]; then
        echo "Successfully added $distro key to $KEYS_DIR/$key_file"
        
        # Show key info if gpg is available
        if command -v gpg >/dev/null 2>&1; then
            echo "Key information:"
            gpg --show-keys --with-fingerprint "$KEYS_DIR/$key_file" 2>/dev/null | head -3
        fi
    else
        echo "Error: Failed to add $distro key"
        return 1
    fi
}

# Function to add all keys
add_all_keys() {
    echo "Adding all distribution keys..."
    
    # Debian
    add_key "Debian" "64E6EA7D" "debian.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x64E6EA7D"
    
    # Ubuntu
    add_key "Ubuntu" "843938DF228D22F7B3742BC0D94AA3F0EFE21092" "ubuntu.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x843938DF228D22F7B3742BC0D94AA3F0EFE21092"
    
    # Fedora
    add_key "Fedora" "38AB71F4" "fedora.key" \
        "https://fedoraproject.org/fedora.gpg"
    
    # openSUSE
    add_key "openSUSE" "3DBDC284" "opensuse.key" \
        "https://build.opensuse.org/projects/openSUSE:Factory/public_key"
    
    # CentOS
    add_key "CentOS" "05B555B3" "centos.key" \
        "https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official"
    
    # Linux Mint
    add_key "Linux Mint" "27DEB15644C6B3CF" "mint.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x27DEB15644C6B3CF"
    
    # Manjaro
    add_key "Manjaro" "11C7F07E" "manjaro.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x11C7F07E"
    
    # Elementary OS
    add_key "Elementary OS" "204DD8AEC33A7AFF" "elementary.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF"
    
    # Pop!_OS
    add_key "Pop!_OS" "204DD8AEC33A7AFF" "popos.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF"
    
    # Kali Linux
    add_key "Kali Linux" "44C6513A8E4FB3D3" "kali.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x44C6513A8E4FB3D3"
    
    # Alpine Linux
    add_key "Alpine Linux" "0482D84022F52DF1" "alpine.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0482D84022F52DF1"
    
    # Gentoo
    add_key "Gentoo" "13EBBDBEDE7A12775DFDB1BABB572E0E2D182910" "gentoo.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x13EBBDBEDE7A12775DFDB1BABB572E0E2D182910"
    
    # Void Linux
    add_key "Void Linux" "307EA4CBAB8FBE56" "void.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x307EA4CBAB8FBE56"
    
    # NixOS
    add_key "NixOS" "B541D55301270E0BCF15CA5D8170B4726D7198DE" "nixos.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB541D55301270E0BCF15CA5D8170B4726D7198DE"
    
    # EndeavourOS
    add_key "EndeavourOS" "003DB8B0CB23504F" "endeavouros.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x003DB8B0CB23504F"
    
    # Zorin OS
    add_key "Zorin OS" "2BED339A87A1C2F4" "zorin.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2BED339A87A1C2F4"
    
    # MX Linux
    add_key "MX Linux" "03872F78" "mxlinux.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x03872F78"
    
    # SUSE Linux Enterprise
    add_key "SUSE Linux Enterprise" "39DB7C82" "sle.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x39DB7C82"
    
    # Rocky Linux
    add_key "Rocky Linux" "15AF5DAC6D745A60" "rocky.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x15AF5DAC6D745A60"
    
    # AlmaLinux
    add_key "AlmaLinux" "51D6647EC21AD6EA" "alma.key" \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x51D6647EC21AD6EA"
    
    echo "Finished adding distribution keys."
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [distribution-name|all]"
    echo ""
    echo "Available distributions:"
    echo "  debian, ubuntu, fedora, opensuse, centos, mint, manjaro,"
    echo "  elementary, popos, kali, alpine, gentoo, void, nixos,"
    echo "  endeavouros, zorin, mxlinux, sle, rocky, alma"
    echo ""
    echo "Examples:"
    echo "  $0 debian          # Add Debian key only"
    echo "  $0 ubuntu          # Add Ubuntu key only"
    echo "  $0 all             # Add all keys"
    echo ""
    echo "Note: This script requires internet access to download keys from keyservers"
    echo "and official distribution websites."
}

# Main script logic
case "${1:-}" in
    "debian")
        add_key "Debian" "64E6EA7D" "debian.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x64E6EA7D"
        ;;
    "ubuntu")
        add_key "Ubuntu" "843938DF228D22F7B3742BC0D94AA3F0EFE21092" "ubuntu.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x843938DF228D22F7B3742BC0D94AA3F0EFE21092"
        ;;
    "fedora")
        add_key "Fedora" "38AB71F4" "fedora.key" \
            "https://fedoraproject.org/fedora.gpg"
        ;;
    "opensuse")
        add_key "openSUSE" "3DBDC284" "opensuse.key" \
            "https://build.opensuse.org/projects/openSUSE:Factory/public_key"
        ;;
    "centos")
        add_key "CentOS" "05B555B3" "centos.key" \
            "https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official"
        ;;
    "mint")
        add_key "Linux Mint" "27DEB15644C6B3CF" "mint.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x27DEB15644C6B3CF"
        ;;
    "manjaro")
        add_key "Manjaro" "11C7F07E" "manjaro.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x11C7F07E"
        ;;
    "elementary")
        add_key "Elementary OS" "204DD8AEC33A7AFF" "elementary.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF"
        ;;
    "popos")
        add_key "Pop!_OS" "204DD8AEC33A7AFF" "popos.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x204DD8AEC33A7AFF"
        ;;
    "kali")
        add_key "Kali Linux" "44C6513A8E4FB3D3" "kali.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x44C6513A8E4FB3D3"
        ;;
    "alpine")
        add_key "Alpine Linux" "0482D84022F52DF1" "alpine.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x0482D84022F52DF1"
        ;;
    "gentoo")
        add_key "Gentoo" "13EBBDBEDE7A12775DFDB1BABB572E0E2D182910" "gentoo.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x13EBBDBEDE7A12775DFDB1BABB572E0E2D182910"
        ;;
    "void")
        add_key "Void Linux" "307EA4CBAB8FBE56" "void.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x307EA4CBAB8FBE56"
        ;;
    "nixos")
        add_key "NixOS" "B541D55301270E0BCF15CA5D8170B4726D7198DE" "nixos.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB541D55301270E0BCF15CA5D8170B4726D7198DE"
        ;;
    "endeavouros")
        add_key "EndeavourOS" "003DB8B0CB23504F" "endeavouros.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x003DB8B0CB23504F"
        ;;
    "zorin")
        add_key "Zorin OS" "2BED339A87A1C2F4" "zorin.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2BED339A87A1C2F4"
        ;;
    "mxlinux")
        add_key "MX Linux" "03872F78" "mxlinux.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x03872F78"
        ;;
    "sle")
        add_key "SUSE Linux Enterprise" "39DB7C82" "sle.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x39DB7C82"
        ;;
    "rocky")
        add_key "Rocky Linux" "15AF5DAC6D745A60" "rocky.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x15AF5DAC6D745A60"
        ;;
    "alma")
        add_key "AlmaLinux" "51D6647EC21AD6EA" "alma.key" \
            "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x51D6647EC21AD6EA"
        ;;
    "all")
        add_all_keys
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        echo "Error: Invalid or missing distribution name"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Import the keys into the distro keyring if gpg is available
if command -v gpg >/dev/null 2>&1; then
    echo ""
    echo "Importing keys into distro keyring..."
    gpg --homedir=/etc/distro/ --import /etc/distro/keys/* 2>/dev/null || echo "Warning: Some keys may have failed to import"
    echo "Keys imported successfully."
    echo ""
    echo "To verify the keys were imported, run:"
    echo "  gpg --homedir=/etc/distro/ --list-keys"
fi

echo ""
echo "Distribution keys have been added to $KEYS_DIR"
echo "They will be automatically trusted for ISO signature verification."