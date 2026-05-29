<cfscript>
response = new services.Response();
crud = new services.CrudService();
try {
    body = crud.readJsonBody();
    param name="body.query" default="";
    param name="body.limit" default=5;
    rag = new services.RagService();
    docs = rag.search(body.query, body.limit);
    response.json({"success": true, "data": docs});
} catch (any e) {
    response.error(e.message, 500, {"detail": e.detail ?: ""});
}
</cfscript>
