/* ======== osd-zone-toggle.js ========
   Companion to osd-facsimile.js: show/hide all zone overlays from a button,
   with the state persisted to the URL.

   Any `[data-zone-toggle]` element toggles the overlays. The state is written
   to the URL as ?zones=on|off (same convention as tei-pager's ?page=N:
   replaceState, existing params kept) so it survives reload and page
   navigation, and is applied to every `.facsimile` — including pages mounted
   lazily later (via the core's onMount hook).

   While hidden, osd-zone-link.js still force-shows the one zone the reader
   hovers / focuses, so a text line can always be located on the image.

   Load AFTER osd-facsimile.js. No-op if the core is absent. */
(function () {
  "use strict";

  var ZONES_PARAM = "zones";
  var zonesHidden = false;

  function injectCss() {
    if (document.getElementById("osd-zone-toggle-css")) return;
    var css =
      /* !important: OpenSeadragon re-sets `display:block` inline on every
         overlay redraw (Overlay.drawHTML), so a non-important rule is ignored. */
      ".facsimile.zones-hidden .osdz { display: none !important; }" +
      /* The zone the reader hovers / focuses stays visible even while zones are
         hidden, so a text line can always be located on the image. This rule has
         higher specificity than the hide rule above (it wins among !important
         declarations), and !important beats OSD's inline non-important display.
         The classes are set by osd-zone-link.js (.osdz-hl / .osdz-active) —
         doing it in CSS, not inline, survives OSD's per-redraw display reset
         (which would strip an inline !important on the next pan/zoom). */
      ".facsimile.zones-hidden .osdz.osdz-hl," +
      ".facsimile.zones-hidden .osdz.osdz-active { display: block !important; }";
    var style = document.createElement("style");
    style.id = "osd-zone-toggle-css";
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
  }

  function readZonesParam() {
    try {
      var v = new URLSearchParams(window.location.search).get(ZONES_PARAM);
      if (v === null) return null;
      v = v.toLowerCase();
      if (v === "off" || v === "hidden" || v === "0" || v === "false") return true;
      if (v === "on"  || v === "show"   || v === "1" || v === "true")  return false;
      return null;
    } catch (e) { return null; }
  }

  function writeZonesParam() {
    try {
      var u = new URL(window.location.href);
      u.searchParams.set(ZONES_PARAM, zonesHidden ? "off" : "on");
      window.history.replaceState(null, "", u.href);
    } catch (e) { /* history 不可な環境では何もしない */ }
  }

  /* push the current state to every facsimile + toggle button (idempotent) */
  function applyZonesHidden() {
    document.querySelectorAll(".facsimile").forEach(function (c) {
      c.classList.toggle("zones-hidden", zonesHidden);
    });
    document.querySelectorAll("[data-zone-toggle]").forEach(function (btn) {
      btn.classList.toggle("tei-extra-on", !zonesHidden);  // active = zones shown
      btn.setAttribute("aria-pressed", String(!zonesHidden));
    });
  }

  function wireToggles() {
    document.querySelectorAll("[data-zone-toggle]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        zonesHidden = !zonesHidden;
        applyZonesHidden();
        writeZonesParam();
      });
    });
  }

  function boot() {
    injectCss();
    zonesHidden = (readZonesParam() === true);  // ?zones=off → start hidden
    wireToggles();
    applyZonesHidden();                         // sync containers + button(s)
  }

  /* keep lazily-mounted pages (tei-pager.js) in sync with the current state */
  if (window.OSDFacsimile && window.OSDFacsimile.onMount) {
    window.OSDFacsimile.onMount(function (container) {
      container.classList.toggle("zones-hidden", zonesHidden);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    setTimeout(boot, 0);
  }
})();
