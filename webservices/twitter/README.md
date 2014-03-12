Twitter Search
===============
This is a basic class that allows you to search Twitter's new v1.1 API.

These classes are incomplete and need to be refactored into a single class

## Usage
Searching twitter has never been easier, simply call the search() function with your query. The query can be a hashtag (e.g. #iot), a user (e.g. @electricimp) or a phrase (e.g. hello world).

	local tweets = twitter.search("@electricimp");

### Optional Parameters
The search() function has 3 optional parameters:
- **count**: The maximum number of results to return
- **since_id**: A tweetID indicating the earliest tweet we want returned. If you are polling the search API, it is good practice to use the previous requests **max_id_str** as your next requests since_id.
- **geocode**: A geocode table with a latitude, longitude, and radius. If a valid geocode table is supplied, only tweets within the specified area will be returned.

### Polling
Below is sample code to poll the twitter search API with a particular query. Setting up code in this way will result in ONLY new tweets being returned each time you call twitter.search():

	// wrapper function for PollTwitter so we can call it in an imp.wakeup
	function PollTwitterWrapper(pollTime, query, count = null, since_id = null, geocode = null) {
		return function() { PollTwitter(pollTime, query, count, since_id, geocode); };
	} 

	function PollTwitter(pollTime, query, count = null, since_id = null, geocode = null) {
		local tweets = twitter.search(query, count, since_id, geocode);
	
		if ("statuses" in tweets && tweets.statuses.len() > 0) {
			local tweetData = []
			foreach (tweet in tweets.statuses) {
				tweetData.push({
					id = tweet.id_str,
					text = tweet.text,
					tweeted_by = tweet.user.screen_name,
					created_at = tweet.created_at,
					coordinates = tweet.coordinates
				});
			}
			device.send("tweets", tweetData);
		}
		if ("search_metadata" in tweets && "max_id_str" in tweets.search_metadata) {
			since_id = tweets.search_metadata.max_id_str;
		}
		imp.wakeup(pollTime, PollTwitterWrapper(pollTime, query, count, since_id, geocode));
	}	

	PollTwitter(1, "@electricimp", 1);
