/* ======== osd-zone-link.js ========
   Companion to osd-facsimile.js: two-way link between a zone overlay and its
   text element.

   For every overlay whose zone has a `target` (an element id, e.g. a
   transcription line <li id="line-…"> or a deed block), this wires:

     * hover (either side)  → mutual highlight  (.osdz-hl / .osd-target-hl)
     * click on the zone    → reveal the text   (scrollIntoView) + focus
     * click on the text    → pan the image to the zone           + focus

   "focus" is single-selection (.osdz-active / .osd-target-active): clicking a
   new pair clears the previous one.

   Works together with osd-zone-toggle.js: even while overlays are hidden, the
   hovered / focused zone stays visible (a higher-specificity rule there) so a
   text line can always be located on the image.

   Load AFTER osd-facsimile.js. No-op if the core is absent. */
(function () {
  "use strict";

  function injectCss() {
    if (document.getElementById("osd-zone-link-css")) return;
    var css =
      /* linked zones (those with a text target) are interactive; non-linked
         zones keep pointer-events:none so they never block OSD panning. */
      ".osdz.linked { pointer-events: auto; cursor: pointer; }" +
      ".osdz.osdz-hl { background: rgba(40,170,110,.30);" +
        " box-shadow: inset 0 0 0 2px rgba(40,170,110,.95); }" +
      ".osdz.osdz-active { background: rgba(245,160,30,.34);" +
        " box-shadow: inset 0 0 0 3px rgba(240,150,0,.98); }" +
      ".osd-target-hl { background: #fff6df; }" +
      ".osd-target-active { background: #ffe6a3;" +
        " box-shadow: inset 3px 0 0 #f0a000; }";
    var style = document.createElement("style");
    style.id = "osd-zone-link-css";
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
  }

  var _activeOverlay = null, _activeTarget = null;
  var linkRegistry = {};      // target element id -> { overlayEl, z, viewer }
  var _pendingFocusId = null; // focusTarget() called before that page mounted

  /* Highlight/focus is class-only (.osdz-hl / .osdz-active). Even while overlays
     are hidden (osd-zone-toggle.js → `.zones-hidden .osdz{display:none!important}`)
     the hovered/focused zone stays visible, because osd-zone-toggle.js carries a
     higher-specificity `.zones-hidden .osdz.osdz-hl/.osdz-active{display:block
     !important}` rule. We deliberately do NOT force display inline here:
     OpenSeadragon re-sets `display:block` (non-important) on every overlay redraw
     (Overlay.drawHTML), which would strip an inline !important on the next
     pan/zoom — exactly when a click pans to the zone. */
  function setActive(overlayEl, targetEl) {
    if (_activeOverlay) _activeOverlay.classList.remove("osdz-active");
    if (_activeTarget) _activeTarget.classList.remove("osd-target-active");
    _activeOverlay = overlayEl; _activeTarget = targetEl;
    if (overlayEl) overlayEl.classList.add("osdz-active");
    if (targetEl) targetEl.classList.add("osd-target-active");
  }

  function setHover(overlayEl, targetEl, on) {
    if (overlayEl) overlayEl.classList.toggle("osdz-hl", on);
    if (targetEl) targetEl.classList.toggle("osd-target-hl", on);
  }

  function panToZone(viewer, z) {
    try {
      viewer.viewport.panTo(
        viewer.viewport.imageToViewportCoordinates(z.x + z.w / 2, z.y + z.h / 2),
        false);
    } catch (e) { /* viewport not ready */ }
  }

  function wireLink(viewer, z, overlayEl, targetEl) {
    var on  = function () { setHover(overlayEl, targetEl, true); };
    var off = function () { setHover(overlayEl, targetEl, false); };
    overlayEl.addEventListener("mouseenter", on);
    overlayEl.addEventListener("mouseleave", off);
    targetEl.addEventListener("mouseenter", on);
    targetEl.addEventListener("mouseleave", off);
    /* zone click → reveal the text line */
    overlayEl.addEventListener("click", function () {
      setActive(overlayEl, targetEl);
      targetEl.scrollIntoView({ behavior: "smooth", block: "center" });
    });
    /* text-line click → pan the image to the zone */
    targetEl.addEventListener("click", function () {
      setActive(overlayEl, targetEl);
      panToZone(viewer, z);
    });
    /* registry for focusTarget(); apply a focus that was requested before
       this page's overlays existed (e.g. a named-entity-list jump). */
    if (targetEl.id) {
      linkRegistry[targetEl.id] = { overlayEl: overlayEl, z: z, viewer: viewer };
      if (_pendingFocusId === targetEl.id) {
        _pendingFocusId = null;
        setActive(overlayEl, targetEl);
        panToZone(viewer, z);
      }
    }
  }

  /* Public focus from outside (e.g. the named-entity list): highlight + scroll
     the text element and pan the image to its zone. If the page's overlay isn't
     mounted yet, remember it and apply the zone part once it appears. */
  function focusTarget(targetEl) {
    if (!targetEl) return;
    var rec = targetEl.id ? linkRegistry[targetEl.id] : null;
    setActive(rec ? rec.overlayEl : null, targetEl);
    targetEl.scrollIntoView({ behavior: "smooth", block: "center" });
    if (rec) { panToZone(rec.viewer, rec.z); _pendingFocusId = null; }
    else { _pendingFocusId = targetEl.id || null; }
  }

  if (!window.OSDFacsimile || !window.OSDFacsimile.onOverlay) return;
  injectCss();
  window.OSDFacsimile.focusTarget = focusTarget;   // used by tei-ne-jump.js
  window.OSDFacsimile.onOverlay(function (z, el, viewer) {
    if (!z.target) return;
    var targetEl = document.getElementById(z.target);
    if (!targetEl) return;
    el.className += " linked";
    el.title = "本文へ移動 / jump to text";
    wireLink(viewer, z, el, targetEl);
  });
})();
