"""Names the recompiled function a host address in the game code DLL is in (from a crash log's "in SCAR.dll+<hex>").

Usage: python tools/addr2func.py out/build/release/SCAR.dll <hex offset> [...]
"""
import bisect
import sys

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from stack_scan import read_exports  # noqa: E402


def main(dll, offsets):
    exports = sorted(read_exports(dll))  # (rva, name)
    rvas = [e[0] for e in exports]
    for text in offsets:
        off = int(text, 16)
        i = bisect.bisect_right(rvas, off) - 1
        print(f"{off:X}: " + (f"{exports[i][1]}+{off - exports[i][0]:X}" if i >= 0 else "before the first export"))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
