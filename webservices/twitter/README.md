# Twitter

This class allows you to Tweet, and to stream results from Twitter’s streaming API.

**Availability** Agent

**Version** 1

## Usage ##

	#require <twitter.class.nut:x>

where x is the integer version number *(see above)*

## Requirements ##

To use the Twitter class, you need a Twitter account. You will also need to sign up for Twitter API access at [Twitter’s Apps site](https://apps.twitter.com). There’s a step-by-step guide to this process [here](https://electricimp.com/docs/learning/twitter/).

## Instantiation ##

Instantiate the class by passing the four keys Twitter provides when you sign up for API access. For example:

	tweetstream <- Twitter(<Your API Key>, <Your API Secret>, <Your Authorization Token>, <Your Token Secret>)
	
You can only have one instance of the streaming API open per account per app.

## Functions ##

### tweet(&lt;Tweet text&gt;, &lt;callback&gt;) ###

**Description**

Posts a Tweet to your Twitter timeline.

**Parameters**

*&lt;Tweet text&gt;* The Tweet itself. Type: String. Range: 0-140 characters

*&lt;callback&gt;* An optional function which will be called immediately after Twitter’s server has responded to the post request. The function must include a single parameter: a table which contains three keys:

- *statuscode* HTTP status code (or libcurl error code). Type: Integer
- *headers* Returned HTTP headers. Type: Table
- *body* Returned HTTP body (if any). Type: String

**Return Values**

The function returns a Boolean value which indicates whether the Tweet was successfully posted (`true`) or was not posted due to an error of some kind (`false`). The function **only** returns a value if no callback was provided *(see Parameters, above)*. If a callback is nominated, use that to check for success or failure.

**Examples**

	local success = tweetstream.tweet("I love @electricimp!")
	tweetstream.tweet("I love @electricimp!", function(table){
	   if (table.statuscode != 200) server.log("Tweet posting failed")})

### stream(&lt;Search terms&gt;, &lt;Tweet callback&gt;, &lt;Error callback&gt;) ###

**Description**

Opens a connection to the Twitter stream.

**Parameters**

*&lt;Search term&gt;* The text you wish to search the Twitter stream for. This can be a Twitter handle, eg. @electricimp (but don’t include the ‘@’ symbol); a hashtag, eg. #InternetOfThings; or some other text. Once the request is posted, future appearances of the search text will trigger the function registered at the &lt;Success callback&gt; parameter, below. Type: String.

*&lt;Tweet callback&gt;* The function to be called when Twitter responds with a Tweet containing the search text. This function will not be called until a suitable Tweet is posted; it does not search Tweets that have already been posted. The function must take a single parameter into which a table with the following keys will be passed:

- *text* The text of the Tweet. Type: String
- *user* Information about the user who posted the Tweet. Type: Table

*&lt;Error callback&gt;* An optional function to be called if the class experiences an error while attempting to connect to the Twitter stream.

**Example**

	twitterstream.stream("electricimp", function(tweet){
	    device.send("tweet", format("%s - %s", tweet.user.screen_name, tweet.text)))

