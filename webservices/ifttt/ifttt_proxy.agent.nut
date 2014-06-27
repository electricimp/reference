#include "rocky.agent.nut"

/* -------------------------[ IFTTT Class ]---------------------------------- */
class IFTTT_Proxy 
{
    
    _rocky = null
    _proxy_key = null;
    _auth_html = null;
    
    _channels = null;
    _clients  = null;
    _agentids = null;
    _users    = null;
    _codes    = null;
    
    _code_timers = null;
    
    constructor(rocky, proxy_key, auth_html = null) {
        
        const AGENT_NOTIFICATION_PERIOD = 300;
        const AUTH_HTML = @"<form method='post'>
                    Enter the one-time code here: <input name='code'><br/>
                    <button type='submit'>Submit</button>
                  </form>";

        
        _rocky = rocky;
        _proxy_key = proxy_key;
        _auth_html = auth_html == null ? AUTH_HTML : auth_html;
        
        _channels = {};   // Holds the valid channel keys, also recording the last agent that came online
        _clients  = {};   // Holds the valid client ID's, also recording the last agent that came online
        _agentids = {};   // Holds the list of valid agent ID's
        _users    = {};   // Maps the usertokens  to the user's name and the agents it has access to, each with a name
        _codes    = {};   // Holds the temporary auth codes that the user must enter within 60 seconds
        
        _code_timers = {}; // Holds the temporary timers that expire security codes after a minute
        
        _load();

        _rocky.authorise(_authorise.bindenv(this));
        _rocky.unauthorised(_unauthorised.bindenv(this));
        _rocky.exception(_exception.bindenv(this));
        _rocky.notfound(_not_found.bindenv(this));
        _rocky.on("POST", "/oauth2/register/agent", _post_oauth2_register_agent.bindenv(this));
        _rocky.on("POST", "/oauth2/register/user", _post_oauth2_register_user.bindenv(this));
        _rocky.on("GET", "/oauth2/authorize", _get_oauth2_authorize.bindenv(this));
        _rocky.on("POST", "/oauth2/authorize", _post_oauth2_authorize.bindenv(this));
        _rocky.on("POST", "/oauth2/token", _post_oauth2_token.bindenv(this));
        _rocky.on("GET", "/ifttt/v1/status", _get_status.bindenv(this));
        _rocky.on("GET", "/ifttt/v1/user/info", _get_user_info.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/[^/]*/[^/]*/fields/device/options", _post_device_options.bindenv(this));
        _rocky.on("POST", "/ifttt/v1/[^/]*/[^/]*/fields/[^/]*/(options|validate)", _post_other_options.bindenv(this));
        
        imp.wakeup(60, _check_agentids.bindenv(this));
    
    }
    

    // .............................................................................
    // Check the request has the proper credentials
    function _authorise(context, credentials) {
        switch (context.req.path) {
            case "/oauth2/authorize":
            case "/oauth2/token":
                return true;
            case "/oauth2/register/user":
            case "/oauth2/register/agent":
                return credentials.pass == _proxy_key;
            case "/ifttt/v1/status":
            case "/ifttt/v1/test/setup":
                return context.header("IFTTT-Channel-Key") in _channels;
            default:
                return credentials.user in _users;
        }
    }

    // .............................................................................
    // This is not a valid request, respond with an error code
    function _unauthorised(context) {
        context.send(401, { "errors": [{"message": "Unauthorised in proxy" }] } );
    }


    // .............................................................................
    // Any unhandled exception
    function _exception(context, e) {
        server.error("Handled exception: " + e)
        context.send(400, { "errors": [{"message": e, "status": "SKIP"}] } );
    }

    
    // .............................................................................
    // A device is registering itself
    function _post_oauth2_register_agent(context) {
        // Check the parameters
        local body = context.req.body;
        if (body.channelkey.len() < 64 || body.agentid.len() < 12 || body.clientid.len() == 0) {
            return context.send(400, "Invalid request");
        } else {
            _channels[body.channelkey] <- body.agentid;
            _clients[body.clientid] <- body.agentid;
            _agentids[body.agentid] <- time();
            _save();
            
            return context.send("OK");
        }
    }


    // .............................................................................
    // The user has requested to register a one-time code against his agent
    function _post_oauth2_register_user(context) {
        // Check the parameters
        local body = context.req.body;
        if (!("agentid" in body) || body.agentid.len() < 12 
         || !("username" in body) || body.username.len() == 0
         || !("usertoken" in body) || body.usertoken.len() == 0
         || !("name" in body) || body.name.len() == 0) {
            return context.send(400, "Invalid request");
        } else {
            // Is this a new user token?
            if (!(body.usertoken in _users)) {
                _users[body.usertoken] <- { "agents":[], "username": "" };
            }
            
            // Remove/replace any preexisting agents
            foreach (id,agent in _users[body.usertoken].agents) {
                if (agent.agentid == body.agentid) {
                    _users[body.usertoken].agents.remove(id);
                    break;
                }
            }
            _users[body.usertoken].username <- body.username;
            _users[body.usertoken].agents.push({ "agentid": body.agentid, "name": body.name });
            _save();
            
            // Generate a new one-time-code to respond with
            local code = format("%06d", 100000 + math.rand()).slice(0, 6);
            _codes[code] <- body;
            _code_timers[code] <- imp.wakeup(60, function() {
                // Expire codes after 60 seconds
                delete _code_timers[code];
                delete _codes[code];
            }.bindenv(this));
            
            server.log(format("Registered one-time code '%s' for agent '%s', named '%s'", code, body.agentid, body.name))
            return context.send(code);
        }
    }

    
    // .............................................................................
    function _get_oauth2_authorize(context) {
    
        local query = context.req.query;
        try {
            if (  query.scope == "ifttt"
               && query.client_id in _clients
               && query.redirect_uri.len() > 5
               && query.state.len() > 5
               && query.response_type == "code"
               ) {
                
                local html = format(_auth_html, query.scope, query.client_id, query.response_type, query.redirect_uri);
                context.set_header("Content-Type", "text/html")
                return context.send(html);
            }
        } catch (e) {
            server.error("Exception in /oauth2/authorize: " + e);
        }
               
        context.set_header("Location", query.redirect_uri + "?error=access_denied")
        context.send(302, "Access rejected");
    
    }
    
    // .............................................................................
    function _post_oauth2_authorize(context) {
    
        local query = context.req.body;
        foreach (k, v in context.req.query) query[k] <- v;
        try {
            if (  query.scope == "ifttt"
               && query.client_id in _clients
               && query.redirect_uri.len() > 5
               && query.state.len() > 5
               && query.response_type == "code"
               && query.code.len() >= 6
               && query.code in _codes
               ) {
                
                context.set_header("Location", query.redirect_uri + "?code=" + _codes[query.code].agentid + "&state=" + query.state)
                context.send(302, "Access granted");
                return;
            }
        } catch (e) {
            server.error("Exception in /oauth2/authorize: " + e);
        }
               
        context.set_header("Location", query.redirect_uri + "?error=access_denied")
        context.send(302, "Access rejected");
        server.error("Rejected in /oauth2/authorize: " + http.jsonencode(query));
    
    }

    // .............................................................................
    function _post_oauth2_token(context) {
    
        try {
            local query = http.urldecode(context.req.body);
            if (  query.grant_type == "authorization_code"
               && query.code in _agentids) {
    
                // Pass this request on to the agent
                local url = format("https://agents.electricimp.com/%s/oauth2/token", query.code);
                http.post(url, context.req.headers, context.req.body).sendasync(function(res) {
                   
                    foreach (k,v in res.headers) context.set_header(k, v);
                    context.send(res.statuscode, res.body);
    
               }.bindenv(this));
               
               return;
            }
        } catch (e) {
            server.error("Exception in /oauth2/token: " + e);
        }
    
        context.send(401, "Access rejected");
    
    }


    // .............................................................................
    function _get_status(context) {
    
        context.send("OK");
        
    }
    
    
    // .............................................................................
    function _get_user_info(context) {
    
        local res = { data = {} };
        res.data.name <- _users[context.user].username;
        res.data.id <- context.user;
        context.send(res);
        
    }
    
    
    // .............................................................................
    function _post_device_options(context) {

        local data = [];
        if (context.user in _users) {
            foreach (agent in _users[context.user].agents) {
                data.push({"label": agent.name, "value": agent.agentid});
            }
        }
        
        context.send({"data": data});
        
    }

    
    // .............................................................................
    function _post_other_options(context) {
    
        if (_users[context.user].agents.len() == 0) throw "This user doesn't appear to have any registered agents.";
        
        // In desperation, choose the first one. This is TERRIBLE as it may not even be the right type of device!
        local agentid = _users[context.user].agents[0].agentid;
        _forward_request(context, agentid)
    }
    
    
    // .............................................................................
    function _not_found(context) {
        
        // Try to extract a valid agentid
        local agentid = null;
        if (context.user == "" && context.header("IFTTT-Channel-Key") in _channels) {
            // This is a pre-authorised but valid request. Use the last agentid that registered
            agentid = _channels[context.header("IFTTT-Channel-Key")];
        }
        
        if ("triggerFields" in context.req.body) {
            if ("device" in context.req.body.triggerFields) {
                agentid = context.req.body.triggerFields.device;
            } else {
                throw "The triggerFields.device field must be present"
            }
        } else if ("actionFields" in context.req.body) {
            if ("device" in context.req.body.actionFields) {
                agentid = context.req.body.actionFields.device;
            } else {
                throw "The actionFields.device field must be present"
            }
        }
        if (agentid == null || agentid == "") {
            throw "I have nowhere to send that request without a device triggerField / actionField.";
        }
        
        local valid_agent = (context.user == "");
        if (!valid_agent && context.user in _users) {
            foreach (agent in _users[context.user].agents) {
                if (agent.agentid == agentid) {
                    valid_agent = true;
                    break;
                }
            }
        }
        if (!valid_agent) {
            throw "This user doesn't have access to agentid " + agentid;
        }
        
        // Finally, forward the request
        _forward_request(context, agentid);
    }
    

    // .............................................................................
    // Check for expired agentids
    function _check_agentids() {
        
        imp.wakeup(60, _check_agentids.bindenv(this));
        
        local now = time();
        local haschanged = false;
        foreach (agentid,timestamp in _agentids) {
            if (now - timestamp > AGENT_NOTIFICATION_PERIOD*2) {
                server.log(format("Agent %s has expired and has been removed", agentid))
                haschanged = true;
                
                // Remove it from the agentids
                delete _agentids[agentid];
                
                // Search and kill from users
                foreach (user in _users) {
                    for (local i = user.agents.len()-1; i >= 0; i--) {
                        if (user.agents[i].agentid == agentid) {
                            user.agents.remove(i);
                        }
                    }
                }
            }
        }
        if (haschanged) _save();
    }

    
    // .............................................................................
    function _forward_request(context, agentid) {
        server.log(format("Forwarding request to: %s:%s@%s", context.user, agentid, context.req.path));
        
        local url = format("https://agents.electricimp.com/%s%s", agentid, context.req.path);
        local body = "";
        if (typeof context.req.body == "table") body = http.jsonencode(context.req.body);
        else if (typeof context.req.body == "null") body = "";
        else body = context.req.body;
        
        if ("content-length" in context.req.headers) delete context.req.headers["content-length"];
    
        // Pass this request on to the agent
        http.request(context.req.method, url, context.req.headers, body).sendasync(function(res) {
           
            foreach (k,v in res.headers) context.set_header(k, v);
            context.send(res.statuscode, res.body);
            
        }.bindenv(this));
    }


    // .............................................................................
    // Saves the state of the agent in case of a reboot
    function _save() {
        local save = { agentids = _agentids, channels = _channels, clients = _clients, users = _users };
        server.save(save);
    }
    
    
    // .............................................................................
    // Restores the state of the agent after a reboot
    function _load() {
        local saved = server.load();
        if ("channels" in saved) _channels = saved.channels;
        if ("clients" in saved) _clients = saved.clients;
        if ("agentids" in saved) _agentids = saved.agentids;
        if ("users" in saved) _users = saved.users;
    }

}


/* ==============================[ Application code ]======================== */

// This random key should be replaced with a custom per-user EI API Key
const PROXY_API_KEY = ""; 

rocky <- Rocky();
ifttt <- IFTTT_Proxy(rocky, PROXY_API_KEY);

server.log("Rebooted")
