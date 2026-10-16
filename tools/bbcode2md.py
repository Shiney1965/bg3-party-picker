"""bbcode2md.py - turn the Nexus BBCode description into a Markdown preview of the page.

Handles only the tags NexusMods_BBCode.txt uses: [size=5]/[size=4] headings, [line], [list]/[*],
[b], [i] and [url=...].

Usage:  python tools/bbcode2md.py <in.txt> <out.md>
"""
import re
import sys


def convert(text):
    out = []
    for line in text.splitlines():
        m = re.fullmatch(r"\[size=([45])\]\[b\](.*?)\[/b\]\[/size\]", line.strip())
        if m:
            out.append(("# " if m.group(1) == "5" else "## ") + m.group(2))
            continue
        if line.strip() == "[line]":
            out.append("---")
            continue
        if line.strip() in ("[list]", "[/list]"):
            continue
        if line.startswith("[*]"):
            line = "- " + line[3:]
        line = re.sub(r"\[url=([^\]]+)\](.*?)\[/url\]", r"[\2](\1)", line)
        line = re.sub(r"\[b\](.*?)\[/b\]", r"**\1**", line)
        line = re.sub(r"\[i\](.*?)\[/i\]", r"*\1*", line)
        out.append(line)
    # blank line around headings and rules; collapse runs of blank lines
    spaced = []
    for line in out:
        if re.match(r"^(#{1,2} |---$)", line):
            spaced += ["", line, ""]
        else:
            spaced.append(line)
    md = re.sub(r"\n{3,}", "\n\n", "\n".join(spaced)).strip() + "\n"
    return md


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as f:
        src = f.read()
    with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
        f.write(convert(src))
