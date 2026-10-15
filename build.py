#!/usr/bin/env python3
"""Builds the Tansy site: src/pages/*.md -> <path>/index.html, plain HTML like betony-site.

    python3 build.py            # writes the pages into the repo root
    python3 build.py --check    # fails if the built files are not up to date

Each page is a small Markdown file with a header block:

    title: Hot flash tracker
    description: ...
    path: hot-flash-tracker/
    ---
    # Heading
    Paragraph with **bold** and [links](../privacy/).
    - list item

Only what the pages use is supported: #/## headings, paragraphs, "- " lists,
**bold**, [text](url). Everything else is escaped, never interpreted.
"""
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent
PAGES = ROOT / "src" / "pages"
SITE_NAME = "Tansy"

NAV = [("Home", ""), ("Hot flash tracker", "hot-flash-tracker/"),
       ("Symptom diary", "perimenopause-symptom-diary/"),
       ("Checklist for your doctor", "menopause-symptom-checklist-for-doctor/"),
       ("Privacy Policy", "privacy/"), ("Support", "support/")]


def inline(text: str) -> str:
    escaped = html.escape(text, quote=False)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
    return re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                  lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>', escaped)


def body(markdown: str) -> str:
    out, paragraph, items = [], [], []

    def flush():
        if paragraph:
            out.append(f"<p>{inline(' '.join(paragraph))}</p>")
            paragraph.clear()
        if items:
            out.append("<ul>\n" + "\n".join(f"<li>{inline(i)}</li>" for i in items) + "\n</ul>")
            items.clear()

    for line in markdown.splitlines():
        stripped = line.strip()
        if not stripped:
            flush()
        elif stripped.startswith("## "):
            flush(); out.append(f"<h2>{inline(stripped[3:])}</h2>")
        elif stripped.startswith("# "):
            flush(); out.append(f"<h1>{inline(stripped[2:])}</h1>")
        elif stripped.startswith("- "):
            if paragraph:
                flush()
            items.append(stripped[2:])
        else:
            if items:
                flush()
            paragraph.append(stripped)
    flush()
    return "\n".join(out)


def page(meta: dict, content: str, prefix: str, absolute: bool = False) -> str:
    link = (lambda p: "/tansy-site/" + p) if absolute else (lambda p: prefix + p if p else (prefix or "./"))
    nav = "\n".join(f'<li><a href="{link(p)}">{name}</a></li>' for name, p in NAV)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="description" content="{html.escape(meta['description'])}">
<title>{html.escape(meta['title'])}</title>
<link rel="stylesheet" href="{link('styles.css')}">
</head>
<body>
<div class="page">
<header>
<a class="site-name" href="{link('')}">{SITE_NAME}</a>
</header>
<main>
{content}
</main>
<footer>
<nav aria-label="Site">
<ul>
{nav}
</ul>
</nav>
<p class="small">Tansy records what you log. It is not a medical device and does not give medical advice.</p>
</footer>
</div>
</body>
</html>
"""


def build() -> dict[pathlib.Path, str]:
    files = {}
    for source in sorted(PAGES.glob("*.md")):
        header, _, markdown = source.read_text(encoding="utf-8").partition("\n---\n")
        meta = {key.strip(): value.strip() for key, _, value in
                (line.partition(":") for line in header.strip().splitlines())}
        path = meta["path"]
        if path == "404":
            files[ROOT / "404.html"] = page(meta, body(markdown), "", absolute=True)
            continue
        depth = path.count("/")
        files[ROOT / path / "index.html"] = page(meta, body(markdown), "../" * depth)
    return files


def main() -> int:
    files = build()
    if "--check" in sys.argv:
        stale = [str(p.relative_to(ROOT)) for p, text in files.items()
                 if not p.exists() or p.read_text(encoding="utf-8") != text]
        print("stale: " + ", ".join(stale) if stale else "up to date")
        return 1 if stale else 0
    for path, text in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
