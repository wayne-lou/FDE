component output="false" {
  public struct function plan(required struct input, required struct intent, required struct narrative, required struct theme, required string mode){
    var slideCount = arguments.mode == "beauty" ? 30 : 26;
    var sections = duplicate(arguments.narrative.sections);
    while(arrayLen(sections) < slideCount){
      arrayInsertAt(sections, max(3, arrayLen(sections)-1), "Evidence");
      arrayInsertAt(sections, max(4, arrayLen(sections)-1), "Example");
      arrayInsertAt(sections, max(5, arrayLen(sections)-1), "Implication");
    }
    var plannedSections = [];
    for(var i=1; i<=slideCount; i++){
      arrayAppend(plannedSections, sections[i]);
    }
    return {
      topic:arguments.input.topic ?: "AI PPT 演示",
      slide_count:slideCount,
      sections:plannedSections,
      mode:arguments.mode,
      theme:arguments.theme
    };
  }
}
