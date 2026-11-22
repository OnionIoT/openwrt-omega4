Omega4 mic input guide
======================

This document covers how to use the onboard RV1103B analog codec (acodec)
to record from the Omega4 microphone input. The physical connection is
Mic In P/N, which maps to the differential left ADC path (DiffadcL).

Quick start
-----------

1) Enable micbias and select the differential left ADC path.

   amixer -c 0 sset 'ADC Main MICBIAS' On
   amixer -c 0 sset 'ADC MICBIAS Voltage' VREFx0_975
   amixer -c 0 sset 'ADC Mode' DiffadcL
   amixer -c 0 sset 'ADC MIC Left' Work
   amixer -c 0 sset 'ADC MIC Right' Work

2) Set reasonable gains (safe defaults used in testing):

   amixer -c 0 sset 'ADC MIC Left Gain' 2
   amixer -c 0 sset 'ADC MIC Right Gain' 2
   amixer -c 0 sset 'ADC ALC Left' 24
   amixer -c 0 sset 'ADC ALC Right' 24
   amixer -c 0 sset 'ADC Digital Left' 195
   amixer -c 0 sset 'ADC Digital Right' 195

3) Record a mono WAV file:

   arecord -D hw:0,0 -f S16_LE -r 16000 -c 1 -d 5 /tmp/mic.wav

4) Optionally copy it to the host:

   scp root@<dut-ip>:/tmp/mic.wav .

Controls reference
------------------

All controls are on card 0 (acodec). Inspect with:

  amixer -c 0 scontrols

Key controls and usage:

- 'ADC Main MICBIAS' (enum: Off/On)
  Enables mic bias. Must be On for electret mics.

- 'ADC MICBIAS Voltage' (enum)
  Available items: VREFx0_8 ... VREFx0_975. We used VREFx0_975.

- 'ADC Mode' (enum)
  DiffadcL, SingadcL, DiffadcR, SingadcR, SingadcLR, DiffadcLR.
  For Mic In P/N on Omega4 use DiffadcL (mono).

- 'ADC MIC Left/Right' (enum: Work/Mute)
  Enable the ADC paths.

- 'ADC MIC Left Gain' / 'ADC MIC Right Gain' (0..3)
  Mic PGA gain. The codec comment maps values roughly as:
    0x01 -> 0 dB
    0x02 -> 20 dB
    0x03 -> 12 dB
  We used 2 (20 dB) for both sides.

- 'ADC ALC Left/Right' (0..31)
  Analog ALC gain. Range is -9 dB (0) to +37.5 dB (31),
  with 1.5 dB steps. We tested 24 (+27 dB) as a balanced setting.

- 'ADC Digital Left/Right' (0..255)
  Digital gain. 0 dB is 0xc3 (195). We used 195 as a baseline.

- 'ADC HPF Cut-off'
  High-pass filter control. Leave default unless you need to remove DC
  or very low frequency noise.

Gain tuning notes
-----------------

- If the signal is too low, increase ALC first (e.g. 24 -> 28),
  then consider increasing digital gain (e.g. 195 -> 210).
- If the signal clips (flat peaks), reduce ALC and/or digital gain.

Verification commands
---------------------

Capture 3 seconds at 16 kHz mono:

  arecord -D hw:0,0 -f S16_LE -r 16000 -c 1 -d 3 /tmp/mic-test.wav

Check current mixer values:

  amixer -c 0 sget 'ADC Main MICBIAS'
  amixer -c 0 sget 'ADC MICBIAS Voltage'
  amixer -c 0 sget 'ADC Mode'
  amixer -c 0 sget 'ADC MIC Left'
  amixer -c 0 sget 'ADC MIC Right'
  amixer -c 0 sget 'ADC MIC Left Gain'
  amixer -c 0 sget 'ADC MIC Right Gain'
  amixer -c 0 sget 'ADC ALC Left'
  amixer -c 0 sget 'ADC ALC Right'
  amixer -c 0 sget 'ADC Digital Left'
  amixer -c 0 sget 'ADC Digital Right'
