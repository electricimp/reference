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




// -----------------------------------------------------------------------------
// Firebase class: Implements the Firebase REST API.
// https://www.firebase.com/docs/rest-api.html
//
// Author: Aron
// Created: September, 2013
//
class Firebase {
    
    database = null;
    authkey = null;
    agentid = null;
    url = null;
    headers = null;
    
    // ........................................................................
    constructor(_database, _authkey, _path = null) {
        database = _database;
        authkey = _authkey;
        agentid = http.agenturl().slice(-12);
        headers = {"Content-Type": "application/json"};
		set_path(_path);
    }
    
    
    // ........................................................................
	function set_path(_path) {
		if (!_path) {
			_path = "agents/" + agentid;
		}
        url = "https://" + database + ".firebaseIO.com/" + _path + ".json?auth=" + authkey;
	}


    // ........................................................................
    function write(data, callback = null) {
    
        if (typeof data == "table") data.heartbeat <- time();
        http.request("PUT", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Write: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function update(data, callback = null) {
    
        if (typeof data == "table") data.heartbeat <- time();
        http.request("PATCH", url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res);
                else server.log("Update: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function push(data, callback = null) {
    
        if (typeof data == "table") data.heartbeat <- time();
        http.post(url, headers, http.jsonencode(data)).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Push: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));
    
    }
    
    // ........................................................................
    function read(callback = null) {
        http.get(url, headers).sendasync(function(res) {
            if (res.statuscode != 200) {
                if (callback) callback(res, null);
                else server.log("Read: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                local body = null;
                try {
                    body = http.jsondecode(res.body);
                } catch (err) {
                    if (callback) return callback(err, null);
                }
                if (callback) callback(null, body);
            }
        }.bindenv(this));
    }
    
    // ........................................................................
    function remove(callback = null) {
        http.httpdelete(url, headers).sendasync(function(res) {
            if (res.statuscode != 204) {
                if (callback) callback(res);
                else server.log("Delete: Firebase response: " + res.statuscode + " => " + res.body)
            } else {
                if (callback) callback(null, res.body);
            }
        }.bindenv(this));
    }
    
}


