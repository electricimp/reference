Basic Text-To-Speech
====================
This example is intended to demonstrate how simple it can be to begin working with audio on the imp.

**NOTE:** This example is NOT production ready, and will only work with very short snippets (as it sends the entire audio file without chunking it, or even checking if the imp has enough memory to store it). When an audio file that is larger than the imp's memory is sent, the imp will simply crash (Out of Memory) and restart.

Hardware
========
This example uses the SparkFun [Mono Audio Amp Breakout](https://www.sparkfun.com/products/11044), and a [8Ω Speaker](https://www.sparkfun.com/products/9151).

Hookup
------
3v3 (imp) --> PWR+ (amp)
GND (imp) --> PWR- (amp)

PIN2 (imp) --> PWR S (amp)
GND (imp) --> 10kΩ resistor --> PWR S (amp)

PIN5 (imp) --> IN+ (amp)
GND (imp) --> IN- (amp)

Usage
=====

- Add your ReadSpeaker API Key to the ReadSpeaker constructor:
```
ttsEngine <- ReadSpeaker("********************************");
```
- Build and Run
- Browse to your agent's URL and add '?say=hello world'
```
GET https://agent.electricimp.com/************?say=hello%20world
```
- Your imp should "speak" the phrase 'hello world' from the speaker.
