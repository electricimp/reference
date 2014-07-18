// Pin allocation
led_red  <- hardware.pinE;
led_grn  <- hardware.pinF;
led_blu  <- hardware.pinK;
led_wht  <- hardware.pinM;

btn1     <- hardware.pinU;
btn2     <- hardware.pinV;

mic_en_l <- hardware.pinT;
mic      <- hardware.pinJ;
spk_en   <- hardware.pinS;
spk      <- hardware.pinC;


// Prepare the sample list
const freq = 13000;
const bufsiz = 6000;
ffd_started <- false;
sample_queue <- [];

function have_new_buffer(buffer, len) {
    if (len == 0) {
        server.log("Sampler overflow")
        return;
    }
    
    // Copy the buffer contents and dump it into the samples list
    local buffercopy = buffer.readblob(len);
    sample_queue.push(buffercopy);
    // server.log(format("+++ %d samples, %d memory free", sample_queue.len(), imp.getmemoryfree()))
    
    // Start the FFD if it hasn't started already
    if (!ffd_started && sample_queue.len() == 3) {
        
        // Start the speaker after shutting down wifi
        server.disconnect();
        imp.setpoweren(true);
        start_dac();
    }
}

function need_new_buffer(oldbuffer) {
    if (sample_queue.len() > 0) {
        hardware.fixedfrequencydac.addbuffer(sample_queue[0]);
        sample_queue.remove(0);
        // server.log(format("--- %d samples left, %d memory free", sample_queue.len(), imp.getmemoryfree()))
    } else {
        server.log("DAC underflow");
    }
}


// Start the microphone sampler
function start_sampler() {
    hardware.sampler.configure(mic, freq, [blob(bufsiz), blob(bufsiz), blob(bufsiz)], have_new_buffer, 0);
    mic_en_l.configure(DIGITAL_OUT);
    mic_en_l.write(0);
    hardware.sampler.start();
}

// Start the DAC
function start_dac() {
    hardware.fixedfrequencydac.configure(spk, freq, sample_queue, need_new_buffer, AUDIO);
    hardware.fixedfrequencydac.start();
    spk_en.configure(DIGITAL_OUT);
    spk_en.write(1);
    ffd_started = true;
}

start_sampler();

server.log("Started with version " + imp.getsoftwareversion())
imp.enableblinkup(true);
