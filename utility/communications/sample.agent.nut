// ==============================[ Sample code ]================================
rest <- Rocky();

rest.authorise(function(context, credentials) {
    // This will be overriden by OAuthClient
    if (credentials.authtype == "Basic") {
        if (credentials.user == "user" && credentials.pass == "pass") {
            return true;
        }
    }
    return false;
}.bindenv(this));

rest.unauthorised(function(context) {
    context.send(401, "unauthorised\n");
}.bindenv(this))

rest.exception(function(context, exception) {
    context.send(500, "exception: " + exception + "\n");
}.bindenv(this))

rest.timeout(function(context) {
    context.send(["timeout"]);
}.bindenv(this), 5)

rest.on("POST", "/", function(context) {
    context.send(["exact match", context]);
}.bindenv(this))

rest.on("GET", "/", function(context) {
    // Simulate an asynchronous task, such as waiting for the device to respond
    local id = context.id;
    imp.wakeup(1, function() {
        if (context = Context.get(id)) {
            context.send([context.req.method, context.path, context.req.query]);
        }
    })
}.bindenv(this))

rest.on("*", "/(test)/([^/]+)/(test)/([^/]+)", function(context) {
    context.send(["regexp match", context.matches]);
}.bindenv(this))

rest.notfound(function(context) {
    // Do nothing, let it timeout
}.bindenv(this))



auth <- OAuthClient("twitter", "apikey", "secret");
auth.expiry(60);
auth.rest(rest);


