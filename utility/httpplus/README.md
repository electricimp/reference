
HTTPPlus
========

This is an enhanced version of the built-in ```http``` object in Squirrel agents. It overrides the existing functionality with a few tweaks:

- It automatically retries when receiving a 429 error from the agent server
- It follows simple redirects (including posting the data again)
- It converts the body content into a string and sets the content-type header


HTTPRetry
=========

This is a similarly enhanced ```http``` object but trimmed down to do only exactly what ```http``` does plus retries on 429 errors and sendasync() requests are queued and delivered in order.

These two clases should probably be combined at some point.

