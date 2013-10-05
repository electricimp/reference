const html_graph = @"<html>
  <head>
    <script type=""text/javascript"" src=""https://www.google.com/jsapi""></script>
    <script type='text/javascript' src='http://code.jquery.com/jquery-latest.js'></script>
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
    
 
    
    function record(){

        if ($('#button').html() == 'Start'){
        

            $('#button').html('Stop')
            $.ajax({ 
                type:'POST', 
                url: window.location +'/startscope', 
                data: '',
                //success: ajaxGetState,
                timeout: 30000,
                error: (function(err){
                    console.log(err);
                	console.log('Error parsing device info from imp');
                	return;
                })
            });
        }
        else{
            $('#button').html('Start')
            $.ajax({ 
                type:'GET', 
                url: window.location + '/stopscope', 
                data: '',
                success: updateChart,
                timeout: 30000,
                error: (function(err){
                    console.log(err);
                    console.log('Error parsing device info from imp');
                	return;
                })
            });
        }
        
    }
    function updateChart(transport){
      drawVisualization(JSON.parse(transport.slice(0,-3) + ""]""));
    }
    //
    </script>
  </head>
  <body>
    Hex from Sample %s<br/>
    Ideal hex if input   %s<br/>
    <button type=""button"" id=""button"" onclick=""record()"">Start</button>
    <div id=""dashboard"" style='width: 100%%'>
        <div id=""chart"" style='width: 99%%; height: 300px;'></div>
        <div id=""control"" style='width: 99%%; height: 50px;'></div>
    </div>
    <p>Download this data as a CSV <a href=""%s/blinkup.csv"">here</a>.</p>
    <p>%s</p>
  </body>
</html>";
 
// Constants &  Globals
const PIXELS_PER_SECOND = 500;  // Number of pixels 
data <- blob();     // Received blinkup data
dataCSV <- "";
dataHex <- "";
hexTable <- [];
graphString <- "";
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

http.onrequest(function(request, response) {
  server.log("HTTP access");
  if (request.path == "/blinkup.csv") {
    clearOldData();
    generateCSV();
    response.header("Content-Type", "application/octet-stream");
    response.send(200, dataCSV);
  } else if (request.path == "/hex.txt") {
    response.header("Content-Type", "text/plain");
    response.send(200, dataHex);
  } else if (request.path == "/startscope") {
      //Tell scope to start
      device.send("scopeRunning", 1);
    response.header("Content-Type", "text/plain");
    response.send(200, "Started");
  } else if (request.path == "/stopscope") {
      //tell scope to stop
    device.send("scopeRunning", 0);
    RESPONSE = response;
    //response.header("Content-Type", "text/plain");
    //response.send(200, "Stopped");      
  } else if (request.path == "/compare") {
    clearOldData();
    local inputHexString = request.query["IdealHex"];
    generateIdealGraph(inputHexString);
    extraHtmlData += "Input Hex Data: " + generateReadableHex(split(inputHexString, ":")) + "<br/>";    
    extraHtmlData += "ImpScope Data: " + generateReadableHex(split(dataHex, ":")) + "<br/>";
    response.send(200, format(html_graph, additionalGraphDataColumns,idealGraphString, chartWidth, 
        chartWidth + 100, dataHex, inputHexString, chartWidth + 100, http.agenturl(), extraHtmlData));
   } else {
//    if (data.len()) {
        clearOldData();
        generateGraph();
      response.send(200, format(html_graph, additionalGraphDataColumns,graphString, dataHex, "",  http.agenturl(), extraHtmlData));
//    }    
  }
});
 
function clearOldData()
{
    idealGraphString = "";
    graphString = "";
    dataCSV = "";
    additionalGraphDataColumns = "";
    extraHtmlData = "";
}
 
// Append received buffers to blinkup data blob
function receiveData(blinkupData) {
  blinkupData.buffer.resize(blinkupData.length);
  data.writeblob(blinkupData.buffer);
  server.log("Received buffer of length " + blinkupData.buffer.len());
  
  //Send Data to page
    clearOldData();
    generateGraph();
    RESPONSE.header("Content-Type", "text/plain");
    RESPONSE.send(200, "[" + graphString + "]"); 
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
    dataHex = "";
    hexTable = [];
    startSampleOfBlinkup = 0;
    valueMin = 4095;
    valueMax = 0;
 
    //initial data analysis
    findMinMax();
    generateHex();
    // Compute chart width
    chartWidth = (data.len().tofloat() / 2.0 / sampleRate.tofloat()) * PIXELS_PER_SECOND;  
}
 
