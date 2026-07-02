component output=false {
  public struct function review(required struct slide, required struct theme){
    var s=arguments.slide;
    if(!structKeyExists(s,"pageType") || !len(s.pageType)) s.pageType="cards";
    if(listFindNoCase("matrix,process,architecture,iceberg,framework", s.pageType)) s.chartData=[];
    s.designerStatus="reviewed";
    return s;
  }
}
