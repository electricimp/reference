mbstring
========

mbstring implements a multibyte string class that can read, write and manipulate UTF8 strings.

It supports the following operations:
- foreach() - Loops over each multibyte character (delivered as a series of strings)
- len() - Returns the number of multibyte characters not the byte length
- slice() - Returns a sub-mbstring
- find() - Searches an mbstring for the first occurence of another string or mbstring.
- tostring() - Converts the mbstring back to a UTF8 string.
- tointeger() - Converts the mbstring back to a UTF8 string and then converts that into an integer.
- tofloat() - Converts the mbstring back to a UTF8 string and then converts that into an float.

Contributors
============

- Aron

Usage
=====

```
local fr = mbstring("123«€àâäèéêëîïôœùûüÿçÀÂÄÈÉÊËÎÏÔŒÙÛÜŸ»");
foreach (x in fr.slice(1, 4)) {
    server.log("Char: " + x);
}
server.log("Find: " + fr.find("ëîïôœ"));
server.log("Euro: " + fr[4])

```
