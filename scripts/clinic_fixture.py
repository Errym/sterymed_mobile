#!/usr/bin/env python3
"""Entry point; implementation and tests live together under testing/."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from testing.clinic_fixture.launcher import main

if __name__ == "__main__":
    raise SystemExit(main())
