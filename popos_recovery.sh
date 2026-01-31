#!/bin/bash

# =============================================
# Pop!_OS Recovery Script - FOR YOUR SYSTEM ONLY
# Uses your exact UUIDs from audit log
# =============================================

set -euo pipefail  # Exit on errors

echo "Pop!_OS Recovery Tool - Starting..."

# --- VALIDATE WE'RE ON THE RIGHT SYSTEM ---
if ! blkid | grep -q "6d89b045-b1ba-494b-a5c0-36ae4775c1c2"; then
    echo "ERROR: This script is for a specific system only!"
    echo "Your root partition (nvme1n1p3) not found."
    exit 1
fi

if ! blkid | grep -q "91E1-9C8D"; then
    echo "ERROR: EFI partition missing!"
    exit 1
fi

# --- MOUNT YOUR PARTITIONS ---
echo "Mounting partitions..."
sudo mkdir -p /mnt/popos /mnt/efi
sudo mount UUID=6d89b045-b1ba-494b-a5c0-36ae4775c1c2 /mnt/popos
sudo mount UUID=91E1-9C8D /mnt/efi

# --- BIND ESSENTIAL DIRECTORIES ---
echo "Setting up chroot environment..."
sudo mount --bind /dev /mnt/popos/dev || true
sudo mount --bind /proc /mnt/popos/proc || true
sudo mount --bind /sys /mnt/popos/sys || true

# --- REINSTALL SYSTEMD-BOOT ---
echo -e "\n[+] Reinstalling systemd-boot..."
sudo chroot /mnt/popos <<EOF
apt update && apt install -y systemd-boot
bootctl --path=/boot/efi install
bootctl update
EOF

# --- VERIFY INSTALLATION ---
echo -e "\n[+] Verifying boot entries:"
ls /mnt/efi/EFI/systemd/

# --- CLEANUP ---
echo -e "\n[+] Unmounting..."
sudo umount -R /mnt/popos /mnt/efi

# --- FINAL INSTRUCTIONS ---
echo -e "\n=== Recovery Complete ==="
echo "1. Reboot your system"
echo "2. In BIOS, ensure 'Linux Boot Manager' is first in boot order"
echo "3. Save changes and exit BIOS"

exit 0
