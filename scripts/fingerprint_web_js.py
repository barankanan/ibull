#!/usr/bin/env python3
"""Fingerprint Flutter web entry JS and deferred part URIs.

dart2js keeps deferred hunks at stable names (main.dart.js_N.part.js). The
entry file is renamed to app.<hash>.js every deploy, so a cached part from
the previous build can load with HTTP 200 while dart2js rejects it:

  DeferredLoadException: Success callback invoked but part ... not loaded

Copy each part to a hash-stamped name and rewrite URIs inside the entry JS.
Original part files stay so an in-flight previous app.<hash>.js still works.
"""

from __future__ import annotations

import pathlib
import re
import shutil
import sys

PART_URI_RE = re.compile(r"main\.dart\.js_(\d+)\.part\.js")
PART_FILE_RE = re.compile(r"^main\.dart\.js_(\d+)\.part\.js$")


def fingerprint_web_js(web_dir: pathlib.Path, hashed_name: str, digest: str) -> tuple[int, int]:
    boot = web_dir / "flutter_bootstrap.js"
    html = web_dir / "index.html"
    if boot.is_file():
        boot.write_text(
            boot.read_text(encoding="utf-8").replace(
                '"mainJsPath":"main.dart.js"',
                f'"mainJsPath":"{hashed_name}"',
            ),
            encoding="utf-8",
        )
    if html.is_file():
        html.write_text(
            html.read_text(encoding="utf-8").replace(
                'href="main.dart.js"',
                f'href="{hashed_name}"',
            ),
            encoding="utf-8",
        )

    copied = 0
    for part in sorted(web_dir.glob("main.dart.js_*.part.js")):
        match = PART_FILE_RE.match(part.name)
        if match is None:
            continue
        stamped = web_dir / f"main.dart.js_{match.group(1)}.part.{digest}.js"
        shutil.copy2(part, stamped)
        copied += 1

    entry = web_dir / hashed_name
    if not entry.is_file():
        raise SystemExit(f"missing fingerprinted entry JS: {entry}")
    text = entry.read_text(encoding="utf-8")
    new_text, rewritten = PART_URI_RE.subn(rf"main.dart.js_\1.part.{digest}.js", text)
    if copied and rewritten == 0:
        raise SystemExit("copied deferred parts but entry JS has no main.dart.js_N.part.js URIs")
    entry.write_text(new_text, encoding="utf-8")
    return copied, rewritten


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: fingerprint_web_js.py WEB_DIR HASHED_JS_NAME DIGEST")
    copied, rewritten = fingerprint_web_js(
        pathlib.Path(sys.argv[1]),
        sys.argv[2],
        sys.argv[3],
    )
    print(f"✓ Fingerprinted deferred parts: copied={copied} uriRewrites={rewritten}")


if __name__ == "__main__":
    main()
