"""
Small driver for on-device testing without screenshots (the app hides its
content from screenshots on purpose, but its accessibility tree is readable).

  python scripts/device_ui.py dump                 # list what is on screen
  python scripts/device_ui.py tap "Stock"          # tap the first element whose text contains it
  python scripts/device_ui.py tapxy 540 1600
  python scripts/device_ui.py type "text"          # type into the focused field
  python scripts/device_ui.py back
  python scripts/device_ui.py swipe up|down
  python scripts/device_ui.py has "text"           # exit code 0 if found

The device serial comes from DEVICE_SERIAL (default: the only attached device).
"""
import os
import re
import subprocess
import sys
import time

SERIAL = os.environ.get("DEVICE_SERIAL")
BASE = ["adb"] + (["-s", SERIAL] if SERIAL else [])


def adb(*args, check=True):
    return subprocess.run(BASE + list(args), capture_output=True, text=True, encoding="utf-8", errors="replace", check=check).stdout


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = adb("shell", "cat", "/sdcard/ui.xml")
    items = []
    for m in re.finditer(r"<node[^>]*>", xml):
        s = m.group(0)
        def attr(name):
            r = re.search(name + r'="([^"]*)"', s)
            return r.group(1) if r else ""
        label = (attr("text") or attr("content-desc")).replace("&#10;", " | ").replace("&amp;", "&")
        b = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", attr("bounds"))
        if label and b:
            x1, y1, x2, y2 = map(int, b.groups())
            items.append((label, (x1 + x2) // 2, (y1 + y2) // 2, attr("class").split(".")[-1], (x1, y1, x2, y2)))
    return items


def find(items, needle):
    needle = needle.lower()
    for it in items:
        if needle in it[0].lower():
            return it
    return None


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "dump"
    if cmd == "dump":
        for label, cx, cy, cls, _ in dump():
            print(f"{label[:100]!r:<104} {cls:<10} ({cx},{cy})")
    elif cmd == "tap":
        it = find(dump(), argv[2])
        if not it:
            print("NOT FOUND:", argv[2])
            sys.exit(1)
        adb("shell", "input", "tap", str(it[1]), str(it[2]))
        print("tapped", repr(it[0][:60]))
    elif cmd == "tapxy":
        adb("shell", "input", "tap", argv[2], argv[3])
    elif cmd == "type":
        adb("shell", "input", "text", argv[2].replace(" ", "%s"))
    elif cmd == "back":
        adb("shell", "input", "keyevent", "4")
    elif cmd == "swipe":
        a, b = ("1500", "600") if argv[2] == "up" else ("600", "1500")
        adb("shell", "input", "swipe", "540", a, "540", b, "300")
    elif cmd == "has":
        sys.exit(0 if find(dump(), argv[2]) else 1)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
