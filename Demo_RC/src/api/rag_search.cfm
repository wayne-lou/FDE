<cfscript>
function sendJson(required any data){cfcontent(type="application/json; charset=utf-8", reset=true); writeOutput(serializeJSON(data)); abort;}
try{q=url.q?:''; rag=new services.RagService(); sendJson({success:true,data:rag.search(q,5)});}catch(any e){sendJson({success:false,message:e.message});}
</cfscript>
