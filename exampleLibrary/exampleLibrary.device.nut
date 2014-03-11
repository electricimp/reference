// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class ExampleLibrary {
    _privateProperty = null;
    publicProperty = null

    constructor(val) {
        _privateProperty = 1;
        publicProperty = val;
    }

    function _privateMethod() {
        return _privateProperty;
    }

    function publicMethod() {
        var x = _privateMethod();
        return x * 2;
    }
}

// create object
example <- ExampleLibrary(123);

// get secret value
server.log(example.publicMethod());

