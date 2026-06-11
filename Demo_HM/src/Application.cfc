component {
  this.name = "demo_hm_app";
  this.applicationTimeout = createTimeSpan(0,2,0,0);
  this.sessionManagement = true;
  this.datasource = "demo_hm";

  // Physical project root, works when deployed at C:\inetpub\demos\demo_hm and served as /demo_hm/.
  variables.projectRoot = getDirectoryFromPath(getCurrentTemplatePath());

  // Support both component styles:
  //   new demo_hm.services.JsonUtil()
  //   new services.JsonUtil()
  this.mappings["/demo_hm"] = variables.projectRoot;
  this.mappings["/services"] = variables.projectRoot & "services/";
  this.mappings["/api"] = variables.projectRoot & "api/";
  this.mappings["/admin"] = variables.projectRoot & "admin/";

  function onApplicationStart(){
    application.demoName = "HoloMemory AI";
    application.voiceBridgeUrl = env("HM_VOICE_BRIDGE_URL", "http://127.0.0.1:8010");

    // Provider credentials must stay outside source control.
    application.minimaxApiKey = env("MINIMAX_API_KEY");
    application.minimaxRegion = env("MINIMAX_REGION", "cn");
    application.minimaxApiHost = env("MINIMAX_API_HOST", "https://api.minimax.chat");
    application.minimaxGroupId = env("MINIMAX_GROUP_ID");
    application.hmPublicBaseUrl = env("HM_PUBLIC_BASE_URL", "http://demos.e-xanke.com/demo_hm");

    application.metapersonClientId = env("METAPERSON_CLIENT_ID");
    application.metapersonClientSecret = env("METAPERSON_CLIENT_SECRET");

    return true;
  }

  private string function env(required string name, string fallback=""){
    var value = createObject("java", "java.lang.System").getenv(arguments.name);
    return isNull(value) ? arguments.fallback : toString(value);
  }
}
