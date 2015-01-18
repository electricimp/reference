Firebase
========

A Squirrel class for interacting with [Firebase](http://firebase.com) from an Electric Imp agent.

Firebase Streaming
-----------------

The Firebase Streaming functionality is not yet finalized, **and is subject to change at any time.**

Usage
=====
See the [Example](./example) folder for a simple implementation using the Firebase class. 

Sample instantiation:

```
const FIREBASENAME = "your firebase";
const FIREBASESECRET = "your secret or token";
firebase <- Firebase(FIREBASENAME, FIREBASESECRET);
```
