<cfscript>
cfcontent(type="application/json; charset=utf-8", reset=true);
writeOutput(serializeJSON({
  success:false,
  message:"当前版本使用浏览器 JavaScript 直接生成 PPTX。请打开首页填写主题并点击“生成 PPT”。",
  renderer:"browser-js",
  requires_node:false,
  requires_python:false
}));
abort;
</cfscript>
