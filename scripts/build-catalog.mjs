#!/usr/bin/env node
/* ===================================================================
 * build-catalog.mjs — generate docs/catalog.json for the TEI Gallery.
 *
 * The TEI Gallery (publisher.html) lists XML documents and XSL
 * stylesheets with their description / language / category / license.
 * Rather than hand-maintaining that metadata in JavaScript, this script
 * derives it from the files themselves:
 *
 *   - XML  : the teiHeader of each docs/xml/<id>/tei.xml
 *            (and remote documents listed in docs/xml/sources.json,
 *             fetched once here so the browser never pays CORS/latency)
 *   - XSL  : the structured leading comment of each docs/xsl/*.xsl
 *            (Title: / Description: / Category: / License: lines)
 *
 * Output: docs/catalog.json (committed; the browser just loads it).
 *
 * Run:  npm run catalog      (or: node scripts/build-catalog.mjs)
 *
 * Dependency-free by design: it only extracts a handful of known
 * elements from our own well-formed files, so targeted regex is enough
 * and the project keeps zero runtime/parse dependencies.
 * =================================================================== */

import { readFile, writeFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const DOCS = join(ROOT, 'docs');

/* ---- tiny text helpers ------------------------------------------- */

function decodeEntities(s) {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
          .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
          .replace(/&amp;/g, '&');
}
/* Drop tags, collapse whitespace — turns an element's inner XML into
 * a plain one-line string. */
function plain(xml) {
  return decodeEntities(String(xml).replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ').trim();
}
/* Inner content of the first <name>…</name> (namespace-prefix agnostic). */
function block(xml, name) {
  const m = xml.match(new RegExp(
    `<(?:[\\w.-]+:)?${name}(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[\\w.-]+:)?${name}>`, 'i'));
  return m ? m[1] : null;
}
/* Value of `attr` on the first <name …> tag. */
function attr(xml, name, a) {
  const m = xml.match(new RegExp(
    `<(?:[\\w.-]+:)?${name}\\s[^>]*\\b${a}\\s*=\\s*["']([^"']+)["']`, 'i'));
  return m ? m[1] : null;
}

/* ---- TEI teiHeader extraction ------------------------------------ */

function teiTitle(header) {
  const ts = block(header, 'titleStmt') || header;
  const re = /<(?:[\w.-]+:)?title(\s[^>]*)?>([\s\S]*?)<\/(?:[\w.-]+:)?title>/gi;
  let m;
  while ((m = re.exec(ts))) {
    if (/\btype\s*=/.test(m[1] || '')) continue;   // skip <title type="sub">
    const t = plain(m[2]);
    if (t) return t;
  }
  return '';
}
function teiAbstract(header) {
  const a = block(header, 'abstract');
  if (a) return plain(a);
  const summary = block(header, 'summary');           // msDesc/summary fallback
  if (summary) return plain(summary);
  return '';
}
function teiLanguages(header) {
  const out = [];
  const re = /<(?:[\w.-]+:)?language\s[^>]*\bident\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = re.exec(header))) out.push(m[1]);
  if (!out.length) {
    const ml = attr(header, 'textLang', 'mainLang');
    if (ml) out.push(ml);
  }
  return [...new Set(out)];
}
function teiCategory(header) {
  const tc = block(header, 'textClass') || header;
  const t = block(tc, 'term');
  return t ? plain(t) : '';
}
function teiLicense(header) {
  const av = block(header, 'availability');
  if (av) {
    const lic = block(av, 'licence') || block(av, 'license');
    if (lic) return plain(lic);
    if (block(av, 'p')) return plain(block(av, 'p'));
  }
  return attr(header, 'availability', 'status') || '';
}
function xmlMeta(xmlText) {
  const header = block(xmlText, 'teiHeader') || xmlText;
  return {
    title:       teiTitle(header),
    description: teiAbstract(header),
    languages:   teiLanguages(header),
    category:    teiCategory(header),
    license:     teiLicense(header),
  };
}

/* ---- XSL leading-comment extraction ------------------------------ */

function xslMeta(xslText) {
  const cm = xslText.match(/<!--([\s\S]*?)-->/);
  const c = cm ? cm[1] : '';
  const field = (name) => {
    const m = c.match(new RegExp('^\\s*' + name + ':\\s*(.+?)\\s*$', 'm'));
    return m ? m[1] : '';
  };
  /* Parse Sample field. Supported forms in the leading comment:
   *   Sample (file):   xml/tei-guide/tei.xml
   *   Sample (file):   https://example.org/some.xml
   *   Sample (folder): xml/ocr-sample (xml: tei.xml)
   * Optional — only used by the XSL gallery as a default input. */
  let sample = null;
  const fileLine   = c.match(/^\s*Sample\s*\(\s*file\s*\)\s*:\s*(\S.+?)\s*$/mi);
  const folderLine = c.match(/^\s*Sample\s*\(\s*folder\s*\)\s*:\s*([^\s(]+)(?:\s*\(\s*xml\s*:\s*([^)]+)\))?\s*$/mi);
  if (fileLine) {
    sample = { kind: 'file', path: fileLine[1] };
  } else if (folderLine) {
    sample = { kind: 'folder', dir: folderLine[1].replace(/\/$/, ''),
               xml: (folderLine[2] || 'tei.xml').trim() };
  }
  return {
    id:          field('Id'),
    input:       field('Input'),   // 'file' or 'folder'
    sample,
    title:       field('Title'),
    description: field('Description'),
    category:    field('Category'),
    license:     field('License'),
  };
}

