# Omega4+ kernel and OpenWrt support

Omega4+ uses RV1106B with 256 MiB external QN3B128M16S-16B DDR3 and
256 MiB SPI NAND. The user confirmed that peripheral wiring, including
Ethernet, matches Omega4 EVB. The new profile is `onion_omega4p-evb`;
its runtime board name is `onion,rv1106b-omega4p-evb`.

## Implementation

The external kernel needs the companion changes in
`arch/arm/mach-rockchip/rockchip.c` and the Rockchip board DT binding.
RV1106B uses the existing RV1103B peripheral drivers. DDR initialization
belongs to the loader, not a Linux driver. RAM capacity is supplied by the
loader/U-Boot; the board DTS does not hard-code a memory bank.

OpenWrt owns the board DTS in `target/linux/rockchip/dts`. The Omega4+ tree
inherits Omega4 EVB peripherals, sets its own model/compatible and partitions,
and uses UART0 at 115200 8N1. FIQ debugger is disabled so it does not contend
with the normal UART driver. The official SDK's RV1106B EVB DTS deletes GMAC;
that peripheral change is deliberately not inherited for this board.

Network MAC extraction from the environment, uboot-envtools configuration,
and NAND sysupgrade recognize the new board. The old Omega4 profile remains
available. Omega4 and Omega4+ sysupgrade board identities are distinct.

## Verified SDK inputs

The reference is the official SDK under `../ref/1103B-SDK`, specifically:

- Report: `output/reports/rv1106b-external-ddr-2026-11-09/REPORT.md`
- Release: `output/rv1106b-256nand-256ram-ddr667-v107-uart115200/`
- Loader: DDR v1.07, configured DDR3 frequency 667 MHz, UART 115200.

Both `download.bin` (USB loader) and `idblock.img` (NAND loader) must use the
correct DDR binary. The vendor report confirms flashing and Linux console
operation with this combination. The bundle helper checks the exact SHA256
of those files and `uboot.img` before copying them. No SDK source is modified.

## Flash layout

Offsets and sizes below are bytes. Page size is 2048 and eraseblock size is
128 KiB. The bootloader and boot offsets match the verified SDK release.

| Partition | Offset | Size |
| --- | --- | --- |
| env | 0x00000000 | 0x00040000 |
| idblock | 0x00040000 | 0x00100000 |
| uboot | 0x00140000 | 0x00200000 |
| meta | 0x00340000 | 0x00200000 |
| boot | 0x00540000 | 0x00600000 |
| ubi | 0x00b40000 | 0x0e600000 |

UBI ends at `0x0f140000`, retaining the SDK's 14.75 MiB end margin. It replaces
the SDK's rootfs and userdata partitions. `rootfs.img` is a UBI image containing
the OpenWrt squashfs rootfs; it is not the SDK EROFS ramdisk. The new environment
selects `ubi.mtd=ubi`, `ubi.block=0,rootfs`, and `/dev/ubiblock0_0`. The vendor
partition identifier `spi-nand0` is retained for U-Boot; Linux has matching
fixed partitions in the DT. Images enforce the 6 MiB boot and 230 MiB UBI limits.

Initial installation requires a filesystem-layout migration and backup of
any existing data/environment. `sysupgrade.tar` is only for an already installed
Omega4+ OpenWrt system with this layout. Sysupgrade does not replace the DDR
loader, U-Boot, meta or environment.

## Build

In OpenWrt menuconfig select Rockchip / Cortex-A7 / Onion Omega4+ EVB and set
the external kernel tree to this workspace's `linux-stable`. Keep the local
`omega4-kernel-packages` feed enabled. For an existing Omega4 configuration,
replace `CONFIG_TARGET_rockchip_cortexa7_DEVICE_onion_omega4-evb=y` with
`CONFIG_TARGET_rockchip_cortexa7_DEVICE_onion_omega4p-evb=y`, then run:

```sh
make defconfig
make -j20
```

Outputs appear under `bin/targets/rockchip/cortexa7/` with the
`openwrt-rockchip-cortexa7-onion_omega4p-evb` prefix: boot, environment, UBI
rootfs and sysupgrade images. The local feed's `omega4p-boot` package builds
U-Boot/SPL and packages the pinned DDR/MCU inputs, producing the three boot
images under `omega4p-boot/`. Install the feed package before `make defconfig`;
the Omega4+ profile selects it by default. It requires a pinned reference SDK
Git checkout for source export (default `../../ref/1103B-SDK`), but does not
reuse finished SDK boot images or modify that checkout. See the package's
`omega4p-boot-doc.md`. To assemble a local bundle after building:

