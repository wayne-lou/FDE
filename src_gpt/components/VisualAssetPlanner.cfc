component output=false {
  public struct function plan(required struct slide, required struct theme){
    var p={iconStyle:"consistent-outline", background:"clean", imageRole:"supporting"};
    if(structKeyExists(arguments.slide,"pageType") && listFindNoCase("image,architecture,iceberg",arguments.slide.pageType)) p.imageRole="main-visual";
    return p;
  }
}
