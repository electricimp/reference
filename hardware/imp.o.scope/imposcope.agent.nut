const html_graph = @"<html>
  <head>
    <script type=""text/javascript"" src=""https://www.google.com/jsapi""></script>
    <script type='text/javascript' src='https://code.jquery.com/jquery-latest.js'></script>
    <script type=""text/javascript"">
      google.load(""visualization"", ""1"", {packages: ['corechart', 'controls']});
      
      
      
      
/////////////////////////////////////////////////////////////////////////////////////////////////
    var d = [];
    function drawVisualization(chartData) {
        var dashboard = new google.visualization.Dashboard(
            document.getElementById('dashboard'));
    
       var control = new google.visualization.ControlWrapper({
         'controlType': 'ChartRangeFilter',
         'containerId': 'control',
         'options': {
           // Filter by the date axis.
           'filterColumnIndex': 0,
           'ui': {
             'chartType': 'LineChart',
             'chartOptions': {
               'chartArea': {'width': '90%%'},
               'hAxis': {'baselineColor': 'none'}
             },
             // Display a single series that shows the closing value of the stock.
             // Thus, this view has two columns: the date (axis) and the stock value (line series).
             'chartView': {
               'columns': [0, 1]
             },
             // 1 day in milliseconds = 24 * 60 * 60 * 1000 = 86,400,000
             'minRangeSize': 86400000
           }
         },
         // Initial range: 2012-02-09 to 2012-03-20.
        // 'state': {'range': {'start': 100, 'end': 200}}
       });
    
       var chart = new google.visualization.ChartWrapper({
         'chartType': 'LineChart',
         'containerId': 'chart',
         'options': {
           // Use the same chart area width as the control for axis alignment.
           'chartArea': {'height': '80%%', 'width': '90%%'},
           'hAxis': {'slantedText': false, 'minorGridlines':{'count':'1'}},
           'vAxis': {'viewWindow': {'min': 0, 'max': 4}, 'minorGridlines':{'count':'1'}},
           'legend': {'position': 'none'}
         },
        // Convert the first column from 'date' to 'string'.
        //  'view': {
        //   'columns': [
        //      {
        //       'calc': function(dataTable, rowIndex) {
        //          return dataTable.getFormattedValue(rowIndex, 0);
        //       },
        //       'type': 'string'
        //      }, 1, 2, 3, 4]
        //  }
        });
        // 
        // 
        var data = new google.visualization.DataTable();
        //columns
        data.addColumn('number','Time');
        data.addColumn('number','Voltage');
        %s
        //rows
        //data.addRows([%s]);
        data.removeRows(0,data.getNumberOfRows());
        data.addRows(chartData);

   dashboard.bind(control, chart);
   dashboard.draw(data);
}
    google.setOnLoadCallback(function() {
        drawVisualization(d);
    });  
    
    ChartRx = false;
    PendingReq = false;
    function record(){
    
        if ($('#button').html() == 'Start'){
            ChartRx = false;
            PendingReq = true;
            $('#button').html('Stop')
            $.ajax({ 
                type:'POST', 
                url: window.location +'/startscope', 
                data: '',
                success: updateChart,
                timeout: 120000,
                error: (function(err){
                    console.log(err);
                    console.log('Error parsing device info from imp');
                	return;
                })
            });
        }
        else{
            $('#button').html('Start')
            if(!ChartRx){
                $.ajax({ 
                    type:'POST', 
                    url: window.location + '/stopscope', 
                    data: '',
                    success: updateChart,
                    timeout: 10000,
                    error: (function(err){
                        console.log(err);
                        console.log('Error parsing device info from imp');
                    	return;
                    })
                });
            }
        }
        
    }
    var chartdata = """";
    function updateChart(transport){
        // if ($('#button').html() == 'Start'){
        //     $('#button').html('Stop')
        // }
        // else{
        //     $('#button').html('Start')
        // }
        if (PendingReq){
            $('#button').html('Start');
        }
        
        chartdata = JSON.parse(""["" + transport.chart.slice(0,-2) + ""]"")
 
        
        drawVisualization(chartdata);

        ChartRx = true;
        PendingReq = false;
    }
    
        // window.onresize = function(event) {
        //     if (chartdata == """"){
        //         drawVisualization([]);
        //     }
        //     else
        //     {
        //         drawVisualization(chartdata);
        //     }
        // }

    var rtime = new Date(1, 1, 2000, 12,00,00);
    var timeout = false;
    var delta = 200;
    $(window).resize(function() {
        rtime = new Date();
        if (timeout === false) {
            timeout = true;
            setTimeout(resizeend, delta);
        }
    });
    
    function resizeend() {
        if (new Date() - rtime < delta) {
            setTimeout(resizeend, delta);
        } else {
            timeout = false;
            if (chartdata == """"){
                drawVisualization([]);
            }
            else
            {
                drawVisualization(chartdata);
            }
        }               
    }

    </script>
  </head>
  <body> 
    <button type=""button"" id=""button"" onclick=""record()"">Start</button>
    <div id=""dashboard"" style='width: 100%%'>
        <div id=""chart"" style='width: 99%%; height: 300px;'></div>
        <div id=""control"" style='width: 99%%; height: 50px;'></div>
    </div>
    <p>Download this data as a CSV <a href=""%s/blinkup.csv"">here</a>.</p>
    <p>%s</p>
    <p>Download this data as a C Array <a href=""%s/exportc.txt"">here</a>.</p>
  </body>
</html>";
 
// Constants &  Globals
const PIXELS_PER_SECOND = 500;  // Number of pixels 
data <- blob();     // Received blinkup data
dataCSV <- "";
dataCblob <- blob(154000);
graphString <- blob(160000);
idealGraphString <- "";
sampleRate <- 0;
chartWidth <- 0;
startSampleOfBlinkup <- 0;
valueMin <- 4095;
valueMax <- 0;
additionalGraphDataColumns <- "";
extraHtmlData <- "";
 
server.log("");
server.log("Welcome to the magic Imp Scope!");
server.log("See a graph at " + http.agenturl());
server.log("Download the data at " + http.agenturl() + "/blinkup.csv");

// Variable to persist Response object for sending data back page via AJAX
RESPONSE <- [];
ChartRequest <- false;

http.onrequest(function(request, response) {
  server.log("HTTP access");
  if (request.path == "/blinkup.csv") {
    clearOldData();
    generateCSV();
    response.header("Content-Type", "application/octet-stream");
    response.send(200, dataCSV);
  } else if (request.path == "/startscope") {
      //Tell scope to start
        device.send("scopeRunning", 1);
        RESPONSE = response;
        ChartRequest = true;
    // response.header("Content-Type", "text/plain");
    // response.send(200, "Started");
  } else if (request.path == "/stopscope") {
      //tell scope to stop
    device.send("scopeRunning", 0);
    // RESPONSE = response;
    //response.header("Content-Type", "text/plain");
    //response.send(200, "Stopped");      
  } 
   else if (request.path == "/exportc.txt")
   {
      server.log("exportC.txt");
      generateC();
      response.header("Content-Type", "text/plain");
      response.send(200, format("%s",dataCblob.tostring()));
      
   } else {
//    if (data.len()) {
        clearOldData();
        //generateGraph();
        generateGraphBlob();
      response.send(200, format(html_graph, additionalGraphDataColumns,graphString.tostring(),   http.agenturl(), extraHtmlData,http.agenturl()));
//    }    
  }
});
 
function clearOldData()
{
    idealGraphString = "";
    graphString = blob(200000);
    dataCSV = "";
    additionalGraphDataColumns = "";
    extraHtmlData = "";
}
 
// Append received buffers to blinkup data blob
function receiveData(blinkupData) {
  blinkupData.buffer.resize(blinkupData.length);
  data.writeblob(blinkupData.buffer);
  server.log("Received buffer of length " + blinkupData.buffer.len());
  
//   //Send Data to page
//     clearOldData();
//     generateGraph();
//     RESPONSE.header("Content-Type", "text/plain");
//     RESPONSE.send(200, "[" + graphString + "]"); 
}
 
function updateState(config) {
  if (config) {
    // If we're starting a new blinkup, clear old data and configure
    data = blob();
    sampleRate = config.sampleRate;
  }
  else {
    // If we're stopping, wait for late data and then call the graph generator
    imp.wakeup(2, generateStoredDataPoints);
  }
}
 
function generateStoredDataPoints() 
{
    //reset stored data points
    dataCSV = "";
    startSampleOfBlinkup = 0;
    valueMin = 4095;
    valueMax = 0;
 
    server.log("Free Memory:" + imp.getmemoryfree())
 
    //initial data analysis
    findMinMax();
    
    // Compute chart width
    chartWidth = (data.len().tofloat() / 2.0 / sampleRate.tofloat()) * PIXELS_PER_SECOND;  
    
    //generate graph
    clearOldData();
    generateGraphBlob();
    
    local payload = { chart = ""};

    payload.chart = format("%s",graphString.tostring());
    //local s1= "" + graphString.tostring();
    //payload.chart   = s1;
    // send chart to pending response.
    //server.log("Before Response.send - Free Memory:" + imp.getmemoryfree())
    RESPONSE.header("Content-Type", "application/json");
    // RESPONSE.send(200, http.jsonencode("[" + graphString + "]"); 
    //server.log(http.jsonencode(payload));
    RESPONSE.send(200, http.jsonencode(payload)); 
    //clearOldData();
    //server.log("After Clear old data - Free Memory:" + imp.getmemoryfree())
}
 
// function generateGraph() {
//   // Add data to a 2D array
//   graphString = "";//"['Sample', 'Value'], ";
//   local i = 0.0;
//   for (local j = 0; j < data.len(); j+=2) {
//     local value = (data[j] >> 4) | (data[j+1] << 4);
//     value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
//     graphString += format("[%.3f, %f], ", i / sampleRate, value);
//     i++;
//     if (j%100 == 0){
//         server.log("Generate Graph Func mem: " + imp.getmemoryfree() + "len ")
//     }
//   }
//   server.log(format("Graph generated with %i values: ", data.len()/2));
  //server.log(graphString);
//   if(ChartRequest){
//     server.log("sending chart data")
//     RESPONSE.header("Content-Type", "text/plain");
//     RESPONSE.send(200, "[" + graphString + "]"); 
//     ChartRequest = false;
//   }
//}
 
 function generateGraphBlob() {
  // Add data to a 2D array
  graphString = blob(200000);//"['Sample', 'Value'], ";
  
  local i = 0.0;
  local s = data.len();
  for (local j = 0; j < s; j+=2) {
    local value = (data[j] >> 4) | (data[j+1] << 4);
    value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
    graphString.writestring(format("[%.3f, %f], ", i / sampleRate, value));
    i++;
    // if (j%100 == 0){
    //     server.log("Generate Graph Func mem: " + imp.getmemoryfree())
    // }
  }
  server.log(format("Graph generated with %i values: ", data.len()/2));
  //server.log(graphString);
//   if(ChartRequest){
//     server.log("sending chart data")
//     RESPONSE.header("Content-Type", "text/plain");
//     RESPONSE.send(200, "[" + graphString + "]"); 
//     ChartRequest = false;
//   }
}
 
 
function generateCSV() {
  dataCSV = "Time (s),Value,\n";
  local i = 0.0;
  for (local j = 0; j < data.len(); j+=2) {
    local value = (data[j] >> 4) | (data[j+1] << 4);
    value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
    dataCSV += format("%f,%f,\n", i / sampleRate, value);
    i++;
  }
  server.log("CSV generated.");
}
 
function generateC() {
    server.log("generateC");
    
    dataCblob.writestring("const sample[] = {");

    local i = 0.0;
    for (local j = 0; j < data.len(); j+=2) {
            //server.log(j + " " + k);
            local value = (data[j] >> 4) | (data[j+1] << 4);
            //value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
            dataCblob.writestring(format("0x%04X",value));
            //server.log(format("0x%04X",data[j]));
            if (j < data.len()-1){
                dataCblob.writestring(",");
            }
            if ((j+2)%32==0){
                dataCblob.writestring("\n");
            }
        }
    dataCblob.writestring("};")
    //server.log(dataC);
} 
 
enum BlinkState {
  NotStarted = 0,
  LongLow = 1,
  FirstHigh = 2,
  FirstLow = 3,
  Going = 4,
  Ended = 5
}
 
function findMinMax() 
{
  //Find the min and max values. We are goign to use an average of a 4 samples to avoid noise
  local vals = [0,(data[0] >> 4) | (data[1] << 4),(data[2] >> 4) | (data[3] << 4),(data[4] >> 4) | (data[5] << 4)];
  for (local j = 4 * 2; j < data.len(); j+=2) {
    local value = (data[j] >> 4) | (data[j+1] << 4);
    vals[0] = vals[1];
    vals[1] = vals[2];
    vals[2] = vals[3];
    vals[3] = value;
    local avg = (vals[0] + vals[1] + vals[2] + vals[3]) / 4;
    if (avg < valueMin)
      valueMin = avg;
    if (avg > valueMax)
      valueMax = avg;
  }
}
 
 
device.on("data", receiveData);
device.on("state", updateState);
