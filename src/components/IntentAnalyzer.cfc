component output="false" {
  public struct function analyze(required struct input){
    var text = lcase(serializeJSON(arguments.input));
    var type = "business";
    if(find("travel", text) || find("journey", text)) type = "travel";
    if(find("teach", text) || find("education", text) || find("course", text)) type = "education";
    if(find("technical", text) || find("architecture", text) || find("system", text)) type = "technical_proposal";
    if(find("personal", text) || find("review", text)) type = "personal_review";

    return {
      presentation_type:type,
      audience:arguments.input.audience ?: "enterprise reviewers",
      goal:arguments.input.goal ?: "communicate a structured decision",
      desired_slide_count:28,
      risk_level:"medium"
    };
  }
}
