component output="false" {
    public void function json(required any data, numeric statusCode=200) output="false" {
        cfcontent(type="application/json; charset=utf-8", reset=true);
        cfheader(statuscode=arguments.statusCode, statustext="OK");
        writeOutput(serializeJSON(arguments.data));
        abort;
    }

    public void function error(required string message, numeric statusCode=400, any detail={}) output="false" {
        cfcontent(type="application/json; charset=utf-8", reset=true);
        cfheader(statuscode=arguments.statusCode, statustext="Error");
        writeOutput(serializeJSON({"success": false, "message": arguments.message, "detail": arguments.detail}));
        abort;
    }
}
