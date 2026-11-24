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

## 2026-11-22 — v0.0.16 release

Prepare release builds for both boards with version 0.0.16 and build 20261122.
The previously validated 25.12 port is unchanged apart from release identity.
Release notes retain hardware coverage and known limitations.

- Both exact v0.0.16 release builds passed. ZIPs passed board/FIT/UBI/environment
  and per-file hash checks. Release source: ddf4b208e550111923ed082dd1079d1bccb66407.
- Exact release sysupgrade SHA-256
  1e2313be199d5f10d215a73bea68c3e4e420ea19ebbadb0bf1b486085593548e
  passed target hash and compatibility checks, then settings-preserving install
  on A29C. Firmware reports 0.0.16 / 20261122. Full smoke passed again, including
  9 Wi-Fi BSS entries, NPU, hardware encoding and 96 MiB memory testing.
  Evidence: sibling releases/v0.0.16/a29c-release-uart.log.

## 2026-11-24 — Update A29C to latest published release

Confirmed Omega4+ identity on user-selected A29C and latest release v0.0.16.
The installed version already reported 0.0.16, but the root filesystem hash
differed from the published sysupgrade payload. Backed up settings/environment,
verified the release ZIP against GitHub's asset digest, verified target download
and sysupgrade compatibility, then performed a settings-preserving sysupgrade.
After boot, kernel/FIT and rootfs hashes exactly match the release payloads;
environment and network configuration hashes are unchanged. Ethernet ping
passed at 192.168.77.156. Both mfg-aic-mac and mfg-aic-uart are installed.
Evidence and private backups: sibling hardware-validation/2026-11-24-update.
Final outputs: USB1 off, USB2 on, RELAY1 on, RELAY2 released.

## 2026-11-24 — A29C Wi-Fi module UART access

With the user's newly connected Wi-Fi UART, the installed mfg-aic-mac load
command successfully loaded RAM test firmware over UART2 at 921600 baud:
XMODEM 267 STX packets, zero retries, load exit 0. mfg-aic-mac show returned
Wi-Fi 000000000000 (remain:2) and BT 000000000000 (remain:2), exit 0.
No setmac/setbtmac or other eFuse programming commands were issued. Rebooted
to restore runtime pinmux/SDIO drivers and verified phy0 and Wi-Fi scanning.
Evidence: sibling hardware-validation/2026-11-24-wifi-uart/uart.log.

- Later read-only MAC recheck after the user requested another check: Wi-Fi
  88:1e:59:09:c3:96 and BT 88:1e:59:09:c3:98, both remain:1. Reloaded the
  UART RAM test firmware because runtime firmware did not support getmac.
  No eFuse writes issued in this check. Evidence: Wi-Fi UART recheck.log.

## 2026-11-24 — SC3336 camera on 25.12

Updated both local Codex development skills for omega4-openwrt-25.12, APK,
config presets and the external kernel workflow. Camera sensor detection
alone did not produce a pipeline on v0.0.16. Fixed async sensor registration
and embedded notifier lifetime in phy-rockchip-csi2-dphy; zero initialized
V4L2 requests in CIF/ISP/CSI2 for Linux 6.12. All four package builds passed.
Installed backed-up module overlays on A29C and rebooted: repeated five-frame
2304x1296 NV12 capture passes; exported image visually confirms a real scene.
Omitted alternate mipi-rx/rkisp1 modules are unnecessary for this camera.
Non-blocking graph-query and ISP startup warnings remain documented in
../omega4-kernel-packages/camera-6.12-doc.md. Evidence: sibling
hardware-validation/2026-11-24-camera. No release was published.

## 2026-11-24 — v0.0.17 release preparation

Build both boards with camera async binding and V4L2 initialization fixes.
Set firmware identity to 0.0.17 / 20261124. Original Omega4 hardware remains
unavailable; qualify exact Omega4+ release capture on A29C before publication.

- Both v0.0.17 board builds and bundle hash/FIT/DT/UBI/environment checks passed.
  Source: a70fa697876758218bb9948eb7a486c128c95814; packages d925860.
