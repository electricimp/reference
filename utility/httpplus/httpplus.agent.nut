// -----------------------------------------------------------------------------
class HTTPPlus {
    
    _http = null;
    
    // .........................................................................
    // Keep a copy of the original http object for internal use
    constructor() {
        _http = http;
    }
    
    // .........................................................................
    // Override the http request function with a new httprequest object
    function request(method, url, headers = {}, body = "") {
        local params = [ method, url, headers, body ];
        return HTTPPlusRequest(_http, _http.request, params);
    }

    // .........................................................................
    function get(url, headers = {}) {
        local params = [ url, headers ];
        return HTTPPlusRequest(_http, _http.get, params);
    }

    // .........................................................................
    function put(url, headers = {}, body = null) {
        if (body == null) body = "";
        if (typeof body == "table" || typeof body == "array" ) {
            body = _http.jsonencode(body);
            headers["Content-Type"] <- "application/json";
        } else if (typeof body != "string") {
            body = body.tostring()
        }
        local params = [ url, headers, body ];
        return HTTPPlusRequest(_http, _http.put, params);
    }
    
    // .........................................................................
    function post(url, headers = {}, body = null) {
        if (body == null) body = "";
        if (typeof body == "table" || typeof body == "array" ) {
            body = _http.jsonencode(body);
            headers["Content-Type"] <- "application/json";
        } else if (typeof body != "string") {
            body = body.tostring()
        }
        local params = [ url, headers, body ];
        return HTTPPlusRequest(_http, _http.post, params);
    }
    
    // .........................................................................
    function httpdelete(url, headers = {}) {
        local params = [ url, headers ];
        return HTTPPlusRequest(_http, _http.httpdelete, params);
    }
    
    // .........................................................................
    // Pass through all the remaining original methods and properties
    function _get(idx) {
        if (idx in this) {
            return this[idx];
        } else if (_http == null && idx in http && typeof http[idx] == "function") {
            return http[idx].bindenv(http);
        } else if (_http != null && idx in _http && typeof _http[idx] == "function") {
            return _http[idx].bindenv(_http);
        } else if (idx in _http) {
            return _http[idx];
        } else {
            throw null;
        }
    }
    
}

class HTTPPlusRequest {

    _http = null;
    _request = null;
    _params = null;
    _retry = null;
    _httprequest = null;
    
    // .........................................................................
    constructor(http, request, params) {
        _http = http;
        _request = request;
        _params = params;
        if (_params) _params.insert(0, this);
    }
    
    // .........................................................................
    function sendsync() {
        
        // Prepare the httprequest object and execute the requested function
        local result = _request.bindenv(_http).acall(_params).sendsync();
        do {
            if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                // This is a retryable failure, wait for as long as are told then try again
                imp.sleep(result.headers["retry-after"].tofloat());
                result = _request.bindenv(_http).acall(_params).sendsync();
            } else if ([301, 302, 307].find(result.statuscode) != null && "location" in result.headers) {
                // This is a redirect request. Go follow it
                _params[1] = redirect(_params[1], result.headers.location);
                result = _request.bindenv(_http).acall(_params).sendsync();
            } else {
                break;
            }
        } while (true);
        
