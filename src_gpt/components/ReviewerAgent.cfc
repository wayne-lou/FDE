component output=false {
  public struct function score(required struct slide){
    var issues=[];
    if(!structKeyExists(arguments.slide,"title") || len(arguments.slide.title)<3) arrayAppend(issues,"标题不足");
    if(structKeyExists(arguments.slide,"chartData") && isArray(arguments.slide.chartData) && listFindNoCase("matrix,process,architecture,iceberg", arguments.slide.pageType)) arrayAppend(issues,"结构页误用图表");
    return {score=max(60,100-arrayLen(issues)*15), issues=issues};
  }
}
