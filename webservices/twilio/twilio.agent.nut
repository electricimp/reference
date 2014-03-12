onst TWILIO_URL = "https://api.twilio.com/2010-04-01/Accounts/";
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

// send a text message
send_sms("15551234", "Hello from my Electric Imp project!!");
