component output=false {
  public string function choose(required struct slide){
    var txt=(structKeyExists(arguments.slide,"title")?arguments.slide.title:"") & " " & (structKeyExists(arguments.slide,"coreMessage")?arguments.slide.coreMessage:"");
    if(findNoCase("流程",txt)||findNoCase("步骤",txt)||findNoCase("路径",txt)) return "process";
    if(findNoCase("矩阵",txt)||findNoCase("对比",txt)||findNoCase("风险",txt)) return "matrix";
    if(findNoCase("架构",txt)||findNoCase("系统",txt)||findNoCase("平台",txt)) return "architecture";
    return "cards";
  }
}
