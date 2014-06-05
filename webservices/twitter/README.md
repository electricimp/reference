#Twitter Class
The Twitter class allows you to tweet, and stream results from Twitter's streaming API.

**NOTE:** You can only have one instance of the streaming API open per account per app.

#Usage

## Create a Twitter App
In order to use the Twitter API, you'll first need to create a [Twitter App](dev.twitter.com).

## Instantiating the class
Instantiate the class with the following line of code:

	twitter <- Twitter(CONSUMER_KEY, CONSUMER_SECRET, AUTH_TOKEN, TOKEN_SECRET);

## Tweeting
Sending a tweet is super easy:

	twitter.tweet("I just tweeted from an @electricimp agent - bit.ly/ei-twitter.");
	
## Streaming
You can get near instantaneous results for a Twitter search by using the streaming API. When we open a stream, we need to provide a callback that will be executed whenever a new tweet comes into the stream:

	function onTweet(tweetData) {
		// log the tweet, and who tweeted it (there is a LOT more info in tweetData)
		server.log(format("%s - %s", tweet.text, tweet.user.screen_name));
	}
	
	twitter.stream("searchTerm", onTweet);
	
