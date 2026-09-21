"""The served scripts, checked as a set rather than one at a time.

Every page loads `/web/common.js` and then its own script, both as classic
`<script>` tags. Classic scripts share one global lexical scope, so a name
declared in both can be a `SyntaxError` — and not a local one: it kills the
*entire* second file before a line of it runs, so the page shows its static
placeholder forever and nothing in the console points at a cause.

That is exactly what happened: the car preview's field catalogue declared
`const fmt`, `common.js` already had one, and the mockup froze on "Loading…".
Syntax-checking either file alone could not see it, because neither is wrong
by itself.

**Only lexical declarations collide.** `function` + `function`, `var` + `var`
and `var` + `function` are all legal redeclarations — the later one simply
wins. `public/site.js` redefines `storedLang` that way on purpose, and
flagging it would be noise. A `let`, `const` or `class` on either side is the
fatal case, and that is what this checks.
"""

import re
from pathlib import Path

import pytest

_APP = Path(__file__).resolve().parent.parent / "app"
_COMMON = _APP / "web" / "common.js"

#: Every script loaded alongside `common.js` in the same global scope.
_PAGE_SCRIPTS = sorted(p for p in _APP.rglob("*.js") if p != _COMMON)

_DECL = re.compile(
    r"^(const|let|var|class|function|async\s+function)\s+([A-Za-z_$][\w$]*)"
)
_LEXICAL = {"const", "let", "class"}


def _top_level_declarations(path: Path) -> dict[str, str]:
    """Global-scope name → the keyword that declared it.

    Column zero is the test: anything indented is inside a function or block
    and cannot collide. Crude, and right for these files, which are written
    flat on purpose.
    """
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if m := _DECL.match(line):
            out[m.group(2)] = m.group(1).split()[-1]
    return out


def test_the_scripts_are_where_we_think_they_are():
    assert _COMMON.exists()
    assert _PAGE_SCRIPTS, "no page scripts found; the layout moved"


@pytest.mark.parametrize("script", _PAGE_SCRIPTS, ids=lambda p: p.name)
def test_page_scripts_do_not_redeclare_a_global_lexically(script):
    common = _top_level_declarations(_COMMON)
    page = _top_level_declarations(script)
    fatal = sorted(
        name for name in common.keys() & page.keys()
        if common[name] in _LEXICAL or page[name] in _LEXICAL
    )
    assert not fatal, (
        f"{script.relative_to(_APP)} redeclares {fatal} from web/common.js with "
        "let/const/class. Two classic scripts share one global scope, so this is "
        "a SyntaxError that silently disables the whole file."
    )
