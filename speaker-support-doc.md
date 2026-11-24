# Omega4 / Omega4+ speaker bring-up on OpenWrt 25.12

## Driver source and configuration

The v0.0.17 device tree enables SAI and the internal codec but Linux 6.12
lacks both drivers; acodec-sound defers with a parse error and ALSA has no cards.
Import the RV1103B-capable Rockchip SAI and RV1106-family codec drivers from
1103B-SDK revision e89cd37b1e87acb3f76c793c41a14e2efb2e77d6,
under sysdrv/source/kernel/sound/soc. The older o4p-support codec does not
include the RV1103B variant and is not a suitable replacement.

Adapt platform remove callbacks, DAI probe placement, explicit DAI name and symmetric_rate for
Linux 6.12. Modern ASoC passes endpoint-relative clock-provider flags, so the
CPU DAI must treat BP_FP as master and BC_FC as slave. The SDK CPU driver
used codec-relative flags; leaving those unchanged stalls playback with both
ends configured as consumers. Use common clock rate adjustment instead of the unavailable vendor
PLL compensation hook. Vendor DMC performance voting is omitted because this
kernel does not implement that facility. Digital-loopback PCM is not enabled;
its SDK header returns ENOSYS if requested. Normal DMA-engine PCM is enabled. The inherited DMA driver only admitted UART
TX requests: add SAI RX/TX requests 10/11 and advertise existing cyclic support.
Receive DMA configuration is allowed only on SAI request 10; UART RX remains
restricted to PIO. ALSA uses period counting because DMA residue granularity
is descriptor-level. Playback/capture lifecycle validation is required.

Persist CONFIG_SND_SOC_ROCKCHIP_SAI=y and CONFIG_SND_SOC_RV1106=y in the target
config; include alsa-utils in both board presets. The default codec audio mux
Path0 routes playback to the internal analog line output. The EVB U4 is an LM4890S: GPIO0_A4 reaches SHUTDOWN through R4 (0 ohm),
with R3 (10 kohm) pulling up to 3.3 V. Enable is active high. The EVB DTS
sets pa-ctl-gpios to GPIO0_A4 active high with explicit GPIO muxing and a
220 ms wake-up delay. The driver requests the GPIO low at probe, enables it
at playback unmute and lowers it at mute. The external pull-up can still enable
the amplifier before Linux takes ownership. Omega4+ inherits this EVB wiring.

J1 pin 1 is VO2 via R5 and pin 2 is VO1 via R6; connect the speaker across
those pins. J1 pins 3/4 are board ground. This is a bridge-tied output: scope
tips on pins 1/2, both scope grounds on board ground, subtract CH1 minus CH2.
TI reference: https://www.ti.com/lit/ds/symlink/lm4890.pdf (shutdown low;
220 ms maximum wake-up in the specified datasheet test conditions).

## Validation — 24 November 2026

A29C runs a development build based on v0.0.17. Final candidate sysupgrade
SHA256: 329e9cb4aa215b70532a1abf36a4b0ccdd7298019c6488ff4fadd6f1fdfe7313.
Full build and target checksum/compatibility checks passed. Environment and
network configuration hashes remain unchanged after settings-preserving upgrades.

Hardware testing exposed and resolved unnamed DAI registration, restricted SAI
DMA channels, and old CPU clock-role semantics. ALSA card 0 is rv1103b-acodec.
Two finite 48 kHz stereo S16_LE playback runs passed before amp integration;
a two-second mono recording also passed (DMA lifecycle, not microphone quality).
Camera smoke passed after the kernel/audio changes.

After the user identified the amplifier GPIO, a temporary GPIO-high playback
proved the physical output path. The final DTS integration was rebuilt and
installed, then tested without manual GPIO writes:

- Probe reports pa_ctl_gpio in use and a 220 ms delay.
- GPIO0_A4 is owned by pa-ctl and low before playback.
- It becomes high during playback; aplay completes successfully.
- It returns low after playback, with the outputs returning near zero.
- CH1/CH2 are opposite-phase during the 1 kHz tone. Differential sine-fit
  amplitude is 0.312 Vpp (about 0.110 Vrms for the fitted fundamental).
- At idle the fitted 1 kHz differential component is about 0.000116 Vpp,
  within the noise of this setup; this is not a calibrated noise-floor test.

The test WAV is 10 seconds, 1 kHz stereo 48 kHz S16_LE, -30 dBFS, with 10 ms
edge ramps. DAC LINEOUT 26 (0 dB), HPMIX 1 (0 dB), Audio Mux Path0.
Scope: Siglent SDS1202X-E, 1x attenuation settings, 100 mV/div, 500 us/div,
70k samples at 10 MSa/s. Both probes reference board GND, tips are on opposite
speaker terminals. During playback the scope offsets were -2.0 V to include
the approximately 2.2 V common-mode bias; at idle offsets were zero. Software
subtracts simultaneously acquired channel samples. Absolute voltage values
assume the physical probes match the configured 1x attenuation.

