#!/usr/bin/env python3
"""Fix the SNES internal header checksum of a LoROM .sfc file in place."""
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    rom = bytearray(f.read())

if len(rom) % 0x8000 != 0:
    sys.exit(f"error: ROM size {len(rom)} is not a multiple of 32KB "
             "(is there a copier header?)")

HDR = 0x7FC0  # LoROM internal header
rom[HDR + 0x1C:HDR + 0x20] = b"\x00\x00\x00\x00"

# checksum + complement always sum to 0x1FE bytewise
checksum = (sum(rom) + 0x1FE) & 0xFFFF
complement = checksum ^ 0xFFFF

rom[HDR + 0x1C] = complement & 0xFF
rom[HDR + 0x1D] = complement >> 8
rom[HDR + 0x1E] = checksum & 0xFF
rom[HDR + 0x1F] = checksum >> 8

with open(path, "wb") as f:
    f.write(rom)

title = rom[HDR:HDR + 21].decode("ascii")
print(f"title='{title}' checksum={checksum:04X} "
      f"complement={complement:04X} size={len(rom)} bytes")
