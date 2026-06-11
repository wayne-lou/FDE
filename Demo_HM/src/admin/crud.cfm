<cfparam name="url.module" default="memories">
<cfif listFindNoCase("personas", url.module)>
  <cflocation url="persona_manager.cfm" addtoken="false">
</cfif>
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title><cfoutput>#url.module eq "memories" ? "Family Memory Timeline" : "HoloMemory CRUD"#</cfoutput></title>
  <cfoutput><link rel="stylesheet" href="../assets/css/app.css?v=#randRange(10000,99999)#"></cfoutput>
</head>
<body class="<cfoutput>#url.module eq "memories" ? "memoryTimelinePage" : ""#</cfoutput>">
<div class="layout">
  <cfmodule template="menu.cfm" active="#url.module#">
  <main class="main">
    <cfif url.module eq "memories">
      <section class="memoryTimelineHero">
        <div class="memoryHeroCopy">
          <span class="memoryEyebrow">HoloMemory Family Archive</span>
          <h1>Family Memory Timeline</h1>
          <p>Stories, voices, photos, and moments that ground Grandpa Li's responses.</p>
        </div>
        <div class="memorySummary" aria-label="Memory archive summary">
          <div><strong id="memoryCount">5</strong><span>Preserved Memories</span></div>
          <div><strong id="memoryTypeCount">5</strong><span>Memory Types</span></div>
          <div><strong>Evidence</strong><span>Ready</span></div>
          <div><strong>Used for RAG</strong><span>Grounding</span></div>
        </div>
      </section>

      <section class="timelineSection" aria-labelledby="timelineHeading">
        <div class="timelineHeading">
          <div>
            <span class="memoryEyebrow">Living family history</span>
            <h2 id="timelineHeading">Moments worth carrying forward</h2>
          </div>
          <p>Every memory gives Grandpa Li emotional context and evidence for a more human response.</p>
        </div>
        <div id="familyMemoryTimeline" class="familyMemoryTimeline">
          <div class="timelineLoading">
            <span></span>
            <p>Opening the family archive...</p>
          </div>
        </div>
      </section>

      <section class="memoryAnswerFlow" aria-labelledby="answerFlowHeading">
        <div class="flowIntro">
          <span class="memoryEyebrow">Memory-grounded AI</span>
          <h2 id="answerFlowHeading">How memories become answers</h2>
          <p>Family context stays visible from capture to conversation.</p>
        </div>
        <div class="answerFlowSteps">
          <div class="answerFlowStep"><b>01</b><span>Memory captured</span></div>
          <i aria-hidden="true"></i>
          <div class="answerFlowStep"><b>02</b><span>Chunked for retrieval</span></div>
          <i aria-hidden="true"></i>
          <div class="answerFlowStep"><b>03</b><span>Evidence selected</span></div>
          <i aria-hidden="true"></i>
          <div class="answerFlowStep"><b>04</b><span>Grandpa responds</span></div>
        </div>
      </section>

      <details class="developerView">
        <summary>
          <span><b>Developer View</b><small>Raw records and editing tools</small></span>
          <span class="developerViewButton">Show raw memory table</span>
        </summary>
        <div class="developerViewBody">
          <div class="adminGrid">
            <div class="card"><h2>Memory records</h2><div id="rows" class="tableWrap"></div></div>
            <div class="card">
              <h2>Create / Update</h2>
              <div id="form" class="formGrid"></div>
              <div class="crudActions">
                <button class="btn" onclick="saveRow()">Save</button>
                <button class="btn secondary" onclick="clearForm()">New</button>
                <button class="btn danger" onclick="deleteRow()">Delete</button>
              </div>
              <div id="status" class="status muted">No row selected.</div>
            </div>
          </div>
        </div>
      </details>
    <cfelse>
      <section class="hero">
        <cfoutput><h1>Module: #encodeForHtml(url.module)#</h1></cfoutput>
        <div class="muted">List-safe fields, dropdown lookups, enum validation, edit by selected row.</div>
      </section>
      <section class="adminGrid">
        <div class="card"><h2>Rows</h2><div id="rows" class="tableWrap"></div></div>
        <div class="card">
          <h2>Create / Update</h2>
          <div id="form" class="formGrid"></div>
          <div class="crudActions">
            <button class="btn" onclick="saveRow()">Save</button>
            <button class="btn secondary" onclick="clearForm()">New</button>
            <button class="btn danger" onclick="deleteRow()">Delete</button>
          </div>
          <div id="status" class="status muted">No row selected.</div>
        </div>
      </section>
    </cfif>
  </main>
</div>

