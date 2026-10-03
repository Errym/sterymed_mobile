"""
Google Play requires apps to run on devices with 16 KB memory pages (Android 15+
devices such as the Pixel 8/9 series and Samsung Galaxy S25/S26 can use them).
A native library whose ELF LOAD segments are aligned to less than 16 KB makes
the app fail the Play check, or crash on such a device.

This lists every arm64 / x86_64 .so inside an APK or AAB and whether each is
aligned to 16 KB (0x4000).

  python scripts/check_16kb_alignment.py build/app/outputs/flutter-apk/app-release.apk
"""
import struct
import sys
import zipfile

PT_LOAD = 1
NEED = 0x4000


def load_alignments(data: bytes):
    if data[:4] != b"\x7fELF" or data[4] != 2:  # 64-bit only
        return None
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type == PT_LOAD:
            aligns.append(struct.unpack_from("<Q", data, off + 0x30)[0])
    return aligns


def main(path):
    bad, ok = [], []
    with zipfile.ZipFile(path) as z:
        for name in sorted(z.namelist()):
            if not name.endswith(".so") or not any(a in name for a in ("arm64-v8a", "x86_64")):
                continue
            aligns = load_alignments(z.read(name))
            if aligns is None:
                continue
            (ok if all(a >= NEED for a in aligns) else bad).append((name, min(aligns)))
    for name, a in ok:
        print(f"  ok   {a:>6x}  {name}")
    for name, a in bad:
        print(f"  FAIL {a:>6x}  {name}")
    print(f"\n{len(ok)} aligned, {len(bad)} NOT aligned to 16 KB")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
