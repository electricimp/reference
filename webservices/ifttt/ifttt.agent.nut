// #include <rocky.agent.nut>

/* -------------------------[ IFTTT Class ]---------------------------------- */
class IFTTT
{
    _rocky = null;
    _channel_key = null;
    _client_id = null;
    _client_secret = null;
    _proxy_url = null;
    _proxy_api_key = null;
    
    _actions = null;
    _action_fields = null;
    _trigger_fields = null;
    _trigger_data = null;
    _trigger_validators = null;
    _test_setup = null;
    _test_teardown = null;
    
    _agentid = null;
    name = null;
    
    constructor(rocky, channel_key, client_id, client_secret, proxy_url, proxy_api_key) {
        
        const TEST_DATA_VALID = "% tesT vALId datA %";
        const TEST_DATA_INVALID = "% tesT iNVALId datA %";
        
        _rocky = rocky;
        _channel_key = channel_key;
        _client_id = client_id;
        _client_secret = client_secret;
        _proxy_url = proxy_url;
        _proxy_api_key = proxy_api_key;
        
        _actions = {};
        _action_fields = {};
        _trigger_fields = {};
        _trigger_data = {};
        _trigger_validators = {};
        _test_setup = null;
        _test_teardown = null;
        
        _agentid = split(http.agenturl(), "/").pop();
        
        name = "Electric Imp User";
        
        // Register the callbacks
        _rocky.authorise(_authorise.bindenv(this));
        _rocky.unauthorised(_unauthorised.bindenv(this));
        _rocky.on("GET",  "/", _get_root.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/test/setup", _post_test_setup.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/test/teardown", _post_test_teardown.bindenv(this));
        _rocky.on("GET",  "/ifttt/v1/user/info", _get_user_info.bindenv(this));
        _rocky.on("GET",  "/oauth2/register", _get_oauth2_register.bindenv(this));
        _rocky.on("GET",  "/oauth2/authorize", _get_oauth2_authorize.bindenv(this));
        _rocky.on("POST", "/oauth2/token", _post_oauth2_token.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/triggers/[^/]*", _post_triggers.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/triggers/[^/]*/fields/[^/]*/validate", _post_trigger_fields_validate.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/triggers/[^/]*/fields/[^/]*/options", _post_trigger_fields_options.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/actions/[^/]*", _post_actions.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/actions/[^/]*/fields/[^/]*/options", _post_actions_fields_options.bindenv(this));

        // Notify the proxy that we are here
        _notify_proxy();
    }

    // .............................................................................
    // Check the Bearer or Channel Key is valid
    function _authorise(context, credentials) {
        switch (context.req.path) {
            case "/": 
            case "/oauth2/register": 
            case "/oauth2/authorize":
            case "/oauth2/token":
                return true;
            default:
                // server.log(format("AUTH: %s => %s / %s", context.req.path, context.header("IFTTT-Channel-Key", "[none]"), context.header("Authorization", "[none]")))
                return context.header("IFTTT-Channel-Key") == _channel_key
                    || context.header("Authorization") == "Bearer " + _agentid;
        }
    }
    
    // .............................................................................
    // This is not a valid request, respond with an error code
    function _unauthorised(context) {
        context.send(401, { "errors": [{"message": "Unauthorised" }] } );
    }


    // .............................................................................
    // Redirect the user from the root to the code registration
    function _get_root(context) {
        context.set_header("Location", http.agenturl() + "/oauth2/register");
        context.send(302, "OK");
    }
    
    
    // .............................................................................
    // IFTTT wants some test data
    function _post_test_setup(context) {
    
        // Respond with the test configuration
        local testrig = { "data": 
                        {   "accessToken": _agentid,
                            "samples": 
                                { "actionRecordSkipping":  { },
                                  "actions":  { },
                                  "triggers":  { },
                                  "triggerFieldValidations": {},
                                }
                        } 
                    };
        foreach (action, field in _action_fields) {
            foreach (label, values in field) {
                // We aren't supporting actionRecordSkipping yet
                testrig.data.samples.actionRecordSkipping[action] <- { };
                testrig.data.samples.actionRecordSkipping[action][label] <- "";
                
                // We are supporting fix action field values
                testrig.data.samples.actions[action] <- { };
                testrig.data.samples.actions[action][label] <- values[math.rand() % values.len()].value;
            }
        }
        foreach (trigger, field in _trigger_fields) {
            foreach (label, values in field) {
                if (!(trigger in testrig.data.samples.triggers)) {
                    testrig.data.samples.triggers[trigger] <- {};
                }
                if (typeof values == "array" && values.len() > 0) {
                    testrig.data.samples.triggers[trigger][label] <- values[math.rand() % values.len()].value;
                } else {
                    testrig.data.samples.triggers[trigger][label] <- label;
                }
            }
        }

        foreach (trigger, field in _trigger_validators) {
            if (!(trigger in testrig.data.samples.triggerFieldValidations)) {
                testrig.data.samples.triggerFieldValidations[trigger] <- {};
            }
            foreach (label, callback in field) {
                testrig.data.samples.triggerFieldValidations[trigger][label] <- { valid = TEST_DATA_VALID, invalid = TEST_DATA_INVALID };
            }
        }
        
        if (_test_setup) _test_setup(testrig);

        // Respond with the test configuration
        context.send(testrig);
    }
    
    // .............................................................................
    // IFTTT has finished testing
    function _post_test_teardown(context) {
        if (_test_teardown) _test_teardown(context);
    }
    
    // .............................................................................
    // IFTT wants to know who is logged in
    function _get_user_info(context) {
        
        local res = { data = {} };
        res.data.name <- name;
        res.data.id <- _agentid;
        context.send(res);
        
    }


    // .............................................................................
    // The user has requested to register this device with the proxy
    function _get_oauth2_register(context) {
        // Generate a one-time code of length 6
        local url = _proxy_url + "/oauth2/register/user";
        
        local headers = {};
        headers["Authorization"] <- "Bearer " + _proxy_api_key;
        headers["Content-Type"] <- "application/json";
        
        local code = format("%06d", 100000 + math.rand()).slice(0, 6);
        local body = { "code": code, "agentid": _agentid };
    
        // Send the code to the proxy
        http.post(url, headers, http.jsonencode(body)).sendasync(function(res) {
            
            // Respond to the user
            if (res.statuscode == 200) {
                if (context.isbrowser()) {
                    context.send("Your one-time code is '" + code + "' and is valid for 60 seconds.");
                } else {
                    context.send({ code = code });
                }
            } else {
                if (context.isbrowser()) {
                    context.send(400, "Error: " + res.statuscode);
                } else {
                    context.send(400, { error = res.statuscode });
                }
            }
            
        })
        
    }
    
        
    // .............................................................................
    function _get_oauth2_authorize(context) {
    
        local query = context.req.query;
        try {
            if (  query.scope == "ifttt"
               && query.client_id == _client_id
               && query.response_type == "code") {
                
                context.set_header("Location", query.redirect_uri + "?code=" + _agentid + "&state=" + query.state)
                context.send(302, "Access granted");
                return;
            }
        } catch (e) {
            server.error("Exception in /oauth2/authorize: " + e);
        }
               
        context.set_header("Location", query.redirect_uri + "?error=access_denied")
        context.send(302, "Access rejected");
    
    }    
    
        
    // .............................................................................
    function _post_oauth2_token(context) {
    
        try {
            local query = http.urldecode(context.req.body);
            if (  query.grant_type == "authorization_code"
               && query.code == _agentid
               && query.client_id == _client_id
               && query.client_secret == _client_secret) {
                   
                   local res = {};
                   res.token_type <- "Bearer";
                   res.access_token <- _agentid;
                   context.send(200, res);
                   return;
               }
        } catch (e) {
            server.error("Exception in /oauth2/token: " + e);
        }
    
        context.send(401, "Access rejected");
    
    }

    
    // .............................................................................
    function _post_triggers(context) {
        // Strip the /ifttt/v1/triggers/ prefix.
        local trigger = context.req.path.slice(19);
        if (trigger in _trigger_data) {
            try {

                // Check the trigger fields
                if (trigger in _trigger_fields && _trigger_fields[trigger].len() > 0) {
                    if (!("triggerFields" in context.req.body)) {
                        throw "Missing triggerFields";
                    }
                    foreach (field,data in _trigger_fields[trigger]) {
                        if (!(field in context.req.body.triggerFields)) {
                            throw "Missing triggerField: " + field;
                        }
                    }
                }
                
                // Load the trigger data into a buffer
                local data = [];
                local limit = 3; // Should be 50;
                if ("limit" in context.req.body) {
                    limit = context.req.body.limit;
                }
                for (local i = 0; i < limit; i++) {
                    if (_trigger_data[trigger].len() > 0) {
                        data.push(_trigger_data[trigger].pop());
                    }
                }
                
                // Send it
                context.send({ "data": data });
            } catch (e) {
                context.send(400, { "errors": [{"message": e, "status": "SKIP"}] } );
            }
        } else {
            context.send(404, "No trigger handler found to match the request");
        }
    }
    
    // .............................................................................
    function _post_trigger_fields_validate(context) {
        local parts = split(context.req.path, "/");
        local trigger = parts[3];
        local field = parts[5];
        local valid = true;

        if (context.req.body.value == TEST_DATA_INVALID) {
            valid = false;
        } else if (trigger in _trigger_validators && field in _trigger_validators[trigger]) {
            valid = _trigger_validators[trigger][field](trigger, field, context.req.body.value);
        }
        
        if (typeof valid == "bool") {
            context.send({ "data": { "valid" : valid } })
        } else {
            context.send({ "data": { "valid" : false, "message": valid } })
        }
    }
    
    // .............................................................................
    function _post_trigger_fields_options(context) {

        local parts = split(context.req.path, "/");
        local trigger = parts[3];
        local field = parts[5];

        if (trigger in _trigger_fields && field in _trigger_fields[trigger]) {
            context.send({ data = _trigger_fields[trigger][field] });
        } else {
            context.send({ data = [] });
        }

    }
    

    // .............................................................................
    function _post_actions(context) {
        
        // Strip down the URL
        local action = context.req.path.slice(18);
        if (action in _actions) {
            try {
                
                if (action in _action_fields) {
                    // Make sure each value supplied exists in the valid value lists
                    foreach (field, values in _action_fields[action]) {
                        if (field in context.req.body.actionFields) {
                            local found = false;
                            foreach (idx, value in values) {
                                if (value.value == context.req.body.actionFields[field]) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) throw "Invalid value for action field '" + field + "'";
                        }
                    }
                }

                if (action in _actions) _actions[action](context, context.req.body.actionFields);
            } catch (e) {
                context.send(400, { "errors": [{"message": e, "status": "SKIP"}] } );
            }
                
        } else {
            server.error("No action handler found to match the request: " + context.req.path);
            context.send(404, "No action handler found to match the request");
        }
    }

    
    // .............................................................................
    function _post_actions_fields_options(context) {
        local parts = split(context.req.path, "/");
        local action = parts[3];
        local field = parts[5];

        if (action in _action_fields && field in _action_fields[action]) {
            context.send({ "data": _action_fields[action][field] })
        } else {
            context.send({ "data": {} })
        }
    }
    
    
    // .............................................................................
    function _push_trigger_record(trigger, data) {
    
        // Build a trigger record
        local d = date();
        local created_at = format("%04d-%02d-%02dT%02d:%02d:%02dZ", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
        local id = ifttt._agentid + ":" + time() + "." + d.usec;
        local meta = { "id": id, "timestamp": d.time }
        
        data.created_at <- created_at;
        data.meta <- meta;
        
        // Stash the trigger record in a queue
        if (!(trigger in _trigger_data)) _trigger_data[trigger] <- [];
        _trigger_data[trigger].push(data)
        
        return true;
    }
    
    // .............................................................................
    // On boot, notify the IFTTT proxy about us
    function _notify_proxy() {
        // Update the proxy
        local url = _proxy_url + "/oauth2/register/agent";
        
        local headers = {};
        headers["Authorization"] <- "Bearer " + _proxy_api_key;
        headers["Content-Type"] <- "application/json";
        
        local body = {  "agentid": _agentid,
                        "channelkey": _channel_key,
                        "clientid": _client_id,
        };
    
        http.post(url, headers, http.jsonencode(body)).sendasync(function(res) {
            if (res.statuscode != 200) server.error("Proxy notified: " + res.statuscode);
        });

    }
    
    
    // .............................................................................
    // Notify IFTTT that they should pull data from the triggers
    function _notify_realtime() {
        local url = "https://realtime.ifttt.com/v1/notifications";
        
        local headers = {};
        headers["Content-Type"] <- "application/json";
        headers["IFTTT-Channel-Key"] <- _channel_key;
        headers["Authorization"] <- "Bearer " + _agentid;
    
        local body = { data = [ { user_id = _agentid } ] };
        http.post(url, headers, http.jsonencode(body)).sendasync(function(res) {
            if (res.statuscode != 200) server.error("Real-time notification: " + res.statuscode)
        })
        
    }
    
    
    // .............................................................................
    // Register the callback for test data
    function test_setup(callback) {

        _test_setup = callback;
    }
    
    // .............................................................................
    // Register the callback for teardown the test data
    function test_teardown(callback) {
        
        _test_teardown = callback;
    }
    
    // .............................................................................
    // Register action field
    function add_action_field(action, field, label, value) {
        if (!(action in _action_fields)) _action_fields[action] <- {};
        if (!(field in _action_fields[action])) _action_fields[action][field] <- []; 
        foreach (id, af in _action_fields[action][field]) {
            if (af.label == label) {
                _action_fields[action][field].remove(id);
                break;
            }
        }
        _action_fields[action][field].push({ label = label, value = value});
    }
    
    // .............................................................................
    // Register an action handler
    function action(act, callback) {
        if (callback == null) {
            delete _actions[act];
        } else {
            _actions[act] <- callback;
        }
    }

    // .............................................................................
    // Reply to an IFTTT action request 
    function action_ok(context) {
        local d = date();
        local id = _agentid + ":" + d.time + "." + d.usec;
        local res = { "data": [ { "id": id } ] }        
        context.send(res);
    }
        
    // .............................................................................
    // Register trigger field
    function add_trigger_field(trigger, field = null, label = null, value = null) {
        
        // Make sure we have a trigger tables setup
        if (!(trigger in _trigger_data)) _trigger_data[trigger] <- [];
        if (!(trigger in _trigger_fields)) _trigger_fields[trigger] <- {};
        if (!(trigger in _trigger_validators)) _trigger_validators[trigger] <- {};
        if (field != null && !(field in _trigger_fields[trigger])) _trigger_fields[trigger][field] <- [];

        
        if ( (field == null) && (label == null) && (value == null) ) {
            
            // We have a trigger with no fields at all
            
        } else if ( (field != null) && (label == null) && (value == null) ) {
            
            // We have a field with no options and no validation

        } else if ( (field != null) && (typeof label == "function") && (value == null) ) {
            
            // This is a text (or location) field that requires validation
            local callback = label;
            _trigger_validators[trigger][field] <- callback;

        } else if ( (field != null) && (label != null) && (value != null) ) {
            
            // This is a new filter option for a drop-down list
            foreach (id, tf in _trigger_fields[trigger][field]) {
                if (tf.label == label) {
                    _trigger_fields[trigger][field].remove(id);
                    break;
                }
            }
            _trigger_fields[trigger][field].push({ label = label, value = value});

        }
    }
    
    // .............................................................................
    function trigger(trigger, ingredients = {}, realtime = true) {
        
        // Push the data into the queue
        _push_trigger_record(trigger, ingredients);
        
        // Real-time notification
        if (realtime) _notify_realtime();
    }
    

}

