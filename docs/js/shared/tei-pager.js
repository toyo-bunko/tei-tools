/* ======== tei-pager.js ========
   Reusable page-by-page navigator for multi-page TEI views.

   Any XSL/HTML output can use it by emitting this markup and the script:

     <div class="tei-pager">
       <section class="tei-page" data-page-label="ページ 1">…</section>
       <section class="tei-page" data-page-label="ページ 2">…</section>
       …
     </div>
     <script src="js/shared/tei-pager.js"></script>

   It shows one `.tei-page` at a time with a sticky prev / next bar and a
   counter; ←/→ keys also navigate. With a single page, no bar is shown.

   Page visibility is driven by an inline `display` style set directly on
   each `.tei-page`, so it cannot be overridden by project CSS.

   If osd-facsimile.js is present, any `.facsimile` viewers inside a page are
   mounted lazily — only when that page is first shown — via
   `window.OSDFacsimile.mountWithin(page)`. This keeps many-page documents
   light: only the current page's OpenSeadragon viewer is initialised.

   Load order: include this BEFORE osd-facsimile.js so that, by the time
   osd-facsimile boots, off-screen pages are already hidden and their
   viewers are skipped. */
(function () {
  "use strict";

  function injectCss() {
    if (document.getElementById("tei-pager-css")) return;
    var css =
      ".tei-pager-bar { position: sticky; top: var(--tei-bar-h, 52px);" +
        " z-index: 25; display: flex; align-items: center;" +
        " justify-content: center; gap: 1rem; padding: .5rem 1rem;" +
        " background: #efece4; border-bottom: 1px solid #d8d2c2; }" +
      ".tei-pager-bar button { font: inherit; font-size: .85rem;" +
        " cursor: pointer; padding: .35rem .9rem; border-radius: 6px;" +
        " border: 1px solid #c8c2b2; background: #fff; color: #2c2622; }" +
      ".tei-pager-bar button:hover:not(:disabled) { background: #f3f1ea; }" +
      ".tei-pager-bar button:disabled { opacity: .4; cursor: default; }" +
      ".tei-pager-counter { font-size: .85rem; color: #5b5346;" +
        " min-width: 8rem; text-align: center;" +
        " font-variant-numeric: tabular-nums; }";
    var style = document.createElement("style");
    style.id = "tei-pager-css";
    style.textContent = css;
    document.head.appendChild(style);
  }

  /* ---- current page <-> URL ?page=N (1-based) ----
     ページ送りで GET パラメータに残し、リロード時はそのページから再開する。
     既存の ?url= / ?xsl= 等は保持。履歴は汚さない (replaceState)。 */
  var PAGE_PARAM = "page";

  function readPageParam() {
    try {
      var n = parseInt(new URLSearchParams(window.location.search).get(PAGE_PARAM), 10);
      return (isFinite(n) && n >= 1) ? n : null;
    } catch (e) { return null; }
  }

  function writePageParam(n) {
    try {
      var u = new URL(window.location.href);
      u.searchParams.set(PAGE_PARAM, String(n));
      window.history.replaceState(null, "", u.href);
    } catch (e) { /* history 不可な環境では何もしない */ }
  }

  function boot() {
    var pager = document.querySelector(".tei-pager");
    if (!pager) return;
    injectCss();

    /* direct-child .tei-page sections (no :scope, for max compatibility) */
    var pages = [];
    for (var c = pager.firstElementChild; c; c = c.nextElementSibling) {
      if (c.classList && c.classList.contains("tei-page")) pages.push(c);
    }
    if (!pages.length) return;

    function mountViewers(page) {
      if (window.OSDFacsimile && window.OSDFacsimile.mountWithin) {
        window.OSDFacsimile.mountWithin(page);
      }
    }

    var current = -1;

    /* Single page: just show it, no navigation bar. */
    if (pages.length === 1) {
      document.documentElement.style.setProperty("--tei-pager-h", "0px");
      pages[0].style.display = "block";
      pages[0].classList.add("tei-page-active");
      mountViewers(pages[0]);
      /* 単一ページでも外部から goTo できるよう API を公開 (切替不要・要素を返すだけ) */
      window.TEIPager = {
        show: function () {},
        goTo: function (x) {
          return (typeof x === "string") ? document.getElementById(x) : x;
        },
        indexOf: function (p) { return pages.indexOf(p); },
        current: function () { return 0; },
        pageCount: 1
      };
      return;
    }

    /* ---- navigation bar ---- */
    var bar = document.createElement("div");
    bar.className = "tei-pager-bar";
    var prev = document.createElement("button");
    prev.type = "button";
    prev.textContent = "‹ 前へ";
    var counter = document.createElement("span");
    counter.className = "tei-pager-counter";
    var next = document.createElement("button");
    next.type = "button";
    next.textContent = "次へ ›";
    bar.appendChild(prev);
    bar.appendChild(counter);
    bar.appendChild(next);
    pager.insertBefore(bar, pager.firstChild);
    /* バー実高を CSS 変数に。全画面レイアウトが height 計算に使える
       (例: height: calc(100vh - var(--tei-bar-h) - var(--tei-pager-h)))。 */
    try {
      document.documentElement.style.setProperty(
        "--tei-pager-h", bar.offsetHeight + "px");
    } catch (e) { /* no-op */ }

    function label(i) {
      var l = pages[i].getAttribute("data-page-label");
      return (l ? l : "ページ " + (i + 1)) + " / " + pages.length;
    }

    function show(i) {
      if (i < 0 || i >= pages.length) return;
      current = i;
      for (var k = 0; k < pages.length; k++) {
        /* inline display — beats any project CSS */
        pages[k].style.display = (k === i) ? "block" : "none";
        if (k === i) pages[k].classList.add("tei-page-active");
        else pages[k].classList.remove("tei-page-active");
      }
      counter.textContent = label(i);
      prev.disabled = (i === 0);
      next.disabled = (i === pages.length - 1);
      writePageParam(i + 1);                   // GET パラメータ ?page=N に反映
      mountViewers(pages[i]);                 // lazy-mount this page's viewers
      bar.scrollIntoView({ block: "nearest" });
    }

    prev.addEventListener("click", function () { show(current - 1); });
    next.addEventListener("click", function () { show(current + 1); });
    document.addEventListener("keydown", function (e) {
      if (e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;
      if (e.key === "ArrowLeft") show(current - 1);
      else if (e.key === "ArrowRight") show(current + 1);
    });

    /* 外部 API: 任意の要素 (または id) を含むページへ切り替えて、その要素を返す。
       NER 一覧などからクリックで該当ページへジャンプするのに使う。 */
    window.TEIPager = {
      show: show,
      goTo: function (x) {
        var el = (typeof x === "string") ? document.getElementById(x) : x;
        if (!el) return null;
        var pg = el.closest ? el.closest(".tei-page") : null;
        var i = pg ? pages.indexOf(pg) : -1;
        if (i >= 0) show(i);
        return el;
      },
      indexOf: function (p) { return pages.indexOf(p); },
      current: function () { return current; },
      pageCount: pages.length
    };

    /* リロード時は ?page=N から再開 (範囲外は端に丸める)。無ければ先頭。 */
    var startParam = readPageParam();
    var start = (startParam !== null)
      ? Math.max(0, Math.min(startParam - 1, pages.length - 1))
      : 0;
    show(start);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
