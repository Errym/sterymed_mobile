"""
Merge several lcov files (one per test chunk) into coverage/lcov.info.

Running the whole suite with coverage in one process needs a lot of memory, so
CI and developers run it in chunks. Each chunk writes its own lcov file; this
sums the hit counts per source line across them, so a line counts as covered if
ANY chunk executed it.

Usage: python scripts/merge_coverage.py build/cov/*.info
Then:  python scripts/coverage_summary.py [--enforce]
"""
import os
import sys
from collections import defaultdict


def main(paths):
    hits = defaultdict(lambda: defaultdict(int))  # file -> line -> hits
    for path in paths:
        current = None
        with open(path, encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if line.startswith("SF:"):
                    current = line[3:].replace("\\", "/")
                elif line.startswith("DA:") and current:
                    number, count = line[3:].split(",")[:2]
                    hits[current][int(number)] += int(count)
                elif line == "end_of_record":
                    current = None
    os.makedirs("coverage", exist_ok=True)
    with open("coverage/lcov.info", "w", encoding="utf-8", newline="\n") as out:
        for file in sorted(hits):
            rows = hits[file]
            out.write(f"SF:{file}\n")
            for number in sorted(rows):
                out.write(f"DA:{number},{rows[number]}\n")
            out.write(f"LF:{len(rows)}\n")
            out.write(f"LH:{sum(1 for c in rows.values() if c > 0)}\n")
            out.write("end_of_record\n")
    print(f"merged {len(paths)} files, {len(hits)} source files -> coverage/lcov.info")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
