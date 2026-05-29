component {
    this.name = "RaceOpsAIDemo";
    this.applicationTimeout = createTimeSpan(0, 2, 0, 0);
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan(0, 1, 0, 0);
    this.datasource = "demo_rc";
    this.mappings["/services"] = getDirectoryFromPath(getCurrentTemplatePath()) & "services";
    this.mappings["/demo_rc"] = getDirectoryFromPath(getCurrentTemplatePath());
    this.charset.web = "utf-8";
    this.charset.resource = "utf-8";

    function onApplicationStart() {
        application.appName = "RaceOps AI Demo";
        /*
        application.aiMockMode = getSystemSetting("AI_MOCK_MODE", "true");
        application.openAiApiKey = getSystemSetting("OPENAI_API_KEY", "");
        application.openAiModel = getSystemSetting("OPENAI_MODEL", "gpt-4.1-mini");
        */
        
        application.aiMockMode = "true";
        application.openAiApiKey = "";
        application.openAiModel = "gpt-4.1-mini";
        
        return true;
    }

    function onRequestStart(required string targetPage) {
        setting requesttimeout=120;
    }
}
