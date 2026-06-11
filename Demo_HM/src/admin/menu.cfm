<cfparam name="attributes.active" default="hologram">
<cfset isHome = attributes.active eq "hologram">
<aside class="side"><div class="logo">HoloMemory<br>AI</div><nav class="nav">
  <cfoutput>
  <a class="#attributes.active eq 'hologram' ? 'active' : ''#" href="#isHome ? 'index.cfm' : '../index.cfm'#">Hologram Agent</a>
  <a class="#attributes.active eq 'persona_studio' ? 'active' : ''#" href="#isHome ? 'admin/persona_manager.cfm' : 'persona_manager.cfm'#">Persona Studio</a>
  </cfoutput>
  <cfset mods=[
    {key:"memories",label:"Memories"},
    {key:"chunks",label:"Memory Chunks"},
    {key:"conversations",label:"Conversations"},
    {key:"agent_tasks",label:"Agent Tasks"},
    {key:"audit_logs",label:"Audit Logs"}
  ]>
  <cfloop array="#mods#" index="m">
    <cfoutput><a class="#attributes.active eq m.key ? 'active' : ''#" href="#isHome ? 'admin/crud.cfm?module=' & m.key : 'crud.cfm?module=' & m.key#">#m.label#</a></cfoutput>
  </cfloop>
  <cfoutput>
  <a class="#attributes.active eq 'memory_retrieval' ? 'active' : ''#" href="#isHome ? 'admin/memory_retrieval_explorer.cfm' : 'memory_retrieval_explorer.cfm'#">Memory Retrieval</a>
  <a class="#attributes.active eq 'digital_pipeline' ? 'active' : ''#" href="#isHome ? 'admin/digital_human_pipeline.cfm' : 'digital_human_pipeline.cfm'#">Digital Human Pipeline</a>
  </cfoutput>
</nav></aside>
