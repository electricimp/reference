
BLE Tracker - Sample BLE112 application
=======================================

This sample BLE112 application is a Bluetooth Smart device tracker. It continously scans for BLE "peripheral" devices, such as iBeacons, fitness monitors like Fitbit and Nike and TI Sensor Tags. Any device that advertises its presence will be recorded and some devices will output extra information about themselves. The signal level of each visible device is graphed using the Google Charts API.

Setup
=====

- Copy the device and agent firmware in the model of the Blimpee (or equivalent) device in the IDE. 
- Edit the index.html and agent code to configure Firebase classes to point to the right location.
- Open index.html in your browser

To Do
=====

This project was designed to demonstrate the basic function of the BLE112 controlled by an Imp. It is left to the reader to add more functions that suit their needs. Below is a list of some further thoughts.

BGLib Device driver
- Expire data after a while to allow it to scan again
- Connection timeout handler
- Example of handling "user" data type

Application to do
- Allow user to track a device (keep the history of its locations)
- Interpolate location from the rssi values
- Update time stamps per-second (http://timeago.yarp.com/)
- Allow tables to be sorted (http://tablesorter.com/docs/)
- Add "archive all" and "delete all" buttons