No maximum power, distortion, acoustic-response or long-duration qualification
was performed. Original Omega4 hardware remains untested; it inherits the same
EVB amplifier DTS configuration. No release has been published for this work.

Evidence: sibling hardware-validation/2026-11-24-speaker/amp-uart.log,
amp-auto-tone.json, amp-auto-idle.json, raw channel .bin files, analysis JSON,
and amp-auto-tone.png. The board is left powered on with the amplifier idle low.

Scope commands and sample conversion follow the manufacturer's programming
guide: https://siglentna.com/wp-content/uploads/dlm_uploads/2017/10/Programming-Guide-1.pdf.

## Microphone pickup test

On A29C, played 700, 1300 and 2100 Hz sequential tones through the nearby
speaker while recording 48 kHz S16_LE stereo. Each tone lasted 1.5 seconds
with 0.5 seconds silence; recording began two seconds before playback.
At -18 dBFS playback level, the left recorded channel contained all three
frequencies in the correct order/timing, approximately 31/55/61 dB above
the corresponding quiet-baseline FFT bins. No samples clipped. These are
frequency-bin comparisons, not broadband SNR or calibrated acoustic measurements.
SAI digital loopback was disabled, Audio Mux Path0, ADC Mode DiffadcL,
MIC gain 20 dB, ALC/digital gain 0 dB, MICBIAS enabled. This supports mic
pickup; electrical crosstalk was not independently isolated.

Working capture command:

```sh
arecord -D hw:0,0 -r 48000 -f S16_LE -c 2 -d 11 /tmp/mic.wav
```

Mono capture is not yet qualified: with simultaneous stereo playback the
recording has half-frequency tones and doubled timing. Enabling SAI Receive
Mono Switch did not correct it; restored that control to Disable. Use stereo
capture for now. Some duplex runs also logged `Failed to idle FS` at stream
shutdown despite successful completion; lifecycle cleanup needs investigation.
No driver change was made during these tests. Amplifier returned low at end.
Evidence: sibling hardware-validation/2026-11-24-microphone/, especially
recording-18-stereo.wav, its analysis JSON/PNG, controls.txt and uart.log.

## Shared frame-clock constraint (24 November)

The `Failed to idle FS` warning was reproduced by starting mono capture and
then stereo playback. SAI hw_params derives shared FSCR frame width and CKR
bit-clock division from channels per lane, but the imported driver advertised
only symmetric sample rates. Opening the second direction could therefore
change an active stream's frame clock. This also explains why mixed capture
had incorrect pitch/timing. After that sequence even a subsequent matching
stereo run could warn until reboot.

A diagnostic kernel recorded STATUS=0x6 (TX/RX idle, FS not idle), XFER=0,
CKR=0x18, master=1, version=0x24031103 at timeout. An extra 1 ms did not
change status. Fresh-boot stereo-only long duplex tests passed twice; isolated
clock gate tests passed 500 combined and 500 staged stops. Increasing the
shutdown timeout or hiding the warning is not the fix.

Set the SAI DAI's `symmetric_channels` flag alongside `symmetric_rate` so ALSA
rejects mismatched duplex channel counts before hw_params changes shared timing.
Use stereo for both recording and playback; applications needing mono can
convert in userspace. Standalone mono capture quality remains unqualified.
The diagnostic logging was removed; the genuine idle-timeout warning remains.

Final candidate SHA256:
716dcfe443274a7c83d8bc083d9c4b14d32093340aa31cfbef91e2a3843e3ddd.
Full build, image checksum and sysupgrade compatibility checks passed. On A29C:
three playback-only, three capture-only, three short stereo duplex and two
11-second stereo duplex recordings completed; three capture-first and three
playback-first mismatched-channel attempts were rejected with ALSA's
`Channels count non available`, leaving the first stream functional. All 17
cases returned to runtime suspended with zero idle warnings. Amplifier returned
low; network and environment hashes unchanged. Final candidate booted and
passed a further normal reboot. Changes are not yet committed or released.

One earlier diagnostic-image boot (fe9f0238...) panicked in run_posix_cpu_timers
while kmodloader was loading omega4_hpmcu_loader. Its automatic restart and
subsequent manual reboot succeeded, as did both final-candidate boots. Cause
has not been established; retained as a separate unresolved boot observation,
not claimed fixed by the audio constraint. Evidence including the panic is in
sibling hardware-validation/2026-11-24-audio-shutdown/uart.log; fixed-validation.log
contains the 17 audio cases. No timeout warning was suppressed.
