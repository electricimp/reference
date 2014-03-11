Electric Imp Reference Library
==============================
The Electric Imp Reference Library contains classes to help you interface with external hardware, webservices, and accomplish a myriad of tasks!

We have split the Reference Library into 3 categories:

- [Agent](/agent) - Agent libraries to simplify tasks such as persistant storage, building APIs, etc
- [Hardware](/hardware) - Device libraries to simplify interfacing with external hardware, managing wifi connections, etc
- [Web Services](/webservices) - Agent libraries that wrap external APIs such as Twitter, Xively, etc

Contributing
============
We welcome contributions to the Electric Imp Reference Library. If you would like to contribute, please read and follow the guidelines listed below:

Root README
-----------
If you are adding a new library, please include it in the parent folder's README.md file ([agent](/agent/README.md), [hardware](/hardware/README.md), [web services](/webservices/README.md)).

Library Structure
-----------------
All libraries must have their own folder (matching the library name) that contains the following files:

- README.md - Include a description of the library, the author, a hookup guide (if required), and sample usage. 
- libraryName.device.nut (if device code is required) - The device code.
- libraryName.agent.nut (if agent code is required) - The agent code.
- Example folder (optional) - An example (if required).

The **libraryName.device|agent.nut** should contain the classes/tables associated with the library, and a sample instantiation, if a more complete example (or sample appliation) is rerequired, it should be contained in an **Example** folder, with a similar structure to the library. 

Example Folder
--------------
If your library includes an example, please use the following structure:

- README.md - Description of example, and a hookup guide (if required)
- libraryName.example.device.nut (if device code is required) - The device code.
- libraryName.example.agent.nut (if agent code is required) - The agent code.
- *Other files as required* - HTML, etc.

Code Conventions
----------------
Please use the following cade conventions in your Squirrel:

- Constants should be ALLCAPS with underscores between words 
  - e.g ```const MAX_SIZE = 12;```
- Class/Tables names should be UpperCamelCased 
  - e.g. ```class ThisClass {```
- Instantiated classes should be lowerCamelCased 
  - e.g. ```thisClass <- ThisClass();```
- Class/Table methods and properties should be lowerCamelCased
  - e.g. ```function publicMethod() {```
- Class/Table methods and properties that should not be externally referenced should be prefaced with an underscore 
  - e.g. ```function _privateMethod() {```

File Headers
------------
Your code files should include the following:

- Copyright notice
- What license it falls under
- Link to license

```
// Copyright (c) 2013 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
```

License
=======
All code in this repository (unless otherwise specificed in the file) is licensed under the MIT License.

See [LICESNE.md](/LICENSE.md) for more information.
