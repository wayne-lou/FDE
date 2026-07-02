component output="false" {
  public struct function validateBeforeRender(required struct spec){
    var errors = [];
    if(!structKeyExists(arguments.spec, "slides") || !isArray(arguments.spec.slides)) arrayAppend(errors, "slides array is missing");
    if(arrayLen(arguments.spec.slides) < application.minSlides || arrayLen(arguments.spec.slides) > application.maxSlides) arrayAppend(errors, "slide count must be 25-30");
    var allowed = "cover,agenda,section_divider,timeline,framework,process,comparison,two_columns,image_left,image_right,cards,quote,table,data,summary,closing";
    for(var slide in arguments.spec.slides){
      if(!len(trim(slide.title ?: ""))) arrayAppend(errors, "slide " & slide.slide_number & " missing title");
      if(!listFindNoCase(allowed, slide.layout ?: "")) arrayAppend(errors, "unsupported layout: " & (slide.layout ?: ""));
    }
    return {success:!arrayLen(errors), errors:errors};
  }

  public struct function validateAfterRender(required struct renderResult, required struct spec){
    var errors = [];
    if(!fileExists(arguments.renderResult.file_path)) arrayAppend(errors, "pptx file was not created");
    if((arguments.renderResult.file_size ?: 0) < 1000) arrayAppend(errors, "pptx output is too small");
    if(arguments.renderResult.slide_count != arrayLen(arguments.spec.slides)) arrayAppend(errors, "slide count mismatch");
    return {success:!arrayLen(errors), errors:errors};
  }
}
