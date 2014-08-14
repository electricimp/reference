class ReadSpeaker {
    _baseUrl = "http://tts.readspeaker.com/a/speak?%s";
    _key = null;
    _data = null;
    
    /************************************************************
     * ReadSpeaker Constructor
     * 
     * Parameters: 
     *  key - your ReadSpeaker key
     ************************************************************/
    constructor(key) {
        this._key = key;
        this._data = {
            key= _key, 
            command="produce",
            lang="en_us",
            voice="Male01",
            text="",
            audioformat="alaw",
            container="none", 
            samplerate=16000,
            sampledepth=8
        };
    }
    
    /************************************************************
     * Function: say
     *
     * Parameters:
     *   text - The text you would like to speak
     *   cb - A callback function with 2 parameters
     *          err - An error (or null on success)
     *          data - [blob] A-Law compressed audio file (null on error)
     *
     * Returns: none
     ************************************************************/
    function say(text, cb) {
        _data["text"] = text;
        local url = format(_baseUrl, http.urlencode(_data));
            _getAndAutoRedirect(url, function(resp) {
            if (resp.statuscode == 200) {
                cb(null, resp.body);
            } else {
                local err = format("ERROR %i: %s", resp.statuscode, resp.body);
                cb(err, null);
            }
        }.bindenv(this));
    }
    
    /******************** PRIVATE METHODS (DO NOT CALL) ********************/
    function _getAndAutoRedirect(url, cb) {
        server.log("GET " + url);
        http.get(url).sendasync(function(resp) {
            // if we got a redirect
            if(resp.statuscode == 302) {
                if ("location" in resp.headers) {
                    server.log("Trying " + resp.headers.location + " in 5 seconds");
                    _getAndAutoRedirect(resp.headers.location, cb);
                }
            } else {
                cb(resp);
            }
        }.bindenv(this));
    }
}

ttsEngine <- ReadSpeaker("********************************");

http.onrequest(function(req, resp) {
    if ("say" in req.query) {
        ttsEngine.say(req.query.say, function(err, data) {
            if (err) {
                server.log(err);
                resp.send(500, "Internal Agent Error: (" + err + ")");
                return;
            } else {
                device.send("audio", data);
                resp.send(200, "OK");
            }
        });
    } else {
        resp.send(400, "Bad Request - missing query parameter 'say'");
    }
});

