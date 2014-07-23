
HTTPPlus
========

This is an enhanced version of the built-in ```http``` object in Squirrel agents. It overrides the existing functionality with a few tweaks:

- It automatically retries when receiving a 429 error from the agent server
- It follows simple redirects (including posting the data again)
- It converts the body content into a string and sets the content-type header

