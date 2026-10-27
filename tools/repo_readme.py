"""repo_readme.py - build the repository's front-page README.md from dist_docs/README.md.

The README in the download and the one GitHub shows are the same text. Only these differ:
file names the download has side by side become links into the repository, a Download section
points to the latest GitHub release, and the Source code section links the developer notes.
Run by tools/make_docs.ps1; edit dist_docs/README.md, never README.md.

Usage:  python tools/repo_readme.py <repo root>
"""
import io
import os
import sys

root = sys.argv[1]
src = io.open(os.path.join(root, "dist_docs", "README.md"), encoding="utf-8").read().replace("\r\n", "\n")

def swap(s, old, new):
    if old not in s:
        sys.exit("repo_readme: not found in dist_docs/README.md: " + old)
    return s.replace(old, new)

s = src
s = swap(s, "(see `INSTALL.md`)", "(see [INSTALL.md](dist_docs/INSTALL.md))")
s = swap(s, "ships with the download as `LICENSE`", "ships with the download as [LICENSE](LICENSE)")
s = swap(s, "see `LICENSE-THIRD-PARTY.md`", "see [LICENSE-THIRD-PARTY.md](dist_docs/LICENSE-THIRD-PARTY.md)")
s = swap(s, "\n## ➤ How to use — please read this\n",
         "\n## Download\n\n"
         "**[Releases](https://github.com/Shiney1965/bg3-party-picker/releases)**: "
         "`PartyPicker-<version>.zip` holds `PartyPicker.pak`, this README and the install guide (Markdown, Word and PDF), "
         "the changelog, the licence, the third-party notices and a manifest of SHA-256 hashes. "
         "Install steps: [INSTALL.md](dist_docs/INSTALL.md). Version history: [CHANGELOG.md](dist_docs/CHANGELOG.md).\n"
         "\n## ➤ How to use — please read this\n")
s = swap(s, "tests and research notes) is on GitHub: <https://github.com/Shiney1965/bg3-party-picker>",
         "tests and research notes) is in this repository. Building and changing the mod: "
         "[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).")

s = "<!-- Generated from dist_docs/README.md by tools/repo_readme.py. Edit that file, not this one. -->\n" + s
with io.open(os.path.join(root, "README.md"), "w", encoding="utf-8", newline="\n") as f:
    f.write(s)
print("wrote README.md")
