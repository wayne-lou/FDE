component output="false" {
  public struct function render(required struct slideSpec){
    if(!structKeyExists(application, "rendererMode") || application.rendererMode != "node"){
      return createObject("component", application.componentRoot & ".CFMLPptxRenderer").render(arguments.slideSpec);
    }

    var specPath = application.outputDir & "/deck_spec_" & createUUID() & ".json";
    var fileName = "enterprise_deck_" & dateFormat(now(), "yyyymmdd") & "_" & replace(createUUID(), "-", "", "all") & ".pptx";
    var outputPath = application.outputDir & "/" & fileName;
    fileWrite(specPath, serializeJSON(arguments.slideSpec), "utf-8");

    var stdout = "";
    var stderr = "";
    try {
      cfexecute(
        name=application.nodePath,
        arguments='"#application.rendererScript#" "#specPath#" "#outputPath#"',
        timeout=180,
        variable="stdout",
        errorVariable="stderr"
      );
    } catch(any e){
      return {success:false, message:e.message & " " & stderr, stdout:stdout, stderr:stderr};
    }

    if(!fileExists(outputPath)){
      return {success:false, message:"Renderer did not create output. " & stderr, stdout:stdout, stderr:stderr};
    }
    return {
      success:true,
      file_name:fileName,
      file_path:outputPath,
      file_size:getFileInfo(outputPath).size,
      slide_count:arguments.slideSpec.slide_count,
      stdout:stdout,
      stderr:stderr
    };
  }
}
