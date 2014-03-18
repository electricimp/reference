// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

server.log("Agent Running at "+http.agenturl());

// The device spends most of its time asleep when on battery power, 
// So the agent keeps track of parameters like the current image and display size.
const WIDTH = 264;
const HEIGHT = 176;

PIXELS <- HEIGHT * WIDTH;
BYTES_PER_SCREEN <- PIXELS / 4;

imgData <- {};
// resize image blobs to display dimensions
imgData.curImg <- blob(BYTES_PER_SCREEN);
imgData.curImgInv <- blob(BYTES_PER_SCREEN);
imgData.nxtImg <- blob(BYTES_PER_SCREEN);
imgData.nxtImgInv <- blob(BYTES_PER_SCREEN);

// fill the current image blobs with dummy data
for (local i = 0; i < BYTES_PER_SCREEN; i++) {
    imgData.curImg.writen(0xAA,'b');
	imgData.curImgInv.writen(0xFF,'b');
}

/*
 * Input: WIF image data (blob)
 *
 * Return: image data (table)
 *         	.height: height in pixels
 * 			.width:  width in pixels
 * 			.data:   image data (blob)
 */
function unpackWIF(packedData) {
	packedData.seek(0,'b');

	// length of actual data is the length of the blob minus the first four bytes (dimensions)
	local datalen = packedData.len() - 4;
	local retVal = {height = null, width = null, normal = blob(datalen*2), inverted = blob(datalen*2)};
	retVal.height = packedData.readn('w');
	retVal.width = packedData.readn('w');
	server.log("Unpacking WIF Image, Height = "+retVal.height+" px, Width = "+retVal.width+" px");

	/*
	 * Unpack WIF for RePaper Display
	 * each row is (width / 4) bytes (2 bits per pixel)
	 * first (width / 8) bytes are even pixels
	 * second (width / 8) bytes are odd pixels
	 * unpacked index must be incremented by (width / 8) every (width / 8) bytes to avoid overwriting the odd pixels.
	 *
	 * Display is drawn from top-right to bottom-left
	 *
	 * black pixel is 0b11
	 * white pixel is 0b10
	 * "don't care" is 0b00 or 0b01
	 * WIF does not support don't-care bits
	 *
	 */

	for (local row = 0; row < retVal.height; row++) {
		//for (local col = 0; col < (retVal.width / 8); col++) {
		for (local col = (retVal.width / 8) - 1; col >= 0; col--) {
			local packedByte = packedData.readn('b');
			local unpackedWordEven = 0x00;
			local unpackedWordOdd  = 0x00;
			local unpackedWordEvenInv = 0x00;
			local unpackedWordOddInv  = 0x00;

			for (local bit = 0; bit < 8; bit++) {
				// the display expects the data for each line to be interlaced; all even pixels, then all odd pixels
				if (!(bit % 2)) {
					// even pixels become odd pixels because the screen is drawn right to left
					if (packedByte & (0x01 << bit)) {
						unpackedWordOdd = unpackedWordOdd | (0x03 << (6-bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x02 << (6-bit));
					} else {
						unpackedWordOdd = unpackedWordOdd | (0x02 << (6-bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x03 << (6-bit));
					}
				} else {
					// odd pixel becomes even pixel
					if (packedByte & (0x01 << bit)) {
						unpackedWordEven = unpackedWordEven | (0x03 << bit - 1);
						unpackedWordEvenInv = unpackedWordEvenInv | (0x02 << bit - 1);
					} else {
						unpackedWordEven = unpackedWordEven | (0x02 << bit - 1);
						unpackedWordEvenInv = unpackedWordEvenInv | (0x03 << bit - 1);
					}
				}
			}

			retVal.normal[(row * (retVal.width/4))+col] = unpackedWordEven;
			retVal.inverted[(row * (retVal.width/4))+col] = unpackedWordEvenInv;
			retVal.normal[(row * (retVal.width/4))+(retVal.width/4) - col - 1] = unpackedWordOdd;
			retVal.inverted[(row * (retVal.width/4))+(retVal.width/4) - col - 1] = unpackedWordOddInv;

		} // end of col
	} // end of row

	server.log("Done Unpacking WIF File.");

	return retVal;
}

/* DEVICE EVENT HANDLERS ----------------------------------------------------*/

// Tell the device how big the screen is and what it has on it when it wakes up and asks.
device.on("params_req",function(data) {
    local dispParams = {};
    dispParams.height <- HEIGHT;
    dispParams.width <- WIDTH;
	device.send("params_res",dispParams);
});

device.on("readyForNewImgInv", function(data) {
    device.send("newImgInv", imgData.nxtImgInv);
});

device.on("readyForNewImgNorm", function(data) {
    device.send("newImgNorm", imgData.nxtImg);
    
    // now move the "next image" data to "current image" in the image data table.
    imgData.curImg = imgData.nxtImg;
    imgData.curImgInv = imgData.nxtImgInv;
    
    // This completes the "new-image" process, and the display will be stopped.
});

/* HTTP EVENT HANDLERS ------------------------------------------------------*/

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/WIFimage" || request.path == "/WIFimage/") {
    	// return right away to keep things responsive
    	res.send(200, "OK\n");

    	// incoming data has to be base64decoded so we can get a blob right away
    	local data = http.base64decode(request.body);
    	server.log("Got new data, len "+data.len());

    	// unpack the WIF image data
    	local newImgData = unpackWIF(data);
    	imgData.nxtImg = newImgData.normal;
    	imgData.nxtImgInv = newImgData.inverted;

    	// send the inverted version of the image currently on the screen to start the display update process
        server.log("Sending new data to device, len: "+imgData.curImgInv.len());
        device.send("newImgStart",imgData.curImgInv);
        
    } else if (request.path == "/clear" || request.path == "/clear/") {
    	res.send(200, "OK\n");

    	device.send("clear", 0);
    	server.log("Requesting Screen Clear.");
    } else {
    	server.log("Agent got unknown request");
    	res.send(200, "OK\n");
    }
});
