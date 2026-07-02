component output="false" {
  public struct function run(required any inputJson, required string mode, required string themeName){
    var started = getTickCount();
    var stages = [];

    var metrics = {
      mode:arguments.mode,
      theme:arguments.themeName,
      model:(structKeyExists(application, "openaiModel") ? application.openaiModel : "gpt-4o-mini"),
      prompt_tokens:0,
      completion_tokens:0,
      estimated_cost:0,
      planning_ms:0,
      rendering_ms:0,
      validation_ms:0,
      execution_ms:0,
      slide_count:0,
      output_size:0
    };

    try {
      var input = normalizeInput(arguments.inputJson);
      addStage(stages, "Input JSON", "pass", "Structured brief accepted.");

      var intentTimer = getTickCount();
      var intent = createObject("component", application.componentRoot & ".IntentAnalyzer").analyze(input);
      addStage(stages, "Intent Analysis", "pass", intent.presentation_type);

      var narrative = createObject("component", application.componentRoot & ".NarrativePlanner").plan(input, intent);
      addStage(stages, "Narrative Planning", "pass", narrative.arc);

      var theme = createObject("component", application.componentRoot & ".ThemeEngine").resolve(arguments.themeName);
      addStage(stages, "Theme Selection", "pass", theme.name);

      var deck = createObject("component", application.componentRoot & ".DeckPlanner").plan(input, intent, narrative, theme, arguments.mode);
      addStage(stages, "Deck Planning", "pass", deck.slide_count & " planned slides");

      var slideSpec = createObject("component", application.componentRoot & ".SlidePlanner").plan(deck, theme);
      metrics.planning_ms = getTickCount() - intentTimer;
      addStage(stages, "Slide Planning", "pass", arrayLen(slideSpec.slides) & " slide specs");

      var validator = createObject("component", application.componentRoot & ".Validator");
      var validationTimer = getTickCount();
      var precheck = validator.validateBeforeRender(slideSpec);
      metrics.validation_ms += getTickCount() - validationTimer;
      if(!precheck.success){
        addStage(stages, "Pre-render Validation", "fail", arrayToList(precheck.errors, "; "));
        return failure(stages, metrics, precheck.errors);
      }
      addStage(stages, "Pre-render Validation", "pass", "Schema and slide count valid.");

      var renderTimer = getTickCount();
      var renderResult = createObject("component", application.componentRoot & ".RendererGateway").render(slideSpec);
      metrics.rendering_ms = getTickCount() - renderTimer;
      if(!renderResult.success){
        addStage(stages, "浏览器导出", "fail", renderResult.message);
        return failure(stages, metrics, [renderResult.message]);
      }
      addStage(stages, "浏览器导出", "pass", renderResult.file_name);

      validationTimer = getTickCount();
      var postcheck = validator.validateAfterRender(renderResult, slideSpec);
      metrics.validation_ms += getTickCount() - validationTimer;
      if(!postcheck.success){
        addStage(stages, "Post-render Validation", "fail", arrayToList(postcheck.errors, "; "));
        return failure(stages, metrics, postcheck.errors);
      }
      addStage(stages, "Post-render Validation", "pass", "PPTX exists and output size is valid.");

      metrics.slide_count = arrayLen(slideSpec.slides);
      metrics.output_size = renderResult.file_size;
      metrics.execution_ms = getTickCount() - started;
      metrics.prompt_tokens = estimateTokens(serializeJSON(input));
      metrics.completion_tokens = estimateTokens(serializeJSON(slideSpec));
      metrics.estimated_cost = estimateCost(metrics.prompt_tokens, metrics.completion_tokens, arguments.mode);

      var recorder = createObject("component", application.componentRoot & ".MetricsRecorder");
      var jobId = recorder.record(input, slideSpec, metrics, stages, renderResult);

      return {
        success:true,
        job_id:jobId,
        download_url:"download.cfm?file=" & urlEncodedFormat(renderResult.file_name),
        file_name:renderResult.file_name,
        stages:stages,
        metrics:metrics,
        slide_spec:slideSpec
      };
    } catch(any e){
      addStage(stages, "Unhandled Error", "fail", e.message);
      metrics.execution_ms = getTickCount() - started;
      createObject("component", application.componentRoot & ".MetricsRecorder").recordError(e, metrics, stages);
      return {success:false, message:e.message, detail:e.detail ?: "", stages:stages, metrics:metrics};
    }
  }

  private struct function normalizeInput(required any value){
    if(isStruct(arguments.value)) return arguments.value;
    if(isSimpleValue(arguments.value) && len(trim(arguments.value))) return deserializeJSON(arguments.value);
    throw(message="Input JSON is required.");
  }

  private void function addStage(required array stages, required string name, required string status, required string summary){
    arrayAppend(arguments.stages, {name:arguments.name, status:arguments.status, summary:arguments.summary, at:dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")});
  }

  private struct function failure(required array stages, required struct metrics, required array errors){
    metrics.execution_ms = metrics.execution_ms ?: 0;
    return {success:false, message:"Workflow validation failed.", errors:arguments.errors, stages:arguments.stages, metrics:arguments.metrics};
  }

  private numeric function estimateTokens(required string text){
    return ceiling(len(arguments.text) / 4);
  }

  private numeric function estimateCost(required numeric promptTokens, required numeric completionTokens, required string mode){
    var rate = arguments.mode == "beauty" ? 0.000006 : 0.000003;
    return ((arguments.promptTokens + arguments.completionTokens) * rate);
  }
}