function generateGraph() {
  
  // Add data to a 2D array
  graphString = "";//"['Sample', 'Value'], ";
  local i = 0.0;
  for (local j = 0; j < data.len(); j+=2) {
    local value = (data[j] >> 4) | (data[j+1] << 4);
    value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
    graphString += format("[%.3f, %f], ", i / sampleRate, value);
    i++;
  }
  server.log(format("Graph generated with %i values: ", data.len()/2));
  server.log(graphString);
}
 
// Convert hex string to an integer
function hexToInteger(hex)
{
    local result = 0;
    local shift = hex.len() * 4;
 
    // For each digit..
    for(local d=0; d<hex.len(); d++)
    {
        local digit;
 
        // Convert from ASCII Hex to integer
        if(hex[d] >= 0x61)
            digit = hex[d] - 0x57;
        else if(hex[d] >= 0x41)
             digit = hex[d] - 0x37;
        else
             digit = hex[d] - 0x30;
 
        // Accumulate digit
        shift -= 4;
        result += digit << shift;
    }
 
    return result;
}
 
function doubleHexToBinary (doubleHex)
{
//  local firstHexAsInt = hexToInteger(doubleHex.slice(0,0));
//  local secondHexAsInt = hexToInteger(doubleHex.slice(1,1));  
  local binArr = [false, false, false, false, false, false, false, false];
  for (local hexSpot = 0; hexSpot < 2; hexSpot++)
  {
    local intVal = hexToInteger(doubleHex.slice(hexSpot, hexSpot+1));
    //server.log(format("hex: %s to int %d", doubleHex.slice(hexSpot, hexSpot+1), intVal));
    for (local boolSpot = 0; boolSpot < 4; boolSpot++)
    {
      binArr[3 - boolSpot + hexSpot * 4] = ((intVal >> boolSpot) & 1) == 0x01 ? true : false ;
      //server.log(format("Int: %d bool:%s", (intVal >> boolSpot), ((intVal >> boolSpot) & 1) == 0x01 ? "true" : "false"));
    }
  }
 
  return binArr;
}
 