```sh
python3 scripts/omega4p/bundle.py \
  --boot-dir bin/targets/rockchip/cortexa7/omega4p-boot \
  --images bin/targets/rockchip/cortexa7 \
  --output bin/targets/rockchip/cortexa7/omega4p-bundle
```

The helper verifies inputs before creating a new output directory, emits
`SHA256SUMS` and a byte-addressed `layout.json`, and never flashes a device.
It does not package or overwrite SDK meta; the bundle is not `update.img`.
The original SDK release remains available through `--sdk-release` instead
of `--boot-dir`. New package-built images require their own hardware test;
the validation below describes the original SDK boot images.

## Hardware validation — 19 November 2026

Flashed and tested on HWSPD-C1 A29C (`uid:4C5719400B3932323834544B`).
The whole readable flash was backed up before writing: 267,911,168 bytes,
all erased (`0xff`). The chip reports SPI NAND ID `c8 52 c8` (GigaDevice),
2 KiB pages and 128 KiB eraseblocks. No existing network settings were present.

Two boot-time issues were fixed:

1. SDK SPL requires a FIT configuration description and actual load addresses.
   `boot-omega4p.its` loads the zImage at `0x02000000` and DTB at `0x00c00000`.
   The ordinary ARM image template's `0xffffff00/1` U-Boot relocation values
   cannot be used with this SPL's direct kernel boot path.
2. The environment MAC cell belongs under `nvmem-layout` with
   `compatible = "u-boot,env"`, matching `CONFIG_NVMEM_LAYOUT_U_BOOT_ENV`.
   Putting that compatible directly on the partition suppressed the MTD NVMEM
   provider and indefinitely deferred Ethernet probing.

The full build passed again after these fixes. Final boot image size is
4,698,112 bytes; UBI image 21,102,592 bytes; environment 262,144 bytes;
sysupgrade archive 24,884,023 bytes. The SDK loader/idblock/U-Boot binaries
remain unchanged. No SDK meta was flashed. SPL logs missing meta and a missing
vendor ramdisk partition, then successfully validates the FIT and boots Linux;
OpenWrt uses UBI instead of the SDK ramdisk.

Verified on hardware:

- Flash writes read back byte-for-byte; boot images were reverified after fixes.
- DDR v1.07 detects 256 MiB and reports 660 MHz for the configured 667 MHz setting.
- OpenWrt 24.10.2 / Linux 6.6.93+ boots with the correct Omega4+ identity.
- 248,840 KiB usable memory; a 96 MiB allocation passes eight address-dependent
  write/read patterns. This is a smoke test, not full DDR qualification.
- Six expected MTD partitions, writable UBIFS overlay, and persistence across
  a cold boot with a measured approximately 2.8-second power-off interval.
- Wi-Fi scan detects eight access points across 2.4 GHz and 5 GHz.
- Ethernet and its PHY initialize; MAC matches the persisted environment.
- 70 lines in `lsmod` (including its header).
- `sysupgrade -T` accepts an on-device archive whose CONTROL, kernel and root
  payload hashes exactly match the build archive. An actual settings-preserving
  sysupgrade completes and reboots. A temporary config marker survives; network
  configuration and the entire environment partition retain identical hashes.
  The on-device archive avoids transferring 25 MiB over serial; tar container
  bytes differ from the host-built archive, but all three payloads match.

The existing first-boot script creates `ethaddr` when absent. An initially
unprovisioned environment requires a subsequent boot for the NVMEM MAC cell
and hostname to reflect that new value. Do not overwrite a provisioned env.img
when updating a device; ordinary sysupgrade preserves it.

Remaining limitations: Ethernet carrier stayed zero, so DHCP/traffic could not
be tested. The camera sensor returned ID zero and no ALSA card enumerated
(`acodec-sound` remains deferred; the inherited kernel lacks SAI build wiring).
Camera and audio are not validated by this bring-up. Ethernet configuration
was not changed. Final state: DUT powered on, boot button released, both USB
ports enabled. Detailed evidence and the flash backup are in the workspace's
`hardware-validation/` directory.

## Package-built bootloader validation — 19 November 2026

The local feed's `omega4p-boot` outputs were subsequently flashed on A29C.
New USB downloader, idblock/U-Boot readback, normal/cold boots and the rebuilt
U-Boot console passed. Network settings and environment were preserved.
Ethernet now had carrier: 100 Mb/s link, an address and 3/3 gateway ping replies;
Wi-Fi scan returned seven APs. The earlier no-carrier limitation is superseded
by this result. Camera/audio remain unvalidated. A UBI timeout occurred before
the bootloader update and did not recur during these tests; it is not considered
a diagnosed/fixed issue. See `hardware-validation/omega4p-boot/REPORT.md`.
