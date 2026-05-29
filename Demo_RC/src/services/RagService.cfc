component output="false" {
    public array function search(required string query, numeric limit=5) output="false" {
        var likeText = "%" & arguments.query & "%";
        var q = queryExecute(
            "SELECT knowledge_document_id, document_type, document_title, document_content, chunk_text FROM rc_knowledge_documents WHERE document_status = 'active' AND (document_title ILIKE ? OR document_content ILIKE ? OR embedding_text ILIKE ?) ORDER BY knowledge_document_id DESC LIMIT ?",
            [
                {value: likeText, cfsqltype:"cf_sql_varchar"},
                {value: likeText, cfsqltype:"cf_sql_varchar"},
                {value: likeText, cfsqltype:"cf_sql_varchar"},
                {value: arguments.limit, cfsqltype:"cf_sql_integer"}
            ],
            {datasource:"demo_rc"}
        );
        var results = [];
        for (var i=1; i <= q.recordCount; i++) {
            arrayAppend(results, {
                "knowledge_document_id": q.knowledge_document_id[i],
                "document_type": q.document_type[i],
                "document_title": q.document_title[i],
                "chunk_text": len(q.chunk_text[i] ?: "") ? q.chunk_text[i] : left(q.document_content[i], 500)
            });
        }
        return results;
    }

    public string function buildContext(required array docs) output="false" {
        var parts = [];
        for (var d in arguments.docs) arrayAppend(parts, "[" & d.document_type & "] " & d.document_title & ": " & d.chunk_text);
        return arrayToList(parts, chr(10));
    }
}