function generateReadableHex(hexArr) {
    local readableString = "";
    local blinkState = true;
    local ssidLength = 0;
    local passStarted = false;
    local passLength = 0;
    local enrolment05 = false;
    local enrolment10 = false;
    local enrolmentLoc = 9999;
    local siteId = false;
    local tokenId = false;
    for (local i = 0; i < hexArr.len(); i++)
    {
        local hex = hexArr[i];
        if (i < 8) {
            if (hex != "AA") {
                readableString += " Start Blink (8xAA) Fail, ";
                blinkState = false;
            }
        } else if (i == 8) {
           if (hex != "2A") {
                readableString += " Start Blink (1x2A) Fail, ";
                blinkState = false;
            }
        } else if (i == 9) {
            if (blinkState)
                readableString += "Start Blink Success, ";
                
            local intVal = hexToInteger(hex.slice(0, 1)) * 16 + hexToInteger(hex.slice(1, 2));
            readableString += "Length: " + intVal + ", ";
        } else if (i == 10) {
            if (hex == "01") {
                readableString += "SSID: ";
            } else if (hex == "03") {
                readableString += "WPS: ";
            } else if (hex == "07") {
                readableString += "RESET ";
                enrolment05 = true;
                enrolment10 = true;
                enrolmentLoc = i + 1 - 16;
            } else if (hex == "04") {
                readableString += "FIRMWARE ";
                enrolment05 = true;
                enrolment10 = true;
                enrolmentLoc = i + 1 - 16;
            }
            
        } else if (i == 11) {
            ssidLength = hexToInteger(hex.slice(0, 1)) * 16 + hexToInteger(hex.slice(1, 2));
        } else if (i > 11 && i < 12 + ssidLength) {
            local intVal = hexToInteger(hex.slice(0, 1)) * 16 + hexToInteger(hex.slice(1, 2));
            readableString += format("%c", intVal);
        } else if (i == 12 + ssidLength) {
            if (hex == "06") { //Found a password
                readableString += " WifiPass: ";
                passStarted = true; //Set to 1 so we hit the length byet
            } else if (hex == "05") {
                readableString += " NoPass, Enrol Start, ";
                enrolment05 = true;
            } else {
                readableString += " Error at wifipass or enrol start, ";
            }
        } else if (passStarted && i == 12 + ssidLength + 1) {
            local intVal = hexToInteger(hex.slice(0, 1)) * 16 + hexToInteger(hex.slice(1, 2));
            passLength = intVal;     
        } else if (passStarted && i < 12 + ssidLength + 2 + passLength) {
            local intVal = hexToInteger(hex.slice(0, 1)) * 16 + hexToInteger(hex.slice(1, 2));
            readableString += format("%c", intVal);
        } else if (passStarted) {
            //We should have a 05 here as the password is done
            passStarted = false;            
            if (hex == "05") {
                readableString += " Enrol Start, ";
                enrolment05 = true;
            } else {
                readableString += " Error at enrol start:" + hex + ", ";
            }
        } else if (enrolment05 && ! enrolment10) {
            if (hex != "10") {
                readableString += " Enrol (0x10) error, ";
            }  else {
                enrolment10 = true;
            }            
            enrolmentLoc = i + 1;
            readableString += " siteId: ";
        } else if (enrolment05 && enrolment10 && i < enrolmentLoc + 8) {
            readableString += hex;
        } else if (enrolment05 && enrolment10 && i == enrolmentLoc + 8) {
            readableString += " , tokenId: " + hex;
        } else if (enrolment05 && enrolment10 && i < enrolmentLoc + 16) {
            readableString += hex;
        } else if (enrolment05 && enrolment10 && i == enrolmentLoc + 16) {
            readableString += " , CRC: " + hex;
        } else  {
            readableString += hex;
        }
    }
    
    return readableString;
}
 
