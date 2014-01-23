/***************************************************************************
 * PersistantData is a static class that wraps up the 
 * server.save()/load() and nv table functionality into 
 * a tidy package.
 *
 * This class can be used in either the device or the agent (the class
 * uses imp.environment() to determin whether or not it's running in an
 * agent, and then sets and gets the data using server.save/load or the 
 * nv table as appropriate.
 *
 * Usage:
 * ======
 * - You do not need to initialize PersistantData
 * - To check whether the datastore has a particular key, call 
 *   PersistantData.hasKey("someKey")
 * - To get the value of data stored with a particular key, call
 *   PersistantData.get("someKey")
 *   - If the key does not exist in the datastore, it will return null
 * - To save data with a key, call PersistantData.save("someKey", value)  
 * - To remove a key from the datastore, call PersistantData.remove("someKey")
 * - At anytime, you can call PersistantData.refresh() to pull down the latest
 *   version of the datastore.
 * - To clear out the datastore, use PersistantData.clear()
 *   - This is the equivalent of server.save({}) in the agent, and nv <- {}
 *     on the device.
 * 
 * NOTE: If you use the PersistantData static class, you should *NEVER* call
 * server.save() or server.load() in the agent, or directly acces the nv table
 * on the device. Additionally, you should *NEVER* directly access 
 * ._data, ._isAgent, ._saveData(), ._loadData, or _checkData(). Instead, use 
 * the provided functions.
 ***************************************************************************/

PersistantData <- {
  function hasKey(key) {
    _checkData();
    return (key in _data);
  }
  
  function get(key) {
    _checkData();
    if(!hasKey(key)) return null;
    return _data[key];
  }
  
  function set(key, value) {
    _checkData();
    _data[key] <- value;
    _saveData();
  }
  
  function remove(key) {
    _checkData();
    if (hasKey(key)) {
      delete _data[key];
      _saveData();
    }
  }
  
  function refresh() {
    _loadData();
  }
  
  function clear() {
    _data = {};
    _saveData();
    _loadData();
  }


  /***** Private - do not call below *****/
  _data = null
  _isAgent = null
  
  function _saveData() {
    if (_isAgent) {
      server.save(_data);
    } else {
      getroottable()["nv"]<- _data;
    }
  }

  function _loadData() {
    if(_isAgent) {
      _data = server.load();
    } else {
      if (!("nv" in getroottable())) {
        _data = {};
        _saveData();
      }
      _data = getroottable()["nv"];
    }
  }

  function _checkData() {
    if(_isAgent == null) _isAgent = (imp.environment() == ENVIRONMENT_AGENT);
    if(_data == null) _loadData();    
  }
}

/********** Example Usage **********/
// Print out key we set at end of last run
// If this isn't the first time runing the code, this should be true
server.log("hasKey runOnce: " + PersistantData.hasKey("runOnce"));

// Clear data so we know the starting point
PersistantData.clear();     //clear the data

// This should be false
server.log("hasKey test:" + PersistantData.hasKey("test"));

// Save some data
PersistantData.set("test", 123);

// This should be true now
server.log("hasKey test:" + PersistantData.hasKey("test"));
server.log("test value: " + PersistantData.get("test"));

// Remove a key
PersistantData.remove("test");

// This should be false now
server.log("hasKey test:" + PersistantData.hasKey("test"));

// Set value for next pass at code
PersistantData.set("runOnce", true);
