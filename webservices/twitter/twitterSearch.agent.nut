/*
The MIT License (MIT)

Copyright (c) 2013 Electric Imp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

class TwitterClient {
    consumerKey = null
    consumerSecret = null
    auth = null;
    
    baseUrl = "https://api.twitter.com/1.1/";
    
    constructor (_consumerKey, _consumerSecret) {
        this.consumerKey = _consumerKey;
        this.consumerSecret = _consumerSecret;
        this.auth = getApplicationAuth();
    }
    
    /************************************************************
     * Gets an application authentication token
     * returns:
     *    string: token if auth was successful
     *    null: if auth was unsuccessful
    ************************************************************/
    function getApplicationAuth() {
        local authURL = "https://api.twitter.com/oauth2/token"
        local body = "grant_type=client_credentials";
        
        local credentials = consumerKey + ":" + consumerSecret;
        local encodedCredentials = http.base64encode(credentials);

        local headers = { 
            "Authorization": "Basic " + encodedCredentials,
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
        }
        server.log("Getting Authorization from Twitter..");
        local response = http.post(authURL, headers, body).sendsync();
        if (response.statuscode != 200) {
            server.log("Error Authenticating: " + response.body);
            return null;
        }
        local data = {};
        try {
            data = http.jsondecode(response.body);
        } catch(ex) { 
            server.log("Error parsing response body to JSON: " + response.body);
            return null;
        }
        
        if (!("token_type" in data)) {
            server.log("Response body missing token_type: " + response.body);
            return null;
        } else if (data.token_type != "bearer") {
            server.log("Error: token_type not 'bearer': " + body.token_type);
            return null;
        }else if (!("access_token" in data)) {
            server.log("Error: response body missing access_token: " + response.body);
            return null;
        }
        server.log("Got Authorized by Twitter!");
        return "Bearer " + data.access_token;
    }
    
    /************************************************************
     * Searches Twitter and returns results
     * returns:
     *    table: a table with tweet information if successful (see  https://dev.twitter.com/docs/api/1.1/get/search/tweets)
     *    null: if there was an error searching
    ************************************************************/ 
    function search(query, count = null, since_id = null, geocode = null) {
        local requestUrl = baseUrl + "search/tweets.json";
        requestUrl += "?" + http.urlencode({ q = query });
        if (count != null) requestUrl += "&count=" + count;
        if (since_id != null) requestUrl += "&since_id=" + since_id;
        if (geocode != null && "latitude" in geocode && "longitude" in geocode && "radius" in geocode) requestUrl += "&geocode=" + geocode.latitude + "," + geocode.longitude + "," + geocode.radius;
        
        local headers = { "Authorization": this.auth };
        local response = http.get(requestUrl, headers).sendsync();
        
        if (response.statuscode != 200) {
            server.log("Error searching tweets. HTTP Status Code " + response.statuscode);
            server.log(response.body);
            return null;
        }

        local tweets = {};
        try {
            tweets = http.jsondecode(response.body);
            return tweets;
        }catch(ex) {
            server.log("Error parsing response from twitter search: " + response.body);
            return null;
        }
    }
} 

twitter <- TwitterClient("CONSUMER_KEY", "CONSUMER_SECRET");
