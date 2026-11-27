# Original Omega4 UBI boundary

The RV1103B Omega4 USB loader reports 255.5 MiB (`0x0ff80000`) on the
256 MiB NAND. The UBI partition starts at `0x00a40000` and must have size
`0x0f540000` (245.25 MiB), ending at the same loader-accessible boundary.
Do not extend UBI into the final 512 KiB or issue USB erases beyond the reported
loader capacity. Omega4+ uses its own smaller UBI partition and is unaffected.

The previous size `0x0f5c0000` made Linux scan to 256 MiB, beyond the USB
flasher's erase range. A reported failure at UBI PEB 1964 (absolute NAND offset
`0x0ffc0000`) contained an older image sequence number and prevented UBI attach.
The release image itself had a consistent sequence number.

Rebuild boot.img to include the corrected device tree. Full firmware bundles
must declare the corrected capacity in flash-layout.json. The web flasher must
use this fixed range and reject release layouts declaring the oversized range.
A corrected rootfs-only flash cannot repair the old kernel's partition map.

For a fresh USB install, use matching corrected boot.img and rootfs.img, erase
only the declared partitions, and preserve provisioned env/MAC unless explicitly
reprovisioning. Existing UBI filesystems that have allocated blocks in the final
512 KiB are not guaranteed to survive a boot-only boundary change; back up data
and use a fresh rootfs installation when migrating those systems.

Validation requires inspecting the DT extracted from the actual boot FIT and
confirming UBI attaches on original Omega4 hardware. An Omega4+ cannot substitute
for this hardware check.

## Environment override

The first DT-only candidate still failed: the boot package and legacy image
template contained `8M(boot),-(ubi)`. Rockchip U-Boot appends mtdparts from the
environment to bootargs, overriding Linux's DT partition sizes. Both sources now
use `8M(boot),251136K(ubi)`. The corrected environment must also be installed;
boot-only flashing or normal sysupgrade does not migrate an old environment.
Use the boot package's fix-env-ubi.py on a backup to preserve MAC and settings.
