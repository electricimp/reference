imp.configure("Cloud Serial Cable",[],[]);
server.log("Start");

hardware.uart12.configure(115220, 8, PARITY_NONE, 1, NO_CTSRTS);
agent.on("serialIn", function(data){
    hardware.uart12.write(data);
})


