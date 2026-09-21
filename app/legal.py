"""Render the repo's PRIVACY.md and TERMS.md as pages.

A deliberate non-dependency: these two documents use headings, bold, links,
lists and paragraphs and nothing else, so a full Markdown library would be a
new dependency in the image for about forty lines of work. The renderer below
covers exactly that subset and escapes everything first — the input is our own
file, but a renderer that only works on trusted input is a trap for whoever
points it at something else later.

The Markdown files stay the single source of truth, so the page and the repo
can never disagree about what the policy says.
"""

from __future__ import annotations

import html
import re
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent

_LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")
_ITALIC = re.compile(r"(?<![\w*])_([^_]+)_(?![\w*])")


def _inline(text: str) -> str:
    out = html.escape(text)
    out = _LINK.sub(lambda m: f'<a href="{html.escape(m.group(2), quote=True)}">{m.group(1)}</a>', out)
    out = _BOLD.sub(r"<strong>\1</strong>", out)
    out = _ITALIC.sub(r"<em>\1</em>", out)
    return out


def to_html(md: str) -> tuple[str, str]:
    """Returns (title, body html)."""
    title = ""
    parts: list[str] = []
    para: list[str] = []
    bullets: list[str] = []

    def flush_para() -> None:
        if para:
            parts.append(f"<p>{_inline(' '.join(para))}</p>")
            para.clear()

    def flush_bullets() -> None:
        if bullets:
            items = "".join(f"<li>{_inline(b)}</li>" for b in bullets)
            parts.append(f"<ul>{items}</ul>")
            bullets.clear()

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush_para(); flush_bullets()
            continue
        if line.startswith("## "):
            flush_para(); flush_bullets()
            parts.append(f"<h2>{_inline(line[3:])}</h2>")
        elif line.startswith("# "):
            flush_para(); flush_bullets()
            title = line[2:].strip()
            parts.append(f"<h1>{_inline(line[2:])}</h1>")
        elif line.startswith("- "):
            flush_para()
            bullets.append(line[2:])
        else:
            if bullets:
                bullets[-1] = bullets[-1] + " " + line.strip()
            else:
                para.append(line.strip())
    flush_para(); flush_bullets()
    return title, "\n".join(parts)


def document(name: str) -> tuple[str, str]:
    """(title, body html) for PRIVACY or TERMS. Raises FileNotFoundError."""
    return to_html((_ROOT / f"{name}.md").read_text(encoding="utf-8"))
