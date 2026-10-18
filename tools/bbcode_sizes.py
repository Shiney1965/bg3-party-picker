"""bbcode_sizes.py - apply the Nexus type scale to NexusMods_BBCode.txt (idempotent).

Nexus renders [size=N] as HTML <font size=N>: 4 = 18px, 5 = 24px, 6 = 32px (measured on the live
MIR page, 2026-10-17); plain text is 13px. [size=6] is in use on other BG3 mod pages; [size=7] was
found on none, so it is not used here. The scale, so headings are always larger than the text:

  title             [size=6][b]...[/b][/size]   32px
  section heading   [size=5][b]...[/b][/size]   24px
  body / list item  [size=4]...[/size]          18px

Each paragraph line and each [*] item is wrapped on its own, as the live MIR page does; a [size]
around a whole [list] is not reliable in the Nexus parser.

The mode is chosen per file. An unsized file (title [size=5]) takes headings as [size=4][b]X[/b][/size].
In a sized file (title [size=6]) new headings must be written [size=5][b]X[/b][/size]; a fully bold
[size=4] line there is body text, and one followed by [list] or a blank line is reported as a
possible heading so it is not silently left small.
Usage:  python tools/bbcode_sizes.py dist_docs/NexusMods_BBCode.txt
"""
import io
import re
import sys

TITLE = re.compile(r"^\[size=[56]\]\[b\](.*?)\[/b\]\[/size\]$")
WRAPPED = re.compile(r"^\[size=4\](.*)\[/size\]$")


GITHUB = "[size=4][b][url=https://github.com/Shiney1965/bg3-party-picker]github.com/Shiney1965/bg3-party-picker[/url][/b][/size]"


def convert(text):
    # Old form: title [size=5], headings [size=4]. Sized form: title [size=6], headings [size=5],
    # and a fully bold [size=4] line is body text.
    sized = text.lstrip().startswith("[size=6]")
    heading = re.compile(r"^\[size=5\]\[b\](.*?)\[/b\]\[/size\]$" if sized else
                         r"^\[size=4\]\[b\]((?:(?!\[/b\]).)*)\[/b\]\[/size\]$")
    out = []
    first = True
    for line in text.splitlines():
        s = line.strip()
        if not s or s in ("[line]", "[list]", "[/list]"):
            out.append(s)
            continue
        if first:
            m = TITLE.match(s)
            if not m:
                sys.exit("first line is not the title: " + s[:60])
            out.append("[size=6][b]" + m.group(1) + "[/b][/size]")
            if not sized:
                out.append(GITHUB)
            first = False
            continue
        if s == GITHUB:
            out.append(s)
            continue
        m = heading.match(s)
        if m:
            out.append("[size=5][b]" + m.group(1) + "[/b][/size]")
            continue
        if sized and re.match(r"^\[size=4\]\[b\]((?:(?!\[/b\]).)*)\[/b\]\[/size\]$", s) and s != GITHUB:
            print("note: fully bold body line, check it is not meant as a heading:", s[:70], file=sys.stderr)
        item = s.startswith("[*]")
        body = s[3:] if item else s
        w = WRAPPED.match(body)
        if w:
            body = w.group(1)
        out.append(("[*]" if item else "") + "[size=4]" + body + "[/size]")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    path = sys.argv[1]
    src = io.open(path, encoding="utf-8").read()
    io.open(path, "w", encoding="utf-8", newline="\n").write(convert(src))
    print("sized:", path)