/* Drop keys whose value is empty ('' or []) — used so that metadata a
 * remote TEI omits (abstract / textClass / availability are rare in
 * OCR output) falls through to the hand-written fallback. */
function stripEmpty(o) {
  return Object.fromEntries(Object.entries(o).filter(
    ([, v]) => !(v === '' || (Array.isArray(v) && v.length === 0))));
}

/* Reconstruct an XSL Sample's full path so it can be matched against an
 * XML document's url: a `file` sample is its path as-is; a `folder` sample
 * is dir + '/' + xml. Returns null when the XSL declares no sample. */
function sampleFullPath(sample) {
  if (!sample) return null;
  if (sample.kind === 'file')   return sample.path;
  if (sample.kind === 'folder') return sample.dir.replace(/\/$/, '') + '/' + sample.xml;
  return null;
}

/* ---- remote fetch (with timeout + graceful fallback) ------------- */

async function fetchText(url, ms = 20000) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), ms);
  try {
    const res = await fetch(url, { signal: ac.signal });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

/* ---- main -------------------------------------------------------- */

async function build() {
  const sources = JSON.parse(
    await readFile(join(DOCS, 'xml', 'sources.json'), 'utf8'));

  /* --- XML documents ---
   * Bundled XML are auto-discovered from docs/xml/<id>/tei.xml (same spirit
   * as the XSL scan below) so a new sample needs no manual manifest edit.
   * sources.json is still read for: (a) remote documents (can't be scanned),
   * and (b) explicit ordering/overrides of bundled entries listed there.
   * Final order = manifest entries first (curated order), then any
   * auto-discovered bundled dir not already in the manifest. */
  const manifestXml = sources.xml || [];
  const manifestIds = new Set(manifestXml.map(e => e.id));
  const xmlDir = join(DOCS, 'xml');
  const discovered = [];
  for (const d of await readdir(xmlDir, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    const inner = await readdir(join(xmlDir, d.name));
    if (inner.includes('tei.xml')) {
      discovered.push({ id: d.name, scope: 'bundled', path: `xml/${d.name}/tei.xml` });
    }
  }
  discovered.sort((a, b) => a.id.localeCompare(b.id));
  const xmlEntries = [
    ...manifestXml,
    ...discovered.filter(e => !manifestIds.has(e.id)),
  ];

  /* --- XSL stylesheets ---
   * Built before the XML documents so each document's recommended
   * stylesheet (below) can be resolved against this list. */
  const xsl = [];
  const xslDir = join(DOCS, 'xsl');
  for (const file of (await readdir(xslDir)).filter(f => f.endsWith('.xsl')).sort()) {
    const meta = xslMeta(await readFile(join(xslDir, file), 'utf8'));
    xsl.push({ url: 'xsl/' + file, ...meta });
    console.log(`  xsl         ${file}`);
  }

  /* Recommended XML × XSL pairing.
   * Each XSL declares the Sample document it is written for, so that sample
   * doubles as the document's recommended stylesheet — we reverse that
   * relationship here (sample full path -> XSL ids). A manifest entry may
   * override it with an explicit `recommend: "<xsl-id>"` (or `recommend: ""`
   * to suppress one); the override also resolves the ambiguity when several
   * XSLs share one sample (e.g. the tutorial guide). */
  const xslIds = new Set(xsl.map(x => x.id).filter(Boolean));
  const sampleToXsl = new Map();
  for (const x of xsl) {
    const p = sampleFullPath(x.sample);
    if (!p || !x.id) continue;
    if (!sampleToXsl.has(p)) sampleToXsl.set(p, []);
    sampleToXsl.get(p).push(x.id);
  }
  function resolveRecommend(entry, url) {
    let id;
    if (Object.prototype.hasOwnProperty.call(entry, 'recommend')) {
      id = entry.recommend;                        // explicit ('' suppresses)
    } else {
      const cands = sampleToXsl.get(url) || [];    // auto: the XSL sampling this doc
      if (cands.length === 1) id = cands[0];
    }
    if (!id) return null;
    if (!xslIds.has(id)) {
      console.warn(`  recommend ?  ${entry.id}: no XSL with id "${id}" — skipped`);
      return null;
    }
    return id;
  }

  /* --- XML documents --- */
  const xml = [];
  for (const entry of xmlEntries) {
    let meta, url;
    if (entry.scope === 'remote') {
      url = entry.url;
      try {
        // Fetched metadata wins where present; the fallback fills any
        // field the remote TEI omits (and is used wholesale on error).
        meta = { ...entry.fallback, ...stripEmpty(xmlMeta(await fetchText(entry.url))) };
        console.log(`  remote ok   ${entry.id}`);
      } catch (err) {
        meta = { ...entry.fallback };
        console.warn(`  remote FAIL ${entry.id} (${err.message}) — using fallback`);
      }
    } else {
      url = entry.path;
      meta = xmlMeta(await readFile(join(DOCS, entry.path), 'utf8'));
      console.log(`  bundled     ${entry.id}`);
    }
    const out = { id: entry.id, scope: entry.scope, url, ...meta };
    const rec = resolveRecommend(entry, url);
    if (rec) out.recommendedXsl = rec;
    xml.push(out);
  }

  const catalog = { generated: new Date().toISOString(), xml, xsl };
  await writeFile(join(DOCS, 'catalog.json'),
    JSON.stringify(catalog, null, 2) + '\n');
  console.log(`\ncatalog.json written: ${xml.length} XML, ${xsl.length} XSL.`);
}

build().catch(err => { console.error(err); process.exitCode = 1; });
