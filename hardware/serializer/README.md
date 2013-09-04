
## Introduction ##

The "serializer" class has three core static functions for serializing any serializable object in Squirrel.

* serialize - Pass in any object (string, integer, float, bool, null, array, table, blob) and returns a blob
* deserialize - Pass in a blob (from serialize) and returns the original object
* CRC - a general purpose 8-bit CRC generator for strings and blobs.

## Usage ##

The functions are all static so there is no need to instantiate the class. Simply call like so:

> local obj = { "Hello": "world", "count": 123 };    
> local bl = serializer.serialize(obj);    
> // *bl* now contains the serialized object.    
> local obj2 = serializer.deserialize(bl);    
> // *obj2* === *obj*     

