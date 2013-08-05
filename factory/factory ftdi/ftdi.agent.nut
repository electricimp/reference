results <- ""; // Variable to store DUT results


//Callback to handle data from device.
device.on("toAgent",function(b){
    server.log(b);
});


http.onrequest(function(_req,_res){
  server.log(_req.path);
    try { 
      if(_req.path == "/rxData" || _req.path == "/rxData/"){
        // The Webhook will send new factory data to device to be push out ftdi serial
        results = _req.body;
        server.log(results);
        device.send("serialIn",results);
        _res.send(200,"OK");
      }
      else
      {
        _res.send(200,"Send Data to /rxData");
      }
    } 
    catch (ex) {
      _res.send(500, "Internal Server Error: " + ex);
    }
});