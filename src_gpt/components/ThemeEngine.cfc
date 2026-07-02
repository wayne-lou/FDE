component output="false" {
  public struct function resolve(required string themeName){
    var themes = {
      executive_dark:{name:"Executive Dark", font:"Aptos", background:"0B1220", primary:"38BDF8", accent:"22C55E", text:"F8FAFC", muted:"94A3B8"},
      education_light:{name:"Education Light", font:"Aptos", background:"F8FAFC", primary:"2563EB", accent:"16A34A", text:"0F172A", muted:"64748B"},
      minimal_white:{name:"Minimal White", font:"Aptos", background:"FFFFFF", primary:"111827", accent:"2563EB", text:"111827", muted:"6B7280"},
      coffee_warm:{name:"Coffee Warm", font:"Georgia", background:"FBF7F0", primary:"7C2D12", accent:"B45309", text:"1C1917", muted:"78716C"},
      travel_editorial:{name:"Travel Editorial", font:"Aptos", background:"F0F9FF", primary:"0369A1", accent:"F97316", text:"0C4A6E", muted:"64748B"}
    };
    return structKeyExists(themes, arguments.themeName) ? themes[arguments.themeName] : themes.executive_dark;
  }
}
