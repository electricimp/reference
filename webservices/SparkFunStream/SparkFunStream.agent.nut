class SparkFunStream {

    // Copyright (c) 2015 Electric Imp
    // This file is licensed under the MIT License
    // http://opensource.org/licenses/MIT

    /*
    * This class wraps the data.sparkfun.com cloud storage API into a class.
    */

    _publicKey = null;
    _privateKey = null;
    _baseUrl = null;
   
    constructor(publicKey, privateKey, baseUrl = "data.sparkfun.com") {
        _privateKey = privateKey;
        _publicKey = publicKey;
        _baseUrl = baseUrl;
    }
    
    /*
     * Perform the provided HTTP request. Retry after a delay if the result is 429 (throttle).
     */
    function _commit(method, url, cb = null) {
        // make the request
        local headers = { "phant-private-key": _privateKey };
        local request = http[method](url, headers);
        if (cb) {
            return request.sendasync(function(res) {
                if (res.statuscode == 429) {
                    imp.wakeup(1, function() {
                        _commit(method, url, cb);
                    }.bindenv(this))
                } else {
                    cb(res);
                }
            }.bindenv(this));
        } else {
            local res = request.sendsync();
            if (res.statuscode == 429) {
                imp.sleep(1);
                return _commit(method, url, cb);
            } else {
                return res;
            }
        }
    }

    /*
     * Push new data into the data store
     */
    function push(data, cb = null) {
        assert(typeof(data == "table"));
        local url = format("https://%s/input/%s?%s", _baseUrl, _publicKey, http.urlencode(data));
        return _commit("get", url, cb);
    }
    
    /*
     * Retrieve previously stored data
     */
    function get(cb = null) {
        local url = format("https://%s/output/%s.json", _baseUrl, _publicKey);
        return _commit("get", url, cb);
    }
    
    /*
     * Delete a previously stored blob of data
     */
    function clear(cb = null) {
        local url = format("https://%s/input/%s/clear", _baseUrl, _publicKey);
        return _commit("httpdelete", url, cb);
    }
}
