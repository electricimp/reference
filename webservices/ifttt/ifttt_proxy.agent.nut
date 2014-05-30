
// #include <rocky.agent.nu>

const PROXY_API_KEY = "<generate your own key>"; 

rest <- Rocky();

channels <- {}; // Holds all the valid channel keys, also recording the last agent that came online
clients <- {};  // Holds all the valid client ID's, also recording the last agent that came online
agents <- {};   // Holds all the agent ID's and the devices they 
codes <- {};    // Holds all the agent ID's which double as the auth tokens.

code_timers <- {}; // Holds the temporary timers that expire security codes after a minute


// .............................................................................
// Check the CHANNEL KEY
rest.authorise(function(context, credentials) {
    switch (context.req.path) {
        case "/oauth2/authorize":
        case "/oauth2/token":
            return true;
        case "/oauth2/register/user":
        case "/oauth2/register/agent":
            return credentials.pass == PROXY_API_KEY;
        case "/ifttt/v1/status":
        case "/ifttt/v1/test/setup":
            return context.header("IFTTT-Channel-Key") in channels;
        default:
            return credentials.user in agents;
    }
}.bindenv(this));

// .............................................................................
// This is not a valid request, respond with an error code
rest.unauthorised(function(context) {
    context.send(401, { "errors": [{"message": "Unauthorised" }] } );
}.bindenv(this));


// .............................................................................
// The user has requested to register a one-time code against his agent
rest.on("POST", "/oauth2/register/user", function(context) {
    // Check the parameters
    local body = context.req.body;
    if (body.code.len() < 6 ||  body.agentid.len() < 12) {
        return context.send(400, "Invalid request");
    } else {
        // Expire codes after 60 seconds
        codes[body.code] <- body;
        code_timers[body.code] <- imp.wakeup(60, function() {
            delete code_timers[body.code];
            delete codes[body.code];
        }.bindenv(this));
        
        server.log(format("Registered one-time code for agent '%s'", body.agentid))
        return context.send("OK");
    }
}.bindenv(this))

// .............................................................................
// A device is registering itself
rest.on("POST", "/oauth2/register/agent", function(context) {
    // Check the parameters
    local body = context.req.body;
    if (body.channelkey.len() < 64 || body.agentid.len() < 12 || body.clientid.len() == 0) {
        return context.send(400, "Invalid request");
    } else {
        channels[body.channelkey] <- body.agentid;
        clients[body.clientid] <- body.agentid;
        agents[body.agentid] <- body.agentid;
        save_state();
        
        server.log(format("Saved channel '%s' for agent '%s'", body.clientid, body.agentid))
        return context.send("OK");
    }
}.bindenv(this))

// .............................................................................
rest.on("GET", "/oauth2/authorize", function(context) {

    server.log("OAuth2 authorize request");

    local query = context.req.query;
    try {
        if (  query.scope == "ifttt"
           && query.client_id in clients
           && query.redirect_uri.len() > 5
           && query.state.len() > 5
           && query.response_type == "code"
           ) {
            
            local html = @"<form method='post'>
                            Enter the one-time code here: <input name='code'><br/>
                            <button type='submit'>Submit</button>
                          </form>";
            html = format(html, query.scope, query.client_id, query.response_type, query.redirect_uri);
            
            context.set_header("Content-Type", "text/html")
            return context.send(html);
        }
    } catch (e) {
        server.error("Exception in /oauth2/authorize: " + e);
    }
           
    context.set_header("Location", query.redirect_uri + "?error=access_denied")
    context.send(302, "Access rejected");

});

// .............................................................................
rest.on("POST", "/oauth2/authorize", function(context) {

    server.log("OAuth2 authorize response");

    local query = context.req.body;
    foreach (k, v in context.req.query) query[k] <- v;
    try {
        if (  query.scope == "ifttt"
           && query.client_id in clients
           && query.redirect_uri.len() > 5
           && query.state.len() > 5
           && query.response_type == "code"
           && query.code.len() >= 6
           && query.code in codes
           ) {
            
            context.set_header("Location", query.redirect_uri + "?code=" + codes[query.code].agentid + "&state=" + query.state)
            context.send(302, "Access granted");
            return;
        }
    } catch (e) {
        server.error("Exception in /oauth2/authorize: " + e);
    }
           
    context.set_header("Location", query.redirect_uri + "?error=access_denied")
    context.send(302, "Access rejected");

});

// .............................................................................
rest.on("POST", "/oauth2/token", function(context) {

    server.log("OAuth2 token");
    
    try {
        local query = http.urldecode(context.req.body);
        if (  query.grant_type == "authorization_code"
           && query.code in agents) {

            // Pass this request on to the agent
            local url = format("https://agents.electricimp.com/%s/oauth2/token", query.code);
            http.post(url, context.req.headers, context.req.body).sendasync(function(res) {
               
               foreach (k,v in res.headers) context.set_header(k, v);
               context.send(res.statuscode, res.body);
           });
           
           return;
        }
    } catch (e) {
        server.error("Exception in /oauth2/token: " + e);
    }

    context.send(401, "Access rejected");

});


// .............................................................................
rest.on("GET", "/ifttt/v1/status", function(context) {

    server.log("Status check");
    context.send("OK");
    
});


// .............................................................................
rest.notfound(function(context) {
    
    server.log("Forwarding: " + context.req.path);
    
    // Pick a default user for test setup
    if (context.user == "" && context.header("IFTTT-Channel-Key") in channels) {
        context.user = channels[context.header("IFTTT-Channel-Key")];
    }
    
    local url = format("https://agents.electricimp.com/%s%s", context.user, context.req.path);
    
    local body = "";
    if (typeof context.req.body == "table") body = http.jsonencode(context.req.body);
    else if (typeof context.req.body == "null") body = "";
    else body = context.req.body;
    
    if ("content-length" in context.req.headers) delete context.req.headers["content-length"];

    // Pass this request on to the agent
    http.request(context.req.method, url, context.req.headers, body).sendasync(function(res) {
       
        foreach (k,v in res.headers) context.set_header(k, v);
        context.send(res.statuscode, res.body);
   });
})

// .............................................................................
// Saves the state of the agent in case of a reboot
function save_state() {
    local save = { agents = agents, channels = channels, clients = clients };
    server.save(save);
}

// .............................................................................
// Restores the state of the agent after a reboot
function restore_state() {
    local saved = server.load();
    if ("channels" in saved) channels = saved.channels;
    if ("clients" in saved) clients = saved.clients;
    if ("agents" in saved) agents = saved.agents;
}
restore_state();

server.log("Rebooted")
