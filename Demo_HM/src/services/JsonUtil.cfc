component output="false" {
  public void function send(required any payload, numeric statusCode=200){
    cfheader(statuscode=arguments.statusCode, statustext="OK");
    cfcontent(type="application/json; charset=utf-8", reset=true);
    writeOutput(serializeJSON(arguments.payload));
    abort;
  }
  public void function error(required string message, numeric statusCode=500, any detail=""){
    send({success:false,message:arguments.message,detail:arguments.detail}, arguments.statusCode);
  }
  public array function queryToArray(required query q){
    var rows=[];
    for(var r=1; r<=q.recordCount; r++){
      var row={};
      for(var c in q.columnList){ row[lcase(c)] = q[c][r]; }
      arrayAppend(rows,row);
    }
    return rows;
  }
}
