# OpenWrt 25.12 — Omega4 and Omega4+ Support

This repository provides **OpenWrt 25.12.6** support for the **Omega4**
(Rockchip RV1103B) and **Omega4+** (Rockchip RV1106B with external DDR).
It uses an external **Linux 6.12.112** kernel and Onion's board support packages.
The default branch in all three repositories is `omega4-openwrt-25.12`.

Support is under active development. Omega4+ has passed boot, sysupgrade,
Ethernet, Wi-Fi scanning, RTC, NPU inference, hardware H.264 encoding and memory
smoke tests. Original Omega4 builds pass, but hardware validation of this port
is pending. Camera capture, audio and NPU dynamic frequency/thermal control
remain unqualified. See [the port documentation](openwrt25-doc.md) for details.

## Repository Scope

- For **Omega4 or Omega4+ questions, issues or contributions**, open an
  [issue](https://github.com/OnionIoT/openwrt-omega4/issues) or
  [pull request](https://github.com/OnionIoT/openwrt-omega4/pulls) here.
- For general OpenWrt topics, use the
  [official OpenWrt repository](https://github.com/openwrt/openwrt).

## Firmware Downloads

Board-specific firmware packages are available on the
[releases page](https://github.com/OnionIoT/openwrt-omega4/releases).
Use the package matching your hardware; Omega4 and Omega4+ have different DDR
initialization, boot formats and flash layouts.

For an existing matching OpenWrt installation, back up settings and use its
`sysupgrade.tar`. Normal sysupgrade preserves configuration, bootloader and
boot environment. The ZIP's `env.img` is for initial provisioning; overwriting
an existing environment can replace its provisioned Ethernet MAC and boot settings.

OpenWrt 25.12 uses **APK instead of opkg**. No custom online APK repository is
published for this target; use matching locally built packages, especially
kernel modules.

## Setting Up the Build Environment

Install the host dependencies described in the original OpenWrt README below.
A fresh build workspace is recommended when moving from OpenWrt 24.10.

### 1. Clone the three repositories

Keep the kernel, OpenWrt and support packages as sibling directories:

```sh
git clone --branch omega4-openwrt-25.12 https://github.com/OnionIoT/linux-stable.git
git clone --branch omega4-openwrt-25.12 https://github.com/OnionIoT/omega4-kernel-packages.git
git clone --branch omega4-openwrt-25.12 https://github.com/OnionIoT/openwrt-omega4.git
cd openwrt-omega4
```

The kernel and OpenWrt branches build on plan44's 25.12 port, with Onion board
support carried forward. The package repository retains Onion's drivers,
utilities and boot packages, adapted for the newer kernel and wireless APIs.

### 2. Prepare the package feeds

```sh
cp feeds.conf.default feeds.conf
./scripts/feeds update -a
./scripts/omega4p/prepare-feeds.sh
./scripts/feeds install -a
```

The local `omega4ko` feed points to the sibling `omega4-kernel-packages` checkout.
The preparation script fixes a dependency in the pinned LuCI feed.

### 3. Select the board and external kernel

For the original **Omega4**:

```sh
cp omega4_defconfig .config
```

For **Omega4+**, use this instead:

```sh
cp omega4p_defconfig .config
```

Set the absolute path to the external kernel tree and expand the configuration:

```sh
printf 'CONFIG_EXTERNAL_KERNEL_TREE="%s"\n' "$(realpath ../linux-stable)" >> .config
make defconfig
```

You can also set the kernel path in `make menuconfig` under
**Advanced configuration options (for developers) → Use external kernel tree**.

### 4. Configure the boot package SDK path

The matching `omega4-boot` or `omega4p-boot` package requires the reference
Rockchip SDK. Its default location is `../../ref/1103B-SDK`, relative to the
OpenWrt checkout. If yours is elsewhere, use `make menuconfig` to set
`CONFIG_OMEGA4_BOOT_SDK_DIR` or `CONFIG_OMEGA4P_BOOT_SDK_DIR` respectively.

These packages build SPL/U-Boot and generate the environment while retaining
pinned vendor DDR initialization inputs. See the
[Omega4 boot package documentation](https://github.com/OnionIoT/omega4-kernel-packages/blob/omega4-openwrt-25.12/omega4-boot/omega4-boot-doc.md)
and [Omega4+ boot package documentation](https://github.com/OnionIoT/omega4-kernel-packages/blob/omega4-openwrt-25.12/omega4p-boot/omega4p-boot-doc.md)
for SDK requirements and provenance.

### 5. Build

```sh
make -j21
```

Adjust parallelism for your build host. Images and boot artifacts are written
to `bin/targets/rockchip/cortexa7/`.

## Acknowledgements

Thanks to [@plan44](https://github.com/plan44) for the initial Rockchip porting
work and the OpenWrt 25.12 / Linux 6.12 foundation used by this port.

Original OpenWrt README.md below:

---

![OpenWrt logo](include/logo.png)

OpenWrt Project is a Linux operating system targeting embedded devices. Instead
of trying to create a single, static firmware, OpenWrt provides a fully
writable filesystem with package management. This frees you from the
application selection and configuration provided by the vendor and allows you
to customize the device through the use of packages to suit any application.
For developers, OpenWrt is the framework to build an application without having
to build a complete firmware around it; for users this means the ability for
full customization, to use the device in ways never envisioned.

Sunshine!

## Download

Built firmware images are available for many architectures and come with a
package selection to be used as WiFi home router. To quickly find a factory
image usable to migrate from a vendor stock firmware to OpenWrt, try the
*Firmware Selector*.

* [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/)

If your device is supported, please follow the **Info** link to see install
instructions or consult the support resources listed below.

## 

An advanced user may require additional or specific package. (Toolchain, SDK, ...) For everything else than simple firmware download, try the wiki download page:

* [OpenWrt Wiki Download](https://openwrt.org/downloads)

## Development

To build your own firmware you need a GNU/Linux, BSD or macOS system (case
sensitive filesystem required). Cygwin is unsupported because of the lack of a
case sensitive file system.

### Requirements

You need the following tools to compile OpenWrt, the package names vary between
distributions. A complete list with distribution specific packages is found in
the [Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem)
documentation.

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.7+ rsync subversion unzip which
```

### Quickstart

1. Run `./scripts/feeds update -a` to obtain all the latest package definitions
   defined in feeds.conf / feeds.conf.default

2. Run `./scripts/feeds install -a` to install symlinks for all obtained
   packages into package/feeds/

3. Run `make menuconfig` to select your preferred configuration for the
   toolchain, target system & firmware packages.

4. Run `make` to build your firmware. This will download all sources, build the
   cross-compile toolchain and then cross-compile the GNU/Linux kernel & all chosen
   applications for your target system.

### Related Repositories

The main repository uses multiple sub-repositories to manage packages of
different categories. All packages are installed via the OpenWrt package
manager called `opkg`. If you're looking to develop the web interface or port
packages to OpenWrt, please find the fitting repository below.

* [LuCI Web Interface](https://github.com/openwrt/luci): Modern and modular
  interface to control the device via a web browser.

* [OpenWrt Packages](https://github.com/openwrt/packages): Community repository
  of ported packages.

* [OpenWrt Routing](https://github.com/openwrt/routing): Packages specifically
  focused on (mesh) routing.

* [OpenWrt Video](https://github.com/openwrt/video): Packages specifically
  focused on display servers and clients (Xorg and Wayland).

## Support Information

For a list of supported devices see the [OpenWrt Hardware Database](https://openwrt.org/supported_devices)

### Documentation

* [Quick Start Guide](https://openwrt.org/docs/guide-quick-start/start)
* [User Guide](https://openwrt.org/docs/guide-user/start)
* [Developer Documentation](https://openwrt.org/docs/guide-developer/start)
* [Technical Reference](https://openwrt.org/docs/techref/start)

### Support Community

* [Forum](https://forum.openwrt.org): For usage, projects, discussions and hardware advise.
* [Support Chat](https://webchat.oftc.net/#openwrt): Channel `#openwrt` on **oftc.net**.

### Developer Community

* [Bug Reports](https://bugs.openwrt.org): Report bugs in OpenWrt
* [Dev Mailing List](https://lists.openwrt.org/mailman/listinfo/openwrt-devel): Send patches
* [Dev Chat](https://webchat.oftc.net/#openwrt-devel): Channel `#openwrt-devel` on **oftc.net**.

## License

OpenWrt is licensed under GPL-2.0
