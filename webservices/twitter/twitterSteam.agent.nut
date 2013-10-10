class TwitterStream {
    // OAuth
    consumerKey = null;
    consumerSecret = null;
    accessToken = null;
    accessSecret = null;
    
    // URLs
    streamUrl = "https://stream.twitter.com/1.1/";
    
    // Streaming
    streamingRequest = null;
    
    constructor (_consumerKey, _consumerSecret, _accessToken, _accessSecret) {
        this.consumerKey = _consumerKey;
        this.consumerSecret = _consumerSecret;
        this.accessToken = _accessToken;
        this.accessSecret = _accessSecret;
    }
    
    function encode(str) {
        return http.urlencode({ s = str }).slice(2);
    }

    function oAuth1Request(postUrl, headers, post) {
        local time = time();
        local nonce = time;
 
        local parm_string = http.urlencode({ oauth_consumer_key = consumerKey });
        parm_string += "&" + http.urlencode({ oauth_nonce = nonce });
        parm_string += "&" + http.urlencode({ oauth_signature_method = "HMAC-SHA1" });
        parm_string += "&" + http.urlencode({ oauth_timestamp = time });
        parm_string += "&" + http.urlencode({ oauth_token = accessToken });
        parm_string += "&" + http.urlencode({ oauth_version = "1.0" });
        parm_string += "&" + http.urlencode(post);
        
        local signature_string = "POST&" + encode(postUrl) + "&" + encode(parm_string);
        
        local key = format("%s&%s", encode(consumerSecret), encode(accessSecret));
        local sha1 = encode(http.base64encode(http.hash.hmacsha1(signature_string, key)));
        
        local auth_header = "oauth_consumer_key=\""+consumerKey+"\", ";
        auth_header += "oauth_nonce=\""+nonce+"\", ";
        auth_header += "oauth_signature=\""+sha1+"\", ";
        auth_header += "oauth_signature_method=\""+"HMAC-SHA1"+"\", ";
        auth_header += "oauth_timestamp=\""+time+"\", ";
        auth_header += "oauth_token=\""+accessToken+"\", ";
        auth_header += "oauth_version=\"1.0\"";
        
        local headers = { 
            "Authorization": "OAuth " + auth_header
        };
        
        local url = postUrl + "?" + http.urlencode(post);
        local request = http.post(url, headers, "");
        return request;
    }
    
    function looksLikeATweet(data) {
        return (
            "created_at" in data &&
            "id" in data &&
            "text" in data &&
            "user" in data
        );
    }
    
    function defaultErrorHandler(errors) {
        foreach(error in errors) {
            server.log("ERROR " + error.code + ": " + error.message);
        }
    }
    
    function Stream(searchTerms, autoReconnect, onTweet, onError = null) {
		server.log("Opening stream for: " + searchTerms);
        // Set default error handler
        if (onError == null) onError = defaultErrorHandler.bindenv(this);
        
        local method = "statuses/filter.json"
        local headers = { };
        local post = { track = searchTerms };
        local request = oAuth1Request(streamUrl + method, headers, post);
        
        
        this.streamingRequest = request.sendasync(
            
            function(resp) {
                // connection timeout
                server.log("Stream Closed (" + resp.statuscode + ": " + resp.body +")");
                // if we have autoreconnect set
                if (resp.statuscode == 28 && autoReconnect) {
                    Stream(searchTerms, autoReconnect, onTweet, onError);
                }
            }.bindenv(this),
            
            function(body) {
                 try {
                    if (body.len() == 2) {
                        server.log("Twitter Keep Alive");
                        return;
                    }
                    
                    local data = http.jsondecode(body);
                    // if it's an error
                    if ("errors" in data) {
                        server.log("Got an error");
                        onError(data.errors);
                        return;
                    } 
                    else {
                        if (looksLikeATweet(data)) {
                            onTweet(data);
                            return;
                        }
                    }
                } catch(ex) {
                    // if an error occured, invoke error handler
                    onError([{ message = "Squirrel Error - " + ex, code = -1 }]);
                }
            }.bindenv(this)
        
        );
    }
}
 
_CONSUMER_KEY <- "";
_CONSUMER_SECRET <- "";
_ACCESS_TOKEN <- "";
_ACCESS_SECRET <- "";
_SEARCH_TERM <- "#electricimp";

function onTweet(tweet) {
	server.log("Got a tweet!");
	server.log("User: " + tweet.user.screen_name);
	server.log("Text: " + tweet.text);
}

stream <- TwitterStream(_CONSUMER_KEY, _CONSUMER_SECRET, _ACCESS_TOKEN, _ACCESS_SECRET);
stream.Stream(_SEARCH_TERM, true, onTweet);