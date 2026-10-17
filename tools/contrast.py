"""Check every palette in a starship.toml for readable contrast.

Usage: python contrast.py starship.toml
  text      each segment's _fg on its _bg, WCAG ratio, target >= 7 (AAA)
  border    each _bg against the next segment's _bg in prompt order
  plain     plain_fg on a typical dark terminal background (#1e1e2e)
"""
import re
import sys

ORDER = ["os", "time", "dir", "gh", "git", "lang", "claude", "docker", "ai"]


def lum(hex_: str) -> float:
    rgb = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def ratio(a: str, b: str) -> float:
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


text = open(sys.argv[1], encoding="utf-8").read()
failed = False
for name, body in re.findall(r"\[palettes\.(\w+)\]\n((?:\w+ = \"#\w+\"\n)+)", text):
    c = dict(re.findall(r'(\w+) = "(#\w+)"', body))
    texts = {s: ratio(c[f"{s}_fg"], c[f"{s}_bg"]) for s in ORDER}
    borders = [ratio(c[f"{a}_bg"], c[f"{b}_bg"]) for a, b in zip(ORDER, ORDER[1:])]
    plain = ratio(c["plain_fg"], "#1e1e2e")
    worst = min(texts, key=texts.get)
    ok = texts[worst] >= 7 and plain >= 7
    failed |= not ok
    print(f"{'OK  ' if ok else 'FAIL'} {name:17} text min {texts[worst]:4.1f} ({worst:6}) "
          f"| border min {min(borders):4.2f} avg {sum(borders) / len(borders):4.2f} | plain {plain:4.1f}")
sys.exit(1 if failed else 0)
