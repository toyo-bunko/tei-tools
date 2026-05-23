/* ======== tei-ne-jump.js ========
   Jump from a named-entity list entry to its occurrences in the text.

   Any element with `data-ne-targets="id1,id2,…"` (a comma list of occurrence
   element ids in document order) becomes a jump control: the first click goes
   to the first occurrence, clicking the same control again cycles to the next.

   On click it closes any open tei-header modal, switches to the page via
   window.TEIPager.goTo, focuses the line via window.OSDFacsimile.focusTarget
   (highlight + pan the image), and flashes the occurrence. Degrades gracefully
   if those modules are absent.

   Load after tei-header.js / tei-pager.js / osd-facsimile.js + osd-zone-link.js. */
(function () {
  "use strict";

  var lastCtrl = null, lastIdx = -1;

  function closeModals() {
    document.querySelectorAll(".tei-modal.open").forEach(function (m) {
      m.classList.remove("open");
    });
  }

  function flash(el) {
    if (!el) return;
    el.classList.remove("ne-flash");
    void el.offsetWidth;            // restart the CSS animation
    el.classList.add("ne-flash");
    setTimeout(function () { el.classList.remove("ne-flash"); }, 1600);
  }

  document.addEventListener("click", function (e) {
    var ctrl = e.target.closest && e.target.closest("[data-ne-targets]");
    if (!ctrl) return;
    var ids = (ctrl.getAttribute("data-ne-targets") || "").split(",")
                .filter(function (s) { return s; });
    if (!ids.length) return;
    e.preventDefault();

    /* same control → cycle to the next occurrence; new control → first */
    if (ctrl === lastCtrl) lastIdx = (lastIdx + 1) % ids.length;
    else { lastCtrl = ctrl; lastIdx = 0; }
    var id = ids[lastIdx];

    closeModals();
    var el = (window.TEIPager && window.TEIPager.goTo)
      ? window.TEIPager.goTo(id)
      : document.getElementById(id);
    if (!el) return;

    var line = el.closest ? el.closest("[id^='line-']") : null;
    if (window.OSDFacsimile && window.OSDFacsimile.focusTarget && line) {
      window.OSDFacsimile.focusTarget(line);   // highlight line + pan image
    } else {
      el.scrollIntoView({ behavior: "smooth", block: "center" });
    }
    flash(el);                                  // pinpoint the exact occurrence
  });
})();
