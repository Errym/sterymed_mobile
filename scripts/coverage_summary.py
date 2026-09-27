import re
import sys
from collections import defaultdict

path = "coverage/lcov.info"
totals = defaultdict(lambda: [0, 0])  # bucket -> [hit, found]
overall = [0, 0]
current_file = None

def bucket_for(path):
    path = path.replace("\\", "/")
    if path.startswith("lib/features/prosthetic/"):
        return "lib/features/prosthetic"
    if path.startswith("lib/core/"):
        return "lib/core"
    if path.startswith("lib/features/"):
        return "lib/features (other)"
    if path.startswith("lib/shared/"):
        return "lib/shared"
    if path.startswith("lib/di/"):
        return "lib/di"
    return "lib (other)"

with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line.startswith("SF:"):
            current_file = line[3:]
        elif line.startswith("LH:"):
            hit = int(line[3:])
            totals[bucket_for(current_file)][0] += hit
            overall[0] += hit
        elif line.startswith("LF:"):
            found = int(line[3:])
            totals[bucket_for(current_file)][1] += found
            overall[1] += found

print(f"{'Bucket':<28}{'Lines hit':>10}{'Lines found':>13}{'Coverage':>10}")
for bucket, (hit, found) in sorted(totals.items()):
    pct = (hit / found * 100) if found else 0.0
    print(f"{bucket:<28}{hit:>10}{found:>13}{pct:>9.1f}%")

pct = (overall[0] / overall[1] * 100) if overall[1] else 0.0
print(f"{'TOTAL':<28}{overall[0]:>10}{overall[1]:>13}{pct:>9.1f}%")
