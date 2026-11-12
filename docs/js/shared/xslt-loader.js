/* ======== XSLT loader ========
   Chrome 158 (2026-11-17) removes the browser's built-in XSLT (both
   <?xml-stylesheet?> and the XSLTProcessor API); Firefox and Safari plan to
   follow. ensureXSLT() resolves once window.XSLTProcessor is usable:
     - native XSLT still works -> resolves immediately ('native')
     - otherwise -> loads the vendored polyfill (libxslt compiled to
       WebAssembly, by the Chrome team: github.com/mfreed7/xslt_polyfill,
       BSD-3-Clause) and resolves when it is ready ('polyfill').
   The polyfill is ~1.4 MB, so it is fetched only when needed.
   Add ?xslt=polyfill to the page URL to force the polyfill (for testing). */
"use strict";
(function () {
  var POLYFILL = new URL('js/vendor/xslt-polyfill/xslt-polyfill.min.js',
    document.currentScript ? new URL('../../', document.currentScript.src) : location.href).href;
  var forced = /[?&]xslt=polyfill(&|$)/.test(location.search);
  var pending = null;

  function nativeWorks() {
    try {
      if (typeof window.XSLTProcessor !== 'function') return false;
      new window.XSLTProcessor();
      return true;
    } catch (e) { return false; }
  }

  window.ensureXSLT = function () {
    if (pending) return pending;
    if (!forced && nativeWorks()) return (pending = Promise.resolve('native'));
    pending = new Promise(function (resolve, reject) {
      // Read once by the polyfill when it executes.
      window.xsltUsePolyfillOnlyIfNeeded = !forced; // forced: replace native
      window.xsltDontAutoloadXmlDocs = true;        // we call it ourselves
      window.xsltPolyfillQuiet = true;
      var s = document.createElement('script');
      s.src = POLYFILL;
      s.charset = 'utf-8';
      s.onload = function () {
        Promise.resolve(window.xsltPolyfillReady ? window.xsltPolyfillReady() : null)
          .then(function () { resolve('polyfill'); }, reject);
      };
      s.onerror = function () {
        reject(new Error('XSLT の部品を読み込めませんでした / Could not load the XSLT polyfill.'));
      };
      document.head.appendChild(s);
    });
    return pending;
  };
})();
