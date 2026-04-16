#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo $0"
    exit 1
fi

echo "=== NVIDIA Driver Installation Script for Debian ==="
echo ""

# 1. Install NVIDIA packages
echo "[1/6] Installing nvidia-kernel-dkms and nvidia-driver..."
apt-get install -y nvidia-kernel-dkms nvidia-driver

# 2. Enroll MOK key for Secure Boot
echo "[2/6] Checking MOK enrollment for Secure Boot..."
if [ ! -f /var/lib/dkms/mok.pub ]; then
    echo "      WARNING: /var/lib/dkms/mok.pub not found — DKMS may not have run yet."
elif mokutil --test-key /var/lib/dkms/mok.pub 2>/dev/null | grep -q "already enrolled"; then
    echo "      MOK key already enrolled, skipping."
else
    echo "      Enrolling MOK key — you will be prompted to set a password."
    echo "      Remember it: you'll need it on the next reboot's blue MOK Manager screen."
    mokutil --import /var/lib/dkms/mok.pub
fi

# 3. Fix GRUB
echo "[3/6] Configuring GRUB..."
GRUB_FILE=/etc/default/grub

# Ensure exactly one GRUB_DEFAULT=0 at the top
sed -i '/^GRUB_DEFAULT=/d' "$GRUB_FILE"
sed -i '1s/^/GRUB_DEFAULT=0\n/' "$GRUB_FILE"

# Add nvidia-drm.modeset=1 to kernel cmdline if not already present
if ! grep -q "nvidia-drm.modeset=1" "$GRUB_FILE"; then
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' "$GRUB_FILE"
fi

# 4. Blacklist nouveau
echo "[4/6] Blacklisting nouveau..."
cat > /etc/modprobe.d/nvidia-blacklists-nouveau.conf <<'EOF'
blacklist nouveau
blacklist lbm-nouveau
alias nouveau off
alias lbm-nouveau off
EOF

# 5. Blacklist amdgpu if AMD display device and NVIDIA both present (iGPU conflict)
echo "[5/6] Checking for AMD iGPU + NVIDIA conflict..."
NVIDIA_PRESENT=$(lspci | grep -iE "VGA|3D|Display" | grep -ic nvidia || true)
AMD_PRESENT=$(lspci | grep -iE "VGA|3D|Display" | grep -iE "amd|radeon" -c || true)

if [ "$NVIDIA_PRESENT" -gt 0 ] && [ "$AMD_PRESENT" -gt 0 ]; then
    echo "      Both AMD and NVIDIA display devices found — blacklisting amdgpu."
    cat > /etc/modprobe.d/blacklist-amdgpu.conf <<'EOF'
blacklist amdgpu
EOF
else
    echo "      No AMD + NVIDIA conflict detected, skipping."
fi

# 6. Apply changes
echo "[6/6] Updating initramfs and GRUB..."
update-initramfs -u
update-grub

echo ""
echo "=== Done! ==="
echo ""
if [ -f /var/lib/dkms/mok.pub ] && mokutil --test-key /var/lib/dkms/mok.pub 2>/dev/null | grep -q "not enrolled"; then
    echo "NEXT: Reboot, then on the blue MOK Manager screen:"
    echo "      Enroll MOK → Continue → enter your password → Reboot"
else
    echo "NEXT: Reboot the system."
fi
echo ""
echo "After reboot, verify:"
echo "  uname -r            # newest kernel"
echo "  lsmod | grep nvidia # nvidia modules loaded"
echo "  nvidia-smi          # GPU info"
