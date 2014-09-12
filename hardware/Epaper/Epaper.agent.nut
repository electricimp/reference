// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

const WIDTH = 264;
const HEIGHT = 176;

PIXELS <- HEIGHT * WIDTH;
BYTES_PER_SCREEN <- (PIXELS / 4) + (HEIGHT / 4);

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
	local retVal = {height = null, width = null, normal = [], inverted = []};
	retVal.height = packedData.readn('w');
	retVal.width = packedData.readn('w');
	retVal.normal = array(retVal.height);
	retVal.inverted = array(retVal.height);
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
	 */

	for (local row = 0; row < retVal.height; row++) {
		retVal.normal[row] = blob(((retVal.width * 2) + (retVal.height * 2)) / 8);
		retVal.inverted[row] = blob(((retVal.width * 2) + (retVal.height * 2)) / 8);
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
						unpackedWordOdd = unpackedWordOdd | (0x03 << (6 - bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x02 << (6 - bit));
					} else {
						unpackedWordOdd = unpackedWordOdd | (0x02 << (6 - bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x03 << (6 - bit));
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

			// the first (width * 3 / 16) bytes are even pixels in descending order [D(264, y), D(262,y)...]
			retVal.normal[row][col] = unpackedWordEven;
			retVal.inverted[row][col] = unpackedWordEvenInv;
			// the last (width * 3 / 16) bytes are odd piels in ascending order
			retVal.normal[row][(retVal.width / 4) + (retVal.height / 4) - col - 1] = unpackedWordOdd;
			retVal.inverted[row][(retVal.width / 4) + (retVal.height / 4) - col - 1] = unpackedWordOddInv;
		} // end of col
		// (height / 4) bytes in the middle are "scan bytes" (for each line, "0b11" = write this line, "0b00" = don't write this line)
		for (local i = (retVal.width / 8); i < ((retVal.width / 8) + (retVal.height / 4)); i++) {
		    if (i - (retVal.width / 8) == math.floor(row / 4)) {
		        retVal.normal[row][i] = (0xC0 >> (2 * (row % 4)));
		        retVal.inverted[row][i] = (0xC0 >> (2 * (row % 4)));
		    } else {
		        retVal.normal[row][i] = 0x00;
		        retVal.inverted[row][i] = 0x00;
		    }
		}
	} // end of row

	server.log("Done Unpacking WIF File.");

	return retVal;
}

function createBlankImg() {
    local screenData = array(HEIGHT);
	for (local row = 0; row < HEIGHT; row++) {
	    screenData[row] = blob(((WIDTH * 2) + (HEIGHT * 2)) / 8);
	    for (local i = 0; i < (WIDTH / 8); i++) {
	        screenData[row][i] = 0xAA;
	    }
	    for (local j = (WIDTH / 8); j < ((WIDTH / 8) + (HEIGHT / 4)); j++) {
	        if ((j - (WIDTH / 8)) == math.floor(row / 4)) {
		        screenData[row][j] = (0xC0 >> (2 * (row % 4)));
		    } else {
		        screenData[row][j] = 0x00;
		    }
	    }
	    for (local k = ((WIDTH / 8) + (HEIGHT / 4)); k < ((WIDTH * 2) + (HEIGHT * 2)) / 8; k++) {
	        screenData[row][k] = 0xAA;
	    }
	}
	return screenData;
}

server.log("Creating a blank image...");

imgData <- {};
local white = createBlankImg();
imgData.curImg      <- white;
imgData.curImgInv   <- white;
imgData.nxtImg      <- white;
imgData.nxtImgInv   <- white;

/* DEVICE EVENT HANDLERS ----------------------------------------------------*/

device.on("readyForWhite", function(data) {
    device.send("white", white);
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
    local path = request.path.tolower();
    if (path == "/wifimage") {
    	// return right away to keep things responsive
    	res.send(200, "OK\n");

    	// incoming data has to be base64decoded so we can get a blob right away
    	local data = blob(request.body.len());
    	data.writestring(request.body);
    	server.log("Got new data, len "+data.len());

    	// unpack the WIF image data
    	local newImgData = unpackWIF(data);
    	imgData.nxtImg = newImgData.normal;
    	imgData.nxtImgInv = newImgData.inverted;

    	// send the inverted version of the image currently on the screen to start the display update process
        server.log("Sending new data to device");
        device.send("newImg", imgData.curImgInv);
        
    } else if (path == "/clear") {
    	res.send(200, "OK\n");
    	device.send("clear", 0);
    } else {
    	server.log("Agent got unknown request");
    	res.send(200, "OK\n");
    }
});

server.log("Agent Ready");