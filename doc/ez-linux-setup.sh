#!/bin/bash

# Script to automate Cannacoin wallet compilation on Ubuntu Server 22.04
# Target file: cannacoin-smoke-main.zip in the home folder
# Addresses libxkbcommon array bounds error during dependency build
# Author: Grok 3 (xAI), PhD-level automation
# Date: 8 April 2025

# Exit on any error
set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Cannacoin wallet compilation process...${NC}"

# Step 1: Update system and install dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y make automake cmake curl g++-multilib libtool binutils-gold \
    bsdmainutils pkg-config python3 patch bison unzip libxcb-xkb-dev libx11-dev libxkbcommon-dev

# Step 2: Set up source code directory
echo "Setting up source code directory..."
cd ~/
mkdir -p source_code
cd source_code

# Check if ZIP file exists in home directory
ZIP_FILE="$HOME/cannacoin-smoke-main.zip"
if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}Error: $ZIP_FILE not found in home directory. Please place it there and rerun the script.${NC}"
    exit 1
fi

# Extract ZIP file
echo "Extracting $ZIP_FILE..."
unzip -o "$ZIP_FILE"
cd cannacoin-smoke-main || { echo -e "${RED}Error: Directory cannacoin-smoke-main not found after extraction.${NC}"; exit 1; }

# Step 3: Optional Boost patching
read -p "Does your wallet require the Boost patch for scrypt-pos? (y/N): " patch_choice
if [[ "$patch_choice" =~ ^[Yy]$ ]]; then
    echo "Downloading and applying Boost patch..."
    wget https://raw.githubusercontent.com/walletbuilders/source-patches/master/scrypt-pos/13.2.0/boost_fix_scrypt_pos_1320.diff
    patch -p1 < boost_fix_scrypt_pos_1320.diff || { echo -e "${RED}Error: Boost patching failed.${NC}"; exit 1; }
fi

# Step 4: Select architecture
echo "Select target architecture:"
echo "1) 64-bit (x86_64-pc-linux-gnu)"
echo "2) 32-bit (i686-pc-linux-gnu)"
read -p "Enter choice (1 or 2): " arch_choice
case $arch_choice in
    1)
        HOST="x86_64-pc-linux-gnu"
        ;;
    2)
        HOST="i686-pc-linux-gnu"
        ;;
    *)
        echo -e "${RED}Error: Invalid choice. Please enter 1 or 2.${NC}"
        exit 1
        ;;
esac

# Step 5: Choose GUI build
read -p "Do you want to build the GUI wallet? (y/N): " gui_choice
if [[ "$gui_choice" =~ ^[Yy]$ ]]; then
    GUI_OPTION=""
else
    GUI_OPTION="--without-gui"
fi

# Step 6: Modify libxkbcommon.mk to prevent array bounds warnings from being errors
echo "Checking and modifying libxkbcommon.mk to ignore array bounds warnings..."
LIBXKB_MK="depends/packages/libxkbcommon.mk"
if [ -f "$LIBXKB_MK" ]; then
    if ! grep -q '\$(package)_cflags += -Wno-error=array-bounds' "$LIBXKB_MK"; then
        echo "\$(package)_cflags += -Wno-error=array-bounds" >> "$LIBXKB_MK"
        echo "Modified $LIBXKB_MK to ignore array bounds warnings."
    else
        echo "$LIBXKB_MK already modified."
    fi
else
    echo "Warning: $LIBXKB_MK not found, proceeding without modification."
fi

# Step 7: Compile dependencies
echo "Building dependencies for $HOST..."
PATH=$(echo "$PATH" | sed -e 's/:\/mnt.*//g')
cd depends || { echo -e "${RED}Error: depends directory not found.${NC}"; exit 1; }
make HOST="$HOST" || { echo -e "${RED}Error: Dependency build failed.${NC}"; exit 1; }
cd ..

# Step 8: Configure and compile wallet
echo "Configuring and compiling wallet..."
./autogen.sh || { echo -e "${RED}Error: autogen.sh failed.${NC}"; exit 1; }
CONFIG_SITE=$PWD/depends/$HOST/share/config.site ./configure $GUI_OPTION --prefix=/ || { echo -e "${RED}Error: Configuration failed.${NC}"; exit 1; }
make || { echo -e "${RED}Error: Compilation failed.${NC}"; exit 1; }

# Step 9: Completion
echo -e "${GREEN}Compilation completed successfully!${NC}"
if [[ "$gui_choice" =~ ^[Yy]$ ]]; then
    echo "GUI wallet binary is located in src/qt."
fi
echo "Daemon/tools are located in src."
echo "To clean up, run 'make clean' in the source directory."

exit 0