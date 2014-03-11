# Xively Library
This class wraps [Xively's public API](https://xively.com/dev/docs/api/), which allows you to push and get time-series data, as well as configure callbacks that can be triggered through Xively's triggers.

### Usage
Creating the Xively client:
	
	client <- Xively.Client("YOUR_API_KEY");
	
Push data to a feed:
	
	// Create a channel and assign a value
	tempChannel <- Xively.Channel("Temperature");
	tempChannel.Set(current_temperature);
	
	// Create a feed (replace FEED_ID with the Xively FeedID you are writting to
	feed <- Xively.Feed("FEED_ID", [tempChannel]);
	
	// Update Xively
	client.Put(feed);
		
Get data from a feed:
	
	// Create a channel
	tempChannel <- Xively.Channel("Temperature");
	
	// Create a feed (replace FEED_ID with the Xively FeedID you are getting
	feed <- Xively.Feed("FEED_ID", [tempChannel]);
	
	// Pull from Xively
	client.Get(feed, Xively.API_KEY);
