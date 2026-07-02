(function(){
  const EMU = 914400;
  const W = 13.333;
  const H = 7.5;
  const CX = Math.round(W * EMU);
  const CY = Math.round(H * EMU);
  const NS_A = 'http://schemas.openxmlformats.org/drawingml/2006/main';
  const NS_R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const NS_P = 'http://schemas.openxmlformats.org/presentationml/2006/main';

  window.BrowserPptx = { renderPlan };

  async function renderPlan(spec, options){
    const deck = normalizeSpec(spec, options || {});
    const theme = themeTokens(deck.themeHint || options.theme || 'minimal_white');
    const slides = deck.slides.map((s, i) => normalizeSlide(s, i, deck));
    const files = buildPackage(deck, slides, theme);
    const blob = zipStore(files);
    return {
      blob,
      fileName: safeFileName(deck.deckTitle || 'ai_ppt') + '_' + today() + '.pptx',
      slideCount: slides.length,
      slideSpec: Object.assign({}, deck, { slides }),
      metrics: {
        mode: options.mode || 'beauty',
        theme: theme.name,
        slide_count: slides.length,
        output_size: blob.size,
        renderer: 'browser-openxml-clean'
      }
    };
  }

  function normalizeSpec(spec, options){
    if(!spec || !Array.isArray(spec.slides) || spec.slides.length < 10){
      throw new Error('OpenAI Slide Spec 无效，已停止渲染。');
    }
    return {
      deckTitle: clean(spec.deckTitle || spec.title || 'AI PPT'),
      subtitle: clean(spec.subtitle || ''),
      audience: clean(spec.audience || options.audience || ''),
      templateType: clean(spec.templateType || spec.narrativeType || ''),
      themeHint: clean(spec.themeHint || options.theme || 'minimal_white'),
      sections: Array.isArray(spec.sections) ? spec.sections : [],
      slides: spec.slides.slice(0, 28)
    };
  }

  function normalizeSlide(raw, index, deck){
    const points = []
      .concat(raw.coreMessage ? [raw.coreMessage] : [])
      .concat(Array.isArray(raw.supportingPoints) ? raw.supportingPoints : [])
      .concat(Array.isArray(raw.points) ? raw.points : [])
      .map(v => clean(v))
      .filter(Boolean)
      .filter(v => !banned(v))
      .slice(0, 5);
    if(points.length === 0) points.push(clean(raw.subtitle || deck.subtitle || deck.deckTitle));
    return {
      slideNo: Number(raw.slideNo || index + 1),
      section: clean(raw.section || sectionFor(index, deck.sections)),
      layoutType: mapLayout(raw.layoutType || raw.visualType || 'cards', index),
      title: clean(raw.title || `${deck.deckTitle} ${index + 1}`),
      coreMessage: clean(raw.coreMessage || raw.subtitle || points[0]),
      supportingPoints: points,
      thinkAboutIt: clean(raw.thinkAboutIt || ''),
      visualType: clean(raw.visualType || 'cards'),
      chartSuggestion: raw.chartSuggestion || raw.chartSpec || null,
      speakerNote: clean(raw.speakerNote || '')
    };
  }

  function buildPackage(deck, slides, theme){
    const files = {};
    files['[Content_Types].xml'] = contentTypes(slides.length);
    files['_rels/.rels'] = rootRels();
    files['docProps/app.xml'] = appProps(slides.length);
    files['docProps/core.xml'] = coreProps(deck.deckTitle);
    files['ppt/presentation.xml'] = presentationXml(slides.length);
    files['ppt/_rels/presentation.xml.rels'] = presentationRels(slides.length);
    files['ppt/theme/theme1.xml'] = themeXml(theme);
    files['ppt/slideMasters/slideMaster1.xml'] = slideMasterXml(theme);
    files['ppt/slideMasters/_rels/slideMaster1.xml.rels'] = slideMasterRels();
    files['ppt/slideLayouts/slideLayout1.xml'] = slideLayoutXml();
    files['ppt/slideLayouts/_rels/slideLayout1.xml.rels'] = slideLayoutRels();
    slides.forEach((slide, i) => {
      files[`ppt/slides/slide${i + 1}.xml`] = slideXml(slide, i, slides.length, deck, theme);
      files[`ppt/slides/_rels/slide${i + 1}.xml.rels`] = slideRels();
    });
    return files;
  }

  function slideXml(slide, index, total, deck, theme){
    let id = 10;
    const shapes = [];
    shapes.push(bg(theme));
    const layout = slide.layoutType;
    if(layout === 'cover'){
      shapes.push(accentBand(theme, 0, 0, 13.333, 7.5, 0.08));
      shapes.push(textBox(++id, slide.title, 0.75, 1.35, 8.2, 1.2, 40, theme.title, true));
      shapes.push(textBox(++id, deck.subtitle || slide.coreMessage, 0.8, 2.65, 7.8, 0.8, 19, theme.body, false));
      shapes.push(bigCircle(++id, 10.2, 1.35, 1.8, theme.primary, '01'));
      shapes.push(card(++id, 8.6, 4.45, 3.4, 1.15, theme.card, theme.border));
      shapes.push(textBox(++id, deck.audience || '目标受众', 8.85, 4.72, 2.9, 0.45, 16, theme.body, true));
    } else if(layout === 'section_divider' || layout === 'section'){
      shapes.push(accentBand(theme, 0, 0, 13.333, 7.5, 0.12));
      shapes.push(textBox(++id, pad2(index + 1), 0.7, 0.75, 1.3, 0.55, 24, theme.primary, true));
      shapes.push(textBox(++id, slide.section || slide.title, 0.75, 2.15, 6.2, 0.9, 34, theme.title, true));
      shapes.push(textBox(++id, slide.coreMessage, 0.78, 3.2, 7.8, 0.8, 18, theme.body, false));
      shapes.push(processDots(++id, 8.5, 2.1, theme));
    } else if(layout === 'timeline' || layout === 'roadmap'){
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(timeline(++id, slide.supportingPoints, theme));
    } else if(layout === 'process_steps' || layout === 'process'){
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(process(++id, slide.supportingPoints, theme));
    } else if(layout === 'comparison'){
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(comparison(++id, slide.supportingPoints, theme));
    } else if(layout === 'framework_matrix' || layout === 'matrix'){
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(matrix(++id, slide.supportingPoints, theme));
    } else if(layout === 'big_number'){
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(bigNumber(++id, index + 1, slide, theme));
    } else if(layout === 'quote'){
      shapes.push(quote(++id, slide, theme));
    } else if(layout === 'closing'){
      shapes.push(accentBand(theme, 0, 0, 13.333, 7.5, 0.08));
      shapes.push(textBox(++id, slide.title || '谢谢', 0.8, 1.4, 7.5, 1.0, 38, theme.title, true));
      shapes.push(cards(++id, slide.supportingPoints.slice(0,3), theme, 0.8, 3.0));
    } else {
      shapes.push(titleBlock(++id, slide, theme));
      shapes.push(cards(++id, slide.supportingPoints, theme, 0.75, 2.05));
    }
    shapes.push(footer(++id, index + 1, total, deck, theme));
    return xmlHeader() + `<p:sld xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>${shapes.join('')}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>`;
  }

  function bg(theme){ return rect(2, 0, 0, 13.333, 7.5, theme.background, theme.background, 0); }
  function titleBlock(id, slide, theme){
    return textBox(id, slide.title, 0.7, 0.55, 8.7, 0.58, 24, theme.title, true)
      + textBox(id + 1000, slide.coreMessage, 0.72, 1.18, 8.6, 0.45, 13.5, theme.body, false)
      + rect(id + 2000, 0.7, 1.78, 1.15, 0.05, theme.primary, theme.primary, 0);
  }
  function cards(id, points, theme, x, y){
    return points.slice(0,4).map((p,i) => {
      const w = 2.95, h = 1.25;
      const cx = x + (i % 2) * 3.25;
      const cy = y + Math.floor(i / 2) * 1.55;
      return card(id + i, cx, cy, w, h, i % 2 ? theme.cardAlt : theme.card, theme.border)
        + textBox(id + 50 + i, `${i+1}`, cx + 0.18, cy + 0.18, 0.35, 0.3, 12, theme.primary, true)
        + textBox(id + 100 + i, p, cx + 0.62, cy + 0.18, w - 0.78, h - 0.25, 13, theme.body, false);
    }).join('');
  }
  function timeline(id, points, theme){
    let out = rect(id, 1.0, 3.2, 11.0, 0.05, theme.primary, theme.primary, 0);
    points.slice(0,5).forEach((p,i) => {
      const x = 1.1 + i * 2.15;
      out += oval(id + 10 + i, x, 3.0, 0.42, 0.42, theme.primary, theme.primary);
      out += textBox(id + 30 + i, p, x - 0.35, 3.55, 1.8, 1.1, 11.5, theme.body, false);
    });
    return out;
  }
  function process(id, points, theme){
    return points.slice(0,5).map((p,i) => {
      const x = 0.75 + i * 2.45;
      return card(id + i, x, 2.35, 2.05, 1.45, theme.card, theme.border)
        + textBox(id + 30 + i, pad2(i+1), x + 0.18, 2.55, 0.5, 0.35, 13, theme.primary, true)
        + textBox(id + 60 + i, p, x + 0.22, 2.98, 1.6, 0.65, 11.5, theme.body, false)
        + (i < 4 ? textBox(id + 90 + i, '→', x + 2.08, 2.85, 0.35, 0.35, 18, theme.primary, true) : '');
    }).join('');
  }
  function comparison(id, points, theme){
    const left = points.slice(0, Math.ceil(points.length/2)).join('\n');
    const right = points.slice(Math.ceil(points.length/2)).join('\n') || points[0];
    return card(id, 0.85, 2.1, 5.55, 3.3, theme.card, theme.border)
      + card(id+1, 6.85, 2.1, 5.55, 3.3, theme.cardAlt, theme.border)
      + textBox(id+2, '方案 A', 1.15, 2.35, 2, 0.4, 16, theme.primary, true)
      + textBox(id+3, left, 1.15, 2.92, 4.8, 1.85, 13, theme.body, false)
      + textBox(id+4, '方案 B', 7.15, 2.35, 2, 0.4, 16, theme.accent, true)
      + textBox(id+5, right, 7.15, 2.92, 4.8, 1.85, 13, theme.body, false);
  }
  function matrix(id, points, theme){
    let out = '';
    for(let r=0;r<2;r++) for(let c=0;c<2;c++){
      const i = r*2+c;
      out += card(id+i, 0.85+c*5.55, 2.0+r*1.75, 5.1, 1.35, i%2?theme.cardAlt:theme.card, theme.border);
      out += textBox(id+20+i, points[i] || '关键判断', 1.1+c*5.55, 2.28+r*1.75, 4.5, 0.65, 13, theme.body, false);
    }
    return out;
  }
  function bigNumber(id, n, slide, theme){
    return textBox(id, String(n), 0.9, 2.0, 2.2, 1.7, 62, theme.primary, true)
      + textBox(id+1, slide.supportingPoints.slice(0,3).join('\n'), 3.25, 2.2, 7.8, 2.2, 16, theme.body, false);
  }
  function quote(id, slide, theme){
    return textBox(id, '“', 0.8, 0.9, 1.0, 1.0, 64, theme.primary, true)
      + textBox(id+1, slide.coreMessage || slide.title, 1.45, 1.65, 9.5, 1.1, 26, theme.title, true)
      + textBox(id+2, slide.supportingPoints.slice(0,3).join('\n'), 1.5, 3.1, 8.2, 1.8, 15, theme.body, false);
  }
  function footer(id, no, total, deck, theme){
    return rect(id, 0.7, 6.92, 11.9, 0.01, theme.border, theme.border, 0)
      + textBox(id+1, deck.deckTitle, 0.72, 6.98, 5.2, 0.25, 8.5, theme.muted, false)
      + textBox(id+2, `${no} / ${total}`, 11.75, 6.98, 0.85, 0.25, 8.5, theme.muted, false);
  }
  function accentBand(theme, x, y, w, h, alpha){ return rect(900, x, y, w, h, theme.cardAlt, theme.cardAlt, 0); }
  function processDots(id, x, y, theme){ return [0,1,2].map(i => oval(id+i, x+i*0.72, y+i*0.35, 0.5, 0.5, i%2?theme.accent:theme.primary, i%2?theme.accent:theme.primary)).join(''); }
  function bigCircle(id, x, y, size, color, text){ return oval(id, x, y, size, size, color, color) + textBox(id+1, text, x+0.46, y+0.58, 0.9, 0.45, 19, '#FFFFFF', true); }
  function card(id,x,y,w,h,fill,border){ return rect(id,x,y,w,h,fill,border,1); }
  function rect(id,x,y,w,h,fill,border,round){
    const prst = round ? 'roundRect' : 'rect';
    return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="shape${id}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${emu(x)}" y="${emu(y)}"/><a:ext cx="${emu(w)}" cy="${emu(h)}"/></a:xfrm><a:prstGeom prst="${prst}"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${hex(fill)}"/></a:solidFill><a:ln w="9525"><a:solidFill><a:srgbClr val="${hex(border)}"/></a:solidFill></a:ln></p:spPr></p:sp>`;
  }
  function oval(id,x,y,w,h,fill,border){
    return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="oval${id}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${emu(x)}" y="${emu(y)}"/><a:ext cx="${emu(w)}" cy="${emu(h)}"/></a:xfrm><a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${hex(fill)}"/></a:solidFill><a:ln w="9525"><a:solidFill><a:srgbClr val="${hex(border)}"/></a:solidFill></a:ln></p:spPr></p:sp>`;
  }
  function textBox(id, text, x, y, w, h, size, color, bold){
    const lines = String(text || '').split('\n').slice(0, 6);
    const paras = lines.map(line => `<a:p><a:r><a:rPr lang="zh-CN" sz="${Math.round(size*100)}" b="${bold?1:0}"><a:solidFill><a:srgbClr val="${hex(color)}"/></a:solidFill><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/></a:rPr><a:t>${esc(line)}</a:t></a:r></a:p>`).join('');
    return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="text${id}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${emu(x)}" y="${emu(y)}"/><a:ext cx="${emu(w)}" cy="${emu(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" anchor="t"/><a:lstStyle/>${paras}</p:txBody></p:sp>`;
  }

  function contentTypes(count){
    let slides = '';
    for(let i=1;i<=count;i++) slides += `<Override PartName="/ppt/slides/slide${i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>`;
    return xmlHeader()+`<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>${slides}</Types>`;
  }
  function rootRels(){ return xmlHeader()+`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>`; }
  function presentationRels(count){
    let rels = `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>`;
    for(let i=1;i<=count;i++) rels += `<Relationship Id="rId${i+2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i}.xml"/>`;
    return xmlHeader()+`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${rels}</Relationships>`;
  }
  function slideRels(){ return xmlHeader()+`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>`; }
  function slideMasterRels(){ return xmlHeader()+`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>`; }
  function slideLayoutRels(){ return xmlHeader()+`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>`; }
  function presentationXml(count){
    let ids='';
    for(let i=1;i<=count;i++) ids += `<p:sldId id="${255+i}" r:id="rId${i+2}"/>`;
    return xmlHeader()+`<p:presentation xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst>${ids}</p:sldIdLst><p:sldSz cx="${CX}" cy="${CY}" type="wide"/><p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle><a:defPPr><a:defRPr lang="zh-CN"/></a:defPPr></p:defaultTextStyle></p:presentation>`;
  }
  function slideMasterXml(theme){
    const tx = `<a:lvl1pPr marL="0" indent="0"><a:defRPr sz="1800"><a:solidFill><a:srgbClr val="${hex(theme.body)}"/></a:solidFill><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/></a:defRPr></a:lvl1pPr>`;
    return xmlHeader()+`<p:sldMaster xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle>${tx}</p:titleStyle><p:bodyStyle>${tx}</p:bodyStyle><p:otherStyle>${tx}</p:otherStyle></p:txStyles></p:sldMaster>`;
  }
  function slideLayoutXml(){ return xmlHeader()+`<p:sldLayout xmlns:a="${NS_A}" xmlns:r="${NS_R}" xmlns:p="${NS_P}" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>`; }
  function themeXml(theme){
    return xmlHeader()+`<a:theme xmlns:a="${NS_A}" name="AITheme"><a:themeElements><a:clrScheme name="Custom"><a:dk1><a:srgbClr val="${hex(theme.title)}"/></a:dk1><a:lt1><a:srgbClr val="${hex(theme.background)}"/></a:lt1><a:dk2><a:srgbClr val="${hex(theme.body)}"/></a:dk2><a:lt2><a:srgbClr val="${hex(theme.card)}"/></a:lt2><a:accent1><a:srgbClr val="${hex(theme.primary)}"/></a:accent1><a:accent2><a:srgbClr val="${hex(theme.accent)}"/></a:accent2><a:accent3><a:srgbClr val="${hex(theme.cardAlt)}"/></a:accent3><a:accent4><a:srgbClr val="${hex(theme.border)}"/></a:accent4><a:accent5><a:srgbClr val="${hex(theme.muted)}"/></a:accent5><a:accent6><a:srgbClr val="${hex(theme.onPrimary)}"/></a:accent6><a:hlink><a:srgbClr val="${hex(theme.primary)}"/></a:hlink><a:folHlink><a:srgbClr val="${hex(theme.accent)}"/></a:folHlink></a:clrScheme><a:fontScheme name="Microsoft YaHei"><a:majorFont><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Microsoft YaHei"/></a:majorFont><a:minorFont><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Microsoft YaHei"/></a:minorFont></a:fontScheme><a:fmtScheme name="Default"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:round/></a:ln><a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:round/></a:ln><a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:round/></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>`;
  }
  function appProps(count){ return xmlHeader()+`<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>AI PPT Generator</Application><PresentationFormat>Wide Screen</PresentationFormat><Slides>${count}</Slides><Company>HoloMemory</Company></Properties>`; }
  function coreProps(title){ const now = new Date().toISOString(); return xmlHeader()+`<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>${esc(title)}</dc:title><dc:creator>AI PPT Generator</dc:creator><cp:lastModifiedBy>AI PPT Generator</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">${now}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">${now}</dcterms:modified></cp:coreProperties>`; }

  function themeTokens(name){
    const themes = {
      education_light:{name:'education_light',background:'#F8FAFC',card:'#FFFFFF',cardAlt:'#EFF6FF',border:'#D7E3F4',primary:'#2563EB',accent:'#14B8A6',title:'#0F172A',body:'#334155',muted:'#64748B',onPrimary:'#FFFFFF'},
      executive_dark:{name:'executive_dark',background:'#07111F',card:'#102033',cardAlt:'#132B46',border:'#315170',primary:'#60A5FA',accent:'#A78BFA',title:'#F8FAFC',body:'#D8E4F3',muted:'#9DB2CC',onPrimary:'#06101F'},
      coffee_warm:{name:'coffee_warm',background:'#FFF7ED',card:'#FFFFFF',cardAlt:'#FDEDD3',border:'#E8D6BD',primary:'#9A5A2E',accent:'#D97706',title:'#2C1810',body:'#5B4031',muted:'#876B5A',onPrimary:'#FFFFFF'},
      travel_editorial:{name:'travel_editorial',background:'#F7FBFF',card:'#FFFFFF',cardAlt:'#EAF6F6',border:'#CFE7E9',primary:'#0E7490',accent:'#F97316',title:'#0F172A',body:'#334155',muted:'#64748B',onPrimary:'#FFFFFF'},
      minimal_white:{name:'minimal_white',background:'#FFFFFF',card:'#F8FAFC',cardAlt:'#F1F5F9',border:'#E2E8F0',primary:'#111827',accent:'#2563EB',title:'#111827',body:'#374151',muted:'#6B7280',onPrimary:'#FFFFFF'}
    };
    const t = themes[name] || themes.minimal_white;
    if(luminance(t.background) < 0.35) return Object.assign({}, t, {title:'#F8FAFC', body:'#E2E8F0', muted:'#B6C2D1'});
    return t;
  }
  function mapLayout(layout, index){
    const map = {section:'section_divider', cards:'data_cards', process:'process_steps', matrix:'framework_matrix', chart:'data_cards', image:'hero_image'};
    const seq = ['cover','agenda','section_divider','data_cards','timeline','process_steps','comparison','framework_matrix','big_number','quote','roadmap','summary','closing'];
    return map[layout] || layout || seq[index % seq.length];
  }
  function sectionFor(index, sections){
    const n = index + 1;
    const hit = sections.find(s => n >= Number(s.slideStart || 0) && n <= Number(s.slideEnd || 999));
    return clean(hit && hit.name) || '';
  }
  function clean(v){ return String(v == null ? '' : v).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '').trim(); }
  function banned(v){ return /形成清晰判断|具体执行建议|为什么现在要关注|听众看完这一页应该改变哪个判断|把复杂内容变成清晰|保留一个可复盘|code|coffee|rocket|warning|database|plane/.test(String(v || '')); }
  function esc(v){ return clean(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;'); }
  function hex(v){ return String(v || '#000000').replace('#','').slice(0,6).padEnd(6,'0').toUpperCase(); }
  function emu(v){ return Math.round(Number(v || 0) * EMU); }
  function xmlHeader(){ return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'; }
  function pad2(n){ return String(n).padStart(2,'0'); }
  function today(){ const d = new Date(); return `${d.getFullYear()}${pad2(d.getMonth()+1)}${pad2(d.getDate())}`; }
  function safeFileName(v){ return clean(v).replace(/[\\/:*?"<>|]/g,'_').slice(0,50) || 'ai_ppt'; }
  function luminance(hexColor){
    const h = hex(hexColor); const r=parseInt(h.slice(0,2),16)/255, g=parseInt(h.slice(2,4),16)/255, b=parseInt(h.slice(4,6),16)/255;
    return 0.2126*r + 0.7152*g + 0.0722*b;
  }

  function zipStore(files){
    const names = Object.keys(files);
    const chunks = [];
    const central = [];
    let offset = 0;
    names.forEach(name => {
      const data = utf8(files[name]);
      const n = utf8(name);
      const crc = crc32(data);
      const local = concat(u32(0x04034b50), u16(20), u16(0), u16(0), u16(0), u16(0), u32(crc), u32(data.length), u32(data.length), u16(n.length), u16(0), n, data);
      chunks.push(local);
      central.push(concat(u32(0x02014b50), u16(20), u16(20), u16(0), u16(0), u16(0), u16(0), u32(crc), u32(data.length), u32(data.length), u16(n.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset), n));
      offset += local.length;
    });
    const cd = concat.apply(null, central);
    const end = concat(u32(0x06054b50), u16(0), u16(0), u16(names.length), u16(names.length), u32(cd.length), u32(offset), u16(0));
    return new Blob([concat.apply(null, chunks.concat([cd, end]))], {type:'application/vnd.openxmlformats-officedocument.presentationml.presentation'});
  }
  function utf8(s){ return new TextEncoder().encode(String(s)); }
  function concat(){ const arrays=[...arguments]; const len=arrays.reduce((n,a)=>n+a.length,0); const out=new Uint8Array(len); let p=0; arrays.forEach(a=>{out.set(a,p);p+=a.length;}); return out; }
  function u16(v){ const a=new Uint8Array(2); a[0]=v&255; a[1]=(v>>>8)&255; return a; }
  function u32(v){ const a=new Uint8Array(4); a[0]=v&255; a[1]=(v>>>8)&255; a[2]=(v>>>16)&255; a[3]=(v>>>24)&255; return a; }
  const CRC_TABLE = (() => { const t=[]; for(let n=0;n<256;n++){ let c=n; for(let k=0;k<8;k++) c=(c&1)?(0xEDB88320^(c>>>1)):(c>>>1); t[n]=c>>>0; } return t; })();
  function crc32(data){ let c=0xffffffff; for(let i=0;i<data.length;i++) c=CRC_TABLE[(c^data[i])&255]^(c>>>8); return (c^0xffffffff)>>>0; }
})();

