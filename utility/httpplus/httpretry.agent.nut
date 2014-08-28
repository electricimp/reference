// -----------------------------------------------------------------------------
// Use HTTPRetry exaclt like you would use http.
// HTTPRetry.get().sendasync();
// Your async requests will be queued and delivered in series and in order. 
// 429 errors will be handled and retried transparently.
// 
class HTTPRetry {

    _queue = null;
    _processing = false;

    constructor() {
        _queue = [];
        _processing = false;
    }
    
    function request(method, url, headers = {}, body = "") {
        local httpretry = _factory();
        local params = [ method, url, headers, body ];
        return HTTPRetryRequest(httpretry, http.request, params);
    }

    function get(url, headers = {}) {
        local httpretry = _factory();
        local params = [ url, headers ];
        return HTTPRetryRequest(httpretry, http.get, params);
    }

    function put(url, headers = {}, body = "") {
        local httpretry = _factory();
        local params = [ url, headers, body ];
        return HTTPRetryRequest(httpretry, http.put, params);
    }
    
    function post(url, headers = {}, body = "") {
        local httpretry = _factory();
        local params = [ url, headers, body ];
        return HTTPRetryRequest(httpretry, http.post, params);
    }
    
    function httpdelete(url, headers = {}) {
        local httpretry = _factory();
        local params = [ url, headers ];
        return HTTPRetryRequest(httpretry, http.httpdelete, params);
    }
    
    function _enqueue(httprequest, callback) {
        _queue.push({httprequest=httprequest, callback=callback});
        _dequeue();
    }
    
    function _factory() {
        if (!("sharedhttpretry" in getroottable())) ::sharedhttpretry <- HTTPRetry();
        return ::sharedhttpretry;
    }
    
    function _dequeue() {
        // Handle the queue of non-long-polling requests
        if (_queue.len() > 0 && _processing == false) {
            local item = _queue[0];
            _processing = true;
            item.httprequest.sendasync(function(result) {
                _processing = false;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    server.error("Too many outbound HTTP requests. We have been throttled.")
                    imp.wakeup(result.headers["retry-after"].tofloat(), _dequeue.bindenv(this));
                } else {
                    // This is a "success", so remove the item from the queue and start again
                    _queue.remove(0);
                    item.callback(result);
                    return _dequeue();
                }
            }.bindenv(this));
        }
    }
}

class HTTPRetryRequest {

    _parent = null;
    _request = null;
    _params = null;
    _retry = null;
    _httprequest = null;
    
    constructor(parent, request, params) {
        _parent = parent;
        _request = request;
        _params = params;
        _params.insert(0, http);
    }
    
    function sendsync() {
        
        // Prepare the httprequest object and execute the requested function
        local result = _request.acall(_params).sendsync();
        while (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
            // This is a retryable failure, wait for as long as are told then try again
            imp.sleep(result.headers["retry-after"].tofloat());
            result = _request.acall(_params).sendsync();
        }
        return result;
    }
    
    function sendasync(oncomplete, longpolldata = null, longpolltimeout = 600) {
        // Prepare the httprequest object
        _httprequest = _request.acall(_params);
        
        if (longpolldata == null) {
            // Queue this request to be handled out of band
            _parent._enqueue(_httprequest, oncomplete);
        } else {
            // Handle a long-polling request
            _httprequest.sendasync(function(result) {
                _httprequest = null;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    server.error("Too many outbound HTTP requests. We have been throttled.")
                    imp.sleep(result.headers["retry-after"].tofloat());
                    sendasync(oncomplete, longpolldata, longpolltimeout);
                } else {
                    // This is a success or a reportable failure
                    oncomplete(result);
                }
            }.bindenv(this), longpolldata, longpolltimeout);
        }
        return _httprequest;
    }
    
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
    

}
