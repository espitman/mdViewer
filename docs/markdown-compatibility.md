# Markdown compatibility

Verified on 2026-11-01. The target is GitHub-style **local Markdown files**, with
MD Viewer's existing typography and Persian/RTL support. This is not a claim of
complete equivalence with every GitHub.com feature or every Markdown dialect.

## Rendering coverage

| Feature | Status |
| --- | --- |
| ATX / Setext headings, paragraphs, thematic breaks | Supported |
| Emphasis, strong emphasis, strikethrough, escapes, entities | Supported |
| Soft breaks, two-space and backslash hard breaks | Supported; soft breaks follow GitHub file rendering |
| Ordered/unordered lists, nesting, loose/tight lists, blockquotes | Supported |
| Task lists, nested tasks, ordered tasks, uppercase X | Supported; read-only checkboxes |
| Fenced/indented code, backtick/tilde fences, inline code | Supported; task markers inside code remain literal |
| Syntax highlighting | Supported for languages in the existing bundled highlight.js; others stay readable as plain code |
| Pipe tables, escaped pipes, column alignment, empty cells | Supported |
| Links, reference links, autolinks, email links, image references | Supported, with boundary differences listed below |
| Relative local images and links | Resolve against the source document's folder; native file-resource handler for WebKit compatibility |
| Local Markdown links | Open through the app's existing document/tab loader |
| External links | Open in the system application/browser |
| Heading anchors, duplicate headings, Unicode headings | Supported using GitHub-style slugs |
| Explicit HTML anchors | Supported; filtered IDs and fragment references are repaired |
| Footnotes and multiple backlinks | Supported |
| HTML tables, details/summary, kbd, sup/sub, picture | Supported through an HTML allowlist |
| Active HTML, script, event handlers, unsafe URLs | Filtered; arbitrary HTML applications are not rendered |
| GitHub alerts: NOTE, TIP, IMPORTANT, WARNING, CAUTION | Supported |
| Named emoji shortcodes | Supported through the bundled gemoji dataset; platform Unicode appearance |
| Inline math, dollar/backtick math, display math, math fences | Supported offline with KaTeX → native MathML |
| Mermaid | Supported using the existing bundled Mermaid, with zoom/pan/fullscreen |
| Invalid Mermaid | Shows its source/error locally and preserves the remaining document |
| Persian/RTL text and bundled Vazirmatn | Preserved |
| HTML export | Uses the same bundled rendering engine, including math and diagrams |

Math uses KaTeX rather than GitHub's MathJax. Commands specific to MathJax are
not guaranteed; invalid expressions remain visible. Mermaid and syntax
highlighting support the versions/languages bundled with the app, not every
future GitHub version.

## Reference verification

