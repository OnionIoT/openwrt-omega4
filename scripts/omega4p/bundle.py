#!/usr/bin/env python3
"""Bundle OpenWrt Omega4+ images with the hash-pinned SDK bootloader release.

This only copies files. It never opens USB devices or writes flash.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tarfile
import zlib

SDK_HASHES = {
    "download.bin": "658113a48c4b83e6e4a9625d6dd26201de497442806e34d597151f788c2f2f30",
    "idblock.img": "3fb6e013e6370fe75573a63a516cce5807b70b6fc6dd263aca5937ae39ca140d",
    "uboot.img": "bf4ec738e361593f21b1f45bd05a396f2699f6296acf7549344035efcde5c6dd",
}
# Byte offsets and capacities; SDK boot offsets, OpenWrt UBI filesystem.
PARTITIONS = {
    "env.img": (0x00000000, 0x00040000),
    "idblock.img": (0x00040000, 0x00100000),
    "uboot.img": (0x00140000, 0x00200000),
    "boot.img": (0x00540000, 0x00600000),
    "rootfs.img": (0x00B40000, 0x0E600000),
}
PREFIX = "openwrt-rockchip-cortexa7-onion_omega4p-evb-squashfs-"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-release", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    files = {name: args.sdk_release / name for name in SDK_HASHES}
    files.update({name: args.images / (PREFIX + name)
                  for name in ("env.img", "boot.img", "rootfs.img", "sysupgrade.tar")})
    # Validate every input before creating the output directory.
    for name, path in files.items():
        if not path.is_file() or not path.stat().st_size:
            parser.error(f"Missing or empty input: {path}")
        if name in SDK_HASHES and sha256(path) != SDK_HASHES[name]:
            parser.error(f"SDK release hash mismatch: {path}")
        if name in PARTITIONS and path.stat().st_size > PARTITIONS[name][1]:
            parser.error(f"Image exceeds its partition: {path}")
    env = files["env.img"].read_bytes()
    if len(env) != 0x40000 or struct.unpack("<I", env[:4])[0] != zlib.crc32(env[4:]):
        parser.error("Invalid U-Boot environment size or CRC")
    expected_env = (
        b"mtdparts=spi-nand0:256K(env),1M@256K(idblock),2M(uboot),2M(meta),6M(boot),230M(ubi)",
        b"sys_bootargs= ubi.mtd=ubi ubi.block=0,rootfs root=/dev/ubiblock0_0 rootfstype=squashfs ro rootwait rk_dma_heap_cma=40M",
    )
    if not all(value in env[4:].split(b"\0") for value in expected_env):
        parser.error("Environment does not match the Omega4+ OpenWrt layout")
    if files["rootfs.img"].read_bytes()[:4] != b"UBI#":
        parser.error("rootfs.img is not a UBI image")
    if files["boot.img"].read_bytes()[:4] != bytes.fromhex("d00dfeed"):
        parser.error("boot.img is not a FIT image")
    board = "onion,rv1106b-omega4p-evb"
    try:
        with tarfile.open(files["sysupgrade.tar"]) as archive:
            control = archive.extractfile(f"sysupgrade-{board}/CONTROL").read()
            kernel = archive.extractfile(f"sysupgrade-{board}/kernel").read()
            root = archive.extractfile(f"sysupgrade-{board}/root").read(4)
        if control.strip() != f"BOARD={board}".encode():
            parser.error("Sysupgrade has the wrong board identity")
        if kernel != files["boot.img"].read_bytes() or root != b"hsqs":
            parser.error("Sysupgrade kernel or squashfs root is inconsistent")
    except (tarfile.TarError, KeyError, AttributeError) as error:
        parser.error(f"Invalid Omega4+ sysupgrade archive: {error}")
    if args.output.exists():
        parser.error("Output already exists; choose a new directory")
    args.output.mkdir(parents=True)
    for name, path in files.items():
        shutil.copy2(path, args.output / name)
    (args.output / "SHA256SUMS").write_text("".join(
        f"{sha256(args.output / name)}  {name}\n" for name in sorted(files)))
    (args.output / "layout.json").write_text(json.dumps({
        "board": "onion,rv1106b-omega4p-evb",
        "ddr": "v1.07, configured 667 MHz, UART 115200",
        "units": "bytes",
        "partitions": {name: {"offset": offset, "capacity": capacity}
                       for name, (offset, capacity) in PARTITIONS.items()},
        "preserved_meta": {"offset": 0x00340000, "capacity": 0x00200000},
        "hardware_validated": False,
        "note": "Use the Omega4+ SPL-compatible FIT with explicit load addresses. "
                "No meta image is supplied. This bundle is not a Rockchip update.img. "
                "Initial installation changes the filesystem layout; sysupgrade is "
                "only for an existing Omega4+ OpenWrt installation.",
    }, indent=2) + "\n")
    print(args.output.resolve())


if __name__ == "__main__":
    main()
