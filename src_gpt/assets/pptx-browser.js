(function(){
  const PPT_W = 12192000; // 13.333in
  const PPT_H = 6858000;  // 7.5in
  const EMU = 914400;
  const FONT = 'Microsoft YaHei';

  function cleanForbidden(v){
    let t=String(v==null?'':v);
    ['OpenAI','Planner','Renderer','Agent','Pipeline','Prompt','Slide Spec','token','cost','fallback','client','server','image prompt','AI generated','placeholder','no fake photo source','visual generated'].forEach(b=>{t=t.replace(new RegExp(b.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'gi'),'');});
    return t.replace(/\bCEO\b/g,'管理层').replace(/\bCTO\b/g,'技术负责人').replace(/\bROI\b/g,'投资回报').replace(/\bAPI\b/g,'接口').replace(/\s{2,}/g,' ').trim();
  }



  function clean(v){ return cleanForbidden(v); }
  function xml(v){ return String(v==null?'':v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;'); }
  function hex6(v){
    let s=String(v==null?'':v).trim().replace(/^#/,'').replace(/[^0-9a-fA-F]/g,'');
    if(s.length===3) s=s.split('').map(c=>c+c).join('');
    if(s.length<6) s=(s+'000000').slice(0,6);
    return s.slice(0,6).toUpperCase();
  }
  function safeFileName(v){ return cleanCn ? cleanCn(v).replace(/[\\/:*?"<>|]/g,'_').replace(/\s+/g,'_').slice(0,40) : String(v||'AI_PPT').replace(/[\\/:*?"<>|]/g,'_'); }
  function today(){ const d=new Date(); return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0'); }
  function extractNumber(s){ const txt=[s&&s.title,s&&s.coreMessage].concat((s&&s.points)||[]).join(' '); const m=txt.match(/\d+(?:\.\d+)?%?|[一二三四五六七八九十]+/); return m?m[0]:''; }
  function normalizeLayout(v, idx, total){
    let x=String(v||'').toLowerCase().replace(/[^a-z_]/g,'');
    if(idx===0) return 'cover';
    if(idx>=total-1) return 'closing';
    const map={cards:'cards',card:'cards',list:'cards',bullet:'cards',image:'image',gallery:'gallery',photo:'image',visual:'image',table:'table',chart:'chart',bar:'chart',timeline:'timeline',roadmap:'timeline',process:'process',steps:'process_steps',matrix:'matrix',framework:'framework_matrix',architecture:'architecture',comparison:'comparison',quote:'quote',summary:'summary',section:'section',divider:'section_divider',code:'code',big_number:'big_number',kpi:'big_number'};
    return map[x] || (idx%6===0?'image':idx%5===0?'process':idx%4===0?'matrix':'cards');
  }
  function inferTheme(deck){
    const t=((deck&&deck.deckTitle)||'')+' '+((deck&&deck.templateType)||'')+' '+((deck&&deck.audience)||'');
    if(/医疗|医院|护理|健康|科研|学术|研究/.test(t)) return 'medical_blue';
    if(/金融|投资|审计|财务|商业|CEO|管理层|订单|Rust/.test(t)) return 'business_blue';
    if(/咖啡|生活|旅行|京都/.test(t)) return 'warm_editorial';
    if(/Python|课程|教学|培训|代码/.test(t)) return 'education_blue';
    return 'minimal_white';
  }
  function themeTokens(name){
    const themes={
      minimal_white:{name:'minimal_white',background:'#F8FAFC',title:'#0F172A',body:'#334155',muted:'#64748B',primary:'#2563EB',accent:'#0EA5E9',soft:'#E0F2FE',card:'#FFFFFF',border:'#BFDBFE',onPrimary:'#FFFFFF'},
      business_blue:{name:'business_blue',background:'#0F172A',title:'#FFFFFF',body:'#E5E7EB',muted:'#CBD5E1',primary:'#60A5FA',accent:'#A78BFA',soft:'#1E293B',card:'#1E293B',border:'#334155',onPrimary:'#FFFFFF'},
      medical_blue:{name:'medical_blue',background:'#F4F8FC',title:'#08345F',body:'#1E3A5F',muted:'#52708C',primary:'#0B5CAD',accent:'#2AA7D8',soft:'#E6F2FB',card:'#FFFFFF',border:'#B9D7F0',onPrimary:'#FFFFFF'},
      warm_editorial:{name:'warm_editorial',background:'#FFF8EE',title:'#2B211C',body:'#5A4034',muted:'#8A6B5B',primary:'#9A3F24',accent:'#D97706',soft:'#FDEDD3',card:'#FFFDF8',border:'#E8CDAF',onPrimary:'#FFFFFF'},
      education_blue:{name:'education_blue',background:'#F7FAFF',title:'#0F172A',body:'#334155',muted:'#64748B',primary:'#2563EB',accent:'#06B6D4',soft:'#DBEAFE',card:'#FFFFFF',border:'#CBD5E1',onPrimary:'#FFFFFF'}
    };
    const key=String(name||'').toLowerCase();
    return themes[key] || themes.minimal_white;
  }


  window.BrowserPptx = { renderPlan };

  async function renderPlan(spec, options){
    const deck = normalizeSpec(spec, options || {});
    const theme = themeTokens(options.theme === 'auto' ? (deck.themeHint || inferTheme(deck)) : (options.theme || deck.themeHint || 'minimal_white'));
    const PptxCtor = getPptxGenCtor();
    if(PptxCtor){
      return renderWithPptxGen(PptxCtor, deck, theme, options || {});
    }
    throw new Error("PptxGenJS 浏览器渲染器未加载，已停止生成 PPT，避免输出损坏文件。");
    const zip = new (window.JSZip || JSZip)();
    buildPackage(zip, deck, theme, options || {});
    const blob = await zip.generateAsync({type:'blob', mimeType:'application/vnd.openxmlformats-officedocument.presentationml.presentation', compression:'STORE'});
    return { blob, fileName: safeFileName(deck.deckTitle || 'AI_PPT') + '_' + (options.mode || 'beauty') + '_' + today() + '.pptx', slideCount: deck.slides.length, slideSpec: deck, metrics:{renderer:'safe-openxml-basic', slide_count:deck.slides.length, output_size:blob.size, theme:theme.name} };
  }

  function getPptxGenCtor(){
    const candidates = [window.PptxGenJS, window.pptxgenjs, window.pptxgen, window.PPTXGenJS].filter(Boolean);
    for(const c of candidates){
      if(typeof c === 'function') return c;
      if(c && typeof c.default === 'function') return c.default;
      if(c && typeof c.PptxGenJS === 'function') return c.PptxGenJS;
    }
    return null;
  }

  async function renderWithPptxGen(PptxCtor, deck, theme, options){
    const pptx = new PptxCtor();
    pptx.layout = 'LAYOUT_WIDE';
    pptx.author = 'AI PPT Generator';
    pptx.company = 'HoloMemory AI';
    pptx.subject = deck.subtitle || '';
    pptx.title = deck.deckTitle || 'AI PPT';
    pptx.lang = 'zh-CN';
    deck.slides.forEach((slide, idx) => addPptxSlide(pptx, normalizeSlide(slide, idx, deck), idx, deck, theme, options));
    let blob;
    try {
      blob = await pptx.write({ outputType: 'blob' });
    } catch(error) {
      blob = await pptx.write('blob');
    }
    if(!(blob instanceof Blob)){
      blob = new Blob([blob], {type:'application/vnd.openxmlformats-officedocument.presentationml.presentation'});
    }
    return {
      blob,
      fileName: safeFileName(deck.deckTitle || 'AI_PPT') + '_' + (options.mode || 'beauty') + '_' + today() + '.pptx',
      slideCount: deck.slides.length,
      slideSpec: deck,
      metrics:{renderer:'pptxgenjs-browser', slide_count:deck.slides.length, output_size:blob.size, theme:theme.name}
    };
  }

  function addPptxSlide(pptx, s, idx, deck, theme, options){
    const slide = pptx.addSlide();
    slide.background = { color: pptxHex(theme.background) };
    const layout = normalizeLayout(s.layoutType, idx, deck.slides.length);
    const dark = isDark(theme.background);
    const titleColor = pptxHex(dark ? '#FFFFFF' : theme.title);
    const bodyColor = pptxHex(dark ? '#E5E7EB' : theme.body);
    const mutedColor = pptxHex(dark ? '#CBD5E1' : theme.muted);
    const primary = pptxHex(theme.primary);
    const accent = pptxHex(theme.accent);
    const card = pptxHex(dark ? '#1E293B' : theme.card);
    const soft = pptxHex(dark ? '#172554' : theme.soft);
    const line = pptxHex(dark ? '#334155' : theme.border);

    addFooter(slide, deck, idx, mutedColor);
    if(idx === 0 || layout === 'cover'){
      slide.addText(clean(deck.deckTitle || s.title), {x:0.7,y:1.2,w:8.4,h:0.9,fontFace:FONT,fontSize:34,bold:true,color:titleColor,fit:'shrink'});
      slide.addText(clean(deck.subtitle || s.coreMessage || ''), {x:0.75,y:2.25,w:7.2,h:0.55,fontFace:FONT,fontSize:15,color:bodyColor,fit:'shrink'});
      slide.addText(clean(deck.audience || ''), {x:0.75,y:3.25,w:3.3,h:0.42,fontFace:FONT,fontSize:11,bold:true,color:primary,fill:{color:soft},line:{color:line},margin:0.08});
      addVisualBlock(slide, 8.6, 0.85, 3.75, 5.05, primary, accent, soft, layout);
      return;
    }

    if(layout === 'section' || layout === 'section_divider'){
      slide.addText(String(idx + 1).padStart(2,'0'), {x:0.75,y:0.9,w:1.2,h:0.5,fontFace:FONT,fontSize:24,bold:true,color:primary});
      slide.addText(clean(s.section || ''), {x:2.0,y:0.96,w:3.8,h:0.35,fontFace:FONT,fontSize:12,bold:true,color:primary});
      slide.addText(clean(s.title), {x:0.75,y:2.05,w:9.8,h:0.85,fontFace:FONT,fontSize:30,bold:true,color:titleColor,fit:'shrink'});
      slide.addText(clean(s.coreMessage || s.points[0] || ''), {x:0.78,y:3.15,w:8.2,h:0.65,fontFace:FONT,fontSize:15,color:bodyColor,fit:'shrink'});
      slide.addText('', {x:0.75,y:5.35,w:4.4,h:0.08,fill:{color:primary},line:{color:primary}});
      return;
    }

    addHeader(slide, s, titleColor, bodyColor, primary);
    if(layout === 'timeline' || layout === 'roadmap'){
      const pts = s.points.slice(0,5);
      slide.addText('', {x:1.0,y:3.45,w:10.8,h:0.04,fill:{color:primary},line:{color:primary}});
      pts.forEach((p,i) => {
        const x = 1.0 + i * (10.0 / Math.max(1, pts.length - 1));
        slide.addText(String(i+1), {x:x,y:3.2,w:0.45,h:0.45,fontFace:FONT,fontSize:13,bold:true,color:'FFFFFF',align:'center',valign:'mid',fill:{color:primary},line:{color:primary},margin:0.02});
        slide.addText(clean(p), {x:Math.max(0.5, x-0.55),y:3.9,w:1.65,h:1.0,fontFace:FONT,fontSize:10,color:bodyColor,align:'center',fit:'shrink'});
      });
      return;
    }
    if(layout === 'process' || layout === 'process_steps'){
      s.points.slice(0,4).forEach((p,i) => addCard(slide, clean(p), 0.75+i*3.1, 2.75, 2.55, 1.25, i%2?card:soft, line, bodyColor, i+1));
      return;
    }
    if(layout === 'comparison' || layout === 'matrix' || layout === 'framework_matrix'){
      slide.addText('现状', {x:0.85,y:2.25,w:4.4,h:0.35,fontFace:FONT,fontSize:14,bold:true,color:primary});
      slide.addText('建议', {x:6.55,y:2.25,w:4.4,h:0.35,fontFace:FONT,fontSize:14,bold:true,color:accent});
      addCard(slide, clean(s.points[0] || s.coreMessage), 0.85, 2.75, 5.0, 1.85, card, line, bodyColor, 'A');
      addCard(slide, clean(s.points.slice(1).join('\n')), 6.55, 2.75, 5.0, 1.85, card, line, bodyColor, 'B');
      return;
    }
    if(layout === 'big_number'){
      slide.addText(extractNumber(s) || String(idx+1), {x:0.9,y:2.35,w:2.4,h:1.3,fontFace:FONT,fontSize:54,bold:true,color:primary,fit:'shrink'});
      slide.addText(clean(s.points.join('\n')), {x:3.55,y:2.35,w:7.6,h:2.3,fontFace:FONT,fontSize:15,color:bodyColor,breakLine:false,fit:'shrink',bullet:{type:'ul'}});
      return;
    }
    if(layout === 'quote'){
      slide.addText('“', {x:0.85,y:2.0,w:0.7,h:0.7,fontFace:'Georgia',fontSize:52,bold:true,color:accent});
      slide.addText(clean(s.coreMessage || s.points[0] || s.title), {x:1.55,y:2.25,w:9.2,h:1.25,fontFace:FONT,fontSize:25,bold:true,color:titleColor,fit:'shrink'});
      slide.addText(clean(s.points.slice(1).join(' / ')), {x:1.6,y:3.75,w:8.5,h:0.5,fontFace:FONT,fontSize:13,color:mutedColor});
      return;
    }
    if(layout === 'table'){
      renderPptxTable(slide, s, dark, card, line, bodyColor, titleColor, primary);
      return;
    }
    if(layout === 'chart'){
      renderPptxChart(slide, s, card, line, bodyColor, primary, accent);
      return;
    }
    if(layout === 'image' || layout === 'gallery'){
      addSceneVisual(slide, s, 0.9, 2.2, 6.5, 3.3, primary, accent, soft);
      s.points.slice(0,3).forEach((p,i) => addCard(slide, clean(p), 7.75, 2.35+i*1.0, 3.75, 0.75, card, line, bodyColor, i+1));
      return;
    }
    if(layout === 'summary' || layout === 'closing'){
      s.points.slice(0,3).forEach((p,i) => addCard(slide, clean(p), 0.9+i*3.75, 2.7, 3.15, 1.4, card, line, bodyColor, i+1));
      slide.addText('总结', {x:0.9,y:5.45,w:2.1,h:0.45,fontFace:FONT,fontSize:22,bold:true,color:primary});
      return;
    }
    s.points.slice(0,4).forEach((p,i) => addCard(slide, clean(p), 0.85+(i%2)*5.75, 2.25+Math.floor(i/2)*1.55, 5.0, 1.15, card, line, bodyColor, i+1));
  }

  function addHeader(slide, s, titleColor, bodyColor, primary){
    slide.addText(clean(s.section || ''), {x:0.75,y:0.45,w:3.2,h:0.25,fontFace:FONT,fontSize:9,bold:true,color:primary});
    slide.addText(clean(s.title), {x:0.75,y:0.85,w:10.7,h:0.62,fontFace:FONT,fontSize:24,bold:true,color:titleColor,fit:'shrink'});
    if(s.coreMessage) slide.addText(clean(s.coreMessage), {x:0.78,y:1.55,w:10.4,h:0.42,fontFace:FONT,fontSize:12,color:bodyColor,fit:'shrink'});
  }
  function addFooter(slide, deck, idx, color){
    slide.addText(`${clean(deck.deckTitle || '')} · ${idx+1}/${deck.slides.length}`, {x:0.65,y:7.05,w:7.2,h:0.2,fontFace:FONT,fontSize:7,color});
  }
  function addCard(slide, text, x, y, w, h, fill, line, color, badge){
    slide.addText(text, {x,y,w,h,fontFace:FONT,fontSize:12,bold:true,color,fill:{color:fill},line:{color:line,transparency:10},margin:0.15,fit:'shrink',breakLine:false});
    slide.addText(String(badge), {x:x+0.12,y:y+0.12,w:0.34,h:0.26,fontFace:FONT,fontSize:8,bold:true,color:'FFFFFF',align:'center',valign:'mid',fill:{color:'2563EB'},line:{color:'2563EB'},margin:0.02});
  }
  function addVisualBlock(slide, x, y, w, h, primary, accent, soft, label){
    slide.addText('', {x,y,w,h,fill:{color:soft},line:{color:primary,transparency:15}});
    slide.addText('', {x:x+w*0.08,y:y+h*0.14,w:w*0.48,h:h*0.55,fill:{color:primary,transparency:8},line:{color:primary}});
    slide.addText('', {x:x+w*0.55,y:y+h*0.36,w:w*0.30,h:h*0.30,fill:{color:accent,transparency:5},line:{color:accent}});
    slide.addText(clean(label || 'visual'), {x:x+0.25,y:y+h-0.55,w:w-0.5,h:0.25,fontFace:FONT,fontSize:9,bold:true,color:'FFFFFF',align:'center',fill:{color:primary},margin:0.03});
  }
  function addSceneVisual(slide, s, x, y, w, h, primary, accent, soft){
    try { slide.addImage({data:sceneSvgDataUri(s, primary, accent, soft), x, y, w, h}); }
    catch(e){ addVisualBlock(slide, x, y, w, h, primary, accent, soft, s.title || 'visual'); }
  }
  function renderPptxTable(slide, s, dark, card, line, bodyColor, titleColor, primary){
    const rows = Array.isArray(s.tableRows) && s.tableRows.length ? s.tableRows : [['维度','建议','备注'], ...s.points.slice(0,4).map((p,i)=>['P'+(i+1), p, ''])];
    const maxRows = Math.min(rows.length, 5);
    const cols = Math.min(Math.max(...rows.slice(0,maxRows).map(r=>Array.isArray(r)?r.length:1)), 4);
    const x=0.75, y=2.25, w=11.75, h=4.0, rowH=h/maxRows, colW=w/cols;
    for(let r=0;r<maxRows;r++){
      const row = Array.isArray(rows[r]) ? rows[r] : [rows[r]];
      for(let c=0;c<cols;c++){
        const isHead = r===0;
        slide.addText(clean(row[c] || ''), {x:x+c*colW,y:y+r*rowH,w:colW,h:rowH,fontFace:FONT,fontSize:isHead?10:9,bold:isHead,color:isHead?'FFFFFF':bodyColor,fill:{color:isHead?primary:card},line:{color:line},margin:0.08,fit:'shrink'});
      }
    }
  }
  function renderPptxChart(slide, s, card, line, bodyColor, primary, accent){
    const data = Array.isArray(s.chartData) && s.chartData.length ? s.chartData : s.points.slice(0,5).map((p,i)=>[p, 90-i*12]);
    const vals = data.map(d=>Number(Array.isArray(d)?d[1]:0)||0); const max = Math.max(1,...vals);
    const x=0.85, base=5.75, maxH=2.6, gap=0.35, barW=1.35;
    data.slice(0,6).forEach((d,i)=>{ const label=Array.isArray(d)?d[0]:String(d); const val=Number(Array.isArray(d)?d[1]:0)||0; const h=Math.max(0.18,maxH*val/max); const bx=x+i*(barW+gap); slide.addText('', {x:bx,y:base-h,w:barW,h,fill:{color:i%2?accent:primary},line:{color:i%2?accent:primary}}); slide.addText(String(val), {x:bx,y:base-h-0.28,w:barW,h:0.22,fontFace:FONT,fontSize:9,bold:true,color:bodyColor,align:'center'}); slide.addText(clean(label), {x:bx-0.1,y:base+0.12,w:barW+0.2,h:0.5,fontFace:FONT,fontSize:8,color:bodyColor,align:'center',fit:'shrink'}); });
    addCard(slide, clean(s.coreMessage || s.title), 8.0, 2.55, 3.8, 1.25, card, line, bodyColor, '结论');
  }
  function pptxHex(v){ return hex6(v).toUpperCase(); }
  function isDark(hex){ const h=hex6(hex); const r=parseInt(h.slice(0,2),16), g=parseInt(h.slice(2,4),16), b=parseInt(h.slice(4,6),16); return (r*299+g*587+b*114)/1000 < 120; }

  function buildPackage(zip, deck, theme, options){
    const n = deck.slides.length;
    zip.file('[Content_Types].xml', contentTypes(n));
    zip.folder('_rels').file('.rels', rootRels());
    zip.folder('docProps').file('app.xml', appXml(n));
    zip.folder('docProps').file('core.xml', coreXml(deck));
    const ppt = zip.folder('ppt');
    ppt.file('presentation.xml', presentationXml(n));
    ppt.file('presProps.xml', presPropsXml());
    ppt.file('viewProps.xml', viewPropsXml());
    ppt.file('tableStyles.xml', tableStylesXml());
    ppt.folder('_rels').file('presentation.xml.rels', presentationRels(n));
    ppt.folder('theme').file('theme1.xml', themeXml(theme));
    ppt.folder('slideMasters').file('slideMaster1.xml', slideMasterXml());
    ppt.folder('slideMasters').folder('_rels').file('slideMaster1.xml.rels', slideMasterRels());
    ppt.folder('slideLayouts').file('slideLayout1.xml', slideLayoutXml());
    ppt.folder('slideLayouts').folder('_rels').file('slideLayout1.xml.rels', slideLayoutRels());
    const slides = ppt.folder('slides');
    const slideRels = slides.folder('_rels');
    deck.slides.forEach((s,i)=>{
      slides.file(`slide${i+1}.xml`, slideXml(normalizeSlide(s,i,deck), i, deck, theme, options));
      slideRels.file(`slide${i+1}.xml.rels`, slideRelsXml());
    });
  }

  function slideXml(s, idx, deck, theme, options){
    let id = 2;
    const shapes = [];
    const layout = normalizeLayout(s.layoutType, idx, deck.slides.length);
    shapes.push(rect(id++, 0,0,PPT_W,PPT_H, theme.background, theme.background));
    if((options.mode||'beauty') === 'beauty'){
      shapes.push(rect(id++, 0, 0, 180000, PPT_H, theme.primary, theme.primary));
      shapes.push(rect(id++, PPT_W-1450000, 0, 1450000, PPT_H, theme.soft, theme.soft));
    }
    if(idx === 0 || layout === 'cover') renderCover(shapes, id, s, deck, theme); else
    if(layout === 'section' || layout === 'section_divider') renderSection(shapes, id, s, idx, theme); else
    if(layout === 'timeline' || layout === 'roadmap') renderTimeline(shapes, id, s, theme); else
    if(layout === 'architecture') renderArchitecture(shapes, id, s, theme); else
    if(layout === 'framework') renderFramework(shapes, id, s, theme); else
    if(layout === 'matrix') renderMatrix(shapes, id, s, theme); else
    if(layout === 'comparison') renderComparison(shapes, id, s, theme); else
    if(layout === 'image' || layout === 'gallery') renderImagePage(shapes, id, s, theme); else
    if(layout === 'chart') renderChartPage(shapes, id, s, theme); else
    if(layout === 'table') renderTable(shapes, id, s, theme); else
    if(layout === 'big_number') renderBigNumber(shapes, id, s, idx, theme); else
    if(layout === 'quote') renderQuote(shapes, id, s, theme); else
    if(layout === 'summary' || layout === 'closing') renderSummary(shapes, id, s, idx, deck, theme); else
    if(layout === 'process' || layout === 'process_steps') renderProcess(shapes, id, s, theme); else renderCards(shapes, id, s, theme);
    shapes.push(textBox(9000, clean(deck.deckTitle || '') + ' · ' + (idx+1) + '/' + deck.slides.length, 650000, 6400000, 7800000, 280000, 800, theme.muted, false));
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>${shapes.join('')}</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>`;
  }

  function renderCover(shapes, id, s, deck, theme){
    shapes.push(rect(id++, 760000, 700000, 9800000, 4800000, theme.card, theme.border));
    shapes.push(rect(id++, 760000, 700000, 150000, 4800000, theme.primary, theme.primary));
    shapes.push(textBox(id++, deck.deckTitle || s.title, 1100000, 1250000, 7600000, 1100000, 3000, theme.title, true));
    shapes.push(textBox(id++, deck.subtitle || s.coreMessage || '', 1120000, 2500000, 7400000, 700000, 1500, theme.body, false));
    const tags = [deck.templateType || 'Presentation', deck.audience || '', 'AI生成演示'].filter(Boolean).slice(0,3);
    tags.forEach((t,i)=>{ shapes.push(rect(id++, 1120000+i*2500000, 3650000, 2100000, 450000, theme.soft, theme.border)); shapes.push(textBox(id++, t, 1200000+i*2500000, 3730000, 1950000, 280000, 950, theme.primary, true)); });
  }
  function renderSection(shapes, id, s, idx, theme){
    shapes.push(textBox(id++, String(idx+1).padStart(2,'0'), 950000, 950000, 1200000, 600000, 2200, theme.primary, true));
    shapes.push(textBox(id++, s.section || '章节', 2300000, 980000, 4200000, 380000, 1200, theme.primary, true));
    shapes.push(textBox(id++, s.title, 950000, 2150000, 9000000, 1000000, 2800, theme.title, true));
    shapes.push(textBox(id++, s.coreMessage || s.points[0] || '', 980000, 3350000, 8500000, 700000, 1550, theme.body, false));
    shapes.push(rect(id++, 950000, 5050000, 4100000, 110000, theme.primary, theme.primary));
  }
  function renderCards(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    s.points.slice(0,4).forEach((p,i)=>{ const x=950000+(i%2)*5450000, y=2100000+Math.floor(i/2)*1500000; shapes.push(cardShape(id++, p, x, y, 4850000, 1050000, theme, i+1)); });
  }
  function renderTimeline(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    const pts=s.points.slice(0,5); const y=3500000; const startX=1250000, endX=10850000; shapes.push(lineShape(id++, startX, y, endX-startX, 0, theme.primary, 2));
    pts.forEach((p,i)=>{ const x=startX+i*((endX-startX)/Math.max(1,pts.length-1)); shapes.push(ellipse(id++, x-170000,y-170000,340000,340000,theme.primary,theme.primary)); shapes.push(textBox(id++, String(i+1), x-90000,y-95000,180000,180000,850,theme.onPrimary,true,'center')); const tx=Math.max(650000, Math.min(x-760000, PPT_W-2100000)); shapes.push(textBox(id++, p, tx,y+420000,1700000,950000,880,theme.body,false,'center')); });
  }
  function renderProcess(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    s.points.slice(0,4).forEach((p,i)=>{ const x=900000+i*2850000; shapes.push(rect(id++,x,2800000,2450000,1100000,i%2?theme.card:theme.soft,theme.border)); shapes.push(textBox(id++,p,x+180000,3000000,2100000,650000,1050,theme.body,true,'center')); });
  }
  function renderComparison(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    shapes.push(textBox(id++,'当前/问题',1000000,2150000,4300000,350000,1250,theme.primary,true));
    shapes.push(textBox(id++,'建议/路径',6600000,2150000,4300000,350000,1250,theme.accent,true));
    shapes.push(cardShape(id++,s.points[0]||s.coreMessage,1000000,2750000,4700000,1800000,theme,'A'));
    shapes.push(cardShape(id++,s.points.slice(1).join('\n'),6600000,2750000,4700000,1800000,theme,'B'));
  }
  
  function renderImagePage(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    shapes.push(rect(id++, 900000, 2150000, 6400000, 3300000, theme.soft, theme.border));
    shapes.push(rect(id++, 900000, 4350000, 6400000, 1100000, theme.primary, theme.primary));
    shapes.push(ellipse(id++, 6100000, 2450000, 650000, 650000, theme.accent, theme.accent));
    /* diagonal line removed: negative ext breaks PowerPoint */
    const visualLabel = (s.section || '') + ' · ' + (s.title || '视觉页');
    shapes.push(textBox(id++, visualLabel, 1200000, 4550000, 5600000, 600000, 1350, theme.onPrimary, true, 'center'));
    shapes.push(textBox(id++, (s.imagePlan&&s.imagePlan.scene)?s.imagePlan.scene:'主题视觉场景', 1200000, 5150000, 5600000, 300000, 850, theme.onPrimary, false, 'center'));
    const pts=s.points.slice(0,3);
    pts.forEach((p,i)=>shapes.push(cardShape(id++,p,7900000,2250000+i*1000000,3200000,760000,theme,i+1)));
  }
  function chartRows(s){
    const rows = Array.isArray(s.chartData) ? s.chartData : [];
    return rows.map(r=>Array.isArray(r)?{label:String(r[0]||''), value:Number(r[1]), unit:String(r[2]||'')}:{label:String(r.label||r.name||''), value:Number(r.value), unit:String(r.unit||'')}).filter(r=>r.label && isFinite(r.value));
  }
  function renderChartPage(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    const rows=chartRows(s).slice(0,6);
    if(rows.length < 2){ renderMatrix(shapes,id,s,theme); return; }
    const max=Math.max(...rows.map(r=>Math.abs(r.value)),1);
    const x=950000, baseY=5150000, maxH=2300000, gap=280000, barW=Math.min(1050000, 5600000/rows.length-260000);
    rows.forEach((r,i)=>{ const h=Math.max(260000, maxH*(Math.abs(r.value)/max)); const bx=x+i*(barW+gap); shapes.push(rect(id++, bx, baseY-h, barW, h, i%2?theme.accent:theme.primary, i%2?theme.accent:theme.primary)); shapes.push(textBox(id++, String(r.value)+(r.unit||''), bx-150000, baseY-h-330000, barW+300000, 260000, 900, theme.title, true, 'center')); shapes.push(textBox(id++, r.label, bx-220000, baseY+160000, barW+440000, 600000, 780, theme.body, false, 'center')); });
    shapes.push(lineShape(id++, 800000, baseY, 7000000, 0, theme.border, 1));
    shapes.push(cardShape(id++, s.coreMessage || '数据用于支撑本页判断，不作装饰。', 8450000, 2550000, 3200000, 1750000, theme, '结论'));
  }

  function renderMatrix(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    const rows = (Array.isArray(s.tableRows)&&s.tableRows.length>=2) ? s.tableRows.slice(0,5) : [['维度','选项一','选项二','选项三'], ...(s.points||[]).slice(0,4).map((p,i)=>['判断'+(i+1),p,'',''])];
    const x=800000,y=2150000,w=10600000,h=3600000; const cols=Array.isArray(rows[0])?rows[0].length:3; const colW=w/cols; const rowH=h/rows.length;
    rows.forEach((row,r)=>{ const arr=Array.isArray(row)?row:Object.values(row); for(let c=0;c<cols;c++){ const fill=r===0?theme.primary:(c===0?theme.soft:theme.card); const color=r===0?theme.onPrimary:(c===0?theme.primary:theme.body); shapes.push(rect(id++,x+c*colW,y+r*rowH,colW,rowH,fill,theme.border)); shapes.push(textBox(id++,String(arr[c]||''),x+c*colW+90000,y+r*rowH+90000,colW-180000,rowH-160000,r===0?880:820,color,r===0||c===0,'center')); }});
    shapes.push(textBox(id++, '矩阵用于比较维度，不用伪柱状图。', 900000, 5900000, 7800000, 300000, 780, theme.muted, false));
  }
  function renderArchitecture(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    const pts=(s.points||[]).slice(0,4); const x=2600000,y=2300000,w=5200000,layerH=620000;
    pts.forEach((p,i)=>{ const yy=y+(pts.length-1-i)*layerH; shapes.push(rect(id++,x-i*160000,yy,w+i*320000,520000,i%2?theme.soft:theme.card,theme.border)); shapes.push(textBox(id++,String(pts.length-i),x-i*160000+120000,yy+120000,420000,230000,950,theme.primary,true,'center')); shapes.push(textBox(id++,p,x-i*160000+650000,yy+100000,w+i*320000-850000,250000,930,theme.body,true,'center')); });
    shapes.push(cardShape(id++, s.coreMessage||'用分层结构说明系统如何落地。', 8450000, 2450000, 3000000, 1600000, theme, '价值'));
    shapes.push(cardShape(id++, '入口稳定 · 核心拆分 · 风险可控', 850000, 2650000, 2300000, 1350000, theme, '原则'));
  }
  function renderFramework(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    shapes.push(ellipse(id++,950000,2400000,3000000,1850000,theme.soft,theme.border));
    shapes.push(rect(id++,1120000,3600000,2650000,1450000,theme.primary,theme.primary));
    shapes.push(textBox(id++,'显性问题',1500000,3900000,1800000,320000,1100,theme.onPrimary,true,'center'));
    shapes.push(textBox(id++,'隐藏风险',1550000,2850000,1700000,320000,1050,theme.primary,true,'center'));
    (s.points||[]).slice(0,5).forEach((p,i)=>{ const x=4700000+(i%2)*3400000, y=2200000+Math.floor(i/2)*1050000; shapes.push(cardShape(id++,p,x,y,3000000,820000,theme,i+1)); });
  }

function renderTable(shapes, id, s, theme){
    header(shapes, id, s, theme); id += 3;
    const pts=s.points.slice(0,4); const x=950000,y=2250000,w=10500000,rowH=620000,colW=[1500000,6800000,2200000];
    ['维度','建议','备注'].forEach((t,i)=>{ shapes.push(rect(id++,x+colW.slice(0,i).reduce((a,b)=>a+b,0),y,colW[i],rowH,theme.primary,theme.border)); shapes.push(textBox(id++,t,x+colW.slice(0,i).reduce((a,b)=>a+b,0)+90000,y+130000,colW[i]-180000,300000,1000,theme.onPrimary,true)); });
    pts.forEach((p,r)=>{ ['P'+(r+1),p,r%2?'备选':'推荐'].forEach((t,i)=>{ shapes.push(rect(id++,x+colW.slice(0,i).reduce((a,b)=>a+b,0),y+(r+1)*rowH,colW[i],rowH,r%2?theme.card:theme.soft,theme.border)); shapes.push(textBox(id++,t,x+colW.slice(0,i).reduce((a,b)=>a+b,0)+90000,y+(r+1)*rowH+120000,colW[i]-180000,320000,950,theme.body,false)); }); });
  }
  function renderBigNumber(shapes, id, s, idx, theme){ header(shapes,id,s,theme); id+=3; shapes.push(textBox(id++, extractNumber(s)||String(idx+1), 1000000, 2300000, 2500000, 1500000, 5600, theme.primary, true)); shapes.push(textBox(id++, s.points.join('\n'), 4000000, 2400000, 7000000, 2400000, 1400, theme.body, false)); }
  function renderQuote(shapes, id, s, theme){ header(shapes,id,s,theme); id+=3; shapes.push(textBox(id++,'“',1000000,2100000,700000,700000,4600,theme.accent,true)); shapes.push(textBox(id++,s.coreMessage||s.points[0],1750000,2400000,8500000,1100000,2200,theme.title,true)); shapes.push(textBox(id++,s.points.slice(1).join(' · '),1800000,3800000,8000000,500000,1200,theme.muted,false)); }
  function renderSummary(shapes, id, s, idx, deck, theme){ header(shapes,id,s,theme); id+=3; s.points.slice(0,3).forEach((p,i)=>shapes.push(cardShape(id++,p,1000000+i*3700000,2500000,3200000,1400000,theme,i+1))); shapes.push(textBox(id++, '总结',1000000,5200000,2200000,550000,2100,theme.primary,true)); }

  function header(shapes, id, s, theme){ shapes.push(textBox(id++,s.section||'',900000,560000,2900000,320000,950,theme.primary,true)); shapes.push(textBox(id++,s.title,900000,900000,9800000,720000,2250,theme.title,true)); if(s.coreMessage) shapes.push(textBox(id++,s.coreMessage,920000,1580000,9800000,420000,1150,theme.body,false)); }
  function cardShape(id,text,x,y,w,h,theme,n){ return rect(id,x,y,w,h,theme.card,theme.border)+ellipse(id+1000,x+220000,y+250000,420000,420000,theme.primary,theme.primary)+textBox(id+2000,String(n),x+220000,y+325000,420000,170000,800,theme.onPrimary,true,'center')+textBox(id+3000,text,x+820000,y+230000,w-980000,h-400000,1100,theme.body,true); }

  function rect(id,x,y,w,h,fill,line){ return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="Rect ${id}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${Math.round(x)}" y="${Math.round(y)}"/><a:ext cx="${Math.round(w)}" cy="${Math.round(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${hex6(fill)}"/></a:solidFill><a:ln><a:solidFill><a:srgbClr val="${hex6(line)}"/></a:solidFill></a:ln></p:spPr></p:sp>`; }
  function ellipse(id,x,y,w,h,fill,line){ return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="Ellipse ${id}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${Math.round(x)}" y="${Math.round(y)}"/><a:ext cx="${Math.round(w)}" cy="${Math.round(h)}"/></a:xfrm><a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="${hex6(fill)}"/></a:solidFill><a:ln><a:solidFill><a:srgbClr val="${hex6(line)}"/></a:solidFill></a:ln></p:spPr></p:sp>`; }
  function lineShape(id,x,y,w,h,color,pt){ return `<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="${id}" name="Line ${id}"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x="${Math.round(x)}" y="${Math.round(y)}"/><a:ext cx="${Math.round(w)}" cy="${Math.round(h)}"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="${Math.round((pt||1)*12700)}"><a:solidFill><a:srgbClr val="${hex6(color)}"/></a:solidFill></a:ln></p:spPr></p:cxnSp>`; }
  function textBox(id,text,x,y,w,h,size,color,bold,align){
    const paras = clean(text).split(/\n+/).filter(Boolean).slice(0,8).map(t=>`<a:p><a:pPr algn="${align||'l'}"/><a:r><a:rPr lang="zh-CN" sz="${Math.max(700,Math.round(size||1100))}" b="${bold?1:0}"><a:solidFill><a:srgbClr val="${hex6(color)}"/></a:solidFill><a:latin typeface="${xml(FONT)}"/><a:ea typeface="${xml(FONT)}"/><a:cs typeface="${xml(FONT)}"/></a:rPr><a:t>${xml(t)}</a:t></a:r><a:endParaRPr lang="zh-CN" sz="${Math.max(700,Math.round(size||1100))}"/></a:p>`).join('') || '<a:p/>';
    return `<p:sp><p:nvSpPr><p:cNvPr id="${id}" name="Text ${id}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="${Math.round(x)}" y="${Math.round(y)}"/><a:ext cx="${Math.round(w)}" cy="${Math.round(h)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr wrap="square" rtlCol="0"><a:normAutofit/></a:bodyPr><a:lstStyle/>${paras}</p:txBody></p:sp>`;
  }

  function contentTypes(n){ let slides=''; for(let i=1;i<=n;i++) slides += `<Override PartName="/ppt/slides/slide${i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>`; return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/><Override PartName="/ppt/viewProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"/><Override PartName="/ppt/tableStyles.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>${slides}</Types>`; }
  function rootRels(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>`; }
  function presentationRels(n){ let rels=`<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>`; for(let i=1;i<=n;i++) rels += `<Relationship Id="rId${i+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i}.xml"/>`; rels += `<Relationship Id="rId${n+2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps" Target="presProps.xml"/><Relationship Id="rId${n+3}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps" Target="viewProps.xml"/><Relationship Id="rId${n+4}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles" Target="tableStyles.xml"/>`; return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${rels}</Relationships>`; }
  function presentationXml(n){ let ids=''; for(let i=1;i<=n;i++) ids += `<p:sldId id="${255+i}" r:id="rId${i+1}"/>`; return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" saveSubsetFonts="1"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst>${ids}</p:sldIdLst><p:sldSz cx="${PPT_W}" cy="${PPT_H}" type="wide"/><p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle><a:defPPr><a:defRPr lang="zh-CN"/></a:defPPr></p:defaultTextStyle></p:presentation>`; }
  function emptyRels(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>`; }
  function slideRelsXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>`; }
  function slideMasterRels(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>`; }
  function slideLayoutRels(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>`; }
  function slideMasterXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>`; }
  function slideLayoutXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>`; }
  function themeXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office"><a:themeElements><a:clrScheme name="Office"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="1F2937"/></a:dk2><a:lt2><a:srgbClr val="F8FAFC"/></a:lt2><a:accent1><a:srgbClr val="2563EB"/></a:accent1><a:accent2><a:srgbClr val="0EA5E9"/></a:accent2><a:accent3><a:srgbClr val="F97316"/></a:accent3><a:accent4><a:srgbClr val="10B981"/></a:accent4><a:accent5><a:srgbClr val="8B5CF6"/></a:accent5><a:accent6><a:srgbClr val="64748B"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Microsoft YaHei"/></a:majorFont><a:minorFont><a:latin typeface="Microsoft YaHei"/><a:ea typeface="Microsoft YaHei"/><a:cs typeface="Microsoft YaHei"/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>`; }
  function appXml(n){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>AI PPT Generator</Application><PresentationFormat>Widescreen</PresentationFormat><Slides>${n}</Slides><Notes>0</Notes><HiddenSlides>0</HiddenSlides><AppVersion>16.0000</AppVersion></Properties>`; }
  function coreXml(deck){ const d=new Date().toISOString(); return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>${xml(deck.deckTitle||'AI PPT')}</dc:title><dc:creator>AI PPT Generator</dc:creator><cp:lastModifiedBy>AI PPT Generator</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">${d}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">${d}</dcterms:modified></cp:coreProperties>`; }
  function presPropsXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentationPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>`; }
  function viewPropsXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:viewPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:normalViewPr><p:restoredLeft sz="15620"/><p:restoredTop sz="94660"/></p:normalViewPr></p:viewPr>`; }
  function tableStylesXml(){ return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>`; }

  function normalizeSpec(spec, options){
    if(!spec||!Array.isArray(spec.slides)) throw new Error('OpenAI Slide Spec 无效，缺少 slides。');
    const wanted=options.mode==='beauty'?26:(options.mode==='economic'?16:22);
    const baseSlides=spec.slides.map((s,i)=>normalizeSlide(s,i,options)).filter(s=>!isBadFillerSlide(s));
    let slides=baseSlides;
    const template=(options.template_type||spec.templateType||'').toLowerCase();
    const bad=needsTemplateLift(baseSlides, template, wanted);
    if(bad){ slides = buildTemplateDeck(options, spec, wanted); }
    else { slides = enrichSlides(baseSlides, options).slice(0,wanted); }
    slides = enforceVisualAndChartPolicy(slides, options);
    slides = ensureCountWithoutFiller(slides, options, wanted);
    return {...spec, deckTitle:cleanCn(spec.deckTitle||options.topic||'AI PPT'), subtitle:cleanCn(spec.subtitle||options.brief||''), audience:cleanCn(spec.audience||options.audience||''), templateType:clean(spec.templateType||options.template_type||''), themeHint:clean(spec.themeHint||options.theme||''), slides};
  }

  function normalizeSlide(raw, idx, options){
    raw = raw || {};
    const core=cleanCn(raw.coreMessage||raw.subtitle||raw.summary||'');
    const src=[].concat(Array.isArray(raw.supportingPoints)?raw.supportingPoints:[]).concat(Array.isArray(raw.points)?raw.points:[]).map(cleanCn).filter(Boolean);
    const seen=new Set(); const pts=[];
    src.forEach(v=>{ const k=v.replace(/[\s。,.，]/g,''); if(v && v!==core && !seen.has(k)){ seen.add(k); pts.push(v); } });
    let tableRows=Array.isArray(raw.tableRows)?raw.tableRows:[];
    tableRows=tableRows.map(r=>Array.isArray(r)?r.map(cleanCn):[cleanCn(r)]);
    let chartData=normalizeChartData(Array.isArray(raw.chartData)?raw.chartData:[]);
    let imagePlan=(raw.imagePlan && typeof raw.imagePlan==='object')?raw.imagePlan:{};
    const title=cleanCn(raw.title||`第${idx+1}页`);
    const imageQuery=clean(raw.image_search_query||raw.imageQuery||imagePlan.query||imagePlan.prompt||'');
    return {slideNo:idx+1,section:cleanCn(raw.section||''),layoutType:clean(raw.layoutType||raw.layout||''),title,coreMessage:core||pts[0]||'',points:pts.length?pts.slice(0,5):[],visualType:clean(raw.visualType||''),visualIntent:cleanCn(raw.visualIntent||''),codeBlock:clean(raw.codeBlock||raw.code||''),tableRows,chartData,imagePlan,image_search_query:imageQuery,chartSuggestion:raw.chartSuggestion||raw.chartSpec||{},codeNotes:Array.isArray(raw.codeNotes)?raw.codeNotes.map(cleanCn):[],speakerNote:cleanCn(raw.speakerNote||''),designSpec:(raw.designSpec&&typeof raw.designSpec==='object')?raw.designSpec:{},thinkAboutIt:cleanCn(raw.thinkAboutIt||''),exerciseAnswer:raw.exerciseAnswer||''};
  }

  function cleanCn(v){
    let t=cleanForbidden(v||'');
    t=String(t).replace(/\bCEO\b/g,'管理层').replace(/\bCTO\b/g,'技术负责人').replace(/\bROI\b/g,'投资回报').replace(/OpenAI|Planner|Renderer|Agent|Pipeline|Prompt|Slide Spec|token|cost|fallback|client|image prompt|visual generated|no fake photo source/ig,'').replace(/\bAPI\b/g,'接口').replace(/\bJava\b/g,'Java').replace(/\bGo\b/g,'Go').replace(/\bRust\b/g,'Rust');
    const ascii=(t.match(/[A-Za-z]/g)||[]).length, zh=(t.match(/[\u4e00-\u9fff]/g)||[]).length;
    if(ascii>30 && zh<4) return '根据本页主题给出具体说明';
    return t.trim();
  }
  function normalizeChartData(rows){
    if(!Array.isArray(rows)) return [];
    const out=[];
    rows.forEach(r=>{
      if(Array.isArray(r)){
        const label=cleanCn(r[0]||'指标');
        let val=Number(r[1]);
        if(!isFinite(val)){ const m=String(r[1]||'').match(/-?\d+(\.\d+)?/); val=m?Number(m[0]):NaN; }
        if(isFinite(val)) out.push([label,val,cleanCn(r[2]||'')]);
      }else if(r && typeof r==='object'){
        const label=cleanCn(r.label||r.name||r.metric||'指标');
        const val=Number(r.value||r.score||r.percent||r.amount);
        if(isFinite(val)) out.push([label,val,cleanCn(r.unit||r.note||'')]);
      }
    });
    return out.slice(0,6);
  }
  function chartIsValid(data){ return Array.isArray(data) && data.filter(r=>Array.isArray(r)&&isFinite(Number(r[1]))).length>=2; }
  function enforceVisualAndChartPolicy(slides, options){
    slides.forEach(s=>{
      const ct=(s.chartSuggestion&&String(s.chartSuggestion.chartType||s.chartSuggestion.chart_type||''))||'';
      if((/matrix|矩阵|对比/.test(ct)||/矩阵/.test(s.title))&&!chartIsValid(s.chartData)){s.layoutType='matrix';s.visualType='matrix';s.chartData=[];}
      if((s.layoutType==='chart'||s.visualType==='chart')&&!chartIsValid(s.chartData)){s.layoutType=s.tableRows&&s.tableRows.length?'table':'cards';s.visualType=s.layoutType;s.chartData=[];}
    });
    const need=options.mode==='beauty'?5:(options.mode==='economic'?2:3);
    let count=slides.filter(s=>['image','gallery'].includes(s.layoutType)||['image','gallery'].includes(s.visualType)).length;
    const cands=slides.map((s,i)=>[s,i]).filter(([s,i])=>i>1&&i<slides.length-2&&!s.codeBlock&&!(s.tableRows&&s.tableRows.length)&&s.layoutType!=='chart');
    let ptr=0;
    while(count<need&&ptr<cands.length){
      const [s,i]=cands[ptr];
      if(i%4===0||count===0){
        s.layoutType='image';s.visualType='image';
        s.image_search_query=s.image_search_query||visualQuery(options,s);
        s.imagePlan=s.imagePlan||{};s.imagePlan.query=s.imagePlan.query||s.image_search_query;s.imagePlan.scene=s.imagePlan.scene||`${s.title}的主题配图`;s.imagePlan.prompt=s.imagePlan.prompt||visualQuery(options,s);
        count++;
      }
      ptr++;
    }
    return slides;
  }
  function visualQuery(options,s){
    const all=`${options.topic||''} ${options.template_type||''} ${s.section||''} ${s.title||''}`;
    if(/咖啡|coffee/i.test(all)) return 'coffee beans roasting tasting cupping warm cafe photography';
    if(/Rust|订单|系统|投资|架构/i.test(all)) return 'ecommerce order system architecture dashboard server operations abstract';
    if(/Python|编程|代码|自动化/i.test(all)) return 'python programming code laptop automation workspace';
    if(/复盘|年度|计划|成长/i.test(all)) return 'annual review planning notebook goals workspace';
    if(/京都|旅行|清水寺|岚山/i.test(all)) return 'Kyoto travel landmark street temple bamboo forest';
    return 'professional presentation visual abstract business workspace';
  }

  function isBadFillerSlide(s){
    const t=(s.section+' '+s.title+' '+s.coreMessage+' '+s.points.join(' ')).toLowerCase();
    return /补充建议|补充说明|补充一个可执行判断|可执行判断点|补充背景|背景判断|深化页|按场景判断|明确下一步行动|给出可执行检查点/.test(t) || (s.title==='谢谢' && s.points.length<2);
  }
  function needsTemplateLift(slides, template, wanted){
    if(slides.length < wanted-2) return true;
    const text=slides.map(s=>[s.title,s.coreMessage].concat(s.points).join('|')).join('\n');
    if(/补充建议|补充说明|P1|P2|Prompt|视觉主图|场景氛围|关键画面/.test(text)) return true;
    const unique=new Set(slides.map(s=>clean(s.coreMessage).replace(/[\s。,.，]/g,''))).size;
    if(unique < Math.max(8, slides.length*0.55)) return true;
    if(template.includes('educational') && !/for |def |import |print\(|\.py|代码/.test(text)) return true;
    if(template.includes('travel') && !/Daiwa Roynet|Cross Hotel|Celestine|四条|河原町|京都站|岚山竹林|清水寺/.test(text)) return true;
    if(template.includes('executive') && !/架构|ROI|延迟|吞吐|风险|成本|迁移/.test(text)) return true;
    return false;
  }

  function mk(section, layoutType, title, coreMessage, points, extra={}){ return {section, layoutType, title, coreMessage, points:(points||[]).filter(Boolean), ...extra}; }
  function contains(text, re){ return re.test(String(text||'').toLowerCase()); }
  function inferDestination(topic){ return clean(topic).replace(/路线|攻略|两日游|三日游|自由行|：.*/g,'').replace(/^.*从/,'').replace(/到.*$/,'') || clean(topic).split(/[：:]/)[0] || '目的地'; }
  function isPythonTopic(options){ return /python|自动化脚本|编程|代码/.test((options.topic+' '+options.brief).toLowerCase()); }
  function buildTemplateDeck(options, spec, wanted){
    const template=(options.template_type||spec.templateType||'proposal').toLowerCase();
    if(template.includes('educational')) return buildEducationDeck(options,wanted);
    if(template.includes('travel')) return buildTravelDeck(options,wanted);
    if(template.includes('executive')) return buildExecutiveDeck(options,wanted);
    if(template.includes('decision')) return buildDecisionDeck(options,wanted);
    if(template.includes('annual')) return buildReviewDeck(options,wanted);
    return buildProposalDeck(options,wanted);
  }

  function buildEducationDeck(o,wanted){
    const python=isPythonTopic(o);
    const title=o.topic||'课程演示';
    const slides=[
      mk('', 'cover', title, o.brief||'从概念到实操，完成一个可交付的小作品。', []),
      mk('目标','cards','学习目标','不是听懂概念，而是能做出一个小作品。',['理解变量/循环/函数/列表/字典的用途','能看懂并改动简单代码','完成第一个文件整理自动化脚本','知道常见错误和调试方法']),
      mk('地图','process','知识地图','先建立概念关系，再逐个攻破。',['变量：给数据起名字','循环：重复动作自动化','函数：把步骤封装成工具','列表/字典：组织多条数据']),
      mk('核心概念','code','变量与数据类型','变量是程序里保存信息的标签。',['字符串适合保存文件名','列表适合保存多个文件','字典适合保存分类规则'], python?{codeBlock:"# 变量：给数据起名字\nfile_name = 'photo.jpg'\nfile_type = 'image'\nsize_kb = 532\nprint(file_name, file_type, size_kb)"}:{}),
      mk('核心概念','code','循环结构','for 循环用于遍历一批对象，while 用于条件持续执行。',['for：遍历文件列表','while：等待任务完成或重试','break/continue：控制流程'], python?{codeBlock:"items = ['a.pdf', 'photo.jpg', 'data.xlsx']\nfor name in items:\n    if name.endswith('.pdf'):\n        print(name, '-> PDF文档')\n    elif name.endswith('.jpg'):\n        print(name, '-> 图片')\n    else:\n        print(name, '-> 其他')"}:{}),
      mk('核心概念','code','函数基础','函数把重复步骤封装成可复用工具。',['输入参数：文件名','内部逻辑：判断扩展名','返回结果：分类名称'], python?{codeBlock:"def classify_file(name):\n    if name.endswith(('.jpg', '.png')):\n        return 'images'\n    if name.endswith(('.pdf', '.docx')):\n        return 'docs'\n    return 'others'\n\nprint(classify_file('photo.jpg'))"}:{}),
      mk('核心概念','code','列表与字典','列表保存文件集合，字典保存分类规则。',['列表：按顺序存多个文件','字典：扩展名到文件夹的映射','组合使用：批量分类'], python?{codeBlock:"rules = {\n    '.jpg': 'images',\n    '.png': 'images',\n    '.pdf': 'docs',\n    '.xlsx': 'sheets'\n}\nprint(rules.get('.pdf', 'others'))"}:{}),
      mk('小项目','process','自动化脚本需求','先把需求拆成可编码步骤。',['扫描目标文件夹','识别文件扩展名','创建分类目录','移动文件并输出结果']),
      mk('小项目','code','完整脚本示例','这个脚本能把文件按类型移动到对应文件夹。',['读取 downloads 目录','按后缀分类','自动创建目标目录','移动文件'], python?{codeBlock:"from pathlib import Path\nimport shutil\n\nsource = Path('downloads')\nrules = {'.jpg':'images', '.png':'images', '.pdf':'docs', '.xlsx':'sheets'}\n\nfor file in source.iterdir():\n    if not file.is_file():\n        continue\n    folder = rules.get(file.suffix.lower(), 'others')\n    target_dir = source / folder\n    target_dir.mkdir(exist_ok=True)\n    shutil.move(str(file), str(target_dir / file.name))\n    print(f'{file.name} -> {folder}')"}:{}),
      mk('小项目','timeline','实现步骤','从最小可运行版本开始，逐步加功能。',['第1步：准备测试文件夹','第2步：写分类规则字典','第3步：遍历文件并打印结果','第4步：确认无误后移动文件','第5步：增加异常处理']),
      mk('小项目','code','运行效果展示','运行前散乱，运行后按 images/docs/sheets/others 分类。',['downloads/photo.jpg → images/photo.jpg','downloads/a.pdf → docs/a.pdf','downloads/data.xlsx → sheets/data.xlsx'], python?{codeBlock:"# 运行前\ndownloads/\n  photo.jpg\n  a.pdf\n  data.xlsx\n\n# 运行后\ndownloads/images/photo.jpg\ndownloads/docs/a.pdf\ndownloads/sheets/data.xlsx"}:{}),
      mk('练习','cards','变量练习','把抽象概念变成可操作任务。',['定义 file_name 并打印','把 size 从字符串转成数字','用 f-string 输出一句说明','修改变量观察输出变化']),
      mk('练习','code','循环练习','用循环处理一组文件名。',['遍历文件名列表','统计图片数量','跳过临时文件','输出分类结果'], python?{codeBlock:"files = ['a.tmp', 'cat.jpg', 'report.pdf', 'dog.png']\nimage_count = 0\nfor name in files:\n    if name.endswith('.tmp'):\n        continue\n    if name.endswith(('.jpg', '.png')):\n        image_count += 1\nprint('图片数量:', image_count)"}:{}),
      mk('练习','code','函数练习','把判断逻辑改成函数，减少重复代码。',['写 classify_file(name)','返回 images/docs/others','用多个文件名测试','观察返回结果'], python?{codeBlock:"def classify_file(name):\n    suffix = name.split('.')[-1]\n    if suffix in ['jpg', 'png']:\n        return 'images'\n    if suffix in ['pdf', 'docx']:\n        return 'docs'\n    return 'others'\n\nfor f in ['a.pdf', 'cat.jpg', 'readme.txt']:\n    print(f, classify_file(f))"}:{}),
      mk('错误','table','常见错误与修复','初学者最容易卡在语法、缩进和路径。',[],{tableRows:[['问题','表现','修复'],['忘记冒号','SyntaxError','检查 if/for/def 结尾'],['缩进混乱','IndentationError','统一4个空格'],['路径不存在','FileNotFoundError','先判断 Path.exists()'],['覆盖文件','目标已有同名文件','移动前检查并重命名']]}),
      mk('错误','code','异常处理','真实脚本必须处理文件不存在和移动失败。',['try/except 捕获错误','打印出错文件名','不中断整个批处理'], python?{codeBlock:"try:\n    shutil.move(str(file), str(target_dir / file.name))\nexcept Exception as e:\n    print('移动失败:', file.name, e)"}:{}),
      mk('总结','summary','知识点回顾','核心能力是把重复任务变成可执行步骤。',['变量保存数据','循环批量处理','函数封装规则','列表/字典组织文件和规则']),
      mk('下一步','cards','后续学习路径','从文件脚本继续扩展到更完整的自动化。',['学习 pathlib 的更多用法','增加日志文件','做命令行参数','学习模块和包管理'])
    ];
    return ensureCountWithoutFiller(slides,o,wanted);
  }

  function buildTravelDeck(o,wanted){
    const title=o.topic||'京都两日游路线：从清水寺到岚山';
    const slides=[
      mk('', 'cover', title, '自由行不是景点堆叠，而是把路线、住宿、交通、餐饮和拍照时段排顺。', []),
      mk('总览','timeline','两日路线总览','Day1 走东山清水寺到祇园河原町；Day2 走岚山到锦市场，减少跨区折返。',['Day1 上午：清水寺、二年坂、三年坂','Day1 下午：八坂神社、花见小路、鸭川','Day2 上午：岚山竹林、天龙寺、渡月桥','Day2 下午：锦市场/京都站返程缓冲']),
      mk('路线','timeline','Day1 上午：清水寺先打卡','08:00 前到清水寺，先拍主舞台和京都街景，再慢走二年坂三年坂。',['07:30–08:00 从酒店出发','08:15–09:45 清水寺主舞台/音羽瀑布','10:00–11:30 二年坂、三年坂、八坂塔','11:30–12:30 清水坂周边轻食或咖啡']),
      mk('路线','timeline','Day1 下午：祇园到河原町','下午不再跨大区，沿八坂神社、花见小路、鸭川走到河原町吃晚餐。',['13:30–14:20 八坂神社/圆山公园','14:40–16:00 花见小路与祇园小巷','16:30–17:30 鸭川散步拍夕阳','18:00 河原町/先斗町晚餐']),
      mk('路线','timeline','Day2 上午：岚山核心段','岚山必须早到，顺序是竹林小径、天龙寺、渡月桥，避免中午人潮。',['08:00 JR/阪急前往岚山','08:45–09:30 竹林小径','09:40–10:40 天龙寺庭园','11:00–12:00 渡月桥与桂川']),
      mk('路线','timeline','Day2 下午：市区收尾','下午回锦市场/四条河原町购物吃小食，最后留足去京都站或机场线时间。',['13:30 返回四条/京都站方向','14:30–16:00 锦市场小食与伴手礼','16:00–17:30 酒店取行李/咖啡休息','18:00 后返程或晚餐']),
      mk('住宿','table','具体酒店建议','住宿不只看价格，要看第一天清水寺和第二天岚山的交通成本。',[],{tableRows:[['区域','具体酒店','适合人群'],['京都站','Daiwa Roynet Hotel Kyoto Ekimae','第一次来/带行李/返程早'],['四条河原町','Cross Hotel Kyoto','晚上吃饭购物/两日均衡'],['祇园清水','Hotel The Celestine Kyoto Gion','想拍清晨清水寺/情侣'],['预算替代','Sotetsu Fresa Inn Kyoto-Kiyomizu Gojo','预算敏感/交通仍方便']]}),
      mk('住宿','matrix','住宿区域选择逻辑','最推荐四条河原町：Day1 晚餐方便，Day2 去岚山和京都站都不算绕。',['京都站：交通最稳，但夜间氛围弱一点','四条河原町：餐饮购物最方便，综合最优','祇园清水：拍照好但价格更高，拖行李麻烦','五条/乌丸：价格更稳，适合预算控制']),
      mk('交通','table','交通执行表','不要现场临时想路线，提前锁定三段关键交通即可。',[],{tableRows:[['路段','建议方式','预估时间'],['京都站/四条 → 清水寺','公交或出租车','25–40分钟'],['祇园 → 河原町','步行','15–25分钟'],['四条/京都站 → 岚山','阪急或JR嵯峨野线','25–45分钟'],['岚山 → 锦市场','JR/阪急+步行','40–55分钟']]}),
      mk('预算','chart','舒适版预算结构','这张图只表达预算结构：住宿最大，餐饮第二，交通和门票不是主要矛盾。',['住宿 ¥30,000','餐饮 ¥12,000','交通 ¥3,000','门票体验 ¥4,500','备用金 ¥6,000'],{chartData:[['住宿',30000],['餐饮',12000],['交通',3000],['门票体验',4500],['备用金',6000]]}),
      mk('餐饮','cards','餐饮落点建议','餐厅不要脱离路线：Day1 晚餐放河原町，Day2 午餐放岚山或回锦市场。',['清水寺周边：轻食/咖啡，避免正餐排长队','河原町/先斗町：晚餐选择最多','岚山：午餐要错峰或准备便利店备选','锦市场：适合小食和伴手礼，不适合重餐']),
      mk('拍照','image','清水寺主视觉','旅行杂志感的第一张图必须是清水寺，不要用旅行社门店或无关室内图。',['清晨光线最好，游客较少','构图包括木舞台、京都城景和远山','人物比例不要太大，保留地点识别度'],{image_search_query:'Kiyomizu-dera Temple Kyoto sunrise wooden stage',imagePlan:{image_prompt:'Kiyomizu-dera Temple wooden stage at sunrise in Kyoto, editorial travel photography, ultra wide angle, no text, no watermark'}}),
      mk('拍照','image','二年坂三年坂街巷','这页要体现京都街巷纵深和传统木屋，而不是普通商业街。',['适合上午10点前或傍晚','画面重点是坡道、木屋、行人尺度','避开过度拥挤时段'],{image_search_query:'Ninenzaka Sannenzaka Kyoto historic street',imagePlan:{image_prompt:'Ninenzaka and Sannenzaka historic streets in Kyoto, traditional wooden houses, morning light, editorial travel photography'}}),
      mk('拍照','image','祇园花见小路夜景','夜景页用灯笼、石板路、木格窗建立氛围。',['日落后30分钟最适合','不要强行拍艺伎，尊重当地规则','构图以街巷和灯光为主'],{image_search_query:'Gion Hanamikoji Kyoto dusk lanterns',imagePlan:{image_prompt:'Gion Hanamikoji street in Kyoto at dusk, lanterns, traditional wooden buildings, cinematic travel photography'}}),
      mk('拍照','image','岚山竹林小径','岚山页必须使用竹林或渡月桥，建立第二天自然线记忆点。',['08:30 前到达体验最好','竖向构图突出竹林高度','人多时用低角度或局部构图'],{image_search_query:'Arashiyama bamboo grove Kyoto morning',imagePlan:{image_prompt:'Arashiyama bamboo grove in Kyoto early morning, vertical composition, cinematic travel photography, no text'}}),
      mk('拍照','image','渡月桥与桂川','渡月桥适合做收束页：视野开阔、体力放松、辨识度高。',['下午光线更柔和','桥、河、山三层画面最稳','适合作为Day2结束前照片'],{image_search_query:'Togetsukyo Bridge Arashiyama Kyoto Katsura River',imagePlan:{image_prompt:'Togetsukyo Bridge and Katsura River in Arashiyama Kyoto, soft afternoon light, editorial travel photo'}}),
      mk('图表','chart','人流风险热力图','图表表达的是排队风险，不是为了凑视觉。',['清水寺 90','岚山竹林 85','锦市场 80','祇园 65','京都站 50'],{chartData:[['清水寺',90],['岚山竹林',85],['锦市场',80],['祇园',65],['京都站',50]]}),
      mk('避坑','matrix','不要硬塞伏见稻荷','两日路线已经覆盖东山和岚山，伏见稻荷会显著增加折返和体力成本。',['硬塞伏见稻荷：交通折返多，拍照也拥挤','替代方案：下次单独半日，或删掉锦市场','体力不足：保留清水寺+岚山，删购物','雨天：保留清水寺街区，缩短岚山户外时间']),
      mk('备选','table','雨天/高温降级方案','旅行计划必须有降级版本，否则现场容易乱。',[],{tableRows:[['情况','删除项','替代项'],['小雨','减少岚山户外停留','茶室/京都站商场'],['大雨','取消竹林深度游','京都国立博物馆/购物'],['高温','减少午后步行','酒店休息+傍晚出门'],['体力不足','删锦市场','直接返程/咖啡休息']]}),
      mk('清单','table','出发前检查清单','清单页要让观众拿着就能出发。',[],{tableRows:[['类别','必备项','原因'],['证件预订','护照/酒店/门票截图','网络差时可用'],['交通','IC卡/零钱/离线地图','公交地铁更顺'],['装备','舒适鞋/雨具/充电宝','京都步行多'],['餐饮','2家午餐备选','避开排队失控']]}),
      mk('总结','summary','最终推荐路线','住四条河原町，Day1东山祇园，Day2岚山锦市场，是第一次京都两日游最稳组合。',['路线顺：东山一条线、岚山一条线','住宿稳：四条河原町兼顾夜生活和交通','照片稳：清水寺、街巷、祇园、竹林、渡月桥都有','预算稳：住宿提前锁定，餐饮保持备选']),
      mk('Q&A','closing','现场调整规则','天气差删拍照点，人多删网红餐厅，体力差优先保留清水寺和岚山。',['保留：清水寺、二年坂三年坂、岚山竹林','可删：锦市场、网红餐厅、过多购物','可换：出租车替代复杂公交','原则：每天只保留一条主线'])
    ];
    return ensureCountWithoutFiller(slides,o,wanted);
  }

  function buildExecutiveDeck(o,wanted){
    const title=o.topic||'业务决策汇报';
    const slides=[
      mk('', 'cover', title, o.brief||'用业务损失、技术方案、ROI和风险控制支持管理层决策。', []),
      mk('结论','big_number','建议批准一期PoC','先用90天验证性能收益，再决定全面迁移。',['一期目标：核心链路延迟下降50%','业务不中断：保留回滚路径','预算可控：先压测和灰度，不一次性重写','决策点：90天后按数据继续/暂停']),
      mk('业务损失','chart','当前损失在哪里','技术问题已经开始转化为订单损失和人工成本。',['高峰超时率 15%','交易失败率 5%','故障排查 40人时/月','客服投诉 +20%'],{chartData:[['超时率',15],['失败率',5],['投诉增长',20],['排查人时',40]]}),
      mk('技术瓶颈','process','现有链路瓶颈','瓶颈集中在同步处理、资源竞争和观测不足。',['订单入口压力集中','服务层阻塞调用变多','数据库写入等待拉长','监控只能看到结果，看不到原因']),
      mk('目标架构','process','Rust重构目标架构','用Rust承接高并发核心链路，外围系统保持兼容。',['API Gateway 保持入口稳定','Rust Order Core 处理下单核心','Async Queue 削峰填谷','PostgreSQL 保留数据一致性','Observability 贯穿链路']),
      mk('数据流','timeline','订单处理数据流','把高峰请求拆成可观测、可回滚的步骤。',['接收订单请求','校验库存/价格','写入订单核心表','异步触发支付/通知','监控指标回传']),
      mk('收益','chart','性能收益预估','收益必须用指标而不是技术口号表达。',['响应时间 2.0s → 0.8s','吞吐 800/min → 2400/min','错误率 5% → 1%','恢复时间 45min → 10min'],{chartData:[['延迟改善',60],['吞吐提升',200],['错误率下降',80],['恢复时间下降',78]]}),
      mk('ROI','table','ROI测算逻辑','ROI来自损失减少、运维节省和增长承载。',[],{tableRows:[['项目','估算口径','业务价值'],['订单挽回','减少超时/失败订单','提升收入稳定性'],['运维节省','减少故障排查人时','释放工程团队'],['增长承载','高峰容量提升','支撑促销和峰值活动'],['风险下降','减少宕机和赔付','保护品牌信任']]}),
      mk('风险','matrix','风险矩阵','主动说明风险，比回避风险更容易获得批准。',['范围失控：冻结一期边界','性能不达标：先建基准测试','业务中断：灰度+回滚','团队不熟Rust：培训+Code Review']),
      mk('迁移','timeline','90天迁移计划','用短周期证明价值，避免大爆炸式重写。',['0–15天：现状压测和基准线','16–45天：订单核心PoC','46–70天：影子流量验证','71–90天：灰度上线和复盘']),
      mk('治理','table','验收指标','没有指标就无法判断投资是否成功。',[],{tableRows:[['指标','当前基线','90天目标'],['P95延迟','2.0s','<0.8s'],['交易失败率','5%','<1%'],['吞吐能力','800/min','2400/min'],['故障恢复','45min','<10min']]}),
      mk('决策','summary','需要管理层批准什么','请求批准的是一期可验证PoC，不是无限期重写。',['批准90天PoC范围','确认跨部门负责人','允许灰度环境和压测资源','90天按指标决定下一阶段'])
    ];
    return ensureCountWithoutFiller(slides,o,wanted);
  }
  function buildDecisionDeck(o,wanted){
    const slides=[mk('', 'cover', o.topic||'选择指南', o.brief||'', []),mk('框架','matrix','先确定选择维度','用可比较标准替代感觉判断。',['预算','偏好/口味','使用场景','风险/避坑']),mk('对比','table','候选方案对比','把选项放到同一张表里。',[],{tableRows:[['选项','适合人群','注意点'],['入门型','第一次尝试','价格友好但上限低'],['均衡型','日常使用','综合体验稳定'],['高端型','明确偏好','成本更高']] }),mk('路径','timeline','购买/选择路径','先小成本试错，再稳定复购。',['明确预算','选择2–3个候选','小规格试用','记录体验','确定长期选择']),mk('避坑','cards','常见误区','避免被单一标签误导。',['不要只看销量','不要只看包装','不要一次买太多','保留试错记录']),mk('总结','summary','最终建议','选择的关键是匹配场景，而不是追求最贵。',['先定需求','再做对比','最后小步试错'])];
    return ensureCountWithoutFiller(slides,o,wanted);
  }
  function buildReviewDeck(o,wanted){ const slides=[mk('', 'cover', o.topic||'复盘', o.brief||'', []),mk('主线','timeline','年度主线','先用一条主线串起全年。',['上半年探索','中期调整','下半年聚焦','年底沉淀']),mk('成果','cards','三件成果','成果要写结果和证据。',['成果一：可量化结果','成果二：关键突破','成果三：能力沉淀']),mk('问题','matrix','三个坑和反思','复盘价值来自看清代价。',['目标不清','节奏失控','复盘不足']),mk('计划','timeline','下一年行动','把愿望改成行动。',['Q1打基础','Q2形成成果','Q3放大优势','Q4复盘迭代']),mk('总结','summary','复盘结论','保留有效方法，停止低效动作。',['继续做','停止做','开始做'])]; return ensureCountWithoutFiller(slides,o,wanted); }
  function buildProposalDeck(o,wanted){ const slides=[mk('', 'cover', o.topic||'方案', o.brief||'', []),mk('背景','cards','为什么要做','先说明问题和目标。',['业务背景','用户痛点','当前限制','机会窗口']),mk('方案','process','方案流程','把方案拆成可执行模块。',['输入','处理','验证','输出']),mk('价值','chart','价值指标','用指标表达方案价值。',['效率提升','成本下降','体验提升','风险降低'],{chartData:[['效率',35],['成本',20],['体验',30],['风险',25]]}),mk('风险','matrix','风险与取舍','说明边界和兜底。',['范围风险','技术风险','运营风险','时间风险']),mk('下一步','summary','下一步行动','把方案落到执行。',['确认范围','安排负责人','启动试点'])]; return ensureCountWithoutFiller(slides,o,wanted); }

  function enrichSlides(slides, options){ return slides.map((s,i)=>{
    const t=(s.title+' '+s.section+' '+options.topic).toLowerCase();
    if(!s.codeBlock && /python|代码|脚本|循环|函数/.test(t)){
      if(/循环/.test(t)) s.codeBlock="items = ['a.pdf', 'photo.jpg', 'data.xlsx']\nfor name in items:\n    if name.endswith('.pdf'):\n        print(name, '-> PDF文档')\n    elif name.endswith('.jpg'):\n        print(name, '-> 图片')\n    else:\n        print(name, '-> 其他')";
      else if(/函数/.test(t)) s.codeBlock="def classify_file(name):\n    if name.endswith(('.jpg', '.png')):\n        return 'images'\n    if name.endswith(('.pdf', '.docx')):\n        return 'docs'\n    return 'others'";
      else if(/脚本|项目/.test(t)) s.codeBlock="from pathlib import Path\nimport shutil\nsource = Path('downloads')\nrules = {'.jpg':'images', '.pdf':'docs', '.xlsx':'sheets'}\nfor file in source.iterdir():\n    if file.is_file():\n        folder = rules.get(file.suffix.lower(), 'others')\n        target = source / folder\n        target.mkdir(exist_ok=True)\n        shutil.move(str(file), str(target / file.name))";
      s.layoutType='code';
    }
    return s;
  }); }

  function ensureCountWithoutFiller(slides, options, wanted){
    let out=slides.filter(s=>!isBadFillerSlide(s)).map((s,i)=>normalizeSlide(s,i));
    const addPool = buildExtraPool(options).map((s,i)=>normalizeSlide(s,i));
    let idx=0; const keySet=new Set(out.map(s=>(s.section+'|'+s.title).toLowerCase()));
    while(out.length<wanted && idx<addPool.length){ const s=addPool[idx++]; const k=(s.section+'|'+s.title).toLowerCase(); if(!keySet.has(k)){ keySet.add(k); out.push(s); } }
    if(out.length>wanted) out=out.slice(0,wanted);
    return out.map((s,i)=>({...s, slideNo:i+1}));
  }
  function buildExtraPool(o){
    // v20: no recursive calls here. build*Deck() calls ensureCountWithoutFiller(),
    // and ensureCountWithoutFiller() calls buildExtraPool(); recursion caused the browser error.
    const t=(o.template_type||'').toLowerCase();
    if(t.includes('travel')) return [
      mk('住宿','table','住宿区域选择','优先选择交通稳定、晚间餐饮方便的区域。',[],{tableRows:[['区域','参考预算','适合人群'],['交通枢纽周边','参考估算 ¥600–1200/晚','第一次自由行/带行李'],['核心商圈','参考估算 ¥800–1600/晚','夜间餐饮购物'],['景区周边','参考估算 ¥1200–2500/晚','拍照/度假'],['外围安静区','参考估算 ¥500–900/晚','预算敏感/安静休息']]}),
      mk('餐饮','cards','餐饮与休息安排','把餐饮点嵌入路线，减少临时搜索。',['早餐靠近住宿解决','午餐准备2家备选','晚餐回到住宿/商圈附近','网红店只作备选']),
      mk('预算','chart','预算拆分','预算为参考估算，真实价格需按日期核验。',['交通','门票体验','餐饮','住宿','备用金'],{chartData:[['交通',1800],['门票体验',2800],['餐饮',9000],['住宿',16000],['备用金',3000]]}),
      mk('备选','cards','雨天与体力不足方案','提前准备降级方案，现场才不会乱。',['雨天转室内博物馆/商场/茶室','体力不足减少跨区移动','下午保留一个可删除项目','晚上就近吃饭避免再跨区'])
    ];
    if(t.includes('educational')) return [
      mk('代码','code','最小可运行示例','先给能运行的代码，再解释概念。',['运行后能看到输出','每行代码只讲一个作用','允许学员先复制再修改'],{codeBlock:`items = ['a.pdf', 'photo.jpg', 'data.xlsx']
for name in items:
    if name.endswith('.pdf'):
        print(name, '-> PDF文档')
    elif name.endswith('.jpg'):
        print(name, '-> 图片')
    else:
        print(name, '-> 其他')`}),
      mk('项目','code','完整文件整理脚本','把变量、循环、函数和字典串成一个小项目。',['扫描目录','按扩展名分类','自动创建文件夹','移动文件'],{codeBlock:`from pathlib import Path
import shutil

source = Path('downloads')
rules = {'.jpg':'images', '.png':'images', '.pdf':'docs', '.xlsx':'sheets'}

for file in source.iterdir():
    if not file.is_file():
        continue
    folder = rules.get(file.suffix.lower(), 'others')
    target = source / folder
    target.mkdir(exist_ok=True)
    shutil.move(str(file), str(target / file.name))
    print(f'{file.name} -> {folder}')`}),
      mk('练习','cards','课堂练习','每个概念都配一个立即可做的练习。',['改文件类型映射','增加 mp3 分类','统计移动文件数量','处理重名文件']),
      mk('错误','table','常见错误与修复','把常见报错转成检查清单。',[],{tableRows:[['问题','表现','修复'],['忘记冒号','SyntaxError','检查 if/for/def 结尾'],['缩进不一致','IndentationError','统一4个空格'],['路径不存在','FileNotFoundError','先判断 Path.exists()'],['文件重名','移动失败/覆盖风险','移动前重命名']]})
    ];
    if(t.includes('executive')||t.includes('proposal')) return [
      mk('架构','process','目标架构图','用分层图说明方案如何落地。',['订单入口保持稳定','Rust服务承接高并发核心链路','数据库写入保留兼容层','监控和回滚贯穿全程']),
      mk('指标','chart','性能收益指标','用指标证明项目不是技术炫技。',['响应时间','吞吐量','错误率','恢复时间'],{chartData:[['响应时间下降',50],['吞吐提升',120],['错误率下降',70],['恢复时间下降',60]]}),
      mk('风险','table','风险与缓解','主动说明风险比回避风险更可信。',[],{tableRows:[['风险','影响','缓解'],['范围失控','延期/超预算','冻结一期边界'],['性能不达标','ROI不足','先做基准压测'],['迁移中断','业务受损','灰度+回滚'],['团队不熟','交付风险','培训+代码评审']]}),
      mk('决策','summary','管理层决策请求','把汇报收束到可批准事项。',['批准一期PoC','确认90天验收指标','保障跨部门资源','按数据决定是否全面迁移'])
    ];
    return [mk('补充','cards','关键补充','补充与主题直接相关的可执行信息。',['背景事实','具体判断','行动建议'])];
  }

  async function renderWithPptxGen(PptxCtor, deck, theme, options){
    const pptx = new PptxCtor(); pptx.layout='LAYOUT_WIDE'; pptx.author='AI PPT Generator'; pptx.company='HoloMemory AI'; pptx.subject=deck.subtitle||''; pptx.title=deck.deckTitle||'AI PPT'; pptx.lang='zh-CN';
    for(let idx=0; idx<deck.slides.length; idx++){ await addPptxSlide(pptx, normalizeSlide(deck.slides[idx], idx, deck), idx, deck, theme, options); }
    let blob; try { blob=await pptx.write({outputType:'blob'}); } catch(e){ blob=await pptx.write('blob'); }
    if(!(blob instanceof Blob)) blob=new Blob([blob],{type:'application/vnd.openxmlformats-officedocument.presentationml.presentation'});
    return {blob,fileName:safeFileName(deck.deckTitle||'AI_PPT')+'_'+(options.mode||'beauty')+'_'+today()+'.pptx',slideCount:deck.slides.length,slideSpec:deck,metrics:{renderer:'pptxgenjs-browser-v19',slide_count:deck.slides.length,output_size:blob.size,theme:theme.name}};
  }

  async function addPptxSlide(pptx, s, idx, deck, theme, options){
    const slide=pptx.addSlide(); const dark=isDark(theme.background); const fg=pptxHex(dark?'#FFFFFF':theme.title), body=pptxHex(dark?'#E5E7EB':theme.body), muted=pptxHex(dark?'#CBD5E1':theme.muted), pri=pptxHex(theme.primary), acc=pptxHex(theme.accent), soft=pptxHex(dark?'#172554':theme.soft), card=pptxHex(dark?'#1E293B':theme.card), line=pptxHex(dark?'#334155':theme.border);
    slide.background={color:pptxHex(theme.background)}; addPFooter(slide,deck,idx,muted);
    const layout=normalizeLayout(s.layoutType,idx,deck.slides.length);
    if(idx===0||layout==='cover') return addPCover(slide,deck,s,fg,body,pri,acc,soft,line);
    addPHeader(slide,s,fg,body,pri);
    if(s.codeBlock||layout==='code') return addPCode(slide,s,body,pri,card,line);
    if(s.tableRows&&s.tableRows.length) return addPTable(slide,s,body,pri,soft,line);
    if(s.chartData&&s.chartData.length) return addPChart(slide,s,body,pri,acc,card,line);
    if(layout==='timeline'||layout==='roadmap') return addPTimeline(slide,s,body,pri);
    if(layout==='process'||layout==='process_steps') return addPProcess(slide,s,body,pri,soft,line);
    if(layout==='comparison'||layout==='matrix'||layout==='framework_matrix') return addPMatrix(slide,s,body,pri,acc,card,line);
    if(layout==='image'||layout==='gallery') return await addPImage(slide,s,body,pri,acc,soft,line,options);
    if(layout==='chart') return addPChart(slide,s,body,pri,acc,card,line);
    if(layout==='table') return addPTable(slide,s,body,pri,soft,line);
    if(layout==='big_number') return addPKpi(slide,s,body,pri,card,line);
    if(layout==='summary'||layout==='closing') return addPSummary(slide,s,body,pri,card,line,idx,deck);
    return addPCards(slide,s,body,pri,card,line);
  }
  function addPHeader(slide,s,fg,body,pri){ slide.addText(clean(s.section||''),{x:0.7,y:0.35,w:3,h:0.25,fontFace:FONT,fontSize:9,bold:true,color:pri}); slide.addText(clean(s.title),{x:0.7,y:0.72,w:10.8,h:0.55,fontFace:FONT,fontSize:24,bold:true,color:fg,fit:'shrink'}); if(s.coreMessage) slide.addText(clean(s.coreMessage),{x:0.72,y:1.34,w:10.4,h:0.36,fontFace:FONT,fontSize:11.5,color:body,fit:'shrink'}); }
  function addPFooter(slide,deck,idx,color){ slide.addText(`${clean(deck.deckTitle||'')} · ${idx+1}/${deck.slides.length}`,{x:0.6,y:7.05,w:7,h:0.2,fontFace:FONT,fontSize:7,color}); }
  function addPCover(slide,deck,s,fg,body,pri,acc,soft,line){ slide.addText(clean(deck.deckTitle||s.title),{x:0.75,y:1.15,w:8.3,h:0.9,fontFace:FONT,fontSize:32,bold:true,color:fg,fit:'shrink'}); slide.addText(clean(deck.subtitle||s.coreMessage||''),{x:0.8,y:2.25,w:7.2,h:0.7,fontFace:FONT,fontSize:14,color:body,fit:'shrink'}); slide.addText('',{x:8.6,y:0.8,w:3.8,h:5.1,fill:{color:soft},line:{color:line}}); slide.addText('',{x:9.0,y:1.35,w:2.8,h:1.4,fill:{color:pri,transparency:10},line:{color:pri}}); slide.addText('',{x:9.5,y:3.15,w:2.3,h:1.2,fill:{color:acc,transparency:15},line:{color:acc}}); }
  function addPCode(slide,s,body,pri,card,line){ const code=s.codeBlock||s.points.join('\n'); slide.addText(code,{x:0.85,y:2.05,w:7.2,h:4.55,fontFace:'Consolas',fontSize:9.5,color:'E5E7EB',fill:{color:'111827'},line:{color:'111827'},margin:0.13,fit:'shrink'}); slide.addText('说明',{x:8.45,y:2.05,w:2.8,h:0.35,fontFace:FONT,fontSize:11,bold:true,color:'FFFFFF',fill:{color:pri},margin:0.05}); slide.addText(s.points.slice(0,4).join('\n'),{x:8.45,y:2.55,w:3.4,h:2.5,fontFace:FONT,fontSize:12,bold:true,color:body,fill:{color:'FFFFFF'},line:{color:line},margin:0.15,fit:'shrink'}); }
  function addPCards(slide,s,body,pri,card,line){ s.points.slice(0,4).forEach((p,i)=>slide.addText(p,{x:0.8+(i%2)*5.65,y:2.15+Math.floor(i/2)*1.45,w:4.9,h:1.05,fontFace:FONT,fontSize:12,bold:true,color:body,fill:{color:card},line:{color:line},margin:0.15,fit:'shrink'})); }
  function addPTable(slide,s,body,pri,soft,line){ const rows=(s.tableRows&&s.tableRows.length?s.tableRows:[['项目','建议','备注']].concat(s.points.map(p=>['',p,'']))).slice(0,5); slide.addTable(rows,{x:0.8,y:2.05,w:11.4,h:3.8,border:{type:'solid',color:line,pt:1},fontFace:FONT,fontSize:10,color:body,fill:'FFFFFF',margin:0.06,autoFit:false}); }
  function shouldUseChart(s,data){
    if(!chartIsValid(data)) return false;
    const title=(s.title||'')+' '+(s.coreMessage||'')+' '+(s.section||'');
    if(/矩阵|架构|流程|路径|步骤|清单|风险控制|避坑|对比|选择逻辑|风味轮|口味|影响对象/.test(title) && !/预算|金额|比例|趋势|增长|下降|评分|数量|耗时|成本|损失|收益/.test(title)) return false;
    const vals=data.map(r=>Number(r[1])).filter(v=>isFinite(v));
    if(vals.length<2) return false;
    const labels=data.map(r=>String(r[0]||''));
    if(labels.some(x=>/指标|维度|烘焙度|处理法/.test(x)) && vals.length<=4) return false;
    return true;
  }
  function addPChart(slide,s,body,pri,acc,card,line){
    const data=normalizeChartData(s.chartData&&s.chartData.length?s.chartData:[]);
    if(!shouldUseChart(s,data)) return addPMatrix(slide,Object.assign({},s,{tableRows:(s.tableRows&&s.tableRows.length?s.tableRows:metricRowsFromPoints(s))}),body,pri,acc,card,line);
    const max=Math.max(...data.map(r=>Math.abs(Number(r[1]))||1));
    const chartW=7.0, barW=Math.min(0.9,chartW/data.length*0.48), gap=(chartW-barW*data.length)/Math.max(1,data.length-1);
    const baseY=5.55,maxH=2.55;
    slide.addText('',{x:0.82,y:2.0,w:7.25,h:4.05,fill:{color:'FFFFFF',transparency:4},line:{color:line}});
    data.slice(0,6).forEach((r,i)=>{const val=Number(r[1])||0;const h=Math.max(0.18,Math.abs(val)/max*maxH);const x=1.05+i*(barW+gap);const color=i%2?acc:pri;slide.addText('',{x,y:baseY-h,w:barW,h,fill:{color},line:{color}});const unit=r[2]?String(r[2]):'';slide.addText(String(r[1])+(unit&&unit.length<=5?unit:''),{x:x-0.18,y:baseY-h-0.35,w:barW+0.36,h:0.25,fontFace:FONT,fontSize:9,bold:true,color:body,align:'center',fit:'shrink'});slide.addText(cleanCn(r[0]),{x:x-0.35,y:baseY+0.15,w:barW+0.7,h:0.55,fontFace:FONT,fontSize:8.2,color:body,align:'center',fit:'shrink'});});
    const note=cleanCn((s.chartSuggestion&&s.chartSuggestion.reason)||s.coreMessage||'');
    slide.addText(note,{x:8.45,y:2.15,w:3.25,h:1.6,fontFace:FONT,fontSize:11.5,bold:true,color:body,fill:{color:card},line:{color:line},margin:0.16,fit:'shrink'});
    const noteText=note||'仅用于对比预算或风险结构，实际金额按出行日期核验。'; slide.addText(noteText,{x:8.45,y:4.05,w:3.25,h:0.85,fontFace:FONT,fontSize:9.5,color:body,fill:{color:'FFFFFF',transparency:10},line:{color:line},margin:0.12,fit:'shrink'});
  }
  function metricRowsFromPoints(s){
    const pts=s.points&&s.points.length?s.points:[];
    let rows=[['维度','判断','建议']];
    pts.slice(0,4).forEach(p=>{const t=cleanCn(p);const parts=t.split(/：|:/);rows.push([parts[0]||'重点',parts[1]||t,parts.slice(2).join('：')||'需要核验/执行']);});
    return rows;
  }
  function addPTimeline(slide,s,body,pri){ const pts=s.points.slice(0,5); slide.addText('',{x:1.0,y:3.55,w:10.5,h:0.03,fill:{color:pri},line:{color:pri}}); pts.forEach((p,i)=>{const x=1+i*(10.2/Math.max(1,pts.length-1)); slide.addText(String(i+1),{x:x,y:3.28,w:0.45,h:0.38,fontFace:FONT,fontSize:10,bold:true,color:'FFFFFF',fill:{color:pri},align:'center',margin:0.01}); slide.addText(p,{x:Math.max(0.35,x-0.7),y:3.9,w:1.85,h:0.95,fontFace:FONT,fontSize:9.5,color:body,align:'center',fit:'shrink'});}); }
  function addPProcess(slide,s,body,pri,soft,line){ s.points.slice(0,5).forEach((p,i)=>{ const x=0.75+i*2.25; slide.addText(String(i+1).padStart(2,'0'),{x,y:2.05,w:0.55,h:0.42,fontFace:FONT,fontSize:12,bold:true,color:'FFFFFF',fill:{color:pri},align:'center'}); slide.addText(p,{x,y:2.72,w:1.92,h:1.25,fontFace:FONT,fontSize:10.2,bold:true,color:body,fill:{color:soft},line:{color:line},margin:0.14,fit:'shrink'}); if(i<4) slide.addText('→',{x:x+1.9,y:3.05,w:0.35,h:0.25,fontFace:FONT,fontSize:16,bold:true,color:pri,align:'center'}); }); }
  function addPMatrix(slide,s,body,pri,acc,card,line){
    let rows=[];
    if(s.tableRows&&s.tableRows.length){rows=s.tableRows;} else rows=metricRowsFromPoints(s);
    rows=rows.slice(0,6).map(r=>Array.isArray(r)?r.map(cleanCn):[cleanCn(r)]);
    const headers=rows[0]||['维度','判断','建议']; const data=rows.slice(1);
    if(data.length<=4){
      slide.addText('',{x:0.85,y:2.0,w:11.2,h:4.25,fill:{color:'FFFFFF',transparency:4},line:{color:line}});
      data.forEach((r,i)=>{const x=1.0+(i%2)*5.45,y=2.25+Math.floor(i/2)*1.75; slide.addText(String(i+1).padStart(2,'0'),{x,y,w:0.55,h:0.42,fontFace:FONT,fontSize:12,bold:true,color:'FFFFFF',fill:{color:i%2?acc:pri},align:'center'}); slide.addText(r[0]||headers[0]||'维度',{x:x+0.75,y,w:4.3,h:0.35,fontFace:FONT,fontSize:12,bold:true,color:pri,fit:'shrink'}); slide.addText((r[1]||'')+(r[2]?'\n'+r[2]:''),{x:x+0.75,y:y+0.45,w:4.3,h:0.85,fontFace:FONT,fontSize:9.8,color:body,fit:'shrink'});});
    }else{
      slide.addTable(rows,{x:0.85,y:2.05,w:11.2,h:3.8,border:{type:'solid',color:line,pt:1},fontFace:FONT,fontSize:9.5,color:body,fill:'FFFFFF',margin:0.06,autoFit:false});
    }
  }

  function addPKpi(slide,s,body,pri,card,line){
    const raw=(s.chartData&&s.chartData.length?s.chartData:[]);
    const items=raw.length?raw.slice(0,4).map(r=>[cleanCn(r[0]||'指标'), String(r[1]||''), cleanCn(r[2]||'')]) : (s.points||[]).slice(0,4).map((p,i)=>[cleanCn(p).split(/：|:/)[0]||('指标'+(i+1)), extractNumber({title:p})||String(i+1), cleanCn(p)]);
    if(!items.length) items.push(['重点','1',cleanCn(s.coreMessage||'核心结论')]);
    items.forEach((it,i)=>{
      const x=0.9+(i%2)*5.45, y=2.15+Math.floor(i/2)*1.65;
      slide.addText(String(it[1]||''),{x,y,w:1.35,h:0.55,fontFace:FONT,fontSize:22,bold:true,color:pri,align:'center',fit:'shrink'});
      slide.addText(it[0],{x:x+1.55,y:y+0.05,w:3.75,h:0.35,fontFace:FONT,fontSize:12,bold:true,color:body,fit:'shrink'});
      slide.addText(it[2]||cleanCn(s.coreMessage||''),{x:x+1.55,y:y+0.48,w:3.75,h:0.65,fontFace:FONT,fontSize:9.5,color:body,fit:'shrink'});
      slide.addText('',{x:x-0.08,y:y-0.12,w:5.0,h:1.35,fill:{color:card,transparency:4},line:{color:line}});
    });
  }

  function addPSummary(slide,s,body,pri,card,line,idx,deck){
    const pts=(s.points&&s.points.length?s.points:s.supportingPoints||[]).slice(0,5).map(cleanCn).filter(Boolean);
    const steps=pts.length?pts:['核心结论','关键判断','下一步行动'];
    slide.addText('',{x:0.85,y:2.05,w:11.0,h:2.15,fill:{color:card,transparency:3},line:{color:line}});
    steps.forEach((p,i)=>{
      const x=1.15+i*(9.8/Math.max(1,steps.length-1));
      slide.addText(String(i+1).padStart(2,'0'),{x,y:2.55,w:0.62,h:0.5,fontFace:FONT,fontSize:12,bold:true,color:'FFFFFF',fill:{color:pri},align:'center',margin:0.01});
      if(i<steps.length-1) slide.addText('→',{x:x+0.75,y:2.68,w:0.65,h:0.25,fontFace:FONT,fontSize:18,bold:true,color:pri,align:'center'});
      slide.addText(p,{x:Math.max(0.6,x-0.45),y:3.25,w:1.65,h:0.75,fontFace:FONT,fontSize:9.5,bold:true,color:body,align:'center',fit:'shrink'});
    });
    const msg=cleanCn(s.coreMessage||'把重点收束为可执行结论。');
    slide.addText(msg,{x:1.05,y:4.65,w:10.4,h:0.7,fontFace:FONT,fontSize:15,bold:true,color:body,align:'center',fit:'shrink'});
    slide.addText('下一步行动',{x:4.6,y:5.65,w:4.0,h:0.55,fontFace:FONT,fontSize:24,bold:true,color:pri,align:'center'});
  }

  async function addPImage(slide,s,body,pri,acc,soft,line,options){
    const isTravel=/旅行|路线|景点|京都|清水寺|岚山|酒店/.test((options.topic||'')+' '+(s.title||'')+' '+(s.section||''));
    const q=s.image_search_query || (s.imagePlan&&(s.imagePlan.prompt||s.imagePlan.image_prompt)) || `${options.topic||s.title} ${s.title}`; let img='';
    if(isTravel) img=await fetchWikiImage(q);
    slide.addImage({data:img||sceneSvgDataUri(s,pri,acc,soft),x:0.8,y:2.0,w:6.75,h:4.25});
    s.points.slice(0,3).forEach((p,i)=>slide.addText(p,{x:8.05,y:2.2+i*1.15,w:3.45,h:0.85,fontFace:FONT,fontSize:11.2,bold:true,color:body,fill:{color:'FFFFFF'},line:{color:line},margin:0.13,fit:'shrink'}));
  }
  function sceneSvgDataUri(s,pri,acc,soft){
    const title=cleanCn(s.title||'主题视觉'); const section=cleanCn(s.section||''); const pts=(s.points||[]).slice(0,4).map(cleanCn); const esc=v=>String(v).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
    const cards=pts.map((p,i)=>`<g transform="translate(${80+(i%2)*500},${250+Math.floor(i/2)*150})"><rect width="420" height="105" rx="20" fill="#ffffff" opacity="0.80"/><circle cx="45" cy="52" r="25" fill="#${i%2?acc:pri}"/><text x="45" y="62" font-size="24" text-anchor="middle" fill="#fff" font-family="Microsoft YaHei,Arial" font-weight="700">${i+1}</text><text x="90" y="48" font-size="24" fill="#1f2937" font-family="Microsoft YaHei,Arial" font-weight="700">${esc(p).slice(0,18)}</text><text x="90" y="78" font-size="18" fill="#64748B" font-family="Microsoft YaHei,Arial">${esc(p).slice(18,38)}</text></g>`).join('');
    const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="760" viewBox="0 0 1200 760"><defs><linearGradient id="g" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#${soft}" offset="0"/><stop stop-color="#ffffff" offset="0.45"/><stop stop-color="#${pri}" offset="1" stop-opacity="0.25"/></linearGradient><pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="#${pri}" stroke-opacity="0.08"/></pattern></defs><rect width="1200" height="760" fill="url(#g)"/><rect width="1200" height="760" fill="url(#grid)"/><circle cx="995" cy="135" r="150" fill="#${acc}" opacity="0.18"/><circle cx="170" cy="620" r="210" fill="#${pri}" opacity="0.10"/><text x="72" y="105" font-family="Microsoft YaHei,Arial" font-size="28" font-weight="700" fill="#${pri}">${esc(section)}</text><text x="72" y="170" font-family="Microsoft YaHei,Arial" font-size="46" font-weight="800" fill="#1f2937">${esc(title)}</text>${cards}</svg>`;
    return 'data:image/svg+xml;base64,'+btoa(unescape(encodeURIComponent(svg)));
  }
  async function fetchWikiImage(query){
    try{
      query=clean(query).replace(/[\u4e00-\u9fff]/g,'').trim() || 'travel landmark';
      const api='https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch='+encodeURIComponent(query)+'&gsrnamespace=6&gsrlimit=3&prop=imageinfo&iiprop=url&iiurlwidth=1200&format=json&origin=*';
      const r=await fetch(api); const j=await r.json(); const pages=j.query&&j.query.pages?Object.values(j.query.pages):[];
      for(const pg of pages){ const url=pg.imageinfo&&pg.imageinfo[0]&&(pg.imageinfo[0].thumburl||pg.imageinfo[0].url); if(url) return await imageUrlToDataUri(url); }
    }catch(e){}
    return '';
  }
  async function imageUrlToDataUri(url){ const r=await fetch(url,{mode:'cors'}); const b=await r.blob(); return await new Promise((res,rej)=>{ const fr=new FileReader(); fr.onload=()=>res(fr.result); fr.onerror=rej; fr.readAsDataURL(b); }); }
})();