`Tests/Rendering/gfm-official.json` contains the **677 numbered examples** from
[the official GFM 0.29 specification](https://github.github.com/gfm/), retrieved
2026-11-01. It is derived from the specification by John MacFarlane and
contributors, licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
The fixture replaces the visual `→` tab marker with real tabs when executed.

The shipped browser bundle is tested, not a separate test implementation.
There are two independent verification layers:

1. **20 recorded responses from GitHub's actual Markdown API**, including all
   twelve cases previously reported as differences, are compared against the
   **production renderer**. Every case must match; there is no deviation
   allowlist. Fixtures retain their request source, mode, endpoint, capture time,
   and exact response HTML in `Tests/Rendering/github-rendering.json`.
2. **677 syntax reference cases** run through the bundled syntax renderer, before
   the deliberate HTML sanitization, math, direction, and highlighting transforms.
   For 665 cases the original official expectation is used. For twelve cases the
   captured current GitHub response takes precedence over the 2019 example.
   Every reference case must match, and every input also runs through production
   rendering without throwing.

The historical specification mixes base CommonMark examples with GFM extension
behavior. Current GitHub output takes precedence for script/style filtering,
automatic links, and HTML comments. Inline HTML comments ending with an extra
dash are parsed as visible text:
`foo <!-- foo--->`. It is now parsed as visible text, with any contained Markdown
still parsed normally, just as on GitHub. Valid comments, block comments, and
comment-like text inside inline/fenced code retain their own rules.

Active script/style tags remain escaped like GitHub; plain URLs and email
addresses remain automatically linked. External HTTP links receive `nofollow`,
and code receives `notranslate`, matching the captured responses.

Serializer spelling, attribute order, insignificant inter-block whitespace and
the two task-list styling classes are normalized. Syntax-only comparisons ignore
invisible comments and the `nofollow` annotation. The fenced-code API snapshot
compares preserved code text (ignoring one optional final newline), because GitHub
adds its own syntax-highlighter wrapper while the app highlights in WebKit.
Other production snapshot comparisons preserve DOM attributes and visible text.

**Current result: 20/20 GitHub snapshots and 677/677 combined reference cases.**
This does not mean that the 677 unmodified historical expectations all match, or
that every GitHub.com feature is implemented. The original specification fixture
is preserved unchanged; no expected result is fabricated from our renderer.

Tests run offline. To deliberately refresh the live fixtures, run:

```bash
node Rendering/update-github-fixtures.mjs
```

Review changes to `github-rendering.json` before accepting an upstream behavior
change. CI never refreshes reference responses automatically.

Fourteen feature/regression cases additionally check tasks inside code, ordered
and nested tasks, tables, breaks, references, footnotes, details, all alert
variants, emoji, all math delimiters, code languages, and HTML filtering.

A native `swift test` loads the complete generated HTML in **WKWebView**, checks
19 rendered behaviors (including a real relative PNG, computed table alignment,
RTL, syntax highlighting, math, malformed comments, literal styles, link/code
annotations, a rendered Mermaid and an invalid Mermaid), verifies
a local Markdown link reaches the native document loader, and
writes `/tmp/mdviewer-render-verification.png` for visual inspection.

A separate native layout regression checks 480, 900, and 1600 pixel viewports,
including enlarged text, long mixed Persian/English inline code and URLs, wide
code blocks, a 28-column table, HTML width attributes, expanded details, and RTL
footnotes. It verifies that the document itself does not scroll horizontally,
content blocks stay inside the viewport, and wide code/tables retain local
scrolling. Fixed-width HTML is constrained by the available content width.
Mixed RTL paragraphs use bidi isolation, avoiding a WebKit overflow caused by
`unicode-bidi: plaintext` when English code appears inside Persian lists.
The reported real document was also verified locally: a 1200 px viewport now
has a 1200 px document width, compared with 1821 px before this fix.
Finder double-clicks were verified with two documents opening in separate tabs
of the same main window.

## Remaining GitHub-specific differences

| Capability | Current behavior |
| --- | --- |
| `@mentions`, `#issues`, commit SHA/repository autolinks | Plain text; no repository/account context is inferred |
| GeoJSON / TopoJSON interactive maps | Source code only |
| STL interactive 3D preview | Source code only |
| YAML front matter metadata table | No dedicated metadata renderer |
| GitHub attachment hosting, video players, private asset authentication | No GitHub service integration |
| Theme-specific image fragments / full GitHub theme parity | Light preview; no GitHub theme-switching behavior |
| MDX, arbitrary embedded JavaScript, wiki-link dialects, custom plugins | Outside GFM coverage |
| Portable local media inside exported HTML | Relative references use the original document folder; local media is not copied/embedded |

## Rebuilding and verifying

The application ships the generated bundle and needs no Node installation or
network connection to render documents. Remote images still need network access.
To change the engine:

```bash
npm ci --prefix Rendering
npm run --prefix Rendering build
npm test --prefix Rendering
swift test
swift build -c release
```

`Rendering/renderer.js` is the source; `Rendering/package-lock.json` pins its
packages. `Rendering/build.mjs` builds the bundled JavaScript and third-party
license notices. CI checks the tests and verifies that the checked-in bundle
matches the source. Commit both source and generated resources when changing
rendering. No release or installed application is updated by these commands.

Local preview images are served through the app's `mdviewer-local` URL scheme.
This avoids file-URL restrictions in older supported WebKit versions. Native
navigation converts these URLs back to file URLs before opening document tabs.
The custom scheme is limited to the preview; exported HTML keeps its original
file base URL.
