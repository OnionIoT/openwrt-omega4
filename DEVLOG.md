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
