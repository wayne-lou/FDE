component output="false" {
  public struct function plan(required struct deck, required struct theme){
    var layouts = ["cover","agenda","section_divider","two_columns","framework","process","comparison","cards","data","summary","closing"];
    var slides = [];
    for(var i=1; i<=arguments.deck.slide_count; i++){
      var sectionName = arguments.deck.sections[i];
      var layout = chooseLayout(i, sectionName, layouts);
      arrayAppend(slides, {
        slide_number:i,
        layout:layout,
        title:makeTitle(i, sectionName, arguments.deck.topic),
        subtitle:i == 1 ? "Structured AI workflow from JSON to PowerPoint" : "",
        bullets:makeBullets(sectionName, i),
        speaker_note:"Generated from structured slide specification. Renderer owns visual presentation.",
        visual:{type:visualType(layout), label:sectionName}
      });
    }
    return {
      deck_title:arguments.deck.topic,
      theme:arguments.theme,
      slide_count:arrayLen(slides),
      slides:slides,
      metadata:{schema_version:"1.0", generator:"Lucee Workflow Engine + Node pptxgenjs Renderer"}
    };
  }

  private string function chooseLayout(required numeric index, required string sectionName, required array layouts){
    if(arguments.index == 1) return "cover";
    if(arguments.index == 2) return "agenda";
    if(findNoCase("Closing", arguments.sectionName)) return "closing";
    if(findNoCase("Background", arguments.sectionName) || findNoCase("Problem", arguments.sectionName)) return "two_columns";
    if(findNoCase("Framework", arguments.sectionName) || findNoCase("Architecture", arguments.sectionName)) return "framework";
    if(findNoCase("Workflow", arguments.sectionName) || findNoCase("Process", arguments.sectionName)) return "process";
    if(findNoCase("Comparison", arguments.sectionName) || findNoCase("Tradeoffs", arguments.sectionName)) return "comparison";
    if(findNoCase("Metrics", arguments.sectionName) || findNoCase("Evidence", arguments.sectionName)) return "data";
    if(arguments.index mod 5 == 0) return "section_divider";
    return "cards";
  }

  private string function makeTitle(required numeric index, required string sectionName, required string topic){
    if(arguments.index == 1) return arguments.topic;
    return arguments.sectionName;
  }

  private array function makeBullets(required string sectionName, required numeric index){
    return [
      arguments.sectionName & " is generated as structured content, not directly as a PPT object.",
      "Layout choice is controlled by reusable renderer rules.",
      "Validation checks prevent missing titles, unsupported layouts and invalid slide count."
    ];
  }

  private string function visualType(required string layout){
    if(listFindNoCase("framework,process,comparison,data", arguments.layout)) return arguments.layout;
    return "accent";
  }
}
