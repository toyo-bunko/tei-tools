/* ======== tei-header.js ========
   Reusable top bar + teiHeader modal for project TEI views.

   Any XSL/HTML output can use it — no build step, no per-project code — by
   emitting this markup once and including this script:

     <div class="tei-header" data-title="Document title">
       <section class="tei-panel" data-label="概要 / Overview">
         …arbitrary metadata HTML (dl.kv, h3, p, p.tei-bibl, …)…
       </section>
       <section class="tei-panel" data-label="写本記述 / MS Description">
         …
       </section>
       <button type="button" class="tei-extra" data-zone-toggle>ゾーン表示</button>
     </div>
     <script src="tei-header.js"></script>

   On load it builds a sticky top bar: the document title plus one menu
   button per `.tei-panel`. Clicking a button opens a modal showing that
   panel's content. Any `.tei-extra` element (e.g. an osd-facsimile.js
   zone-toggle button) is moved into the bar as-is.

   It exposes the bar height as the CSS variable `--tei-bar-h`, so page
   layout can offset for it with `var(--tei-bar-h, 52px)`.

   Shared by tei-vellum.xsl and tei-urenja.xsl. */
(function () {
  "use strict";

  function injectCss() {
    if (document.getElementById("tei-header-css")) return;
    /* Colors/fonts read 東洋文庫デザインシステム tokens (css/theme.css) with the
       original hardcoded values as var() fallbacks, so views that don't link
       theme.css render exactly as before, while views that do (e.g.
       tei-ocr-facsimile) drive the whole chrome from the design tokens. */
    var css =
      ":root { --tei-bar-h: 52px; }" +
      ".tei-topbar { position: sticky; top: 0; z-index: 40;" +
        " height: var(--tei-bar-h); display: flex; align-items: center;" +
        " gap: 1rem; padding: 0 1rem;" +
        " background: var(--tei-bar-bg, #2c2622);" +
        " color: var(--tei-bar-fg, #f3f1ea); }" +
      ".tei-home { flex: none; font-size: .85rem; font-weight: 600;" +
        " color: var(--tei-bar-accent, #d8b88a); text-decoration: none;" +
        " white-space: nowrap; padding: .35rem .55rem; border-radius: 6px;" +
        " display: inline-flex; align-items: center; gap: .35em; }" +
      ".tei-home:hover { background: var(--tei-bar-hover-soft, rgba(255,255,255,.10)); }" +
      ".tei-home svg { width: 1em; height: 1em; opacity: .8; }" +
      ".tei-brand { font-size: .9rem; font-weight: 600; flex: 1; min-width: 0;" +
        " white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      ".tei-nav { display: flex; gap: .25rem; flex: none; flex-wrap: wrap;" +
        " justify-content: flex-end; }" +
      ".tei-nav button { font: inherit; font-size: .8rem; cursor: pointer;" +
        " color: var(--tei-bar-fg, #f3f1ea); background: transparent; border: 0;" +
        " padding: .4rem .7rem; border-radius: 6px; }" +
      ".tei-nav button:hover { background: var(--tei-bar-hover, rgba(255,255,255,.14)); }" +
      ".tei-nav button.tei-extra-on { background: var(--tei-bar-accent-strong, rgba(216,184,138,.3)); }" +
      ".tei-nav a.tei-srclink { font: inherit; font-size: .8rem;" +
        " color: var(--tei-bar-fg, #f3f1ea); text-decoration: none;" +
        " padding: .4rem .7rem; border-radius: 6px;" +
        " display: inline-flex; align-items: center; gap: .3em; }" +
      ".tei-nav a.tei-srclink:hover { background: var(--tei-bar-hover, rgba(255,255,255,.14)); }" +
      ".tei-nav a.tei-srclink svg { width: .85em; height: .85em;" +
        " opacity: .6; }" +
      ".tei-srclink-sep { width: 1px; align-self: stretch;" +
        " background: var(--tei-bar-divider, rgba(255,255,255,.18)); margin: .5rem .25rem; }" +
      ".tei-modal { display: none; position: fixed; inset: 0; z-index: 50;" +
        " background: var(--tei-overlay, rgba(20,17,14,.55));" +
        " padding: calc(var(--tei-bar-h) + 1rem) 1rem 1rem; }" +
      ".tei-modal.open { display: flex; justify-content: center;" +
        " align-items: flex-start; }" +
      ".tei-modal-box { background: var(--surface-raised, #fff); border-radius: 12px;" +
        " max-width: 640px; width: 100%; max-height: 100%; overflow: auto;" +
        " padding: 1.3rem 1.6rem 1.6rem; position: relative;" +
        " font-family: var(--font-sans, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif);" +
        " color: var(--ink, #1a1a1a); }" +
      ".tei-modal-close { position: absolute; top: .7rem; right: .8rem;" +
        " font-size: 1.3rem; line-height: 1; cursor: pointer;" +
        " background: transparent; border: 0; color: var(--ink-subtle, #888); }" +
      ".tei-modal-section h2 { font-size: 1.1rem; margin: 0 0 .9rem;" +
        " color: var(--tei-modal-head, #8a6d3b); }" +
      ".tei-modal-section h3 { font-size: .9rem; margin: 1.1rem 0 .3rem; }" +
      ".tei-modal-section p { font-size: .86rem; line-height: 1.7;" +
        " margin: .4rem 0; }" +
      ".tei-modal-section dl.kv { display: grid;" +
        " grid-template-columns: max-content 1fr; gap: .35rem .9rem;" +
        " margin: 0; font-size: .87rem; }" +
      ".tei-modal-section dl.kv dt { color: var(--ink-subtle, #8a8275); white-space: nowrap; }" +
      ".tei-modal-section dl.kv dd { margin: 0; }" +
      ".tei-modal-section .tei-bibl { padding-left: 1.1em;" +
        " text-indent: -1.1em; }";
    var style = document.createElement("style");
    style.id = "tei-header-css";
    style.textContent = css;
    document.head.appendChild(style);
  }

  function boot() {
    var src = document.querySelector(".tei-header");
    if (!src) return;
    injectCss();

    var title = src.getAttribute("data-title") ||
      (document.title || "TEI Document");
    var panels = [].slice.call(src.querySelectorAll(":scope > .tei-panel"));
    var extras = [].slice.call(src.querySelectorAll(":scope > .tei-extra"));

    /* ---- modal ---- */
    var modal = document.createElement("div");
    modal.className = "tei-modal";
    var box = document.createElement("div");
    box.className = "tei-modal-box";
    var close = document.createElement("button");
    close.type = "button";
    close.className = "tei-modal-close";
    close.setAttribute("aria-label", "close");
    close.innerHTML = "&#215;";
    box.appendChild(close);
    modal.appendChild(box);

    function closeModal() { modal.classList.remove("open"); }
    function openSection(sec) {
      modal.classList.add("open");
      [].forEach.call(box.querySelectorAll(".tei-modal-section"), function (s) {
        s.style.display = (s === sec) ? "block" : "none";
      });
    }
    close.addEventListener("click", closeModal);
    modal.addEventListener("click", function (e) {
      if (e.target === modal) closeModal();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") closeModal();
    });

    /* ---- top bar ---- */
    var bar = document.createElement("header");
    bar.className = "tei-topbar";
    var home = document.createElement("a");
    home.className = "tei-home";
    home.href = "https://toyo-bunko.github.io/tei-tools/";
    home.title = "TEI Tools home";
    home.innerHTML =
      '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">' +
        '<path d="M8 1.4L1 7.5V14a1 1 0 0 0 1 1h3.5v-4a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v4H14a1 1 0 0 0 1-1V7.5L8 1.4z"/>' +
      '</svg><span>TEI Tools</span>';
    var brand = document.createElement("div");
    brand.className = "tei-brand";
    brand.textContent = title;
    brand.title = title;
    var nav = document.createElement("nav");
    nav.className = "tei-nav";
    bar.appendChild(home);
    bar.appendChild(brand);
    bar.appendChild(nav);

    panels.forEach(function (panel, i) {
      var label = panel.getAttribute("data-label") || ("Panel " + (i + 1));
      var section = document.createElement("section");
      section.className = "tei-modal-section";
      section.style.display = "none";
      var h2 = document.createElement("h2");
      h2.textContent = label;
      section.appendChild(h2);
      while (panel.firstChild) section.appendChild(panel.firstChild);
      box.appendChild(section);

      var btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = label;
      btn.addEventListener("click", function () { openSection(section); });
      nav.appendChild(btn);
    });

    /* extras (e.g. a zone-toggle button) move into the bar untouched */
    extras.forEach(function (el) { nav.appendChild(el); });

    /* Source links: when this page was opened via view.html?url=…&xsl=…
       (the typical full-screen render route), expose the underlying
       TEI/XML and XSL as inline links in the bar so a reader can jump
       to the raw markup. Quietly skipped when the params aren't set.

       ?xsl= may be a bare catalog id (legacy form) — in that case the
       value is not a usable href, so we resolve it through catalog.json
       (same logic as view.js) before adding the link. */
    function makeSrcLink(label, href) {
      var a = document.createElement("a");
      a.className = "tei-srclink";
      a.href = href;
      a.target = "_blank";
      a.rel = "noopener";
      a.title = href;
      a.innerHTML =
        '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">' +
          '<path d="M9 1a1 1 0 0 0 0 2h2.59L6.3 8.29a1 1 0 1 0 1.42 1.42L13 4.41V7a1 1 0 1 0 2 0V2a1 1 0 0 0-1-1H9zM3.5 3A2.5 2.5 0 0 0 1 5.5v7A2.5 2.5 0 0 0 3.5 15h7a2.5 2.5 0 0 0 2.5-2.5V9a1 1 0 1 0-2 0v3.5a.5.5 0 0 1-.5.5h-7a.5.5 0 0 1-.5-.5v-7a.5.5 0 0 1 .5-.5H7a1 1 0 0 0 0-2H3.5z"/>' +
        '</svg>' + label;
      return a;
    }
    function looksLikeUrl(s) {
      return !!s && (/^https?:/i.test(s) || s.indexOf("/") !== -1 ||
                     /\.xslt?$/i.test(s));
    }
    try {
      var params = new URLSearchParams(location.search);
      var srcUrl = params.get("url");
      var xslUrl = params.get("xsl");
      if (srcUrl || xslUrl) {
        var sep = document.createElement("span");
        sep.className = "tei-srclink-sep";
        nav.appendChild(sep);
        if (srcUrl) nav.appendChild(makeSrcLink("TEI/XML", srcUrl));
        if (xslUrl) {
          if (looksLikeUrl(xslUrl)) {
            nav.appendChild(makeSrcLink("XSL", xslUrl));
          } else {
            // bare id — resolve via catalog.json, then add the link
            var xslLink = makeSrcLink("XSL", "#");
            xslLink.style.visibility = "hidden";
            nav.appendChild(xslLink);
            fetch("catalog.json").then(function (r) { return r.json(); })
              .then(function (cat) {
                var hit = (cat.xsl || []).find(function (x) {
                  return x.id === xslUrl;
                });
                if (hit && hit.url) {
                  xslLink.href = hit.url;
                  xslLink.title = hit.url;
                  xslLink.style.visibility = "";
                } else {
                  xslLink.parentNode.removeChild(xslLink);
                }
              })
              .catch(function () {
                xslLink.parentNode.removeChild(xslLink);
              });
          }
        }
      }
    } catch (e) { /* no URLSearchParams or no location — ignore */ }

    document.body.insertBefore(bar, document.body.firstChild);
    document.body.appendChild(modal);
    src.parentNode.removeChild(src);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
