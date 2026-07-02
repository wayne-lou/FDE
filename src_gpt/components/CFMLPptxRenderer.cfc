component output="false" {
  public struct function render(required struct slideSpec){
    var fileName = "enterprise_deck_" & dateFormat(now(), "yyyymmdd") & "_" & replace(createUUID(), "-", "", "all") & ".pptx";
    var outputPath = application.outputDir & "/" & fileName;
    var workDir = application.outputDir & "/pptx_work_" & replace(createUUID(), "-", "", "all");

    try {
      directoryCreate(workDir, true, true);
      createPackage(arguments.slideSpec, workDir);
      zipDirectory(workDir, outputPath);
      directoryDelete(workDir, true);

      if(!fileExists(outputPath)){
        return {success:false, message:"CFML renderer did not create output."};
      }

      return {
        success:true,
        file_name:fileName,
        file_path:outputPath,
        file_size:getFileInfo(outputPath).size,
        slide_count:arrayLen(arguments.slideSpec.slides),
        stdout:"CFML OOXML renderer",
        stderr:""
      };
    } catch(any e){
      try { if(directoryExists(workDir)) directoryDelete(workDir, true); } catch(any ignored){}
      return {success:false, message:e.message, detail:e.detail ?: ""};
    }
  }

  private void function createPackage(required struct spec, required string root){
    writeText(arguments.root & "/[Content_Types].xml", contentTypes(arguments.spec));
    writeText(arguments.root & "/_rels/.rels", rootRels());
    writeText(arguments.root & "/docProps/app.xml", appProps(arrayLen(arguments.spec.slides)));
    writeText(arguments.root & "/docProps/core.xml", coreProps(arguments.spec.deck_title ?: "Generated Presentation"));
    writeText(arguments.root & "/ppt/presentation.xml", presentationXml(arguments.spec));
    writeText(arguments.root & "/ppt/_rels/presentation.xml.rels", presentationRels(arguments.spec));
    writeText(arguments.root & "/ppt/theme/theme1.xml", themeXml(arguments.spec.theme));
    writeText(arguments.root & "/ppt/slideMasters/slideMaster1.xml", slideMasterXml());
    writeText(arguments.root & "/ppt/slideMasters/_rels/slideMaster1.xml.rels", slideMasterRels());
    writeText(arguments.root & "/ppt/slideLayouts/slideLayout1.xml", slideLayoutXml());
    writeText(arguments.root & "/ppt/slideLayouts/_rels/slideLayout1.xml.rels", slideLayoutRels());

    for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
      writeText(arguments.root & "/ppt/slides/slide#i#.xml", slideXml(arguments.spec.slides[i], arguments.spec.theme, i));
      writeText(arguments.root & "/ppt/slides/_rels/slide#i#.xml.rels", slideRels());
    }
  }

  private void function writeText(required string path, required string content){
    var dir = getDirectoryFromPath(arguments.path);
    if(!directoryExists(dir)) directoryCreate(dir, true, true);
    fileWrite(arguments.path, arguments.content, "utf-8");
  }

  private void function zipDirectory(required string sourceDir, required string zipPath){
    if(fileExists(arguments.zipPath)) fileDelete(arguments.zipPath);
    var zos = createObject("java", "java.util.zip.ZipOutputStream").init(
      createObject("java", "java.io.FileOutputStream").init(arguments.zipPath)
    );
    try {
      var paths = directoryList(arguments.sourceDir, true, "path");
      for(var p in paths){
        if(!directoryExists(p)){
          var rel = replace(p, arguments.sourceDir & "\", "", "one");
          rel = replace(rel, "\", "/", "all");
          zos.putNextEntry(createObject("java", "java.util.zip.ZipEntry").init(rel));
          zos.write(fileReadBinary(p));
          zos.closeEntry();
        }
      }
    } finally {
      zos.close();
    }
  }

  private string function contentTypes(required struct spec){
    var xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'];
    arrayAppend(xml, '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    arrayAppend(xml, '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    arrayAppend(xml, '<Default Extension="xml" ContentType="application/xml"/>');
    arrayAppend(xml, '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>');
    arrayAppend(xml, '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>');
    arrayAppend(xml, '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    arrayAppend(xml, '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>');
    arrayAppend(xml, '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>');
    arrayAppend(xml, '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>');
    for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
      arrayAppend(xml, '<Override PartName="/ppt/slides/slide#i#.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    arrayAppend(xml, '</Types>');
    return arrayToList(xml, "");
  }

  private string function rootRels(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' &
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>' &
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' &
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>' &
      '</Relationships>';
  }

  private string function presentationRels(required struct spec){
    var xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'];
    arrayAppend(xml, '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
      arrayAppend(xml, '<Relationship Id="rId#i#" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide#i#.xml"/>');
    }
    arrayAppend(xml, '<Relationship Id="rId#arrayLen(arguments.spec.slides)+1#" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>');
    arrayAppend(xml, '<Relationship Id="rId#arrayLen(arguments.spec.slides)+2#" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    arrayAppend(xml, '</Relationships>');
    return arrayToList(xml, "");
  }

  private string function presentationXml(required struct spec){
    var xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'];
    arrayAppend(xml, '<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">');
    arrayAppend(xml, '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId#arrayLen(arguments.spec.slides)+2#"/></p:sldMasterIdLst>');
    arrayAppend(xml, '<p:sldIdLst>');
    for(var i=1; i<=arrayLen(arguments.spec.slides); i++){
      arrayAppend(xml, '<p:sldId id="#256+i#" r:id="rId#i#"/>');
    }
    arrayAppend(xml, '</p:sldIdLst><p:sldSz cx="12192000" cy="6858000" type="wide"/><p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle><a:defPPr><a:defRPr lang="en-US"/></a:defPPr></p:defaultTextStyle></p:presentation>');
    return arrayToList(xml, "");
  }

  private string function slideRels(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' &
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>' &
      '</Relationships>';
  }

  private string function slideMasterRels(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' &
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>' &
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>' &
      '</Relationships>';
  }

  private string function slideLayoutRels(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' &
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>' &
      '</Relationships>';
  }

  private string function slideMasterXml(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">' &
      '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld>' &
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>' &
      '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>';
  }

  private string function slideLayoutXml(){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">' &
      '<p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>';
  }

  private string function appProps(required numeric count){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' &
      '<Application>Holo Enterprise PPT Platform</Application><PresentationFormat>Widescreen</PresentationFormat><Slides>#arguments.count#</Slides>' &
      '</Properties>';
  }

  private string function coreProps(required string titleText){
    var created = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss'Z'");
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' &
      '<dc:title>#x(arguments.titleText)#</dc:title><dc:creator>AI PPT 生成器</dc:creator>' &
      '<cp:lastModifiedBy>Lucee CFML Renderer</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">#created#</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">#created#</dcterms:modified>' &
      '</cp:coreProperties>';
  }

  private string function slideXml(required struct slideSpec, required struct theme, required numeric index){
    var bg = cleanColor(arguments.theme.background ?: "FFFFFF");
    var primary = cleanColor(arguments.theme.primary ?: "2563EB");
    var textColor = cleanColor(arguments.theme.text ?: "0F172A");
    var muted = cleanColor(arguments.theme.muted ?: "64748B");
    var xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'];
    arrayAppend(xml, '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="#bg#"/></a:solidFill></p:bgPr></p:bg><p:spTree>');
    arrayAppend(xml, '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>');
    arrayAppend(xml, rectShape(2, 0, 0, 140000, 6858000, primary, primary));
    arrayAppend(xml, textShape(3, arguments.slideSpec.title ?: "Untitled", 620000, 520000, 10800000, 720000, 3000, true, textColor));
    if(len(trim(arguments.slideSpec.subtitle ?: ""))){
      arrayAppend(xml, textShape(4, arguments.slideSpec.subtitle, 650000, 1300000, 9000000, 400000, 1500, false, muted));
    }

    var y = 1900000;
    var shapeId = 5;
    for(var item in (arguments.slideSpec.bullets ?: [])){
      arrayAppend(xml, textShape(shapeId, "- " & item, 850000, y, 10500000, 520000, 1450, false, textColor));
      y += 620000;
      shapeId++;
      if(shapeId > 10) break;
    }

    arrayAppend(xml, textShape(90, "Generated Platform | slide " & arguments.index, 650000, 6420000, 4200000, 220000, 800, false, muted));
    arrayAppend(xml, '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>');
    return arrayToList(xml, "");
  }

  private string function textShape(required numeric id, required string value, required numeric xPos, required numeric yPos, required numeric width, required numeric height, required numeric size, required boolean bold, required string color){
    var b = arguments.bold ? ' b="1"' : '';
    return '<p:sp><p:nvSpPr><p:cNvPr id="#arguments.id#" name="Text #arguments.id#"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>' &
      '<p:spPr><a:xfrm><a:off x="#arguments.xPos#" y="#arguments.yPos#"/><a:ext cx="#arguments.width#" cy="#arguments.height#"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr>' &
      '<p:txBody><a:bodyPr wrap="square" anchor="t"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="#arguments.size#"#b#><a:solidFill><a:srgbClr val="#cleanColor(arguments.color)#"/></a:solidFill></a:rPr><a:t>#x(arguments.value)#</a:t></a:r><a:endParaRPr lang="en-US"/></a:p></p:txBody></p:sp>';
  }

  private string function rectShape(required numeric id, required numeric xPos, required numeric yPos, required numeric width, required numeric height, required string fill, required string line){
    return '<p:sp><p:nvSpPr><p:cNvPr id="#arguments.id#" name="Accent #arguments.id#"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>' &
      '<p:spPr><a:xfrm><a:off x="#arguments.xPos#" y="#arguments.yPos#"/><a:ext cx="#arguments.width#" cy="#arguments.height#"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="#cleanColor(arguments.fill)#"/></a:solidFill><a:ln><a:solidFill><a:srgbClr val="#cleanColor(arguments.line)#"/></a:solidFill></a:ln></p:spPr></p:sp>';
  }

  private string function themeXml(required struct theme){
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' &
      '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Enterprise Theme"><a:themeElements>' &
      '<a:clrScheme name="Enterprise"><a:dk1><a:srgbClr val="0F172A"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="1E293B"/></a:dk2><a:lt2><a:srgbClr val="F8FAFC"/></a:lt2><a:accent1><a:srgbClr val="#cleanColor(arguments.theme.primary ?: '2563EB')#"/></a:accent1><a:accent2><a:srgbClr val="#cleanColor(arguments.theme.accent ?: '16A34A')#"/></a:accent2><a:accent3><a:srgbClr val="64748B"/></a:accent3><a:accent4><a:srgbClr val="94A3B8"/></a:accent4><a:accent5><a:srgbClr val="CBD5E1"/></a:accent5><a:accent6><a:srgbClr val="E2E8F0"/></a:accent6><a:hlink><a:srgbClr val="2563EB"/></a:hlink><a:folHlink><a:srgbClr val="7C3AED"/></a:folHlink></a:clrScheme>' &
      '<a:fontScheme name="Enterprise"><a:majorFont><a:latin typeface="Aptos"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme><a:fmtScheme name="Enterprise"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>' &
      '</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>';
  }

  private string function cleanColor(required string value){
    var color = ucase(replace(arguments.value, "##", "", "all"));
    color = rereplace(color, "[^0-9A-F]", "", "all");
    return len(color) == 6 ? color : "2563EB";
  }

  private string function x(required string value){
    var out = replace(arguments.value, "&", "&amp;", "all");
    out = replace(out, "<", "&lt;", "all");
    out = replace(out, ">", "&gt;", "all");
    out = replace(out, '"', "&quot;", "all");
    out = replace(out, "'", "&apos;", "all");
    return out;
  }
}
