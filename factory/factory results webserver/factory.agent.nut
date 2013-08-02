const HTML=@"<html lang='en'>
              <head>
                <script src='http://ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.js'></script>
                <script type='text/javascript'>
                    deviceID = 'gII-ITUCrYZo' //put your device id here
                    urlResults = document.url + deviceID + '/txData'
                    //urlResults = document.url + 'gII-ITUCrYZo/txData'
                    // AJAX Error Handler
                   function delay(jqXHR, textStatus, errorThrown){
                       //document.getElementById('powerLabel').innerHTML = textStatus + ' Delaying...';
                       console.log('Text Status: ' + textStatus + ', Error Thrown: ' + errorThrown);
                       setTimeout(poll,1000);
                       return true;
                   }
                     
                    // function to populate results div with results.
                    function pubResults(results){
                      // put results into a table in key,value pairs
                      tablehtml = '<table border=1>';
                      $.each(JSON.parse(results), function(k, v) {
                        tablehtml += '<tr><td>' + k + ' </td><td> ' + v + ' </td></tr>';
                      });
                      tablehtml += '</table>'
                       $('#results').html(tablehtml);
                       poll();
                       return true;
                    }
                    
                    // function to periodically check for results
                    function poll(jqXHR, textStatus){
                      if(textStatus=='error'){
                          console.log('Error in Poll function :' + jqXHR );
                          return;
                    }
                      
                      $.ajax({ type:'GET', url: 'http://staging-agent.electricimp.com/gII-ITUCrYZo/txData', 
                          success: pubResults,
                          //complete: poll, 
                          error: delay, 
                          //beforeSend: ajaxBeforeSend,
                          timeout: 60000
                      });
                      return true;
                  }
                  
                  window.onload = poll();
                  
              </script>
            </head>
            <body>
            <h1>DUT Test Results:</h1>
            <div id='results'>
              <table id='results_table' border='1'></table>  
            </div>
            </body>
            </html>"

results <- "";
servPollRes  <- {};
newData <- 0;
http.onrequest(function(_req,_res){
  server.log(_req.path);
    try { 
      if(_req.path == "/rxData" || _req.path == "/rxData/"){
        // The Webhook will send new factory data (encodded as JSON) to the agent via this path
        results = _req.body;
        server.log(results);
        updateAllRequests();
        newData = 1;
      }
      if(_req.path == "/txData" || _req.path == "/txData/"){
        // Ajax calls to this path will populate the results div with factory JSON data
        server.log("Got request from page, newData:" + newData);
        if (newData == 1){
          // if there is new data available send it page
          _res.send(200, results); 
          newData = 0;
        }
        else
        {
          //server.log(_res);
          servPollRes[time()] <- _res;
          server.log("Request initiated by page, Pending Requests: " + servPollRes.len());
         }
        imp.wakeup(30, function(){
          server.log("Checking Response Age")
          //clean up response older than 30sec
          newData  = 0;
          foreach (timestamp, r in servPollRes){
                if(time()-timestamp >= 30){
                    server.log("Cleaning Response " + timestamp)
                    // respond to req
                    server.log("Responding to Old Requests");
                    r.send(200, results);
                    // delete response from table
                    delete servPollRes[timestamp];
                }
            }
        });
         
      }
      else
      {
        _res.send(200,HTML);
      }
    } 
    catch (ex) {
      _res.send(500, "Internal Server Error: " + ex);
    }
});


function updateAllRequests(){
        // Loop through all pending requests and respond.
        
        foreach (idx, r in servPollRes){
            server.log("AGENT - Responded to request :" + idx);
            //r.send(200, http.jsonencode(state));
            r.send(200, results);
        }
        //wipe table 
        servPollRes = {}; 
        newData  = 0;
}
