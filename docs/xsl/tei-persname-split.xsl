<?xml version="1.0" encoding="UTF-8"?>
<!--
  tei-persname-split.xsl — Line-spanning entity view / 行をまたぐエンティティのビュー

  Id:          persname-split
  Input:       file
  Sample (file): xml/persname-split/tei.xml
  Title:       Line-spanning entity view / 行をまたぐエンティティのビュー
  Description: 1 ab = 1 行 = 1 zone の構成で、行を跨いで分割された persName / placeName (@next/@prev) を断片ごとに描き、@corresp で同一エンティティ単位に再統合した出現一覧を併記する集計ビュー。/ Visualises <ab> blocks bound one-to-one with zones, plus persName / placeName fragments split across lines with @next / @prev, and aggregates them per canonical entity via @corresp.
  Category:    汎用 / General-purpose
  License:     自由に利用・改変できます（XSLT 1.0）。/ Free to use and adapt (XSLT 1.0).

  断片を「鎖の頭（@prev を持たない断片）」だけ数えることで重複なく出現回数を集計する。
  鎖の本文・行範囲は @next を辿って再構築する。XSLT 1.0。
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="tei">

  <xsl:output method="html" encoding="UTF-8" indent="yes"
      doctype-system="about:legacy-compat"/>

  <!-- xml:id を名前空間プレフィックスの有無に依存せず引く -->
  <xsl:key name="by-id"
      match="tei:persName | tei:placeName"
      use="@*[local-name() = 'id']"/>

  <xsl:variable name="title" select="normalize-space(//tei:titleStmt/tei:title)"/>

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="$title"/></title>
        <style>
          * { box-sizing: border-box; }
          body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                 margin: 0; color: #1a1a1a; background: #fafafa; line-height: 1.6; }
          main { max-width: 980px; margin: 0 auto;
                 padding: 1.2rem clamp(1rem,4vw,2.5rem) 2rem; }
          h1 { font-size: 1.05rem; color: #333; margin: 0 0 .4rem;
               letter-spacing: .03em; }
          h2 { font-size: .8rem; color: #555; margin: 1.8rem 0 .6rem;
               letter-spacing: .08em; text-transform: uppercase; }
          h3.section-h { font-size: .85rem; color: #444; margin: .9rem 0 .35rem;
                         font-weight: 600; display: flex; align-items: baseline;
                         gap: .5rem; }
          .section-lang, .section-type { font-size: .7rem; color: #aaa;
                          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                          text-transform: uppercase; letter-spacing: .05em;
                          padding: 0 .35em; border: 1px solid #ddd;
                          border-radius: 3px; }
          .section-type { color: #1f6feb; border-color: #c9deff; }
          .intro { color: #555; font-size: .87rem; margin: 0 0 1.2rem; }
          .intro code { background: #eee; padding: 0 .3em; border-radius: 3px;
                        font-size: .9em; }

          /* ===== Layout pane: one row per ab block ===== */
          ol.lines { list-style: none; margin: 0; padding: 0;
                     border: 1px solid #e3e3e3; background: #fff;
                     border-radius: 6px; }
          ol.lines li { display: flex; gap: .9rem; padding: .4rem .7rem;
                        border-bottom: 1px dotted #eaeaea; font-size: .95rem; }
          ol.lines li:last-child { border-bottom: 0; }
          .lineno { flex: 0 0 1.5rem; text-align: right; color: #bbb;
                    font-variant-numeric: tabular-nums; }
          .zoneref { flex: 0 0 3.2rem; color: #c7c7c7; font-size: .8rem;
                     font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
          .linetext { flex: 1 1 auto; word-break: break-word; }

          /* Entity fragments highlighted by type and chain role */
          .ent { padding: 0 .2rem; border-radius: 3px; }
          .ent.persName  { background: #fff2c7; }
          .ent.placeName { background: #d8efff; }
          .ent[data-part="head"]   { border-top-right-radius: 0;
                                     border-bottom-right-radius: 0;
                                     padding-right: .35rem; }
          .ent[data-part="head"]::after { content: " ⇢"; color: #b08400; }
          .ent.placeName[data-part="head"]::after { color: #1f6feb; }
          .ent[data-part="tail"]   { border-top-left-radius: 0;
                                     border-bottom-left-radius: 0;
                                     padding-left: .35rem; }
          .ent[data-part="tail"]::before { content: "⇢ "; color: #b08400; }
          .ent.placeName[data-part="tail"]::before { color: #1f6feb; }

          /* ===== Aggregation pane ===== */
          ul.entities { list-style: none; margin: 0; padding: 0;
                        display: grid; gap: .45rem; }
          ul.entities > li { background: #fff; border: 1px solid #e3e3e3;
                             border-radius: 6px; padding: .55rem .8rem;
                             font-size: .9rem; }
          ul.entities > li.persName  { border-left: 3px solid #f5c33b; }
          ul.entities > li.placeName { border-left: 3px solid #58a6ff; }
          .canon { font-weight: 600; }
          .canon-id { color: #aaa; font-weight: normal; font-size: .8em;
                      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                      margin-left: .3rem; }
          .count { color: #888; font-size: .82rem; margin-left: .4rem; }
          ul.mentions { list-style: none; margin: .35rem 0 0 0;
                        padding: 0 0 0 .9rem; display: grid; gap: .15rem; }
          ul.mentions li { color: #555; font-size: .87rem; }
          .surface { color: #333; }
          .surface::before { content: "“"; color: #999; }
          .surface::after  { content: "”"; color: #999; }
          .where { color: #999; margin-left: .35rem; font-size: .8rem; }
          .split-badge { background: #fff2c7; color: #875c00;
                         border-radius: 3px; padding: 0 .35em;
                         font-size: .72rem; margin-left: .35rem;
                         letter-spacing: .04em; }
          ul.entities > li.placeName .split-badge { background: #d8efff;
                                                    color: #0a55a3; }
          .ms-badge { background: #e8f7d4; color: #3a6d12;
                      border-radius: 3px; padding: 0 .35em;
                      font-size: .72rem; margin-left: .35rem;
                      letter-spacing: .04em; }

          /* prose (milestone) layout */
          .prose { background: #fff; border: 1px solid #e3e3e3;
                   border-radius: 6px; padding: .9rem 1.1rem; }
          .prose-p { margin: 0; line-height: 2; }
          .ms { color: #b8b8b8; font-size: .8em;
                font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
          .ms-pb { color: #999; background: #f0f0f0; padding: 0 .3em;
                   border-radius: 3px; margin: 0 .2em; }
          .ent[data-part="milestone-wrap"] { background: #e8f7d4; }
          .ent.placeName[data-part="milestone-wrap"] { background: #d4ecff; }

          .legend { display: flex; flex-wrap: wrap; gap: .8rem;
                    color: #777; font-size: .8rem; margin: .3rem 0 0; }
          .legend .ent { font-size: .8rem; padding: 0 .3rem; }
        </style>
      </head>
      <body>
        <main>
          <h1><xsl:value-of select="$title"/></h1>
          <p class="intro">
            <xsl:text>各行は </xsl:text><code>&lt;ab&gt;</code>
            <xsl:text> として 1 行 1 ゾーンに紐づき、行を跨ぐ人名・地名は </xsl:text>
            <code>@next</code><xsl:text> / </xsl:text><code>@prev</code>
            <xsl:text> で分割。下段の集計はそれを </xsl:text>
            <code>@corresp</code>
            <xsl:text> で正規エンティティ単位に再統合した結果です。 / </xsl:text>
            <xsl:text>Lines are 1-to-1 with zones (</xsl:text>
            <code>&lt;ab&gt;</code>
            <xsl:text>); persName / placeName spanning two lines are split with </xsl:text>
            <code>@next</code><xsl:text> / </xsl:text><code>@prev</code>
            <xsl:text>; the second list reconstructs each canonical entity via </xsl:text>
            <code>@corresp</code><xsl:text>.</xsl:text>
          </p>
          <p class="legend">
            <span><span class="ent persName">persName</span> 人名</span>
            <span><span class="ent placeName">placeName</span> 地名</span>
            <span><span class="ent persName" data-part="head">head</span> 鎖の先頭 (@next を持つ)</span>
            <span><span class="ent persName" data-part="tail">tail</span> 鎖の末尾 (@prev を持つ)</span>
            <span><span class="ent persName" data-part="milestone-wrap">milestone-wrap</span> &lt;lb/&gt;/&lt;pb/&gt; を内包 (分割不要)</span>
          </p>

          <h2>原本配置 / Source layout</h2>
          <xsl:choose>
            <xsl:when test="//tei:body/tei:div">
              <xsl:for-each select="//tei:body/tei:div">
                <h3 class="section-h">
                  <xsl:value-of select="normalize-space(tei:head)"/>
                  <xsl:if test="@xml:lang">
                    <span class="section-lang"><xsl:value-of select="@xml:lang"/></span>
                  </xsl:if>
                  <xsl:if test="@type">
                    <span class="section-type"><xsl:value-of select="@type"/></span>
                  </xsl:if>
                </h3>
                <xsl:choose>
                  <xsl:when test=".//tei:ab">
                    <ol class="lines">
                      <xsl:apply-templates select=".//tei:ab"/>
                    </ol>
                  </xsl:when>
                  <xsl:when test=".//tei:p">
                    <div class="prose">
                      <xsl:apply-templates select=".//tei:p" mode="prose"/>
                    </div>
                  </xsl:when>
                </xsl:choose>
              </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
              <ol class="lines">
                <xsl:apply-templates select="//tei:body//tei:ab"/>
              </ol>
            </xsl:otherwise>
          </xsl:choose>

          <h2>エンティティ集計 / Aggregated entities</h2>
          <ul class="entities">
            <xsl:apply-templates select="//tei:listPerson/tei:person" mode="entity"/>
            <xsl:apply-templates select="//tei:listPlace/tei:place" mode="entity"/>
          </ul>
        </main>

        <!-- ===== teiHeader データ（共有ヘッダー: js/shared/tei-header.js） ===== -->
        <div class="tei-header" hidden="hidden" data-title="{$title}">
          <section class="tei-panel" data-label="書誌情報 / Metadata">
            <dl class="kv">
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'主タイトル / Title'"/>
                <xsl:with-param name="value" select="//tei:titleStmt/tei:title[@type='main'] | //tei:titleStmt/tei:title[not(@type)][1]"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'副題 / Subtitle'"/>
                <xsl:with-param name="value" select="//tei:titleStmt/tei:title[@type='sub']"/>
              </xsl:call-template>
              <xsl:call-template name="kv-list">
                <xsl:with-param name="label" select="'著者 / Author'"/>
                <xsl:with-param name="nodes" select="//tei:titleStmt/tei:author"/>
              </xsl:call-template>
              <xsl:call-template name="kv-list">
                <xsl:with-param name="label" select="'編者 / Editor'"/>
                <xsl:with-param name="nodes" select="//tei:titleStmt/tei:editor"/>
              </xsl:call-template>
              <xsl:call-template name="kv-list">
                <xsl:with-param name="label" select="'助成 / Funder'"/>
                <xsl:with-param name="nodes" select="//tei:titleStmt/tei:funder"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'版 / Edition'"/>
                <xsl:with-param name="value" select="//tei:editionStmt/tei:edition"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'分量 / Extent'"/>
                <xsl:with-param name="value" select="//tei:fileDesc/tei:extent"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'出版 / Publisher'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:publisher"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'出版地 / Publication place'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:pubPlace"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'日付 / Date'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:date"/>
              </xsl:call-template>
              <xsl:if test="//tei:publicationStmt/tei:date/@when">
                <dt>日付 (when) / Date (when)</dt>
                <dd><xsl:value-of select="//tei:publicationStmt/tei:date/@when"/></dd>
              </xsl:if>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'識別子 / Identifier'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:idno"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'ライセンス / Licence'"/>
                <xsl:with-param name="value" select="//tei:publicationStmt/tei:availability/tei:licence"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'原資料 / Source'"/>
                <xsl:with-param name="value" select="//tei:sourceDesc/tei:p"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'プロジェクト / Project'"/>
                <xsl:with-param name="value" select="//tei:encodingDesc/tei:projectDesc/tei:p"/>
              </xsl:call-template>
              <xsl:call-template name="kv">
                <xsl:with-param name="label" select="'編集方針 / Editorial decl.'"/>
                <xsl:with-param name="value" select="//tei:encodingDesc/tei:editorialDecl/tei:p"/>
              </xsl:call-template>
              <xsl:call-template name="kv-pp">
                <xsl:with-param name="label" select="'要旨 / Abstract'"/>
                <xsl:with-param name="nodes" select="//tei:profileDesc/tei:abstract/tei:p"/>
              </xsl:call-template>
              <xsl:call-template name="kv-list">
                <xsl:with-param name="label" select="'言語 / Languages'"/>
                <xsl:with-param name="nodes" select="//tei:langUsage/tei:language"/>
              </xsl:call-template>
              <xsl:call-template name="kv-list">
                <xsl:with-param name="label" select="'分類 / Keywords'"/>
                <xsl:with-param name="nodes" select="//tei:textClass/tei:keywords/tei:term"/>
              </xsl:call-template>
              <dt>行数 / Lines</dt>
              <dd><xsl:value-of select="count(//tei:body//tei:ab)"/></dd>
              <dt>人名出現 / persName mentions</dt>
              <dd><xsl:value-of select="count(//tei:persName[not(ancestor::tei:teiHeader) and not(ancestor::tei:standOff) and not(@prev)])"/></dd>
              <dt>地名出現 / placeName mentions</dt>
              <dd><xsl:value-of select="count(//tei:placeName[not(ancestor::tei:teiHeader) and not(ancestor::tei:standOff) and not(@prev)])"/></dd>
            </dl>
            <xsl:if test="//tei:titleStmt/tei:respStmt">
              <h3>責任表示 / Responsibility</h3>
              <dl class="kv">
                <xsl:for-each select="//tei:titleStmt/tei:respStmt">
                  <dt><xsl:value-of select="normalize-space(tei:resp)"/></dt>
                  <dd>
                    <xsl:for-each select="tei:name | tei:persName | tei:orgName">
                      <xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
                      <xsl:value-of select="normalize-space(.)"/>
                    </xsl:for-each>
                  </dd>
                </xsl:for-each>
              </dl>
            </xsl:if>
            <xsl:if test="//tei:revisionDesc/tei:change">
              <h3>改訂履歴 / Revision history</h3>
              <ul>
                <xsl:for-each select="//tei:revisionDesc/tei:change">
                  <li>
                    <xsl:if test="@when">
                      <strong><xsl:value-of select="@when"/></strong>
                      <xsl:text> — </xsl:text>
                    </xsl:if>
                    <xsl:value-of select="normalize-space(.)"/>
                  </li>
                </xsl:for-each>
              </ul>
            </xsl:if>
          </section>
        </div>

        <script src="js/shared/tei-header.js"></script>
      </body>
    </html>
  </xsl:template>

  <!-- ===== Layout: render one <ab> as one row ===== -->
  <xsl:template match="tei:ab">
    <li>
      <span class="lineno"><xsl:value-of select="@n"/></span>
      <span class="zoneref">
        <xsl:if test="@facs"><xsl:value-of select="@facs"/></xsl:if>
      </span>
      <span class="linetext"><xsl:apply-templates/></span>
    </li>
  </xsl:template>

  <!-- highlight persName / placeName fragments; label chain role -->
  <xsl:template match="tei:persName | tei:placeName">
    <span>
      <xsl:attribute name="class">ent <xsl:value-of select="local-name()"/></xsl:attribute>
      <xsl:attribute name="data-part">
        <xsl:choose>
          <xsl:when test="@next and not(@prev)">head</xsl:when>
          <xsl:when test="@prev and not(@next)">tail</xsl:when>
          <xsl:when test="@prev and @next">middle</xsl:when>
          <xsl:otherwise>whole</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@corresp">
        <xsl:attribute name="title"><xsl:value-of select="@corresp"/></xsl:attribute>
      </xsl:if>
      <xsl:value-of select="."/>
    </span>
  </xsl:template>

  <!-- ===== Prose (milestone) mode: <p> with <lb/> and <pb/> milestones ===== -->
  <xsl:template match="tei:p" mode="prose">
    <p class="prose-p"><xsl:apply-templates mode="prose"/></p>
  </xsl:template>

  <xsl:template match="tei:lb" mode="prose">
    <span class="ms ms-lb" title="lb">⤶</span>
    <br/>
  </xsl:template>

  <xsl:template match="tei:pb" mode="prose">
    <span class="ms ms-pb" title="pb (page {@n})">⛚</span>
  </xsl:template>

  <!-- In prose mode, an entity may wrap <lb/> / <pb/> milestones; render
       descendants recursively so those breaks remain visible inside the
       highlight. -->
  <xsl:template match="tei:persName | tei:placeName" mode="prose">
    <span>
      <xsl:attribute name="class">ent <xsl:value-of select="local-name()"/></xsl:attribute>
      <xsl:attribute name="data-part">
        <xsl:choose>
          <xsl:when test="@next and not(@prev)">head</xsl:when>
          <xsl:when test="@prev and not(@next)">tail</xsl:when>
          <xsl:when test="@prev and @next">middle</xsl:when>
          <xsl:when test=".//tei:lb or .//tei:pb">milestone-wrap</xsl:when>
          <xsl:otherwise>whole</xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:if test="@corresp">
        <xsl:attribute name="title"><xsl:value-of select="@corresp"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates mode="prose"/>
    </span>
  </xsl:template>

  <xsl:template match="text()" mode="prose">
    <xsl:value-of select="."/>
  </xsl:template>

  <!-- ===== Aggregation: per-entity mentions ===== -->
  <xsl:template match="tei:person | tei:place" mode="entity">
    <xsl:variable name="pid" select="@*[local-name() = 'id']"/>
    <xsl:variable name="ref" select="concat('#', $pid)"/>
    <xsl:variable name="elem">
      <xsl:choose>
        <xsl:when test="self::tei:person">persName</xsl:when>
        <xsl:otherwise>placeName</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- 鎖の頭 = @prev を持たない断片。これだけ数えれば重複しない。 -->
    <xsl:variable name="heads"
        select="//tei:*[local-name() = $elem]
                       [@corresp = $ref and not(@prev)]"/>
    <li class="{$elem}">
      <span class="canon">
        <xsl:value-of select="normalize-space(*[local-name() = $elem])"/>
      </span>
      <span class="canon-id">#<xsl:value-of select="$pid"/></span>
      <span class="count">
        — <xsl:value-of select="count($heads)"/>
        <xsl:text> mention</xsl:text>
        <xsl:if test="count($heads) != 1">s</xsl:if>
      </span>
      <ul class="mentions">
        <xsl:for-each select="$heads">
          <li>
            <span class="surface">
              <xsl:call-template name="reconstruct">
                <xsl:with-param name="node" select="."/>
              </xsl:call-template>
            </span>
            <xsl:choose>
              <xsl:when test="@next">
                <span class="split-badge">split</span>
              </xsl:when>
              <xsl:when test=".//tei:lb or .//tei:pb">
                <span class="ms-badge">milestone-wrap</span>
              </xsl:when>
            </xsl:choose>
            <span class="where">
              <xsl:call-template name="locator">
                <xsl:with-param name="node" select="."/>
              </xsl:call-template>
            </span>
          </li>
        </xsl:for-each>
      </ul>
    </li>
  </xsl:template>

  <!-- Walk @next chain. For Latin-script text, join with a single space
       (the original line break sits at a word boundary). For CJK text
       (xml:lang starts with ja/zh/ko), join without a separator since
       neighbouring fragments concatenate without a space.
       normalize-space() collapses the source-formatting whitespace that
       milestone-wrapped entities pick up across <lb/> markers. -->
  <xsl:template name="reconstruct">
    <xsl:param name="node"/>
    <xsl:value-of select="normalize-space($node)"/>
    <xsl:if test="$node/@next">
      <xsl:variable name="lang"
          select="$node/ancestor::*[@xml:lang][1]/@xml:lang"/>
      <xsl:if test="not(starts-with($lang, 'ja'))
                and not(starts-with($lang, 'zh'))
                and not(starts-with($lang, 'ko'))">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:call-template name="reconstruct">
        <xsl:with-param name="node"
            select="key('by-id', substring-after($node/@next, '#'))"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Locator: produces "line N", "line N–M", "page N", or "pages N–M".
       For ab-based entities: line(s) from ancestor @n, walking @next for
       split chains. For milestone-based entities (inside <p>): page(s)
       from the preceding/inside <pb>. -->
  <xsl:template name="locator">
    <xsl:param name="node"/>
    <xsl:choose>
      <xsl:when test="$node/ancestor::tei:ab">
        <xsl:text>line </xsl:text>
        <xsl:value-of select="$node/ancestor::tei:ab/@n"/>
        <xsl:if test="$node/@next">
          <xsl:text>–</xsl:text>
          <xsl:call-template name="last-line">
            <xsl:with-param name="node" select="$node"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="pbBefore" select="$node/preceding::tei:pb[1]"/>
        <xsl:variable name="pbInside" select="$node//tei:pb"/>
        <xsl:choose>
          <xsl:when test="$pbInside">
            <xsl:text>pages </xsl:text>
            <xsl:value-of select="$pbBefore/@n"/>
            <xsl:text>–</xsl:text>
            <xsl:value-of select="$pbInside[last()]/@n"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>page </xsl:text>
            <xsl:value-of select="$pbBefore/@n"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="last-line">
    <xsl:param name="node"/>
    <xsl:variable name="nxt"
        select="key('by-id', substring-after($node/@next, '#'))"/>
    <xsl:choose>
      <xsl:when test="$nxt/@next">
        <xsl:call-template name="last-line">
          <xsl:with-param name="node" select="$nxt"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$nxt/ancestor::tei:ab/@n"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Helper: key/value row, skipped when empty -->
  <xsl:template name="kv">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <xsl:if test="normalize-space($value) != ''">
      <dt><xsl:value-of select="$label"/></dt>
      <dd><xsl:value-of select="normalize-space($value)"/></dd>
    </xsl:if>
  </xsl:template>

  <!-- Helper: multiple values rendered comma-separated, skipped when empty -->
  <xsl:template name="kv-list">
    <xsl:param name="label"/>
    <xsl:param name="nodes"/>
    <xsl:if test="$nodes">
      <dt><xsl:value-of select="$label"/></dt>
      <dd>
        <xsl:for-each select="$nodes">
          <xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
      </dd>
    </xsl:if>
  </xsl:template>

  <!-- Helper: multiple paragraphs each on its own line, skipped when empty -->
  <xsl:template name="kv-pp">
    <xsl:param name="label"/>
    <xsl:param name="nodes"/>
    <xsl:if test="$nodes">
      <dt><xsl:value-of select="$label"/></dt>
      <dd>
        <xsl:for-each select="$nodes">
          <xsl:if test="position() &gt; 1"><br/></xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
      </dd>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
