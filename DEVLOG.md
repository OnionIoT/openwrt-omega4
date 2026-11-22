# DEVLOG - Omega4 Mic Input Bring-up

This log captures the mic input bring-up work for Omega4 (RV1103B).

## Scope

- Target: Omega4 (RV1103B).
- Goal: bring up mic input capture using the onboard acodec.
- Mic wiring: Mic In P/N (differential), mapped to DiffadcL.

## Repos

- OpenWrt tree: `/home/zh/workspace/omega4/audio-support/openwrt-omega4`
- External kernel tree: `/home/zh/workspace/omega4/audio-support/linux-stable`

## Status

- Mic capture works and is verified with recorded waveforms.
- Mixer controls are accessible via alsa-utils (amixer/arecord).

## Commands used

Enable micbias and capture:

- `amixer -c 0 sset 'ADC Main MICBIAS' On`
- `amixer -c 0 sset 'ADC MICBIAS Voltage' VREFx0_975`
- `amixer -c 0 sset 'ADC Mode' DiffadcL`
- `amixer -c 0 sset 'ADC MIC Left' Work`
- `amixer -c 0 sset 'ADC MIC Right' Work`
- `arecord -D hw:0,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav`


## 2026-11-22 — OpenWrt 25.12 migration (in progress)

- Checkpointed the existing firmware and WebUSB flasher before migrating.
- OpenWrt base: plan44/p44_25.12 at 1b0c773ac7 (25.12.6).
- External Linux base: plan44/linux-stable-openwrt25 at 245834464f06
  (6.12.112). Work proceeds on omega4-openwrt-25.12-port branches.
- Retained both Onion board identities, FIT formats and NAND layouts. Added
  RV1106B machine recognition and ported the existing DMA heaps, mailbox and RTC.
- Updated feed pins to the reference; retained the local omega4ko feed.
- Deleted no recovery assets. Baseline configs and build logs are under the sibling
  upgrade-25.12 directory. The old o4p-support branches retain the 24.10 sources.
- Validation target explicitly selected by user: A29C. Booted its baseline 24.10.2,
  Linux 6.6.93+, confirmed onion,rv1106b-omega4p-evb, and backed up its settings
  and 256 KiB environment. No new firmware has been flashed yet.
- Cleared stale package metadata. Pinned LuCI's unused weechat app selects a
  virtual package with conflicting variants; explicit weechat-minimal resolves
  Kconfig recursion. The scripts/omega4p/prepare-feeds.sh hook makes this feed adjustment reproducible.
- Full 25.12 build started. Build and hardware qualification are pending.

- Use CONFIG_BUILD_SUFFIX="openwrt25" to separate target objects and staging
  from the older build. Host elfutils initially failed because 880 unprefixed
  gnulib macros from the 24.10 host staging area shadowed the newer gl_* macros.
  Moved only files identical to the retained old gnulib source into the migration
  backup, then rebuilt elfutils successfully. No source workaround was required.
- Baseline A29C smoke checks: Ethernet 100 Mbps full duplex; 248840 KiB RAM;
  70 loaded modules; /dev/rtc0 and Rockchip CMA heap present; Wi-Fi scan 13 cells.

- Linux 6.12.112 now builds within the Omega4+ 6 MiB kernel limit. Preserved
  vendor camera/encoder UAPI headers, ported Rockchip heap helpers to the new
  DMA API, and exposed required V4L2 helper Kconfig options for external modules.
- Support packages now use void platform removal callbacks, current V4L2 frame
  interval/buffer APIs with 6.6 compatibility, explicit OF/vmalloc includes,
  and cfg80211 6.17 radio/link arguments (OpenWrt backports are 6.18.55).
- RF test tool version normalized to 2025.10.16 for apk. The build selects apk
  and no longer includes opkg. Camera and wireless driver builds are progressing;
  complete firmware and new-image hardware validation remain pending.
- Baseline NPU MobileNet demo passed on A29C: 15.25 ms, expected top class 156,
  score 0.929572. This is a baseline result, not yet a 25.12 result.

- Baseline MPP H.264 encoding passed: eight synthetic 640x480 frames, exit 0.
  This gives a camera-independent encoder comparison for the new kernel.

- First 25.12 build succeeded and settings-preserving sysupgrade on A29C passed
  the image hash/compatibility checks. New Linux 6.12.112 booted; Ethernet works,
  boot environment is byte-identical, and the network config differs only by
  formatting plus a new DHCP DUID. NPU inference matches the baseline (15.25 ms),
  and 96 MiB/eight-pattern RAM testing passed. Direct Wi-Fi scanning found 9 APs
  using a temporary interface because the saved radio configuration is disabled.
- Hardware testing exposed disabled vendor CPU device matches (RTC/ISP) and an
  inherited DMA-heap Makefile using unused dma-buf-objs variables. Added the
  CPU_RV1103B target option and corrected heap object lists. Rebuilding for retest.
- NPU inference works at its configured clock; vendor Rockchip OPP/DVFS helpers
  are absent from the reference 6.12 kernel, and devfreq initialization reports
  that limitation. Camera sensor remains physically absent.

- Final corrected Omega4+ build and original Omega4 build both passed. Restoring
  the plus configuration and rebuilding reproduced the exact tested sysupgrade
  SHA-256: 55e8de7e5c2fab4e672a4181409a947b52d009d7df2a5f8c4cb8f63716f7a494.
- A29C full smoke passed: Ethernet transfer/ping, 15 Wi-Fi BSS entries, RTC, NPU
  MobileNet, eight 640x480 hardware H.264 frames (~280 fps), and 96 MiB/eight
  memory patterns. Both 24.10→25.12 and 25.12→25.12 settings-preserving upgrades
  succeeded. Cold boot after ~11 seconds off retained overlay marker, network
  settings and byte-identical environment. APK installed database has 214 packages.
- Original Omega4 artifacts passed board identity, FIT/UBI, environment CRC and
  boot image hash checks; original hardware is unavailable. Existing A29C boot
  binaries were retained. Camera/audio, NPU DVFS and online APK updates remain
  outside the successful smoke coverage. Full evidence: sibling
  upgrade-25.12/hardware/REPORT.md. Final fixture state is powered on, boot released.
