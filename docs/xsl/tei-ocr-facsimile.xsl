<?xml version="1.0" encoding="UTF-8"?>
<!--
  tei-ocr-facsimile.xsl — OCR transcription view / OCR 翻刻ビュー

  Id:          ocr
  Input:       folder
  Sample (folder): xml/ocr-sample (xml: tei.xml)
  Title:       OCR transcription view / OCR 翻刻ビュー
  Description: OCR 出力の TEI を、ページ画像と行ごとの翻刻テキストを左右に全画面で並べて表示する検証ビュー。固有表現 (persName/placeName/orgName/date) を色分けし、ヘッダーから一覧できる。/ A full-screen verification view placing each page image beside its numbered OCR lines, colour-coding named entities with a list in the header.
  Category:    汎用 / General-purpose
  License:     自由に利用・改変できます（XSLT 1.0）。/ Free to use and adapt (XSLT 1.0).

  facsimile の surface/zone/graphic と text の pb/lb を扱う。
  TEIScanner / NDL古典籍OCR / Azure Document Intelligence などの OCR 結果を想定。
  本文に持つインライン固有表現 (persName/placeName/orgName/date) は種別ごとに色分け表示する。

  共有モジュール（docs/js/shared/）を利用する:
    * tei-header.js    … 上部バー＋ teiHeader / 固有表現一覧モーダル
    * tei-pager.js     … 1 ページずつの全画面ページャー (?page=N で URL 連動)
    * osd-facsimile.js … OpenSeadragon 拡大縮小＋行 zone オーバーレイ。
                         本文行 と zone はホバーで相互ハイライト、クリックでフォーカス。
  配色は東洋文庫デザインシステム (臙脂 #76161b / クリーム / BIZ UD・EB Garamond) に準拠。

  パフォーマンス: 全文が単一 <p> に数千ノード並ぶため、素朴な // 検索や
  preceding/following-sibling フィルタは O(n^2) でブラウザがハングする。
  lb 参照・ページ所属・行内容はすべて xsl:key で索引化して O(1) にしている。
  XSLT 1.0。
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="tei">

  <xsl:output method="html" encoding="UTF-8" indent="yes"
      doctype-system="about:legacy-compat"/>

  <!-- xml:id は名前空間プレフィックスの有無に依存しないよう local-name() で照合 -->
  <xsl:key name="surface-by-id" match="tei:surface" use="@*[local-name() = 'id']"/>
  <!-- zone ラベル用: lb を @corresp で引く (zone ごとの //tei:lb 走査=O(n^2) を回避) -->
  <xsl:key name="lb-by-corresp" match="tei:lb" use="@corresp"/>
  <!-- 行をページ (直前の pb) で索引化 -->
  <xsl:key name="lb-by-page" match="tei:lb" use="generate-id(preceding-sibling::tei:pb[1])"/>
  <!-- 行内容 (テキスト/NE) を「直前の lb」で索引化 -->
  <xsl:key name="line-content"
      match="tei:p/text() | tei:p/tei:persName | tei:p/tei:placeName
             | tei:p/tei:orgName | tei:p/tei:date"
      use="generate-id(preceding-sibling::tei:lb[1])"/>
  <!-- 固有表現の重複除去 (Muenchian): 種別|正規化テキスト。
       本文 (tei:body) 限定 — teiHeader の <date> 等を一覧に混ぜないため。 -->
  <xsl:key name="ne-key"
      match="tei:body//tei:persName | tei:body//tei:placeName
             | tei:body//tei:orgName | tei:body//tei:date"
      use="concat(local-name(), '|', normalize-space(.))"/>

  <xsl:variable name="title" select="normalize-space(//tei:titleStmt/tei:title)"/>

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="$title"/></title>
        <link rel="preconnect" href="https://fonts.googleapis.com"/>
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="crossorigin"/>
        <link rel="stylesheet"
            href="https://fonts.googleapis.com/css2?family=BIZ+UDPGothic:wght@400;700&amp;family=EB+Garamond:ital,wght@0,400;0,500;1,400&amp;display=swap"/>
        <!-- 東洋文庫デザインシステム トークン。正本は css/theme.css。
             <link> なので head パース時に解決され、本文・共有ヘッダー
             (js/shared/tei-header.js) ともこのトークンを参照する (FOUC なし)。 -->
        <link rel="stylesheet" href="css/theme.css"/>
        <style>
          * { box-sizing: border-box; }
          html, body { height: 100%; }
          body { font-family: var(--font-sans); margin: 0; color: var(--ink);
                 background: var(--surface); line-height: 1.6; }

          /* ===== 全画面: 現在ページを画面いっぱい (左=翻刻スクロール / 右=IIIF画像) =====
             高さ = ビューポート − 上部バー − ページャーバー (どちらも sticky で in-flow)。
             ページャーが .tei-page に inline display:block を付けるため flex は使わず固定高。 */
          .tei-page { padding: 0;
                      height: calc(100vh - var(--tei-bar-h, 52px) - var(--tei-pager-h, 46px)); }
          .page-grid { height: 100%; display: flex; gap: 0; align-items: stretch; }
          /* 左にテキスト、右に画像（order でモバイル縦積み時もテキストが上に来る）。 */
          .facsimile-col { flex: 1 1 50%; min-width: 0; min-height: 0; order: 1;
                           display: flex; flex-direction: column;
                           border-left: 1px solid var(--line); }
          .facsimile-col .facsimile { flex: 1 1 auto; width: 100%; min-height: 0;
                                      border: 0; background: #1c1916; }

          /* ===== 翻刻行 ===== */
          .lines { flex: 1 1 50%; min-width: 0; min-height: 0; order: 0; margin: 0;
                   padding: .7rem clamp(1rem,3vw,2rem); overflow-y: auto;
                   list-style: none; background: var(--surface); }
          .lines li { display: flex; gap: .85rem; padding: .3rem .4rem;
                      border-bottom: 1px solid var(--line); cursor: pointer;
                      scroll-margin-top: calc(var(--tei-bar-h, 52px) + 8px); }
          .lines li:hover { background: var(--surface-sunken); }
          .lines li:target { background: var(--enji-50); }
          /* osd-facsimile.js が付ける相互ハイライト / フォーカス (zone と行) */
          .lines li.osd-target-hl { background: var(--enji-50); }
          .lines li.osd-target-active { background: var(--enji-100);
                      box-shadow: inset 3px 0 0 var(--enji-700); }
          .lineno { flex: 0 0 2.2rem; text-align: right; color: var(--ink-subtle);
                    font-size: .8rem; padding-top: .15rem;
                    font-variant-numeric: tabular-nums; }
          .linetext { font-family: var(--font-text); font-size: 1.08rem;
                      white-space: normal; word-break: break-word; }
          .empty { color: var(--ink-subtle); font-style: italic; }

          /* ===== 固有表現の色分け (本文インライン) ===== */
          .ne { border-radius: 2px; padding: 0 .08em; }
          .ne-pers  { color: var(--ne-pers);  background: rgba(30,60,105,.10);
                      box-shadow: inset 0 -2px 0 rgba(30,60,105,.45); }
          .ne-place { color: var(--ne-place); background: rgba(27,107,99,.10);
                      box-shadow: inset 0 -2px 0 rgba(27,107,99,.45); }
          .ne-org   { color: var(--ne-org);   background: rgba(87,59,33,.12);
                      box-shadow: inset 0 -2px 0 rgba(87,59,33,.45); }
          .ne-date  { color: var(--ne-date);  background: rgba(130,120,38,.14);
                      box-shadow: inset 0 -2px 0 rgba(130,120,38,.45); }

          /* ===== 固有表現一覧パネル (tei-header.js のモーダルに移設される) ===== */
          .ne-legend { margin: 0 0 .8rem; font-size: .82rem; color: var(--ink-muted); }
          .ne-group-h { margin: 1rem 0 .4rem; font-size: .9rem; color: var(--ink);
                        display: flex; align-items: center; gap: .45rem; }
          .ne-chip { display: inline-block; width: .8em; height: .8em;
                     border-radius: 2px; }
          .ne-chip-pers  { background: var(--ne-pers); }
          .ne-chip-place { background: var(--ne-place); }
          .ne-chip-org   { background: var(--ne-org); }
          .ne-chip-date  { background: var(--ne-date); }
          .ne-list { margin: 0; padding: 0; list-style: none;
                     columns: 2; column-gap: 1.4rem; font-size: .9rem; }
          .ne-list li { break-inside: avoid; padding: .12rem 0; }
          .ne-count { color: var(--ink-subtle); font-size: .85em; }
          /* 一覧の各固有表現はジャンプボタン (本文 span の色を継承) */
          .ne-jump { font: inherit; border: 0; appearance: none;
                     -webkit-appearance: none; cursor: pointer; }
          .ne-jump:hover { text-decoration: underline; }
          .ne-jump:focus-visible { outline: 2px solid var(--enji-700); outline-offset: 1px; }
          /* ジャンプ先の出現を一瞬強調 (tei-ne-jump.js が .ne-flash を付与) */
          .ne-flash { animation: ne-flash-kf 1.6s ease-out; }
          @keyframes ne-flash-kf {
            0%, 22% { background: var(--enji-300);
                      box-shadow: 0 0 0 3px var(--enji-100); }
            100% { }
          }

          /* IIIF info.json リンク: 画像パネル下端の細いキャプション */
          .facsimile-src { flex: 0 0 auto; margin: 0; padding: .3rem .6rem;
                           font-size: .7rem; color: #b9b2a6; background: #1c1916;
                           word-break: break-all; }
          .facsimile-src a { color: #cdbf9a; }

          @media (max-width: 720px) {
            .tei-page { height: auto; }
            .page-grid { flex-direction: column; height: auto; }
            .facsimile-col { width: 100%; height: 70vh; border-left: 0;
                             border-top: 1px solid var(--line); }
            .lines { height: auto; overflow-y: visible; }
            .ne-list { columns: 1; }
          }
        </style>
      </head>
      <body>
        <!-- ページャー: tei-pager.js が 1 ページずつ全画面表示する -->
        <div class="tei-pager">
          <xsl:apply-templates select="//tei:body//tei:pb"/>
        </div>

        <!-- ===== teiHeader データ（共有ヘッダー: js/shared/tei-header.js） ===== -->
        <div class="tei-header" hidden="hidden" data-title="{$title}">
          <button type="button" class="tei-extra" data-zone-toggle="">ゾーン表示</button>

          <section class="tei-panel" data-label="書誌情報 / Metadata">
            <dl class="kv">
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'タイトル / Title'"/>
                <xsl:with-param name="value" select="//tei:titleStmt/tei:title"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'著者 / Author'"/>
                <xsl:with-param name="value" select="//tei:titleStmt/tei:author | //tei:sourceDesc/tei:bibl/tei:author"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'出版 / Publisher'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:publisher"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'日付 / Date'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:date"/>
              </xsl:call-template>
              <xsl:if test="//tei:publicationStmt/tei:date/@when">
                <dt>日付 (when)</dt>
                <dd><xsl:value-of select="//tei:publicationStmt/tei:date/@when"/></dd>
              </xsl:if>
              <dt>ページ数 / Pages</dt>
              <dd><xsl:value-of select="count(//tei:body//tei:pb)"/></dd>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'原資料 / Source'"/>
                <xsl:with-param name="value" select="//tei:sourceDesc/tei:p | //tei:sourceDesc/tei:bibl"/>
              </xsl:call-template>
            </dl>
            <xsl:for-each select="//tei:titleStmt/tei:respStmt">
              <h3><xsl:value-of select="normalize-space(tei:resp)"/></h3>
              <p>
                <xsl:for-each select="tei:name">
                  <xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
                  <xsl:value-of select="normalize-space(.)"/>
                </xsl:for-each>
              </p>
            </xsl:for-each>
          </section>

          <!-- ===== 固有表現一覧 (種別ごとに重複除去・出現数つき) ===== -->
          <xsl:if test="//tei:body//tei:persName | //tei:body//tei:placeName | //tei:body//tei:orgName | //tei:body//tei:date">
            <section class="tei-panel" data-label="固有表現 / Named entities">
              <p class="ne-legend">本文中では種別ごとに色分けして表示しています。/ Colour-coded inline in the transcription.</p>
              <xsl:call-template name="ne-group">
                <xsl:with-param name="all" select="//tei:body//tei:persName"/>
                <xsl:with-param name="type" select="'persName'"/>
                <xsl:with-param name="label" select="'人名 / Persons'"/>
                <xsl:with-param name="chip" select="'ne-chip-pers'"/>
                <xsl:with-param name="cls" select="'ne-pers'"/>
              </xsl:call-template>
              <xsl:call-template name="ne-group">
                <xsl:with-param name="all" select="//tei:body//tei:placeName"/>
                <xsl:with-param name="type" select="'placeName'"/>
                <xsl:with-param name="label" select="'地名 / Places'"/>
                <xsl:with-param name="chip" select="'ne-chip-place'"/>
                <xsl:with-param name="cls" select="'ne-place'"/>
              </xsl:call-template>
              <xsl:call-template name="ne-group">
                <xsl:with-param name="all" select="//tei:body//tei:orgName"/>
                <xsl:with-param name="type" select="'orgName'"/>
                <xsl:with-param name="label" select="'団体名 / Organizations'"/>
                <xsl:with-param name="chip" select="'ne-chip-org'"/>
                <xsl:with-param name="cls" select="'ne-org'"/>
              </xsl:call-template>
              <xsl:call-template name="ne-group">
                <xsl:with-param name="all" select="//tei:body//tei:date"/>
                <xsl:with-param name="type" select="'date'"/>
                <xsl:with-param name="label" select="'日付 / Dates'"/>
                <xsl:with-param name="chip" select="'ne-chip-date'"/>
                <xsl:with-param name="cls" select="'ne-date'"/>
              </xsl:call-template>
            </section>
          </xsl:if>
        </div>

        <script src="js/shared/tei-header.js"></script>
        <script src="js/shared/tei-pager.js"></script>
        <script src="js/shared/osd-facsimile.js"></script>
        <script src="js/shared/osd-zone-link.js"></script>
        <script src="js/shared/osd-zone-toggle.js"></script>
        <script src="js/shared/tei-ne-jump.js"></script>
      </body>
    </html>
  </xsl:template>

  <!-- ===== one page per <pb> ===== -->
  <xsl:template match="tei:pb">
    <xsl:variable name="surface"
        select="key('surface-by-id', substring-after(@facs, '#'))"/>
    <!-- このページに属する lb (O(1)) -->
    <xsl:variable name="lines" select="key('lb-by-page', generate-id(.))"/>
    <section class="tei-page" data-page-label="ページ {@n}">
      <div class="page-grid">
        <div class="facsimile-col">
          <xsl:choose>
            <xsl:when test="$surface/tei:graphic[@url or @sameAs]">
              <!-- osd-facsimile.js mounts OpenSeadragon here.
                   data-iiif は @sameAs (IIIF info.json) を優先し、無ければ @url。
                   osd-facsimile.js は /info.json を IIIF タイルソースとして読むので、
                   sameAs があれば単純画像でなく本来の IIIF タイル表示になる。 -->
              <xsl:variable name="iiif-src">
                <xsl:choose>
                  <xsl:when test="$surface/tei:graphic/@sameAs">
                    <xsl:value-of select="$surface/tei:graphic/@sameAs"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$surface/tei:graphic/@url"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <div class="facsimile" data-iiif="{$iiif-src}">
                <script type="application/json" class="facsimile-zones">
                  <xsl:text>[</xsl:text>
                  <xsl:for-each select="$surface/tei:zone">
                    <xsl:if test="position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
                    <xsl:variable name="zid" select="@*[local-name()='id']"/>
                    <!-- O(1): @corresp 索引で対応 lb を引く -->
                    <xsl:variable name="lb"
                        select="key('lb-by-corresp', concat('#', $zid))"/>
                    <xsl:text>{"x":</xsl:text><xsl:value-of select="number(@ulx)"/>
                    <xsl:text>,"y":</xsl:text><xsl:value-of select="number(@uly)"/>
                    <xsl:text>,"w":</xsl:text>
                    <xsl:value-of select="number(@lrx) - number(@ulx)"/>
                    <xsl:text>,"h":</xsl:text>
                    <xsl:value-of select="number(@lry) - number(@uly)"/>
                    <xsl:text>,"type":"line","label":"</xsl:text>
                    <xsl:choose>
                      <xsl:when test="$lb/@n"><xsl:value-of select="$lb/@n"/></xsl:when>
                      <xsl:otherwise><xsl:value-of select="position()"/></xsl:otherwise>
                    </xsl:choose>
                    <xsl:text>","target":"line-</xsl:text>
                    <xsl:value-of select="$zid"/><xsl:text>"}</xsl:text>
                  </xsl:for-each>
                  <xsl:text>]</xsl:text>
                </script>
              </div>
              <!-- sameAs (IIIF info.json) があればソースへのリンクも明示 -->
              <xsl:if test="$surface/tei:graphic/@sameAs">
                <p class="facsimile-src">
                  <xsl:text>IIIF: </xsl:text>
                  <a href="{$surface/tei:graphic/@sameAs}" target="_blank" rel="noopener">
                    <xsl:value-of select="$surface/tei:graphic/@sameAs"/>
                  </a>
                </p>
              </xsl:if>
            </xsl:when>
            <xsl:otherwise>
              <p class="empty">（画像なし / no image）</p>
            </xsl:otherwise>
          </xsl:choose>
        </div>
        <ol class="lines">
          <xsl:for-each select="$lines">
            <!-- 行内容 = この lb を直前 lb とするノード群 (テキスト＋NE要素), O(1)。
                 旧実装の following-sibling::text()[1] は NE 始まり行を空判定する empty バグ。 -->
            <xsl:variable name="content" select="key('line-content', generate-id(.))"/>
            <xsl:variable name="rendered">
              <xsl:apply-templates select="$content" mode="line"/>
            </xsl:variable>
            <li id="line-{substring-after(@corresp, '#')}">
              <span class="lineno"><xsl:value-of select="@n"/></span>
              <xsl:choose>
                <xsl:when test="normalize-space($rendered) != ''">
                  <span class="linetext"><xsl:copy-of select="$rendered"/></span>
                </xsl:when>
                <xsl:otherwise>
                  <span class="linetext empty">(空行 / empty)</span>
                </xsl:otherwise>
              </xsl:choose>
            </li>
          </xsl:for-each>
        </ol>
      </div>
    </section>
  </xsl:template>

  <!-- ===== 行内容のレンダリング (mode=line): テキストはそのまま、NE は色付き span ===== -->
  <xsl:template match="text()" mode="line"><xsl:value-of select="."/></xsl:template>
  <!-- id=generate-id() で各出現を一意化し、固有表現一覧からジャンプできるようにする
       (一覧側 data-ne-targets と同じ generate-id() なので一致する)。 -->
  <xsl:template match="tei:persName" mode="line">
    <span class="ne ne-pers" id="{generate-id()}" title="人名 / Person"><xsl:apply-templates mode="line"/></span>
  </xsl:template>
  <xsl:template match="tei:placeName" mode="line">
    <span class="ne ne-place" id="{generate-id()}" title="地名 / Place"><xsl:apply-templates mode="line"/></span>
  </xsl:template>
  <xsl:template match="tei:orgName" mode="line">
    <span class="ne ne-org" id="{generate-id()}" title="団体名 / Organization"><xsl:apply-templates mode="line"/></span>
  </xsl:template>
  <xsl:template match="tei:date" mode="line">
    <span class="ne ne-date" id="{generate-id()}" title="日付 / Date"><xsl:apply-templates mode="line"/></span>
  </xsl:template>
  <xsl:template match="*" mode="line"><xsl:apply-templates mode="line"/></xsl:template>

  <!-- ===== Helper: 固有表現の種別グループ (Muenchian で重複除去・出現数つき) ===== -->
  <xsl:template name="ne-group">
    <xsl:param name="all"/>
    <xsl:param name="type"/>
    <xsl:param name="label"/>
    <xsl:param name="chip"/>
    <xsl:param name="cls"/>
    <xsl:if test="$all">
      <h3 class="ne-group-h">
        <span class="ne-chip {$chip}"></span>
        <xsl:value-of select="$label"/>
        <xsl:text> (</xsl:text><xsl:value-of select="count($all)"/><xsl:text>)</xsl:text>
      </h3>
      <ul class="ne-list">
        <xsl:for-each select="$all[generate-id()
            = generate-id(key('ne-key', concat($type, '|', normalize-space(.)))[1])]">
          <xsl:sort select="normalize-space(.)"/>
          <xsl:variable name="occ"
              select="key('ne-key', concat($type, '|', normalize-space(.)))"/>
          <li>
            <!-- data-ne-targets = 全出現の id (本文 span の generate-id と一致)。
                 tei-ne-jump.js がクリックで該当ページへジャンプ＋行ハイライト、
                 同じ項目の再クリックで次の出現へ循環する。 -->
            <button type="button" class="ne-jump ne {$cls}"
                title="本文の該当箇所へ / jump to text (再クリックで次へ)">
              <xsl:attribute name="data-ne-targets">
                <xsl:for-each select="$occ">
                  <xsl:if test="position() &gt; 1">,</xsl:if>
                  <xsl:value-of select="generate-id()"/>
                </xsl:for-each>
              </xsl:attribute>
              <xsl:value-of select="normalize-space(.)"/>
            </button>
            <xsl:if test="count($occ) &gt; 1">
              <span class="ne-count"> ×<xsl:value-of select="count($occ)"/></span>
            </xsl:if>
          </li>
        </xsl:for-each>
      </ul>
    </xsl:if>
  </xsl:template>

  <!-- ===== Helper: one key/value row, skipped when empty ===== -->
  <xsl:template name="kv">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <xsl:if test="normalize-space($value) != ''">
      <dt><xsl:value-of select="$label"/></dt>
      <dd><xsl:value-of select="normalize-space($value)"/></dd>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
