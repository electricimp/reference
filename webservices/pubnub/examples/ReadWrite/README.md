ReadWrite
=========

ReadWrite is a simple example that demonstrates how to use PubNub to pass realtime (bi-directional) data between a webpage and an imp.

Instructions
============

- Create a PubNub account - [https://admin.pubnub.com/#signup](https://admin.pubnub.com/#signup)
- Copy and paste the ReadWrite.agent.nut to your agent code window.
- Copy and paste the ReadWrite.device.nut to your device code window.
- Replace the PubNub keys with your PubNub keys (lines 286-288):

```
	const PUBKEY = "pub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
	const SUBKEY = "sub-c-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
	const SECRETKEY = "sec-c-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
```

- Open the ReadWrite.html file in a text editor
  - Replace the PubNub keys with your keys (lines 44-45)
  - Replace the xxxxxxxxxx in the Channel names with your agentURL (lines 49 and 64):
  
```
	pubnub.subscribe({
    	channel : "xxxxxxxxxxxx-lightLevel",
```

and

```
	pubnub.publish({
		channel : "xxxxxxxxxxxx-ledState",
```

- Hit Build and Run, then open the webpage in your browser.