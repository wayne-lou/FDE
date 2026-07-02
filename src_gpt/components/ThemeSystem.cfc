component output=false {
  public struct function resolve(required string topic, string theme=""){
    var t=arguments.topic & " " & arguments.theme;
    if(reFindNoCase("医院|医疗|科研|健康",t)) return {industry:"medical",primary:"0B3A6E",accent:"E86C2E"};
    if(reFindNoCase("金融|投资|审计|订单|Rust|ROI",t)) return {industry:"finance",primary:"B91C1C",accent:"F59E0B"};
    if(reFindNoCase("课程|Python|教学",t)) return {industry:"education",primary:"2563EB",accent:"06B6D4"};
    return {industry:"general",primary:"1F2937",accent:"2563EB"};
  }
}
