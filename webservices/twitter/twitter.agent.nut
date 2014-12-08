// Twitter Keys

const API_KEY = "";
const API_SECRET = "";
const AUTH_TOKEN = "";
const TOKEN_SECRET = "";

class Twitter {

	// Copyright 2014 Electric Imp
	// Issued under the MIT license (MIT)

	// Permission is hereby granted, free of charge, to any person obtaining a copy
	// of this software and associated documentation files (the "Software"), to deal
	// in the Software without restriction, including without limitation the rights
	// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	// copies of the Software, and to permit persons to whom the Software is
	// furnished to do so, subject to the following conditions:
	// 	The above copyright notice and this permission notice shall be included in
	// 	all copies or substantial portions of the Software.

	// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	// THE SOFTWARE.
	
	// OAuth

	_consumerKey = null;
	_consumerSecret = null;
	_accessToken = null;
	_accessSecret = null;
    
	// URLs

	streamUrl = "https://stream.twitter.com/1.1/";
	tweetUrl = "https://api.twitter.com/1.1/statuses/update.json";
    
	// Streaming

	streamingRequest = null;
	_reconnectTimeout = null;
	_buffer = null;

	constructor (consumerKey, consumerSecret, accessToken, accessSecret) {
		this._consumerKey = consumerKey;
		this._consumerSecret = consumerSecret;
		this._accessToken = accessToken;
		this._accessSecret = accessSecret;
        
		this._reconnectTimeout = 60;
		this._buffer = "";
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
		local request = _oAuth1Request(tweetUrl, headers, { "status": status} );
		if (cb == null) {
			local response = request.sendsync();
			if (response && response.statuscode != 200) {
				server.log(format("Error updating_status tweet. HTTP Status Code %i:\r\n%s", response.statuscode, response.body));
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
		server.log("Opening stream for: " + searchTerms);

		// Set default error handler

		if (onError == null) onError = _defaultErrorHandler.bindenv(this);
        
		local method = "statuses/filter.json"
		local headers = { };
		local post = { track = searchTerms };
		local request = _oAuth1Request(streamUrl + method, headers, post);
        
		this.streamingRequest = request.sendasync(
			function(resp) {
				// connection timeout
				server.log("Stream Closed (" + resp.statuscode + ": " + resp.body +")");
				
				// if we have autoreconnect set
				if (resp.statuscode == 28 || resp.statuscode == 200) {
					stream(searchTerms, onTweet, onError);
				} else if (resp.statuscode == 420) {
					imp.wakeup(_reconnectTimeout, function() { stream(searchTerms, onTweet, onError); }.bindenv(this));
					_reconnectTimeout *= 2;
				}
			}.bindenv(this),
            
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
					server.log("Got an error");
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
		local time = time();
		local nonce = time;
		local parm_string = http.urlencode({ oauth_consumer_key = _consumerKey });
		parm_string += "&" + http.urlencode({ oauth_nonce = nonce });
		parm_string += "&" + http.urlencode({ oauth_signature_method = "HMAC-SHA1" });
		parm_string += "&" + http.urlencode({ oauth_timestamp = time });
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
		auth_header += "oauth_timestamp=\""+time+"\", ";
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
			server.log("ERROR " + error.code + ": " + error.message);
		}
	}
}
 
twitter <- Twitter(API_KEY, API_SECRET, AUTH_TOKEN, TOKEN_SECRET);
