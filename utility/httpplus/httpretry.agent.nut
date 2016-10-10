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
    
    function _factory() {
        if (!("sharedhttpretry" in getroottable())) ::sharedhttpretry <- HTTPRetry();
        return ::sharedhttpretry;
    }
    
    function _enqueue(requestobj, callback) {
        _queue.push({requestobj=requestobj, callback=callback});
        _dequeue();
    }
    
    function _dequeue() {
        // Process the queue of non-long-polling requests
        if (_queue.len() > 0 && _processing == false) {
            local item = _queue[0];
            _processing = true;
            item.requestobj._sendasyncqueued(function(success, result, retry_delay=0) {
                if (success) {
                    _processing = false;
                    _queue.remove(0);
                    item.callback(result);
                    return _dequeue();
                } else {
                    imp.wakeup(retry_delay, function() {
                        _processing = false;
                        _dequeue();
                    }.bindenv(this));
                }
            }.bindenv(this));
        }
    }

    function _remove(requestobj) {
        foreach (k,v in _queue) {
            if (v.requestobj == requestobj) {
                _queue.remove(k);
                return k;
            }
        }
        return null;
    }
    
}


// -----------------------------------------------------------------------------
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
    
    function _sendasyncqueued(dequeue_callback) {

        _httprequest = _request.acall(_params);
        _httprequest.sendasync(function(result) {
            _httprequest = null;
            if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                // This is a retryable failure, wait for as long as are told then try again
                server.error("Too many outbound HTTP requests. We have been throttled.")
                dequeue_callback(false, result, result.headers["retry-after"].tofloat());
            } else {
                // This is a "success", so remove the item from the queue and start again
                dequeue_callback(true, result);
            }
        }.bindenv(this));
    }
    
    function sendasync(oncomplete, longpolldata = null, longpolltimeout = 600) {
        if (longpolldata == null) {
            // Queue this request to be handled out of band
            _parent._enqueue(this, oncomplete);
        } else {
            // Prepare the httprequest object
            _httprequest = _request.acall(_params);
            
            // Handle a long-polling request
            _httprequest.sendasync(function(result) {
                _httprequest = null;
                if (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
                    // This is a retryable failure, wait for as long as are told then try again
                    server.error("Too many outbound HTTP requests. We have been throttled.")
                    _retry = imp.wakeup(result.headers["retry-after"].tofloat(), function() {
                        _retry = null;
                        sendasync(oncomplete, longpolldata, longpolltimeout);
                    }.bindenv(this);
                } else {
                    // This is a success or a reportable failure
                    oncomplete(result);
                }
            }.bindenv(this), longpolldata, longpolltimeout);
        }
        return _httprequest;
    }
    
    function sendsync() {
        
        // Prepare the httprequest object and execute the requested function
        _httprequest = _request.acall(_params);
        local result = _httprequest.sendsync();
        _httprequest = null;
        while (result.statuscode == 429 && "x-agent-rate-limited" in result.headers && "retry-after" in result.headers) {
            // This is a retryable failure, wait for as long as are told then try again
            imp.sleep(result.headers["retry-after"].tofloat());
            result = _request.acall(_params).sendsync();
        }
        return result;
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
        } else {
            // Pull it out of the queue
            _parent._remove(this);
        }
    }
    
}
