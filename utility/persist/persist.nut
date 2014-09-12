// -----------------------------------------------------------------------------
class Persist {

    cache = null;

    // -------------------------------------------------------------------------
    function read(key = null, def = null) {
        if (cache == null) {
            cache = server.load();
        }
        return (key in cache) ? cache[key] : def;
    }

    // -------------------------------------------------------------------------
    function write(key, value) {
        if (cache == null) {
            cache = server.load();
        }
        if (key in cache) {
            if (cache[key] != value) {
                cache[key] <- value;
                server.save(cache);
            }
        } else {
            cache[key] <- value;
            server.save(cache);
        }
        return value;
    }
}
