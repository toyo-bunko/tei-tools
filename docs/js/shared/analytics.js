/* Google Analytics 4 (gtag.js) loader.
   Loaded with <script async src="js/shared/analytics.js"> from every HTML page
   so the Measurement ID lives in exactly one file. */
(function () {
  var MEASUREMENT_ID = 'G-TW3W4G98RK';

  var s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + MEASUREMENT_ID;
  document.head.appendChild(s);

  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = gtag;
  gtag('js', new Date());
  gtag('config', MEASUREMENT_ID);
})();
