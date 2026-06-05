#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo $0"
    exit 1
fi

echo "=== NVIDIA Driver Installation (NVIDIA's CUDA apt repo, Debian) ==="
echo ""

KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb"
PIN_FILE=/etc/apt/preferences.d/nvidia-cuda-repo.pref

# 1. Set up NVIDIA's repo and pin
echo "[1/7] Configuring NVIDIA CUDA repo + apt pin..."

cat > "$PIN_FILE" <<'EOF'
# All packages from NVIDIA's CUDA apt repo win over Debian's.
# (Debian forky packages have priority 900; 990 overrides them.)
# The repo only ships nvidia-* and cuda-* packages, so this is safe.
Package: *
Pin: origin developer.download.nvidia.com
Pin-Priority: 990
EOF
echo "      wrote $PIN_FILE"

if ! dpkg -l cuda-keyring >/dev/null 2>&1; then
    TMPDEB=$(mktemp --suffix=.deb)
    echo "      downloading cuda-keyring..."
    wget -q -O "$TMPDEB" "$KEYRING_URL"
    dpkg -i "$TMPDEB"
    rm -f "$TMPDEB"
else
    echo "      cuda-keyring already installed"
fi

apt-get update

# 2. Remove any pre-existing Debian nvidia stack to avoid conflicts
echo "[2/7] Removing any old Debian nvidia stack..."
if dpkg -l | awk '{print $2}' | grep -qE '^(nvidia-kernel-dkms|nvidia-driver|libnvidia-cfg1)$'; then
    apt-get purge -y '~nnvidia-kernel-(dkms|common|support|550|535|525|470|460|450|418|390|340)' \
                     '~nlibnvidia-' 'xserver-xorg-video-nvidia*' \
                     glx-alternative-nvidia 2>/dev/null || true
    apt-get autoremove --purge -y
else
    echo "      none present"
fi

# 3. Install NVIDIA's driver (open kernel module — required for Turing+, fine for Ampere+)
echo "[3/7] Installing nvidia-open from NVIDIA's repo..."
apt-get install -y nvidia-open

# 4. Enroll MOK key for Secure Boot
echo "[4/7] Checking MOK enrollment for Secure Boot..."
if [ ! -f /var/lib/dkms/mok.pub ]; then
    echo "      /var/lib/dkms/mok.pub not present (Secure Boot likely off, or DKMS didn't sign)."
elif mokutil --test-key /var/lib/dkms/mok.pub 2>/dev/null | grep -q "already enrolled"; then
    echo "      MOK key already enrolled."
else
    echo "      Enrolling MOK key — you will be prompted to set a one-time password."
    echo "      Remember it: needed on next reboot's blue MOK Manager screen."
    mokutil --import /var/lib/dkms/mok.pub
fi

# 5. GRUB config
echo "[5/7] Configuring GRUB..."
GRUB_FILE=/etc/default/grub
# Collapse any duplicate GRUB_DEFAULT lines down to one at the top.
sed -i '/^GRUB_DEFAULT=/d' "$GRUB_FILE"
sed -i '1s/^/GRUB_DEFAULT=0\n/' "$GRUB_FILE"
# Ensure nvidia-drm.modeset=1 is on the kernel cmdline.
if ! grep -q "nvidia-drm.modeset=1" "$GRUB_FILE"; then
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' "$GRUB_FILE"
fi

# 6. Blacklist nouveau (nvidia-open's postinst usually handles this, but be explicit)
echo "[6/7] Blacklisting nouveau..."
cat > /etc/modprobe.d/nvidia-blacklists-nouveau.conf <<'EOF'
blacklist nouveau
blacklist lbm-nouveau
alias nouveau off
alias lbm-nouveau off
EOF

# Remove any leftover AMD iGPU blacklist — the dGPU/iGPU coexist fine,
# and blacklisting amdgpu doesn't help if the monitor is on the dGPU outputs.
rm -f /etc/modprobe.d/blacklist-amdgpu.conf

# 7. Apply
echo "[7/7] Updating initramfs and GRUB..."
update-initramfs -u
update-grub

echo ""
echo "=== Done! ==="
echo ""
echo "DKMS status:"
/usr/sbin/dkms status || true
echo ""
if [ -f /var/lib/dkms/mok.pub ] && mokutil --test-key /var/lib/dkms/mok.pub 2>/dev/null | grep -q "not enrolled"; then
    echo "NEXT: Reboot. On the blue MOK Manager screen:"
    echo "      Enroll MOK → Continue → enter your password → Reboot"
else
    echo "NEXT: Reboot the system."
fi
echo ""
echo "After reboot, verify:"
echo "  uname -r            # currently booted kernel"
echo "  lsmod | grep nvidia # nvidia modules loaded"
echo "  nvidia-smi          # GPU info, expect 610.x or whatever you installed"
