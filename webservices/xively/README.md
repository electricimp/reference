# Xively Electric Imp Sample Code
Class for reading and writing Xively feeds / channels. 
  
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
