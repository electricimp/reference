/*
Copyright (C) 2013 electric imp, inc.
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
 
// =============================================================================
class serializer {
 
    // Serialize a variable of any type into a blob
    function serialize (obj) {
        // Take a guess at the initial size
        local b = blob(2000);
        // Write dummy data for len and crc late
        b.writen(0, 'b');
        b.writen(0, 'b');
        b.writen(0, 'b');
        // Serialise the object
        _serialize(b, obj);
        // Shrink it down to size
        b.resize(b.tell());
        // Go back and add the len and CRC
		local len = b.len()-3;
        b[0] = len >> 8 & 0xFF;
        b[1] = len & 0xFF;
        b[2] = CRC(b, 3);
        return b;
	}
 
	function _serialize (b, obj) {
 
		switch (typeof obj) {
			case "integer":
                return _write(b, 'i', format("%d", obj));
			case "float":
                local f = format("%0.7f", obj).slice(0,9);
                while (f[f.len()-1] == '0') f = f.slice(0, -1);
                return _write(b, 'f', f);
			case "null":
            case "function": // Silently setting this to null
                return _write(b, 'n');
			case "bool":
                return _write(b, 'b', obj ? "\x01" : "\x00");
			case "blob":
                return _write(b, 'B', obj);
			case "string":
                return _write(b, 's', obj);
			case "table":
			case "array":
				local t = (typeof obj == "table") ? 't' : 'a';
				_write(b, t, obj.len());
				foreach ( k,v in obj ) {
                    _serialize(b, k);
                    _serialize(b, v);
				}
				return;
			default:
				throw ("Can't serialize " + typeof obj);
				// server.log("Can't serialize " + typeof obj);
		}
	}
 
 
    function _write(b, type, payload = null) {
 
        // Calculate the lengths
        local payloadlen = 0;
        switch (type) {
            case 'n':
            case 'b':
                payloadlen = 0;
                break;
            case 'a':
            case 't':
                payloadlen = payload;
                break;
            default:
                payloadlen = payload.len();
        }
        
        // Update the blob
        b.writen(type, 'b');
        if (payloadlen > 0) {
            b.writen(payloadlen >> 8 & 0xFF, 'b');
            b.writen(payloadlen & 0xFF, 'b');
        }
        if (typeof payload == "string" || typeof payload == "blob") {
            foreach (ch in payload) {
                b.writen(ch, 'b');
            }
        }
    }
 
 
	// Deserialize a string into a variable 
	function deserialize (s) {
		// Read and check the header
        s.seek(0);
        local len = s.readn('b') << 8 | s.readn('b');
        local crc = s.readn('b');
        if (s.len() != len+3) throw "Expected exactly " + len + " bytes in this blob";
        // Check the CRC
        local _crc = CRC(s, 3);
        if (crc != _crc) throw format("CRC mismatch: 0x%02x != 0x%02x", crc, _crc);
        // Deserialise the rest
		return _deserialize(s, 3).val;
	}
    
	function _deserialize (s, p = 0) {
		for (local i = p; i < s.len(); i++) {
			local t = s[i];
			switch (t) {
				case 'n': // Null
					return { val = null, len = 1 };
				case 'i': // Integer
					local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
					local val = s.readblob(len).tostring().tointeger();
					return { val = val, len = 3+len };
				case 'f': // Float
					local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
    				local val = s.readblob(len).tostring().tofloat();
					return { val = val, len = 3+len };
				case 'b': // Bool
					local val = s[i+1];
					return { val = (val == 1), len = 2 };
				case 'B': // Blob 
					local len = s[i+1] << 8 | s[i+2];
					local val = blob(len);
					for (local j = 0; j < len; j++) {
						val[j] = s[i+3+j];
					}
					return { val = val, len = 3+len };
				case 's': // String
					local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
    				local val = s.readblob(len).tostring();
					return { val = val, len = 3+len };
				case 't': // Table
				case 'a': // Array
					local len = 0;
					local nodes = s[i+1] << 8 | s[i+2];
					i += 3;
					local tab = null;
 
					if (t == 'a') {
						// server.log("Array with " + nodes + " nodes");
						tab = [];
					}
					if (t == 't') {
						// server.log("Table with " + nodes + " nodes");
						tab = {};
					}
 
					for (; nodes > 0; nodes--) {
 
						local k = _deserialize(s, i);
						// server.log("Key = '" + k.val + "' (" + k.len + ")");
						i += k.len;
						len += k.len;
 
						local v = _deserialize(s, i);
						// server.log("Val = '" + v.val + "' [" + (typeof v.val) + "] (" + v.len + ")");
						i += v.len;
						len += v.len;
 
						if (t == 'a') tab.push(v.val);
						else          tab[k.val] <- v.val;
					}
					return { val = tab, len = len+3 };
				default:
					throw format("Unknown type: 0x%02x at %d", t, i);
			}
		}
	}
 
 
	function CRC (data, offset = 0) {
		local LRC = 0x00;
		for (local i = offset; i < data.len(); i++) {
			LRC = (LRC + data[i]) & 0xFF;
		}
		return ((LRC ^ 0xFF) + 1) & 0xFF;
	}
 
}
