
Factory Agent FTDI Example
======

With this example a DUT can post results data to a url webhook that will relay it to the device. The device will then send all posted data to a PC via an FTDI cable.

Example:

curl -d 'results=a,b,c,d,e' http://staginagent.electricimp.com/agentid/rxData/

Output on PC:

results=a,b,c,d,e