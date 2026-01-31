#!/bin/bash

# =============================================
# Pop!_OS Recovery Script - COMPLETE VERSION 2.0
# With EFI checks, Secure Boot handling, and more
# =============================================

set -euo pipefail

echo "Pop!_OS Recovery Tool - Starting..."

# --- SYSTEM VERIFICATION ---
if ! blkid | grep -q "6d89b045-b1ba-494b-a5c0-36ae4775c1c2"; then
    echo "ERROR: This script is for a specific system only!"
    exit 1
fi

if ! blkid | grep -q "91E1-9C8D"; then
    echo "ERROR: EFI partition missing!"
    exit 1
fi

# --- SECURE BOOT CHECK ---
echo -e "\n[+] Checking Secure Boot status..."
if [ -d "/sys/firmware/efi" ]; then
    if grep -q "SecureBootEnabled" /sys/firmware/efi/efivars/SecureBoot-*; then
        echo "WARNING: Secure Boot is enabled!"
        echo "You may need to disable it in BIOS for recovery."
    fi
else
    echo "Not running in EFI mode - skipping Secure Boot check"
fi

# --- EFI PARTITION CHECK ---
echo -e "\n[+] Checking EFI partition..."
sudo mount UUID=91E1-9C8D /mnt/efi
if [ -d "/mnt/efi" ]; then
    echo "Running dosfsck on EFI partition..."
    sudo dosfsck -a /dev/nvme1n1p1 || true  # Continue even if minor errors
fi

# --- FILESYSTEM CHECKS ---
echo -e "\n[+] Checking all filesystems..."
for part in $(blkid | awk '/ext4|vfat/{print $1}'); do
    case "$(blkid -s TYPE -o value "$part")" in
        ext4) sudo fsck -y "$part" || true ;;
        vfat) sudo dosfsck -a "$part" || true ;;
        ntfs) sudo ntfsfix "$part" || true ;;
    esac
done

# --- MOUNT PARTITIONS ---
sudo mkdir -p /mnt/popos /mnt/efi
sudo mount UUID=6d89b045-b1ba-494b-a5c0-36ae4775c1c2 /mnt/popos
sudo mount UUID=91E1-9C8D /mnt/efi

# --- BIND ESSENTIAL DIRECTORIES ---
sudo mount --bind /dev /mnt/popos/dev || true
sudo mount --bind /proc /mnt/popos/proc || true
sudo mount --bind /sys /mnt/popos/sys || true

# --- BACKUP CRITICAL FILES ---
echo -e "\n[+] Backing up critical files..."
sudo cp /mnt/popos/etc/fstab /mnt/popos/etc/fstab.bak.$(date +%Y%m%d)
if [ -f "/mnt/popos/boot/grub/grub.cfg" ]; then
    sudo cp /mnt/popos/boot/grub/grub.cfg /mnt/popos/boot/grub/grub.cfg.bak
fi

# --- CHROOT AND REPAIR ---
echo -e "\n[+] Entering chroot for repairs..."
sudo chroot /mnt/popos <<EOF
apt update && apt install -y systemd-boot dosfstools ntfs-3g
update-initramfs -u -k all  # Update initramfs for all kernels

# Install and configure bootloader
bootctl --path=/boot/efi install
bootctl update

# Verify boot entries
echo -e "\n[+] Boot entries after repair:"
efibootmgr | grep -E "Linux|Windows"

EOF

# --- VERIFY BOOT ENTRIES ---
echo -e "\n[+] Final boot entry verification..."
BOOT_ENTRY=$(efibootmgr | grep -o "Boot[0-9]*\* Linux" | head -1)
if [ -z "$BOOT_ENTRY" ]; then
    echo "ERROR: No valid Linux boot entry found!"
    exit 1
fi

# --- SET BOOT ORDER ---
echo -e "\n[+] Setting boot order..."
sudo efibootmgr --bootorder $BOOT_ENTRY,0002  # Linux first, Windows second

# --- CLEANUP ---
echo -e "\n[+] Unmounting..."
sudo umount -R /mnt/popos /mnt/efi

# --- FINAL INSTRUCTIONS ---
echo -e "\n=== Recovery Complete ==="
echo "1. Reboot your system"
echo "2. The boot order has been set automatically"
echo ""
echo "NOTES:"
echo "- Secure Boot may need to be disabled in BIOS"
echo "- If issues persist, check /etc/fstab.bak for restoration"

exit 0
