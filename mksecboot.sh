#!/bin/bash

FIRMWARE_PATH=${1}
ROOT=$(pwd)
TMP_DIR="${ROOT}/tmp"
CONFIG_DIR="${ROOT}/config"
DOWNLOAD_DIR="${ROOT}/dl"
GRUB2_REPO_URL="https://github.com/dweeezil/grub.git"
GRUB2_REPO_BRANCH="master"
GRUB2_MODULES="acpi ahci ata cbfs boot configfile disk gzio halt linux linux16
loadenv msdospart part_msdos probe ext2 scsi search_fs_file
search_fs_uuid search_label search serial squash4 ehci usb verify
xzio memdisk ohci uhci nativedisk serial"
COREBOOT_REPO_URL="https://review.coreboot.org/p/coreboot.git"
COREBOOT_REPO_BRANCH="master"
MAKE_ARGS="-j8"

mkdir "${TMP_DIR}"
mkdir "${DOWNLOAD_DIR}"

if [ ! -d "${DOWNLOAD_DIR}/grub" ] ; then
  cd "${DOWNLOAD_DIR}"
  git clone "${GRUB2_REPO_URL}" -b "${GRUB2_REPO_BRANCH}"
  git clone --recursive "${COREBOOT_REPO_URL}" -b "${COREBOOT_REPO_BRANCH}"
else
  cd "${DOWNLOAD_DIR}"
  cd grub && git clean -d -x -f && git stash

  cd "${DOWNLOAD_DIR}"
  cd coreboot && git clean -d -x -f && git stash
fi

# build grub2 with device-mapper and lzma for module compression
cd "${DOWNLOAD_DIR}"

cd grub && ./autogen.sh
./configure --enable-device-mapper --enable-liblzma --prefix="${TMP_DIR}" \
    --with-platform=coreboot
make "${MAKE_ARGS}"
make install

# Build coreboot cbfsutil in order to edit firmware image
cd "${DOWNLOAD_DIR}"

cd coreboot/util/cbfstool
make "${MAKE_ARGS}"
cp -a cbfstool fmaptool rmodtool "${TMP_DIR}/bin/"

# Add grub2.elf as payload for the firmware image and generate standalone grub for coreboot as payload
cd "${ROOT}"

"${TMP_DIR}/bin/grub-mkstandalone" --format i386-coreboot --compress=xz \
    --install-modules="${GRUB2_MODULES}" --verbose \
    --modules="${GRUB2_MODULES}" \
    --output "${TMP_DIR}/grub2.elf" \
    --fonts= --themes= --locales= \
    /boot/grub/grub.cfg="${CONFIG_DIR}/grub.cfg" \
    /memdisk/boot.pub="${CONFIG_DIR}/boot.pub"

echo "--------------------------OLD--------------------------"
"${TMP_DIR}/bin/cbfstool" "${FIRMWARE_PATH}" print
echo "-------------------------------------------------------"

"${TMP_DIR}/bin/cbfstool" "${FIRMWARE_PATH}" remove -n img/grub
"${TMP_DIR}/bin/cbfstool" "${FIRMWARE_PATH}" add-payload -f "${TMP_DIR}/grub2.elf" -n img/grub

echo "--------------------------NEW--------------------------"
"${TMP_DIR}/bin/cbfstool" "${FIRMWARE_PATH}" print
echo "-------------------------------------------------------"