- Exact Omega4+ sysupgrade SHA256 7e37c273366b2e52adb5ddb0cf3539364993d190bffc9071895f08e8c9caa367
  passed compatibility checking and settings-preserving installation on A29C.
  Runtime identity is 0.0.17 / 20261124; kernel/rootfs hashes match the release.
  Environment and network configuration hashes are unchanged. Camera modules
  match /rom (no development overlay); two five-frame 2304x1296 NV12 capture
  tests passed and exported image was visually checked. Ethernet ping passed.
  Evidence: sibling releases/v0.0.17/a29c-uart.log and camera-preview.png.

## 2026-11-24 — Speaker bring-up

A29C v0.0.17 has no ALSA cards: SAI and RV1103B codec drivers are missing.
Imported matching official SDK drivers into external Linux and adapted 6.12
APIs; kernel compile passes. Enabled both drivers and ALSA utilities for both
board presets. Full build in progress; no playback issued. User reported scope
ground on a speaker terminal; requested board-GND/two-channel differential
rewiring before enabling audio. See speaker-support-doc.md and sibling
hardware-validation/2026-11-24-speaker for ongoing validation.

- Full Omega4+ firmware build passed; ALSA tools included and sysupgrade
  board identity checked. Candidate retained with SHA256SUMS in evidence folder.
  Not installed while scope ground reconnection is pending.

- After user confirmed scope rewiring, boot testing found missing DAI name,
  UART-only DMA channel admission, and old CPU clock-provider semantics.
  Fixed all three. Candidate 9384650563aac57d0b04e8fed2e959606eb466b72b4163b33395c930d83f68c0
  boots with ALSA card 0, passes repeated finite playback and 2-second capture.
  Camera smoke passed; env/network hashes unchanged. Speaker stays silent: scope
  shows common-mode pickup, negligible differential tone. User confirmed amp
  has GPIO enable; waiting for pin/polarity before adding pa-ctl-gpios.

- User identified EVB LM4890S U4 enable as GPIO0_A4 active high. Added EVB
  pa-ctl-gpios, explicit pinmux and 220 ms wake-up delay (inherited by Omega4+).
  Manual enable first proved output. Final candidate
  329e9cb4aa215b70532a1abf36a4b0ccdd7298019c6488ff4fadd6f1fdfe7313
  then passed automatic low/high/low GPIO lifecycle and finite playback on A29C.
  Scope captured opposite-phase 1 kHz signals, 0.312 Vpp differential fitted
  amplitude, returning to noise-level output after stop. Settings/env unchanged.
  Full evidence and measurement limitations in speaker-support-doc.md.

- Microphone pickup test: simultaneous 48 kHz stereo recording and nearby
  speaker playback recovered 700/1300/2100 Hz in order, no clipping, digital
  loopback disabled. Mono duplex capture has half-pitch/doubled timing even
  with Receive Mono Switch enabled; stereo is the validated workaround.
  Some runs log Failed to idle FS at shutdown. See speaker-support-doc.md
  and 2026-11-24-microphone evidence. No new firmware changes in this test.

- Audio shutdown investigation: mixed mono capture/stereo playback reproduced
  persistent FS non-idle (STATUS 0x6, XFER 0, CKR 0x18 on SAI 0x24031103).
  Fresh-boot matching stereo duplex and 1000 idle clock gate cycles passed.
  Added SAI symmetric_channels: shared FSCR/CKR cannot be reprogrammed for
  mismatched concurrent streams. Diagnostic timeout extension/logging removed.
  Full build passed; candidate hardware validation in progress.
- Final audio constraint candidate 716dcfe443274a7c83d8bc083d9c4b14d32093340aa31cfbef91e2a3843e3ddd
  installed and validated: 11 supported cases, 6 expected mismatch rejections,
  all 17 runtime suspends, zero idle warnings. Settings/env hashes unchanged.
  Final-image boot and reboot passed. Diagnostic-image first boot had a separate
  timer-interrupt panic during module loading; retained unresolved in evidence
  and speaker-support-doc.md. No commit/push/release performed.
