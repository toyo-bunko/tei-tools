# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DOCX → TEI/XML converter: a static, no-build-step browser app that sends `.docx` files to the [TEI Garage](https://teigarage.tei-c.org/) REST API and displays the resulting TEI/XML. Deployed to Cloudflare Pages at https://tei-converter.pages.dev/.

## Development

No build step. Serve the `docs/` directory with any HTTP server:

```bash
cd docs && python3 -m http.server 8000
```

There are no tests or linting configured.

`wrangler` is the only dev dependency (for Cloudflare Pages deployment).

## Architecture

All application code lives in `docs/` — three files:

- **`index.html`** — page structure with `data-i18n` attributes for bilingual (JA/EN) support
- **`app.js`** — all logic: i18n, file upload/drag-drop, TEI Garage API call, XML pretty-printing with syntax highlighting, CETEIcean-powered TEI preview, tab switching, copy/download
- **`style.css`** — UI styles plus extensive CSS for rendering CETEIcean custom elements (`tei-head`, `tei-p`, `tei-note`, etc.)
- **`sample.docx`** — bundled sample file for quick testing

External dependency: [CETEIcean](https://github.com/TEIC/CETEIcean) loaded from CDN in `index.html`.

## Key Patterns

- **i18n**: `I18N` object at the top of `app.js` holds all JA/EN strings. HTML elements use `data-i18n="key"` attributes. `applyLang()` updates the DOM.
- **API endpoint**: The TEI Garage conversion URL is hardcoded in `app.js` as the `API` constant.
- **XML display**: Custom syntax highlighting via regex-based `highlightXml()` (not a library).
- **TEI preview**: CETEIcean transforms TEI XML into custom HTML elements; CSS in `style.css` styles them (`.tei-preview tei-*` selectors).
- **Note popups**: `tei-note` elements show content on hover via pure CSS (`:hover > *`).
