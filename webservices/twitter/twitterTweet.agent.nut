helper <- {
    function encode(str) {
        return http.urlencode({ s = str }).slice(2);
    }
}
 
class TwitterClient {
    consumerKey = null;
    consumerSecret = null;
    accessToken = null;
    accessSecret = null;
    
    baseUrl = "https://api.twitter.com/";
    
    constructor (_consumerKey, _consumerSecret, _accessToken, _accessSecret) {
        this.consumerKey = _consumerKey;
        this.consumerSecret = _consumerSecret;
        this.accessToken = _accessToken;
        this.accessSecret = _accessSecret;
    }
    
    function post_oauth1(postUrl, headers, post) {
        local time = time();
        local nonce = time;
 
        local parm_string = http.urlencode({ oauth_consumer_key = consumerKey });
        parm_string += "&" + http.urlencode({ oauth_nonce = nonce });
        parm_string += "&" + http.urlencode({ oauth_signature_method = "HMAC-SHA1" });
        parm_string += "&" + http.urlencode({ oauth_timestamp = time });
        parm_string += "&" + http.urlencode({ oauth_token = accessToken });
        parm_string += "&" + http.urlencode({ oauth_version = "1.0" });
        parm_string += "&" + http.urlencode({ status = post });
        
        local signature_string = "POST&" + helper.encode(postUrl) + "&" + helper.encode(parm_string)
        
        local key = format("%s&%s", helper.encode(consumerSecret), helper.encode(accessSecret));
        local sha1 = helper.encode(http.base64encode(http.hash.hmacsha1(signature_string, key)));
        
        local auth_header = "oauth_consumer_key=\""+consumerKey+"\", ";
        auth_header += "oauth_nonce=\""+nonce+"\", ";
        auth_header += "oauth_signature=\""+sha1+"\", ";
        auth_header += "oauth_signature_method=\""+"HMAC-SHA1"+"\", ";
        auth_header += "oauth_timestamp=\""+time+"\", ";
        auth_header += "oauth_token=\""+accessToken+"\", ";
        auth_header += "oauth_version=\"1.0\"";
        
        local headers = { 
            "Authorization": "OAuth " + auth_header,
        };
        
        local response = http.post(postUrl + "?status=" + helper.encode(post), headers, "").sendsync();
        return response
    }
 
    function Tweet(_status) {
        local postUrl = baseUrl + "1.1/statuses/update.json";
        local headers = { };
        
        local response = post_oauth1(postUrl, headers, _status)
        if (response && response.statuscode != 200) {
            server.log("Error updating_status tweet. HTTP Status Code " + response.statuscode);
            server.log(response.body);
            return null;
        } else {
            server.log("Tweet Successful!");
        }
    }
}
 
_CONSUMER_KEY <- "YourConsumerKey";
_CONSUMER_SECRET <- "YourConsumerSecret";
_ACCESS_TOKEN <- "YourAccessToken";
_ACCESS_SECRET <- "YourAccessSecret";
twitter <- TwitterClient(_CONSUMER_KEY, _CONSUMER_SECRET, _ACCESS_TOKEN, _ACCESS_SECRET);
 
twitter.Tweet("Tweeting with the new @electricimp hash functionality.");

