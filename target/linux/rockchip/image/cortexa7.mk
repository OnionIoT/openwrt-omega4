# SPDX-License-Identifier: GPL-2.0-only
# Keep Omega4's existing Rockchip FIT/resource and NAND upgrade format.

define Build/omega4-fit
	rm -rf $@.boot
	mkdir -p $@.boot
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/board.dtb
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel
	$(CP) rv1103b/boot.its $@.boot/boot.its
	$(CP) rv1103b/logo.bmp rv1103b/logo_kernel.bmp $@.boot/
	(cd $@.boot && $(KDIR)/omega4-resource-tool board.dtb logo.bmp logo_kernel.bmp)
	$(CP) $@.boot/board.dtb $@.boot/fdt
	$(CP) $@.boot/resource.img $@.boot/resource
	PATH="$(LINUX_DIR)/scripts/dtc:$(PATH)" mkimage -B 0x200 -E -p 0x800 -f $@.boot/boot.its $@
endef

define Build/omega4-env
	mkenvimage -s 0x40000 -p 0x0 -o $@ rv1103b/uboot-env.txt
endef

define Device/omega4-common
  PROFILES := Default
  SOC := rv1103b
  DEVICE_VENDOR := plan44
  DEVICE_MODEL := Omega4 baseboard
  BOARD_NAME := plan44,rv1103b-p44-base-omega4
  SUPPORTED_DEVICES := plan44,rv1103b-p44-base-omega4
  DEVICE_DTS_DIR := ../dts
  DEVICE_DTC_FLAGS := -@
  KERNEL_NAME := zImage
  KERNEL := kernel-bin | omega4-fit | check-size 8192k
  FILESYSTEMS := squashfs
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 97280k
  MKUBIFS_OPTS := -m 2048 -e 124KiB -c 2114
  IMAGES := boot.img rootfs.img env.img sysupgrade.tar
  IMAGE/boot.img := append-kernel
  IMAGE/rootfs.img := append-ubi | pad-to $$$$(PAGESIZE) | check-size $$$$(IMAGE_SIZE)
  IMAGE/env.img := omega4-env
  IMAGE/sysupgrade.tar := sysupgrade-tar | append-metadata
  DEVICE_PACKAGES := kmod-dtbocfg
endef

define Device/plan44_p44-xx-omega4
  $(Device/omega4-common)
  DEVICE_DTS := rv1103b-p44-base-omega4
endef
TARGET_DEVICES += plan44_p44-xx-omega4

# Explicit opt-in: UART0 M0 conflicts with production OLED/I2C0 M0 overlays.
# Same runtime board identity/archive directory preserves the 24.10 upgrade path.
define Device/plan44_p44-xx-omega4-debug
  $(Device/omega4-common)
  DEVICE_VARIANT := PIO serial debug (no OLED/I2C0 M0 overlays)
  DEVICE_DTS := rv1103b-p44-base-omega4-debug
endef
TARGET_DEVICES += plan44_p44-xx-omega4-debug

# Onion boards retain their installed NAND layout and runtime board identity.
define Build/onion-boot-env
	$(CP) $(BIN_DIR)/$(1)-boot/env.img $@
endef

define Build/boot-omega4p-bin
	rm -rf $@.boot
	mkdir -p $@.boot
	$(CP) boot-omega4p.its $@.boot/boot.its
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/fdt
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel
	PATH="$(LINUX_DIR)/scripts/dtc:$(PATH)" mkimage -B 0x200 -E -p 0x800 -f $@.boot/boot.its $@
endef

define Device/onion_omega4-evb
  $(Device/omega4-common)
  DEVICE_VENDOR := Onion
  DEVICE_MODEL := Omega4 EVB
  BOARD_NAME := onion,rv1103b-omega4-evb
  SUPPORTED_DEVICES := onion,rv1103b-omega4-evb onion,onion_omega4
  DEVICE_DTS := rv1103b-omega4-evb
  DEVICE_PACKAGES := kmod-rknpu-rockchip
  IMAGE/env.img := onion-boot-env omega4
endef
TARGET_DEVICES += onion_omega4-evb

define Device/onion_omega4p-evb
  $(Device/omega4-common)
  DEVICE_VENDOR := Onion
  DEVICE_MODEL := Omega4+ EVB
  BOARD_NAME := onion,rv1106b-omega4p-evb
  SUPPORTED_DEVICES := onion,rv1106b-omega4p-evb
  SOC := rv1106b
  DEVICE_DTS := rv1106b-omega4p-evb
  DEVICE_PACKAGES := kmod-rknpu-rockchip
  IMAGE_SIZE := 235520k
  KERNEL_SIZE := 6144k
  KERNEL := kernel-bin | boot-omega4p-bin | check-size 6144k
  IMAGE/env.img := onion-boot-env omega4p
endef
TARGET_DEVICES += onion_omega4p-evb