function generateIdealGraph(hexString) {
    //Explode the hex string
    //generate the graph
  local hexs = split(hexString, ":");
  
  //local startTime = startSampleOfBlinkup / sampleRate;
  additionalGraphDataColumns = "data.addColumn({type:'string', role:'annotation'});\n"
  additionalGraphDataColumns += "data.addColumn('number','Ideal');\n"
  additionalGraphDataColumns += "data.addColumn({type:'string', role:'annotation'});\n"
  /*idealGraphString += format("[%.3f, %f], ", 0, valueMin);
  local runTime = startTime;
  for (local i = 0; i < hexs.len(); i++)
  {
    local binary = doubleHexToBinary(hexs[i]);
    for (local binSpot = 0; binSpot < 16; binSpot++)
    {
      local value = (valueMin / 4095.0) * 3.3;;
      if (binary[binSpot] == 1)
        value = (valueMax / 4095.0) * 3.3;   // Scale and convert to voltage
      idealGraphString += format("[%.3f, %f], ", runTime + 0.01, value);
      idealGraphString += format("[%.3f, %f], ", runTime + 1.0 / 60.0, value);
      runTime + 1.0 / 60.0;
    }
  }*/
 
 
  local i = 0.0;
  local switchPoint = 0;//startSampleOfBlinkup;
  local samplesPerTick = sampleRate / 60.0; //Samples per bit
  
  local idealValue = valueMin;
  local binarySpot = 8;
  local hexSpot = 0;
  local binary = null;
  local tickSpot = 0;
  local annotation = null;
  local hexTableSpot = 0;
  local nextHexTableSample = 0;
  local sampledAnnotation = null;
  if (hexTable.len() > 0) {
      nextHexTableSample = hexTable[0].sample;
  }
  
//   if (startSampleOfBlinkup * 2 + 1 > data.len() - 1)
//   {
//       server.log("Sample past data? sample:%d, data:%d", startSampleOfBlinkup, data.len());
//   }
  
  local startJ = startSampleOfBlinkup * 2;
  startJ = startJ.tointeger()
  
  //Loop through the data to create the graph string
  for (local j = startJ; j < data.len(); j+=2) {
    //If we have just passed a hex sample, make annotation
    if (j / 2 > nextHexTableSample)
    {
        //Make sure we have at least one annotation
        if (hexTable.len() > 0)
            sampledAnnotation = hexTable[hexTableSpot].hex;
            
        //If there was no data, insert a n! symbol
        if (sampledAnnotation == null)
            sampledAnnotation = "n!";
            
         //server.log("HTSpot:" + hexTableSpot + " sample: " + j / 2 + " annot: " + sampledAnnotation + " hexSpotSample: " + hexTable[hexTableSpot].sample);
        //Advance to the next spot in the annotation table
        hexTableSpot++;
        if (hexTable.len() > hexTableSpot) {    
            nextHexTableSample = hexTable[hexTableSpot].sample;
        } else {
            nextHexTableSample = 999999999;
        }
    }
  
    // If we have gone through 8 bits, it's time to grab more
    // data from the input string
    if (binarySpot == 8)
    {        
        binary = doubleHexToBinary(hexs[hexSpot]);
        if (hexSpot > 0)
            annotation = hexs[hexSpot - 1];
        //server.log(format("Processing spot: %s with Binary0: %s 1: %s", hexs[hexSpot], (binary[0]) ? "0" : "1", (binary[1]) ? "0" : "1"));
        binarySpot = 0;
        hexSpot++;
    }
    
    if (hexSpot >= hexs.len())
    {
        binarySpot = 0;
        hexSpot = 0;
        switchPoint = 9999999;
        idealValue = 0;
    }
    
    if (i > switchPoint) {
        if (binary[binarySpot])    
            idealValue = valueMax;
        else
            idealValue = valueMin;
        binarySpot++;
        tickSpot++;
        switchPoint = (samplesPerTick * tickSpot);// + startSampleOfBlinkup;        
    }
 
    if (j + 1 > data.len() - 1) {
        server.log("Sample past data during for? sample:%d, data:%d", startSampleOfBlinkup, data.len());
    }
    /*server.log("j:" + j + " len:" + data.len());
    local t1 = data[j];
    local t2 = data[j + 1]; */
    
    local value = (data[j] >> 4) | (data[j+1] << 4);
    value = (value / 4095.0) * 3.3;   // Scale and convert to voltage
    if (annotation != null && sampledAnnotation != null)
        idealGraphString += format("[%.3f, %f, '%s', %f, '%s'], ", i / sampleRate, value, sampledAnnotation, (idealValue / 4095.0) * 3.3, annotation);
    else if (annotation != null)
        idealGraphString += format("[%.3f, %f, null, %f, '%s'], ", i / sampleRate, value, (idealValue / 4095.0) * 3.3, annotation);
    else if (sampledAnnotation != null)
        idealGraphString += format("[%.3f, %f, '%s', %f, null], ", i / sampleRate, value, sampledAnnotation, (idealValue / 4095.0) * 3.3);
    else
        idealGraphString += format("[%.3f, %f, null, %f, null], ", i / sampleRate, value, (idealValue / 4095.0) * 3.3);
        
    sampledAnnotation = null;
    annotation = null;
    i++;
  }
  server.log(format("Ideal graph generated"));
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
 
//Go through the raw data and generate a hex interpretation of the data
// Store the result as a string in dataHex and in a table hexTable
function generateHex() {
  dataHex = "";
 
  local hysteresisDiff = (valueMax - valueMin) * 0.25;
  local changePointWhenHigh = valueMax - hysteresisDiff;
  local changePointWhenLow = valueMin + hysteresisDiff;
  
 
  local lastBool = true;
  local timeSinceChange = 0.0;
  local timePerBit = 1.0/60.0;
  local timePerSample = 1.0 / sampleRate;
  local blinkState = BlinkState.NotStarted;
  local centerTime = 0; //This is the time calculated as the center of the first high
  local nextBitTime = 0; //Time to grab the next bit
  local hexValue = 0;
  local hexBitSet = 0;
  local possibleStart = 0;
  local foundFirstAA = false;
  local secondLowSampleSpot = 0;
  local lastValue = 0.0;
  server.log("Found Min:" + valueMin + " Max:" + valueMax);
  server.log("High Change:" + changePointWhenHigh + " Low Change: " + changePointWhenLow);
  //hexTable.append({"sample": 0, "hex":format("%02X", 0x00)});
  for (local j = 0; j < data.len(); j+=2) {
    local value = (data[j] >> 4) | (data[j+1] << 4);
    local delta = value - lastValue;
    //if delta is > 0, we are going up else going down
    local time = j / 2.0 / sampleRate;
    local didChange = false;
    local currentBool = false;
    if (lastBool == false) {
      if (value > changePointWhenLow && delta > 0.09) {
        didChange = true;
        currentBool = true;
        timeSinceChange = 0.0;
      } else {
        currentBool = false;
        timeSinceChange += timePerSample;
      }
    } else {
      if (value < changePointWhenHigh && delta < -0.09) {
        didChange = true;
        currentBool = false;
        timeSinceChange = 0.0;
      } else {
        currentBool = true;
        timeSinceChange += timePerSample;
      }
    }
 
    
    if (blinkState == BlinkState.NotStarted) {
        //if (time < 3)
        //server.log("Time: " + time + " currentBool:" + currentBool + " lbool: " + lastBool + " didChange:" + didChange + " timeSinceChange: " + timeSinceChange);
        if (currentBool == false && timeSinceChange > 0.1) {
            blinkState = BlinkState.LongLow;            
            server.log("Going to long low at time " + time);
        }
    } else if (blinkState == BlinkState.LongLow) {
        if (didChange && currentBool == true) {
            blinkState = BlinkState.FirstHigh;
            centerTime = time;
            server.log("Going to first high at time " + time);
            startSampleOfBlinkup = j / 2.0;
            hexValue = hexValue<<1 | 0x01;
            hexBitSet++;            
        }
    } else if (blinkState == BlinkState.FirstHigh) {
        //If we hi for longer than 1/60th of a second, something is wrong
        if (timeSinceChange > 1.0/40.0) {
            blinkState = BlinkState.NotStarted;
            server.log("We've been high to long, reset");
            timeSinceChange = 0.0;
            hexBitSet = 0;
            hexValue = 0;
        } else if (didChange && currentBool == false) {
            secondLowSampleSpot = j;
            blinkState = BlinkState.Going;
            //This time is not actually the center of the bit, but 3/4 through the bit
            // this will hopefully allow the signal to be more stable at this point
            centerTime = centerTime + timePerBit * 0.70;//(time - centerTime) / 2.0;
            nextBitTime = centerTime + timePerBit * 2.0;
            hexValue = hexValue<<1; 
            hexBitSet++;
            server.log("Going to going at time "+ time);
        }
    } else if (blinkState == BlinkState.Going) {
        if (time > nextBitTime) {
            //Grab the bit
            nextBitTime += timePerBit;
            if (currentBool == true) {
                hexValue = hexValue<<1 | 0x01;
            } else {
                hexValue = hexValue<<1;        
            }
            hexBitSet++;
        }
    }
    
    
    if (hexBitSet == 8) {
        if (! foundFirstAA)
        {
            //Lets be more rebust and check for an AA pattern
            if (hexValue == 0xAA)
            {
                foundFirstAA = true;
            } else
            {
                j = secondLowSampleSpot + 2;
                currentBool == false;
                timeSinceChange = 0.0;                        
                blinkState = BlinkState.LongLow;            
                server.log("Resetting on bad AA: " + format("%02X:", hexValue) + " at time: " + time);
                hexBitSet = 0;
                hexValue = 0;
            }
        }
        
        if (foundFirstAA)
        {
            dataHex += format("%02X:", hexValue);
            hexTable.append({"sample": j / 2, "hex":format("%02X", hexValue)});            
            hexValue = 0;
            hexBitSet = 0;            
        }
 
    }
    
    lastBool = currentBool;
    lastValue = value;
    
//
//enum BlinkState {
//  NotStarted = 0,
//  LongLow,
//  FirstHigh,
//  FirstLow,
//  Going,
//  Ended
//}
    
  }
 
 
  //server.log("Hex generated.");
}
 
device.on("data", receiveData);
device.on("state", updateState)
