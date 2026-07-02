component output="false" {
  this.name = "AIPptGenerator_20260630_async2";
  this.applicationTimeout = createTimeSpan(1,0,0,0);
  this.sessionManagement = true;
  this.sessionTimeout = createTimeSpan(0,2,0,0);
  this.mappings["/pptComponents"] = getDirectoryFromPath(getCurrentTemplatePath()) & "components";

  public boolean function onApplicationStart(){
    application.dsn = "demo_ppt";
    application.componentRoot = "pptComponents";
    application.outputDir = resolveOutputDir();
    application.rendererMode = "js";

    // API Key 只允许放在服务端配置中，前端页面不显示、不保存、不传入。
    application.openaiApiKey = "sk-t370615694ecf968fce41216d83c664238fa57211e0OqOSj";
    application.openaiModel = "gpt-4o-mini";
    application.openaiModel = "gpt-4.1-mini";
    // 高质量PPT内容生成优先模型；如果接口不支持，worker 会自动回退到 openaiModel。
    application.openaiQualityModel = "gpt-4.1-mini";
    application.openaiApiUri = "https://api.gptsapi.net/v1/chat/completions";

    application.maxSlides = 28;
    application.minSlides = 25;
    application.enableDb = true;

    ensureDirectory(application.outputDir);
    return true;
  }

  public void function onRequestStart(required string targetPage){
    if(structKeyExists(url, "reload")){
      onApplicationStart();
    }
  }

  private void function ensureDirectory(required string path){
    if(!directoryExists(arguments.path)){
      directoryCreate(arguments.path, true, true);
    }
  }

  private string function resolveOutputDir(){
    var localOutput = expandPath("./output");
    var siblingOutput = expandPath("../output");
    if(directoryExists(localOutput)) return localOutput;
    return siblingOutput;
  }
}