        return result;
    }
    
    // .........................................................................
    function sendasync(oncomplete, longpolldata = null, longpolltimeout = 600) {
        // Prepare the httprequest object
        _httprequest = _request.bindenv(_http).acall(_params);
        
        if (longpolldata == null) {
            // Handle a non-long-polling request
            _httprequest.sendasync(function(result) {
                _httprequest = null;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    _retry = imp.wakeup(result.headers["retry-after"].tofloat(), function() {
                        _retry = null;
                        sendasync(oncomplete);
                    }.bindenv(this));
                } else if ([301, 302, 307].find(result.statuscode) != null && "location" in result.headers) {
                    _params[1] = redirect(_params[1], result.headers.location);
                    _retry = imp.wakeup(0, function() {
                        _retry = null;
                        sendasync(oncomplete);
                    }.bindenv(this));
                } else {
                    oncomplete(result);
                }
            }.bindenv(this));
        } else {
            // Handle a long-polling request
            _httprequest.sendasync(function(result) {
                _httprequest = null;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    _retry = imp.wakeup(result.headers["retry-after"].tofloat(), function() {
                        _retry = null;
                        sendasync(oncomplete, longpolldata, longpolltimeout);
                    }.bindenv(this));
                } else if ([301, 302, 307].find(result.statuscode) != null && "location" in result.headers) {
                    _params[1] = redirect(_params[1], result.headers.location);
                    _retry = imp.wakeup(0, function() {
                        _retry = null;
                        sendasync(oncomplete);
                    }.bindenv(this));
                } else {
                    oncomplete(result);
                }
            }.bindenv(this), longpolldata, longpolltimeout);
        }
        return _httprequest;
    }
    
    // .........................................................................
    function cancel() {
        if (_retry) {
            // Cancel the retry timer
            imp.cancelwakeup(_retry);
            _retry = null;
        } else if (_httprequest) {
            // Cancel the http request
            _httprequest.cancel();
            _httprequest = null;
        }
    }
    
    // .........................................................................
    function parse_url(_url) {

        local url = { scheme=null, user=null, pass=null, host=null, port=null, path=null, query=null, fragment=null };
        
        // Extract the scheme
        local slashslash = _url.find("//");
        url.scheme = _url.slice(0, slashslash-1);

        // Prepare for the username and password
        local startofhost = slashslash+2;
        local atsign = _url.find("@", slashslash+2);
        local firstslash = _url.find("/", slashslash+2);
        if (firstslash == null) firstslash = _url.len();
        local firsthash = _url.find("#", firstslash+1);
        
        // Extract the user and pass
        if (atsign != null && atsign > slashslash && atsign < firstslash) {
            startofhost = atsign+1;
            local credentials = _url.slice(slashslash+2, atsign);
            local colon = credentials.find(":");
            if (colon == null) {
                url.user = credentials;
                url.pass = "";
            } else {
                url.user = credentials.slice(0, colon);
                url.pass = credentials.slice(colon+1);
            }
        }
        
        // Extract the host name
        local firstcolon = _url.find(":", startofhost);
        local firstquestion = _url.find("?", startofhost);
        local endofhost = _url.len();
        if (firstcolon != null && firstcolon < endofhost) endofhost = firstcolon;
        if (firstslash != null && firstslash < endofhost) endofhost = firstslash;
        if (firstquestion != null && firstquestion < endofhost) endofhost = firstquestion;
        if (firsthash != null && firsthash < endofhost) endofhost = firsthash;
        url.host = _url.slice(startofhost, endofhost);

        // Extract the port
        local startofpath = endofhost;
        if (firstcolon != null && firstcolon == endofhost) {
            local endofport = null;
            if (firstslash != null) endofport = firstslash;
            else if (firstquestion != null) endofport = firstquestion;

            if (endofport) {
                startofpath = endofport;
                url.port = _url.slice(firstcolon+1, endofport).tointeger();
            }
        }
        
        // Extract the path
        local endofpath = _url.len();
        if (startofpath != _url.len()) {
            if (firstquestion != null) endofpath = firstquestion;
            else if (firsthash != null) endofpath = firsthash;
            url.path = _url.slice(startofpath, endofpath);
        }
        
        // Extract the query
        local endofquery = _url.len();
        if (endofpath != _url.len()) {
            if (firsthash != null) endofquery = firsthash;
            if (endofpath+1 < endofquery) url.query = _url.slice(endofpath+1, endofquery);
        }
        
        // Extract the fragment
        if (endofquery != null && endofquery != _url.len()) {
            url.fragment = _url.slice(endofquery+1);
        }
        
        return url;
    }
    
    // .........................................................................
    function redirect(oldurl, newurl, allowcircular = false) {
        
        if (typeof newurl != "string" || newurl.len() == 0) {
            throw "Invalid redirect";
        }
        
        local url = parse_url(oldurl);
        local finalurl = null;
        if (newurl.len() >= 7 && newurl.slice(0, 7).tolower() == "http://") {
            // A full HTTP url
            finalurl = newurl;
        } else if (newurl.len() >= 8 && newurl.slice(0, 7).tolower() == "https://") {
            // A full HTTPS url
            finalurl = newurl;
        } else if (newurl[0] == '/') {
            // An absolute URL
            finalurl = format("%s://%s%s%s", url.scheme, url.host, url.port == null ? "" : (":" + url.port), newurl);
        } else {
            // A relative URL
            if (url.path == null || url.path == "" || url.path == "/") {
                finalurl = format("%s://%s%s/%s", url.scheme, url.host, url.port == null ? "" : (":" + url.port), newurl);
            } else {
                local lastslash = 0, nextslash;
                while ((nextslash = url.path.find("/", lastslash+1)) != null) {
                    lastslash = nextslash;
                }
                local newpath = url.path.slice(0, lastslash);
                finalurl = format("%s://%s%s%s/%s", url.scheme, url.host, url.port == null ? "" : (":" + url.port), newpath, newurl);
            }
        }

        if (!allowcircular && oldurl == finalurl) throw "Circular redirect detected";
        else if (finalurl != null) return finalurl;
        else return oldurl;
    }
    

}



// -------------------------[ Application code ]-------------------------

http <- HTTPPlus();
