component output="false" {
  public struct function plan(required struct input, required struct intent){
    var arcs = {
      education:{arc:"Teach", sections:["Cover","Agenda","Concept","Why it matters","Framework","Examples","Practice","Comparison","Recap","Closing"]},
      business:{arc:"Persuade", sections:["Cover","Agenda","Context","Problem","Market need","Framework","Operating model","Comparison","Metrics","Roadmap","Closing"]},
      travel:{arc:"Journey", sections:["Cover","Agenda","Destination context","Route","Moments","Culture","Logistics","Comparison","Tips","Summary","Closing"]},
      personal_review:{arc:"Story", sections:["Cover","Agenda","Starting point","Turning points","Evidence","Lessons","Comparison","Next chapter","Summary","Closing"]},
      technical_proposal:{arc:"Decision Making", sections:["Cover","Agenda","Background","Problem","Architecture","Workflow","Validation","Metrics","Tradeoffs","Roadmap","Closing"]}
    };
    return structKeyExists(arcs, arguments.intent.presentation_type) ? arcs[arguments.intent.presentation_type] : arcs.business;
  }
}
