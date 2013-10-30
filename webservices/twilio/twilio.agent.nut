/*
Copyright (C) 2013 Electric Imp, Inc

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/



// -----------------------------------------------------------------------------
const TWILIO_URL = "https://api.twilio.com/2010-04-01/Accounts/";
const TWILIO_SID = "";
const TWILIO_PWD = "";
const TWILIO_SRC = "";
function send_sms(message, number) {
    local data = { From = TWILIO_SRC, To = number, Body = message };
    local auth = http.base64encode(TWILIO_SID + ":" + TWILIO_PWD);
    local headers = {"Authorization": "Basic " + auth};
    http.post(TWILIO_URL + TWILIO_SID + "/SMS/Messages.json", headers, http.urlencode(data)).sendasync(function(res) {
        if (res.statuscode == 200 || res.statuscode == 201) {
            server.log("Twilio SMS sent to: " + number);
        } else {
            server.log("Twilio error: " + res.statuscode + " => " + res.body);
        }
    })
}


