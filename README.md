#pimatic-plugin-ethboard

Plugin to control ethernet connected devices by tcp commands on boards from - <http://www.robot-electronics.co.uk>.

There are different boards with a combination of the following onboard devices:
   * Relays (16A @ 24VDC / 230VAC)
   * Digital switching I/Os (NPN OC transistor with 10k)
   * Analog inputs (0-3,3V or 0-5V with 10 bits resolution)

This plugin is only for controlling and not for configuring the devices.

Note, this is an early version of the plugin provided for testing purposes. Please provide feedback via 
[github](https://github.com/mplessing/pimatic-ethboard/issues).

## Supported devices
The ethernet/wifi devices from robot-electronics have three numbers at the end of the device name giving the amount of the different supported devices by the board. The left number is the amount of analog inputs, the middle number represents the number of digital switching I/Os and the right number gives the number of relays.

There are the following standard devices available:
ETH002, ETH008, ETH484, ETH8020
WIFI002, WIFI008, WIFI484, WIFI0820

## Restrictions
Currently only the the relay feature of an ETH002 is implemented and tested. The relay feature of the other boards should work out of the box.

## Configuration
You can load the plugin by editing your `config.json` to include the following in the `plugins` section. The properties `host` and `port` are used to connect to the board. If you set a TCP password in the board configuration also set this password here. The property 
`pingInterval` specifies the time interval in seconds for updating the data set. For debugging purposes you may set 
property `debug` to true. This will write additional debug messages to the pimatic log. The values set in the example config afterwards represent also the default values. 

    {
          "plugin": "ethboard",
          "host": "192.168.0.200",
          "port": 17498,
          "pingInterval": 60,
          "password": ""
          "debug": false
    },

Then you need to add a device in the `devices` section. Currently, only the following device type is supported:

* EthRelay: This type is able to switch a relay and display its current state.

As part of the device definition you need to provide the `deviceid`, which is the relay number on the board. You can also specify a `pulseTime`, where each increment counts as 100ms. If `pulseTime` expires the relay state will toggle back, while `pulseType` is on of ["none", "on", "off", "both"], what configures the states for which the pulseTimer will be activated.

    {
          "id": "ethrelay01",
          "class": "EthRelay",
          "name": "Ethernet Relay 01",
          "deviceid": 1,
          "pulseType": "none",
          "pulseTime": 0
    },

## Contributions

Contributions to the project are welcome. You can simply fork the project and create a pull request with your contribution to start with.

## History

* 20160106, V0.0.1
    * Initial Version
