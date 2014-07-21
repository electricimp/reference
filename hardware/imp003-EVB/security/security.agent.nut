// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT


const TWILIO_SID = "TWILLIO_ACCOUNT_SID";	// Your Twilio Account SID
const TWILIO_AUTH = "TWILLIO_AUTH_TOKEN";	// Your Twilio Auth Token
const TWILIO_NUM = "TWILLIO_PHONE_NUM";		// Your Twilio Phone Number

class Twilio 
{
    _baseUrl = "https://api.twilio.com/2010-04-01/Accounts/";

    _accountSid = null;
    _authToken = null;
    _phoneNumber = null;

    constructor(accountSid, authToken, phoneNumber) 
    {
        _accountSid = accountSid;
        _authToken = authToken;
        _phoneNumber = phoneNumber;
    }

    function send(to, message, callback = null) 
    {
        local url = _baseUrl + _accountSid + "/SMS/Messages.json";
        local auth = http.base64encode(_accountSid + ":" + _authToken);
        local headers = { "Authorization": "Basic " + auth };
        local body = http.urlencode({
            From = _phoneNumber,
            To = to,
            Body = message
        });

        local request = http.post(url, headers, body);
        
        if (callback == null)
        {
			return request.sendsync();
		}
        else
        {
			request.sendasync(callback);
		}
    }

    function Respond(resp, message) 
    {
        local data = { Response = { Message = message } };
        local body = xmlEncode(data);
        resp.header("Content-Type", "text/xml");
		server.log(body);
		resp.send(200, body);
    }

    function xmlEncode(data, version="1.0", encoding="UTF-8") 
    {
        return format("<?xml version=\"%s\" encoding=\"%s\" ?>%s", version, encoding, _recursiveEncode(data))
    }

    /******************** Private Function (DO NOT CALL) ********************/
    
    function _recursiveEncode(data) 
    {
        local s = "";
        
        foreach(k, v in data) 
        {
            if (typeof(v) == "table" || typeof(v) == "array") 
            {
                s += format("<%s>%s</%s>", k.tostring(), _recursiveEncode(v), k.tostring());
            }
            else 
            {
                s += format("<%s>%s</%s>", k.tostring(), v.tostring(), k.tostring());;
            }
        }
        
        return s;
    }
}

twilio <- Twilio(TWILIO_SID, TWILIO_AUTH, TWILIO_NUM);

// sending a message

numberToSendTo <- "12125551212"

// processing messages

http.onrequest(function(request, response) 
{
    local path = request.path.tolower();
    
    if (path == "/twilio" || path == "/twilio/") 
    {
        // twilio request handler
        
        try 
        {
            local data = http.urldecode(request.body);
            twilio.Respond(response, "You just said '" + data.Body + "'");
        } 
        catch(ex) 
        {
            local message = "Uh oh, something went horribly wrong: " + ex;
            twilio.Respond(response, message);
        }
    } 
    else 
    {
        // default request handler
        
        response.send(200, "OK");
    }
});


device.on("alarm", function(val){
    server.log("ALARM CONDITION");
    twilio.send(numberToSendTo, "ALARM CONDTION!", function(resp) { server.log(resp.statuscode + " - " + resp.body); });
});
