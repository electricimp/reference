// -----------------------------------------------------------------------------
class OAuthClient
{
    _provider = "";
    _api_key = null;
    _api_secret = null;
    _auth_secrets = null;
    
    _rest = null;
    
    _auth = null;
    _auth_expiry = 604800; // One week
    
    _request_token_url = null;
    _authenticate_url = null;
    _access_token_url = null;
    
    _token_path = null;
    _login_path = null;
    
    // .........................................................................
    constructor(provider, api_key, api_secret) {
        
        _provider = provider;
        _api_key = api_key;
        _api_secret = api_secret;
        
        _auth_secrets = {};

        _token_path         = "/oauth/token";
        _login_path         = "/login";
        
        _auth = _load();
        if ("user" in _auth && "pass" in _auth && "expires" in _auth) {
            if (_auth.expires > time()) {
                server.log(format("Welcome back, %s. Your password is: %s.", _auth.user, _auth.pass))
            }
        }
        
        // Load the settings for the selected provider
        switch (provider)
        {
            case "twitter":
                _request_token_url  = "https://api.twitter.com/oauth/request_token";
                _authenticate_url   = "https://api.twitter.com/oauth/authenticate";
                _access_token_url   = "https://api.twitter.com/oauth/access_token";
                break;
            
            default:
                throw "Invalid or unsupported OAuth provider: " + provider;
        }
    }
    
    
    // .........................................................................
    function expiry(seconds = null) {
        if (seconds != null) _auth_expiry = seconds;
        return _auth_expiry;
    }
    
    // .........................................................................
    function rest(rest) {
        _rest = rest;
        
        if (_rest) {
            _rest.on("*", _token_path, auth_response.bindenv(this));
            _rest.on("*", _login_path, login.bindenv(this));
            _rest.authorise(authorise.bindenv(this))
        }
    }
    
    // .........................................................................
    function _load(key = "OAuthClient") {
        local old = server.load();
        if (key in old) {
            return old[key];
        } else {
            return {};
        }
    }
    
    
    // .........................................................................
    function _save(obj, key = "OAuthClient") {
        local old = server.load();
        old[key] <- obj;
        server.save(old);
    }

    // .........................................................................
    function _urlencode(str) {
        if (str == null || str == "") return "";
        return http.urlencode({ s = str }).slice(2);
    }

    // .........................................................................
    function _signing_key(oauth_token) {
        local secret = _api_secret;
        local token = _api_key;
        switch (_provider) {
            
            case "twitter":
                token = oauth_token;
                break;
                
        }
        
        local signing_key = _urlencode(secret) + "&" + _urlencode(token);
        // server.log("SIGNING KEY ==> " + secret + " & " + token)
        return signing_key;
    }
    
    // .........................................................................
    function _post(url, headers, body, verb, extras = {}) {
        local timestamp = time();
        local nonce = format("%d.%d", time(), date().usec);

        // Generate the signature string
        local bits = [  "oauth_consumer_key=" + _urlencode(_api_key),
                        "oauth_nonce=" + _urlencode(nonce),
                        "oauth_signature_method=HMAC-SHA1",
                        "oauth_timestamp=" + timestamp,
                        "oauth_version=1.0"
                     ];
        foreach (k,v in extras) bits.push(format("%s=%s", _urlencode(k), _urlencode(v)));
        bits.sort();
        
        // Sort and join the bits
        local signature_bits = "";
        foreach (bit in bits) signature_bits += bit + "&";
        signature_bits = signature_bits.slice(0, -1);
        
        // Calculate the signature from the signature string
        local base_signature = format("%s&%s&%s", verb, _urlencode(url), _urlencode(signature_bits));
        local signing_key = _signing_key("oauth_token" in extras ? extras.oauth_token : "");
        local signature = http.base64encode(http.hash.hmacsha1(base_signature, signing_key));
        
        // Repeat the process to generate the authorization header
        local bits = [  "oauth_consumer_key=\"" + _urlencode(_api_key) + "\"",
                        "oauth_nonce=\"" + _urlencode(nonce) + "\"",
                        "oauth_signature=\"" + _urlencode(signature) + "\"",
                        "oauth_signature_method=\"HMAC-SHA1\"",
                        "oauth_timestamp=\"" + timestamp + "\"",
                        "oauth_version=\"1.0\"",
                     ];
        foreach (k,v in extras) bits.push(format("%s=\"%s\"", _urlencode(k), _urlencode(v)));
        bits.sort();
        
        // Rejoin the bits
        local auth_bits = "";
        foreach (bit in bits) auth_bits += bit + ", ";
        auth_bits = auth_bits.slice(0, -2);
        headers.Authorization <- "OAuth " + auth_bits;

        server.log("____________________________________");
        server.log("signature base = " + base_signature);
        server.log("authorization header = " + headers.Authorization);
        // server.log("signing key = " + signing_key);
        // server.log("signature = " + signature);
        
        if (verb == "GET") {
            return http.get(url, headers);
        } else if (verb == "POST") {
            return http.post(url, headers, body);
        } else {
            // We can support more but for now we don't need to
            return null;
        }
    }
    
    
    // .........................................................................
    function authorise(context, credentials) {
        if (context.req.path == _token_path) {
            return true;
        } else if (context.req.path == _login_path) {
            return true;
        } else if (credentials.authtype == "Basic" && "user" in _auth && "pass" in _auth && "expires" in _auth) {
            if (credentials.user == _auth.user && credentials.pass == _auth.pass && _auth.expires > time()) {
                return true;
            }
        } else if (credentials.authtype == "Bearer" && "pass" in _auth && "expires" in _auth) {
            if (credentials.pass == _auth.pass && _auth.expires > time()) {
                return true;
            }
        }
        
        context.header("WWW-Authenticate", "OAuth realm=\"" + http.agenturl() + "\"");
        return false;
    }

