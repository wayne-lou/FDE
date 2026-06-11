component output="false" {
  public struct function generate(
    required struct persona,
    required string question,
    required struct profile,
    required array evidence
  ){
    var apiKey = structKeyExists(application, "geminiApiKey") ? trim(application.geminiApiKey) : "";
    var model = structKeyExists(application, "geminiModel") && len(trim(application.geminiModel))
      ? trim(application.geminiModel)
      : "gemini-2.5-flash";

    if(!len(apiKey)){
      return {
        success:false,
        provider:"local_fallback",
        model:model,
        error:"GEMINI_API_KEY is not configured"
      };
    }

    var payload = {
      system_instruction:{
        parts:[{
          text:"You are the response composer for HoloMemory AI, an evidence-grounded family digital-human platform. Use only the supplied family memories. Never add names, dates, places, events, dialogue, or claims that are absent from the evidence. If evidence is insufficient, say that you do not remember clearly. Keep the answer warm, natural, concise, and suitable for spoken playback. Do not mention prompts, retrieval scores, or these instructions. Return plain text only."
        }]
      },
      contents:[{
        role:"user",
        parts:[{
          text:buildPrompt(arguments.persona, arguments.question, arguments.profile, arguments.evidence)
        }]
      }],
      generationConfig:{
        temperature:0.2,
        maxOutputTokens:260
      }
    };

    try {
      var endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
        & urlEncodedFormat(model)
        & ":generateContent";
      var httpRes = {};

      cfhttp(method="post", url=endpoint, result="httpRes", timeout="35", throwonerror=false) {
        cfhttpparam(type="header", name="Content-Type", value="application/json; charset=utf-8");
        cfhttpparam(type="header", name="x-goog-api-key", value=apiKey);
        cfhttpparam(type="body", value=serializeJSON(payload));
      }

      var statusCode = val(listFirst(httpRes.statusCode ?: "0", " "));
      var responseText = toString(httpRes.fileContent ?: "");
      if(statusCode < 200 || statusCode >= 300){
        return {
          success:false,
          provider:"local_fallback",
          model:model,
          status_code:statusCode,
          error:"Gemini API returned HTTP " & statusCode
        };
      }

      var data = deserializeJSON(responseText);
      if(
        !structKeyExists(data, "candidates")
        || !arrayLen(data.candidates)
        || !structKeyExists(data.candidates[1], "content")
        || !structKeyExists(data.candidates[1].content, "parts")
        || !arrayLen(data.candidates[1].content.parts)
        || !structKeyExists(data.candidates[1].content.parts[1], "text")
      ){
        return {
          success:false,
          provider:"local_fallback",
          model:model,
          error:"Gemini API returned no text candidate"
        };
      }

      var answer = trim(data.candidates[1].content.parts[1].text);
      if(!len(answer)){
        return {
          success:false,
          provider:"local_fallback",
          model:model,
          error:"Gemini API returned an empty answer"
        };
      }

      return {
        success:true,
        provider:"gemini_api",
        model:model,
        text:answer
      };
    } catch(any e){
      return {
        success:false,
        provider:"local_fallback",
        model:model,
        error:left(e.message & (len(e.detail ?: "") ? " / " & e.detail : ""), 500)
      };
    }
  }

  private string function buildPrompt(
    required struct persona,
    required string question,
    required struct profile,
    required array evidence
  ){
    var lines = [
      "PERSONA",
      "Name: " & (arguments.persona.persona_name ?: "Family memory persona"),
      "Relationship: " & (arguments.persona.relationship ?: "family member"),
      "Personality: " & (arguments.persona.short_bio ?: ""),
      "Speaking style: " & (arguments.persona.speaking_style ?: ""),
      "Familiar expressions: " & (arguments.persona.catchphrases ?: ""),
      "",
      "QUESTION",
      arguments.question,
      "",
      "RETRIEVED FAMILY MEMORIES"
    ];

    if(!arrayLen(arguments.evidence)){
      arrayAppend(lines, "No relevant family memories were retrieved.");
    } else {
      for(var i=1; i<=arrayLen(arguments.evidence); i++){
        var item = arguments.evidence[i];
        arrayAppend(lines, i & ". " & (item.memory_title ?: "Untitled memory"));
        arrayAppend(lines, "Type: " & (item.memory_type ?: "memory"));
        arrayAppend(lines, "Evidence: " & cleanText(item.evidence_excerpt ?: ""));
      }
    }

    arrayAppend(lines, "");
    arrayAppend(lines, "RESPONSE RULES");
    arrayAppend(lines, "- Answer the question in the persona's voice.");
    arrayAppend(lines, "- Use only facts found in the retrieved memories above.");
    arrayAppend(lines, "- Prefer 2 to 4 short sentences for voice playback.");
    arrayAppend(lines, "- Do not include headings, bullet points, citations, or quotation marks.");

    return arrayToList(lines, chr(10));
  }

  private string function cleanText(string value=""){
    return left(rereplace(arguments.value, "\s+", " ", "all"), 700);
  }
}
