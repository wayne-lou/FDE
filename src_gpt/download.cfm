<cfscript>
setting requesttimeout=60;

fileName = trim(url.file ?: "");
if(!refindNoCase("^[a-zA-Z0-9_-]+\.pptx$", fileName)){
  cfheader(statuscode=400, statustext="Bad Request");
  writeOutput("Invalid file name.");
  abort;
}

filePath = application.outputDir & "/" & fileName;
if(!fileExists(filePath)){
  cfheader(statuscode=404, statustext="Not Found");
  writeOutput("PowerPoint file not found.");
  abort;
}

cfheader(name="Content-Disposition", value="attachment; filename=#fileName#");
cfcontent(
  type="application/vnd.openxmlformats-officedocument.presentationml.presentation",
  file=filePath,
  deletefile=false
);
</cfscript>
