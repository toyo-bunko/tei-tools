<?xml version="1.0" encoding="UTF-8"?>
<!--
  tei-ner.xsl — Named-entity overview / 固有表現の一覧・可視化

  Id:          ner
  Input:       file
  Sample (file): xml/morrison-ner/tei.xml
  Title:       Named-entity overview / 固有表現の一覧・可視化
  Description: 本文中にインライン付与された固有表現 (persName / placeName / orgName / date) を集計し、種別ごとの件数・頻出表現の棒グラフ（HTML/CSS のみ）と、異なり一覧テーブルで可視化します。LLM 等で NE タグを付けた TEI の俯瞰に。/ Aggregates inline named entities (persName / placeName / orgName / date) and visualizes them with per-type and top-frequency bar charts (pure HTML/CSS) plus a distinct-entity table. For surveying TEI marked up with NE tags (e.g. by an LLM).
  Category:    分析 / Analysis
  License:     自由に利用・改変できます（XSLT 1.0）。/ Free to use and adapt (XSLT 1.0).

  集計対象は本文 (tei:text) 内の persName / placeName / orgName / date 要素。
  異なり (distinct) は「種別 + 正規化テキスト」で Muenchian grouping。
  グラフは外部ライブラリを使わず HTML/CSS のみ。共有ヘッダー
  (js/shared/tei-header.js) に teiHeader 情報を渡す。本文そのものは
  描画しない（俯瞰・集計に特化したビュー）。
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="tei">

  <xsl:output method="html" encoding="UTF-8" indent="yes"
      doctype-system="about:legacy-compat"/>

  <xsl:key name="ent"    match="tei:persName|tei:placeName|tei:orgName|tei:date" use="local-name()"/>
  <xsl:key name="entKey" match="tei:persName|tei:placeName|tei:orgName|tei:date"
           use="concat(local-name(), '#', normalize-space(.))"/>

  <xsl:variable name="title" select="normalize-space(//tei:titleStmt/tei:title)"/>

  <!-- 本文中の全 NE 要素 -->
  <xsl:variable name="ents"
      select="//tei:text//tei:persName | //tei:text//tei:placeName
              | //tei:text//tei:orgName | //tei:text//tei:date"/>
  <!-- 異なり (種別+正規化テキストごとに最初の1件) -->
  <xsl:variable name="distinct"
      select="$ents[generate-id() =
              generate-id(key('entKey', concat(local-name(), '#', normalize-space(.)))[1])]"/>

  <!-- 頻出バーのスケール用：最頻の件数 -->
  <xsl:variable name="freqMax">
    <xsl:for-each select="$distinct">
      <xsl:sort select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"
                data-type="number" order="descending"/>
      <xsl:if test="position() = 1">
        <xsl:value-of select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <html>
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>固有表現 — <xsl:value-of select="$title"/></title>
        <!-- 東洋文庫デザインシステム トークン (正本 css/theme.css) -->
        <link rel="stylesheet" href="css/theme.css"/>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                 line-height: 1.7; color: #1a1a1a; background: #fff; margin: 0; }
          .doc { padding: 2rem clamp(1rem, 5vw, 4rem); }
          h1 { font-size: 1.5rem; margin: 0 0 .3rem; }
          h2 { font-size: 1.1rem; margin: 2.2rem 0 .9rem;
               border-bottom: 2px solid #e3e3e3; padding-bottom: .3rem; }
          .doc-sub { color: #666; font-size: .9rem; margin: 0 0 1.5rem; }

          .cards { display: grid; gap: .8rem; margin: 1.2rem 0 .5rem;
                   grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); }
          .card { background: #f7f8fa; border: 1px solid #e3e3e3; border-radius: 8px;
                  padding: .9rem 1rem; }
          .card-num { font-size: 1.7rem; font-weight: 700; color: #2563eb;
                      font-variant-numeric: tabular-nums; line-height: 1.2; }
          .card-label { font-size: .78rem; color: #666; margin-top: .15rem; }

          /* 棒グラフ */
          .chart { margin: .5rem 0 1rem; }
          .bar-row { display: grid; grid-template-columns: 14rem 1fr 4.5rem;
                     align-items: center; gap: .6rem; padding: .15rem 0; }
          .bar-label { font-size: .85rem; color: #1a1a1a; text-align: right;
                       overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
          .bar-track { background: #eef0f3; border-radius: 4px; height: 1.15rem; }
          .bar-fill { display: block; height: 100%; min-width: 2px; border-radius: 4px; }
          .bar-val { font-size: .85rem; color: #444; text-align: right;
                     font-variant-numeric: tabular-nums; }
          .bar-pct { color: #999; font-size: .72rem; }

          /* 種別カラー */
          .t-persName { background: linear-gradient(90deg,#60a5fa,#2563eb); }
          .t-placeName{ background: linear-gradient(90deg,#34d399,#059669); }
          .t-orgName  { background: linear-gradient(90deg,#fbbf24,#d97706); }
          .t-date     { background: linear-gradient(90deg,#c084fc,#7c3aed); }

          /* バッジ */
          .badge { display:inline-block; font-size:.7rem; font-weight:600; color:#fff;
                   padding:.05rem .45rem; border-radius:999px; vertical-align:middle; }
          .b-persName { background:#2563eb; } .b-placeName{ background:#059669; }
          .b-orgName  { background:#d97706; } .b-date     { background:#7c3aed; }

          /* テーブル */
          table.ents { border-collapse: collapse; width: 100%; font-size: .9rem; margin:.5rem 0 1rem; }
          table.ents th, table.ents td { border-bottom: 1px solid #eee; padding: .35rem .6rem; text-align: left; }
          table.ents th { background:#f7f8fa; position: sticky; top: 0; font-size:.8rem; color:#444; }
          table.ents td.num { text-align: right; font-variant-numeric: tabular-nums; width: 4rem; }
          .empty { color: #bbb; }
          @media (max-width: 560px) { .bar-row { grid-template-columns: 8rem 1fr 3.4rem; } }
        </style>
      </head>
      <body>
        <main class="doc">
          <h1>固有表現の一覧・可視化 / Named-entity overview</h1>
          <p class="doc-sub"><xsl:value-of select="$title"/></p>

          <xsl:choose>
            <xsl:when test="count($ents) = 0">
              <p class="empty">固有表現タグ (persName/placeName/orgName/date) が見つかりません。 / No named-entity tags found.</p>
            </xsl:when>
            <xsl:otherwise>
              <!-- 要約カード -->
              <div class="cards">
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($ents)"/>
                  <xsl:with-param name="label" select="'総出現数 / Mentions'"/>
                </xsl:call-template>
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($distinct)"/>
                  <xsl:with-param name="label" select="'異なり数 / Distinct'"/>
                </xsl:call-template>
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($ents[local-name()='persName'])"/>
                  <xsl:with-param name="label" select="'人名 / persName'"/>
                </xsl:call-template>
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($ents[local-name()='placeName'])"/>
                  <xsl:with-param name="label" select="'地名 / placeName'"/>
                </xsl:call-template>
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($ents[local-name()='orgName'])"/>
                  <xsl:with-param name="label" select="'組織 / orgName'"/>
                </xsl:call-template>
                <xsl:call-template name="card">
                  <xsl:with-param name="num" select="count($ents[local-name()='date'])"/>
                  <xsl:with-param name="label" select="'日付 / date'"/>
                </xsl:call-template>
              </div>

              <!-- 種別ごとの件数 -->
              <h2>種別ごとの出現数 / Mentions by type</h2>
              <div class="chart">
                <xsl:call-template name="typebar">
                  <xsl:with-param name="type" select="'persName'"/>
                </xsl:call-template>
                <xsl:call-template name="typebar">
                  <xsl:with-param name="type" select="'placeName'"/>
                </xsl:call-template>
                <xsl:call-template name="typebar">
                  <xsl:with-param name="type" select="'orgName'"/>
                </xsl:call-template>
                <xsl:call-template name="typebar">
                  <xsl:with-param name="type" select="'date'"/>
                </xsl:call-template>
              </div>

              <!-- 頻出固有表現 Top 30 -->
              <h2>頻出固有表現 Top 30 / Most frequent entities</h2>
              <div class="chart">
                <xsl:for-each select="$distinct">
                  <xsl:sort select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"
                            data-type="number" order="descending"/>
                  <xsl:sort select="normalize-space(.)"/>
                  <xsl:if test="position() &lt;= 30">
                    <xsl:variable name="c"
                        select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"/>
                    <div class="bar-row">
                      <span class="bar-label" title="{normalize-space(.)}">
                        <xsl:value-of select="normalize-space(.)"/>
                      </span>
                      <span class="bar-track">
                        <span class="bar-fill t-{local-name()}"
                              style="width:{format-number($c div $freqMax * 100, '0.#')}%"></span>
                      </span>
                      <span class="bar-val"><xsl:value-of select="$c"/></span>
                    </div>
                  </xsl:if>
                </xsl:for-each>
              </div>

              <!-- 異なり一覧 (種別→件数 降順) -->
              <h2>異なり一覧 / Distinct entities (<xsl:value-of select="count($distinct)"/>)</h2>
              <table class="ents">
                <tr><th>種別 / Type</th><th>表記 / Surface</th><th class="num">件数 / n</th></tr>
                <xsl:for-each select="$distinct">
                  <xsl:sort select="local-name()"/>
                  <xsl:sort select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"
                            data-type="number" order="descending"/>
                  <xsl:sort select="normalize-space(.)"/>
                  <tr>
                    <td><span class="badge b-{local-name()}"><xsl:value-of select="local-name()"/></span></td>
                    <td><xsl:value-of select="normalize-space(.)"/></td>
                    <td class="num">
                      <xsl:value-of select="count(key('entKey', concat(local-name(), '#', normalize-space(.))))"/>
                    </td>
                  </tr>
                </xsl:for-each>
              </table>
            </xsl:otherwise>
          </xsl:choose>
        </main>

        <!-- teiHeader データ（共有ヘッダー: js/shared/tei-header.js が上部バーを生成） -->
        <div class="tei-header" hidden="hidden" data-title="{$title}">
          <section class="tei-panel" data-label="書誌情報 / Metadata">
            <dl class="kv">
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'タイトル / Title'"/>
                <xsl:with-param name="value" select="//tei:titleStmt/tei:title"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'出版 / Publisher'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:publisher"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'出版年 / Date'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:date"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'言語 / Language'"/>
                <xsl:with-param name="value" select="//tei:langUsage/tei:language"/>
              </xsl:call-template>
            </dl>
          </section>
        </div>
        <script src="js/shared/tei-header.js"></script>
      </body>
    </html>
  </xsl:template>

  <!-- 要約カード -->
  <xsl:template name="card">
    <xsl:param name="num"/>
    <xsl:param name="label"/>
    <div class="card">
      <div class="card-num"><xsl:value-of select="$num"/></div>
      <div class="card-label"><xsl:value-of select="$label"/></div>
    </div>
  </xsl:template>

  <!-- 種別バー (全体に対する割合付き) -->
  <xsl:template name="typebar">
    <xsl:param name="type"/>
    <xsl:variable name="c" select="count($ents[local-name()=$type])"/>
    <div class="bar-row">
      <span class="bar-label" title="{$type}"><xsl:value-of select="$type"/></span>
      <span class="bar-track">
        <span class="bar-fill t-{$type}"
              style="width:{format-number($c div count($ents) * 100, '0.#')}%"></span>
      </span>
      <span class="bar-val">
        <xsl:value-of select="$c"/>
        <xsl:text> </xsl:text>
        <span class="bar-pct"><xsl:value-of select="format-number($c div count($ents), '0.0%')"/></span>
      </span>
    </div>
  </xsl:template>

  <!-- teiHeader パネル用 -->
  <xsl:template name="kv">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <xsl:if test="$value[normalize-space(.) != '']">
      <dt><xsl:value-of select="$label"/></dt>
      <dd>
        <xsl:for-each select="$value">
          <xsl:if test="position() &gt; 1"><xsl:text>; </xsl:text></xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
      </dd>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
