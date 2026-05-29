<cfscript>
function sendJson(required any data, numeric code=200){cfcontent(type="application/json; charset=utf-8", reset=true); cfheader(statuscode=code,statustext=code==200?'OK':'Error'); writeOutput(serializeJSON(data)); abort;}
try{
  raw=toString(getHttpRequestData().content); body=len(trim(raw))?deserializeJSON(raw):{};
  goal=structKeyExists(body,'goal')?body.goal:'Review driver fatigue risk and prepare an operations plan';
  driverId=structKeyExists(body,'driver_id')?val(body.driver_id):1; eventId=structKeyExists(body,'race_event_id')?val(body.race_event_id):1; userId=structKeyExists(body,'user_id')?val(body.user_id):1;
  svc=new services.AiAgentService();
  plan=svc.plan(goal,driverId,eventId,userId);
  sendJson({success:true,data:plan});
}catch(any e){sendJson({success:false,message:e.message},500);}
</cfscript>
