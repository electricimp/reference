// number_format: Adds commas into integers and floats.
function number_format(num, decimals=null, separator=",") {
    // Fix the decimals
    if (decimals == null) {
        if (typeof num == "string") decimals = 0;
        else if (typeof num == "integer") decimals = 0;
        else if (typeof num == "float") decimals = 2;
        else return num;
    }
    // Check we have a number or convert to one if required
    if (typeof num == "string") {
        if (decimals == 0) num = num.tointeger();
        else num = num.tofloat();
    } else if (typeof num != "integer" && typeof num != "float") {
        return num;
    }
    // Format the number
    local nums = 0;
    if (decimals == 0) {
        num = format("%0.0f", num.tofloat());
        nums = num.len();
    } else {
        nums = format("%0.0f", num.tofloat()).len();
        num = format("%0.0" + decimals + "f", num.tofloat());
    }
    // Add in the commas
    local newnum = "";
    for (local i = 0; i < num.len(); i++) {
        local ch = num[i];
        newnum += ch.tochar();
        if (i >= nums-2) {
            // We are at the end of the integer part, dump the rest
            newnum += num.slice(i+1);
            break;
        }
        if ((nums-i) % 3 == 1) {
            // Time for a comma
            newnum += separator;
        }
    }
    return newnum;
}
