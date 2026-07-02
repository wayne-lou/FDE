component output=false {
  public struct function check(required struct spec){
    var result={status:"passed", issues:[]};
    if(!structKeyExists(arguments.spec,"slides") || !isArray(arguments.spec.slides) || arrayLen(arguments.spec.slides)<10){ result.status="failed"; arrayAppend(result.issues,"页数不足"); }
    return result;
  }
}