<script>window.MODULE=<cfoutput>"#encodeForJavaScript(url.module)#"</cfoutput>;</script>
<cfif url.module eq "memories">
<script>
(function(){
  const target=document.getElementById('familyMemoryTimeline');
  const typeLabels={audio:'Voice',voice:'Voice',photo:'Photo',video:'Video',diary:'Diary',chat:'Chat',event:'Diary',note:'Diary'};
  const descriptions={
    audio:'Preserves a familiar voice and family wisdom for future generations.',
    voice:'Preserves a familiar voice and family wisdom for future generations.',
    photo:'A vivid family moment used to answer questions with emotional context.',
    video:'Keeps movement, voices, and a shared family moment alive.',
    diary:'A personal story used for emotional grounding and family continuity.',
    chat:'A remembered conversation that helps preserve personality and advice.',
    event:'A shared family story used for emotional grounding.',
    note:'A written memory that carries family context into future conversations.'
  };

  function esc(value){
    return String(value == null ? '' : value).replace(/[&<>"']/g,function(char){
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char];
    });
  }

  function field(row,name){
    if(Object.prototype.hasOwnProperty.call(row,name)) return row[name];
    const key=Object.keys(row).find(function(item){return item.toLowerCase()===name.toLowerCase();});
    return key ? row[key] : '';
  }

  function prettyDate(value){
    if(!value) return 'A timeless family memory';
    const text=String(value).trim();
    const raw=text.slice(0,10);
    const parts=raw.split('-');
    if(parts.length===3){
      const date=new Date(Number(parts[0]),Number(parts[1])-1,Number(parts[2]));
      if(!isNaN(date.getTime())) return date.toLocaleDateString('en-US',{month:'long',day:'2-digit',year:'numeric'});
    }
    const parsed=new Date(text.replace(/,\s*/g,' '));
    if(!isNaN(parsed.getTime())) return parsed.toLocaleDateString('en-US',{month:'long',day:'2-digit',year:'numeric'});
    return text.replace(/\s+00:00:00.*$/,'');
  }

  function typeKey(row){
    return String(field(row,'memory_type')||'note').toLowerCase();
  }

  function cardDescription(row,key){
    const title=String(field(row,'memory_title')||'').toLowerCase();
    if(title.includes('ocean park')) return 'Used by Grandpa Li to answer family-trip questions.';
    if(title.includes('advice')||title.includes('beijing')) return 'Preserves voice and advice for future generations.';
    if(title.includes('neighborhood')||title.includes('park walk')) return 'A quiet family memory used for emotional grounding.';
    const summary=String(field(row,'summary')||'').trim();
    if(summary) return summary;
    return descriptions[key]||descriptions.note;
  }

  function render(rows){
    document.getElementById('memoryCount').textContent=rows.length;
    document.getElementById('memoryTypeCount').textContent=new Set(rows.map(typeKey)).size;
    if(!rows.length){
      target.innerHTML='<div class="timelineEmpty"><b>Your family archive is ready.</b><p>Add the first story in Developer View to begin the timeline.</p></div>';
      return;
    }
    target.innerHTML=rows.map(function(row,index){
      const key=typeKey(row);
      const label=typeLabels[key]||'Memory';
      const rawTitle=field(row,'memory_title')||'Untitled family memory';
      const title=/ocean park/i.test(rawTitle)?'Ocean Park Family Trip':
        /stressful work|advice/i.test(rawTitle)?"Grandpa's Beijing Family Advice":
        /morning walk/i.test(rawTitle)?'Morning Walk Routine':
        /spring festival|family dinner/i.test(rawTitle)?'Family Dinner Before Spring Festival':
        /momo|waiting by the door/i.test(rawTitle)?'Momo Waiting by the Door':rawTitle;
      const location=field(row,'location_text')||'Family archive';
      const emotion=field(row,'emotion_tag')||'remembered';
      const status=field(row,'memory_status')||'active';
      return '<article class="familyMemoryCard type-'+esc(key)+'" style="--timeline-delay:'+(index*70)+'ms">'+
        '<div class="timelineNode"><span></span></div>'+
        '<div class="memoryCardTop">'+
          '<span class="memoryFormatBadge">'+esc(label)+' Memory</span>'+
          '<span class="memoryStatusBadge">'+esc(status)+'</span>'+
        '</div>'+
        '<h3>'+esc(title)+'</h3>'+
        '<div class="memoryPlaceDate">'+esc(location)+' <span></span> '+esc(prettyDate(field(row,'memory_date')))+'</div>'+
        '<p>'+esc(cardDescription(row,key))+'</p>'+
        '<div class="memoryCardFooter">'+
          '<span>Emotion: <b>'+esc(emotion)+'</b></span>'+
          '<span class="groundingBadge">Ready for grounding</span>'+
        '</div>'+
      '</article>';
    }).join('');
  }

  fetch('../api/crud.cfm?module=memories&action=list')
    .then(function(response){return response.json();})
    .then(function(data){if(!data.success) throw new Error('Archive unavailable'); render(data.rows||[]);})
    .catch(function(){
      target.innerHTML='<div class="timelineEmpty"><b>Family archive temporarily unavailable.</b><p>Developer tools remain available below.</p></div>';
    });
})();
</script>
</cfif>
<script src="../assets/js/crud.js"></script>
</body>
</html>
