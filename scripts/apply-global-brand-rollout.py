#!/usr/bin/env python3
"""Add the shared official KRIM brand loader to every tracked HTML page."""
from pathlib import Path
import subprocess

files = subprocess.check_output(["git", "ls-files", "*.html"], text=True).splitlines()
css = '<link rel="stylesheet" href="/logistics-saas/assets/krim-global-brand.css?v=20261111-global-brand-v1">'
js = '<script defer src="/logistics-saas/assets/krim-global-brand.js?v=20261111-global-brand-v1"></script>'
changed = 0
for name in files:
    path = Path(name)
    text = path.read_text(encoding="utf-8")
    if "krim-global-brand.js" in text and "krim-global-brand.css" in text:
        continue
    additions = []
    if "krim-global-brand.css" not in text:
        additions.append(css)
    if "krim-global-brand.js" not in text:
        additions.append(js)
    block = "\n<!-- KRIM_GLOBAL_BRAND_ROLLOUT -->\n" + "\n".join(additions) + "\n"
    lower = text.lower()
    pos = lower.find("</head>")
    if pos >= 0:
        text = text[:pos] + block + text[pos:]
    else:
        pos = lower.find("<body")
        if pos >= 0:
            text = text[:pos] + block + text[pos:]
        else:
            text = block + text
    path.write_text(text, encoding="utf-8")
    changed += 1
print(f"Processed {len(files)} tracked HTML pages; updated {changed}.")