    // .........................................................................
    function login(context) {
        request_token(function(url) {
            if (url) {
                context.header("Location", url);
                context.send(307, "OAuth")
            } else {
                context.send(401, "Access denied")
            }
        });
    }
    
    // .........................................................................
    function request_token(callback) {
        local url = _request_token_url;
        local headers = {};
        local body = "";
        local callbackurl = http.agenturl() + _token_path;

        local oauth_token = null;

        // Make and sign the request
        local post = _post(url, headers, body, "POST", {oauth_callback = callbackurl});
        
        // Post the request to the provider
        post.sendasync(function (res) {
            if (res.statuscode == 200) {
                local response = http.urldecode(res.body);
                if ("oauth_token" in response && "oauth_token_secret" in response) {
                    oauth_token = response.oauth_token;
                    _auth_secrets[oauth_token] <- response.oauth_token_secret;
    
                    // Discard secrets after 10 minutes
                    imp.wakeup(600, function() {
                        if (oauth_token in _auth_secrets) {
                            delete _auth_secrets[oauth_token];
                        }
                    }.bindenv(this))
                }
            } else {
                server.log("request_token response " + res.statuscode + ": " + res.body );
            }
            
            if (oauth_token != null) {
                callback(_authenticate_url + "?oauth_token=" + oauth_token + "&oauth_callback=" + _urlencode(callbackurl));
            } else {
                callback(null);
            }
            
        });
    }
    
    // .........................................................................
    function auth_response(context) {
        local oauth_token = null;
        local oauth_verifier = null;
        if ("oauth_token" in context.req.query) oauth_token = context.req.query.oauth_token;
        if ("oauth_verifier" in context.req.query) oauth_verifier = context.req.query.oauth_verifier;
        if (oauth_token != null) {
            local url = _access_token_url;
            local headers = {};
            local body = oauth_verifier ? ("oauth_verifier=" + oauth_verifier) : "";
            local post = _post(url, headers, body, "POST", {oauth_token=oauth_token});
            post.sendasync(function(res) {
                if (res.statuscode == 200) {
                    local response = http.urldecode(res.body);
                    if ("oauth_token" in response) {
                        _auth = {};
                        
                        _auth.pass <- response.oauth_token;
                        _auth.expires <- time() + _auth_expiry;
                        if ("screen_name" in response) _auth.user <- response.screen_name;
                        else if ("uid" in response) _auth.user <- response.uid;
                        else return context.send(401, "Access denied");
                        
                        _save(_auth);
                        
                        context.send(200, _auth);
                    }
                } else {
                    server.log("access_token response " + res.statuscode + ": " + res.body);
                    context.send(401, "Access denied");
                }
            }.bindenv(this));
        }
    }
    
}
