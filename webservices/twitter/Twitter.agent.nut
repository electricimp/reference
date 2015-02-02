class Twitter {
	
	// Copyright (c) 2015 Electric Imp
	// This file is licensed under the MIT License
	// http://opensource.org/licenses/MIT

	// Twitter access class
	// Requires: Twitter account from which the above keys can be accessed
	// Availability: Agent

	// Usage: 
	//   Twitter Keys
	//   const API_KEY = "";
	//   const API_SECRET = "";
	//   const AUTH_TOKEN = "";
	//   const TOKEN_SECRET = "";

	//   twitter <- Twitter(API_KEY, API_SECRET, AUTH_TOKEN, TOKEN_SECRET)

	// URLs
	static STREAM_URL = "https://stream.twitter.com/1.1/";
	static TWEET_URL = "https://api.twitter.com/1.1/statuses/update.json";
    
	// OAuth
	_consumerKey = null;
	_consumerSecret = null;
	_accessToken = null;
	_accessSecret = null;
    
	// Streaming
	_streamingRequest = null;
	_reconnectTimeout = null;
	_buffer = null;

	constructor (consumerKey, consumerSecret, accessToken, accessSecret) {
		_consumerKey = consumerKey;
		_consumerSecret = consumerSecret;
		_accessToken = accessToken;
		_accessSecret = accessSecret;
        
		_reconnectTimeout = 60;
		_buffer = "";
	}
    
	/***************************************************************************
	* function: Tweet
	*   Posts a tweet to the user's timeline
	* 
	* Params:
	*   status - the tweet
	*   cb - an optional callback
	* 
	* Return:
	*   bool indicating whether the tweet was successful(if no cb was supplied)
	*   nothing(if a callback was supplied)
	**************************************************************************/

	function tweet(status, cb = null) {
		local headers = { };
		local request = _oAuth1Request(TWEET_URL, headers, { "status": status} );
		if (cb == null) {
			local response = request.sendsync();
			if (response && response.statuscode != 200) {
				server.error(format("Error updating_status tweet. HTTP Status Code %i:\r\n%s", response.statuscode, response.body));
				return false;
			} else {
				return true;
			}
		} else {
			request.sendasync(cb);
		}
	}
    
	/***************************************************************************
	* function: Stream
	*   Opens a connection to twitter's streaming API
	* 
	* Params:
	*   searchTerms - what we're searching for
	*   onTweet - callback function that executes whenever there is data
	*   onError - callback function that executes whenever there is an error
	**************************************************************************/

	function stream(searchTerms, onTweet, onError = null) {
		// server.log("Opening stream for: " + searchTerms);

		// Set default error handler

		if (onError == null) onError = _defaultErrorHandler.bindenv(this);
        
		local method = "statuses/filter.json"
		local headers = { };
		local post = { track = searchTerms };
		local request = _oAuth1Request(STREAM_URL + method, headers, post);
        
		_streamingRequest = request.sendasync(

			// Handle the end of the stream
			function(resp) {
				// connection timeout
				// server.log("Stream Closed (" + resp.statuscode + ": " + resp.body +")");
				
				// if we have autoreconnect set
				if (resp.statuscode == 28 || resp.statuscode == 200) {
					stream(searchTerms, onTweet, onError);
				} else if (resp.statuscode == 420 || resp.statuscode == 429) {
					imp.wakeup(_reconnectTimeout, function() { stream(searchTerms, onTweet, onError); }.bindenv(this));
					_reconnectTimeout *= 2;
				}
			}.bindenv(this),
            

            // Handle a new packet in the middle of the stream
			function(body) {
				try {
				if (body.len() == 2) {
					_reconnectTimeout = 60;
					_buffer = "";
					return;
				}
                    
				local data = null;
				try {
					data = http.jsondecode(body);
				} catch(ex) {
					_buffer += body;
					try {
						data = http.jsondecode(_buffer);
					} catch (ex) {
						return;
					}
				}

				if (data == null) return;

				// if it's an error
				if ("errors" in data) {
					onError(data.errors);
					return;
				} 
				else {
					if (_looksLikeATweet(data)) {
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
    
	/***** Private Function - Do Not Call *****/

	function _encode(str) {
		return http.urlencode({ s = str }).slice(2);
	}

	function _oAuth1Request(postUrl, headers, data) {
		local nonce = time();
		local parm_string = http.urlencode({ oauth_consumer_key = _consumerKey });
		parm_string += "&" + http.urlencode({ oauth_nonce = nonce });
		parm_string += "&" + http.urlencode({ oauth_signature_method = "HMAC-SHA1" });
		parm_string += "&" + http.urlencode({ oauth_timestamp = nonce });
		parm_string += "&" + http.urlencode({ oauth_token = _accessToken });
		parm_string += "&" + http.urlencode({ oauth_version = "1.0" });
		parm_string += "&" + http.urlencode(data);
        
		local signature_string = "POST&" + _encode(postUrl) + "&" + _encode(parm_string);
        
		local key = format("%s&%s", _encode(_consumerSecret), _encode(_accessSecret));
		local sha1 = _encode(http.base64encode(http.hash.hmacsha1(signature_string, key)));
        
		local auth_header = "oauth_consumer_key=\""+_consumerKey+"\", ";
		auth_header += "oauth_nonce=\""+nonce+"\", ";
		auth_header += "oauth_signature=\""+sha1+"\", ";
		auth_header += "oauth_signature_method=\""+"HMAC-SHA1"+"\", ";
		auth_header += "oauth_timestamp=\""+nonce+"\", ";
		auth_header += "oauth_token=\""+_accessToken+"\", ";
		auth_header += "oauth_version=\"1.0\"";
        
		local headers = { 
			"Authorization": "OAuth " + auth_header
		};
        
		local url = postUrl + "?" + http.urlencode(data);
		local request = http.post(url, headers, "");
		return request;
	}
    
	function _looksLikeATweet(data) {
		return (
			"created_at" in data &&
			"id" in data &&
			"text" in data &&
			"user" in data
		);
	}
    
	function _defaultErrorHandler(errors) {
		foreach(error in errors) {
			server.error("Twitter (error " + error.code + "): " + error.message);
		}
	}
}
