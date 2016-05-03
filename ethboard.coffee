# #EthBoard plugin

# This is a plugin for creating devices from a EthBoard. 
# Currently the main focus is on the ethernet and wlan boards 
# available here: http://www.robot-electronics.co.uk
# They are supporting the following onboard devices:
#   * Relays
#   * Digital I/Os (open collector)
#   * Analog inputs (10 bit resoltion)
# Additionally the digitial I/Os can be configured to switch remote relays,
# but this configuration is not covered by this plugin

# ##The plugin code

module.exports = (env) ->

  # ###require modules included in pimatic

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the net library
  net = require 'net'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  # ###EthBoard class
  # Create a class that can communicate with a ethernet capable relay board
  class EthBoard extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>

      @host = @config.host
      @port = @config.port
      @interval = 1000 * @config.pingInterval
      @password = @config.password
      @debug = @config.debug
      @isConnected = false
      @cmdObj = null
      @client = null
      @pluginIdle = true
      @deviceType = null
      @cmdFifo = []

      @ethBoardObjects = []

      @ethBoardClasses = [
        EthRelay,
#        EthDigitalInOut,
        EthAnalogSensor
      ]
      
      @createConnection()

      deviceConfigDef = require("./device-config-schema")
      for Cl in @ethBoardClasses
        do (Cl) =>
          @framework.deviceManager.registerDeviceClass(Cl.name, {
            configDef: deviceConfigDef[Cl.name]
            createCallback: (config, lastState) =>
              device = new Cl(config, @, lastState)
              @ethBoardObjects.push device
              return device
          })

      env.logger.debug("ethBoard init") if @config.debug
    
    removeEthBoardDevice: ( ethBoardDevice ) ->
      for device, index in @ethBoardObjects
        if ethBoardDevice.id is device.id 
          @ethBoardObjects.splice index, 1
          env.logger.debug "Removed #{device.id}, devices left: #{@ethBoardObjects.length}" if @debug
          break

    # used to setup the connection, also for connection recovery
    createConnection: ->
      @client = net.createConnection(@port, @host, @connCallback.bind(this))

      @client.on('data', @dataCallback.bind(this))
      @client.on('close', @closeCallback.bind(this))
      @client.on('error', @errorCallback.bind(this))
      @client.on('end', @endCallback.bind(this))

    pushCommand: (id, cmd) ->
      @cmdFifo.push({cmd: cmd, id: id})
      if @cmdFifo.length is 1
        @sendNextCommand()

    sendNextCommand: ->
      if @pluginIdle is false or @cmdFifo.length is 0
        return

      @pluginIdle = false

      @cmdObj = @cmdFifo.shift()
      cmd = @cmdObj.cmd
      id = @cmdObj.id

      # commands "on" and "off" deliver also the pulseTime, so split it
      if cmd.indexOf("on", 0) >= 0 or cmd.indexOf("off", 0) >= 0
        elems = cmd.split " "
        cmd = elems[0]
        pulse = parseInt(elems[1])
        
      env.logger.debug("cmd: "+cmd) if @debug
      switch cmd
        when "auth"
          @client.write(String.fromCharCode(121)+@password)
        when "analog"
          @client.write(String.fromCharCode(50)+String.fromCharCode(id))
        when "info"
          @client.write(String.fromCharCode(16))
        when "volt"
          @client.write(String.fromCharCode(120))
        when "check"
          @client.write(String.fromCharCode(36))
        when "on"
          @client.write(String.fromCharCode(32)+String.fromCharCode(id)+String.fromCharCode(pulse))
        when "off"
          @client.write(String.fromCharCode(33)+String.fromCharCode(id)+String.fromCharCode(pulse))

    # setup the interval for requesting the relay state
    _scheduleUpdate: ->
      unless typeof @intervalObject is 'undefined'
        clearInterval(@intervalObject)

      @intervalObject = setInterval(=>
        @_doDevicePolling()
      , @interval
      )

    # send command to request the relay state or recover connection
    _doDevicePolling: ->
      # check the connection also cyclic to react on module disconnect
      if @isConnected is false
        env.logger.error "Lost connection to "+@host+", trying to reconnect."
        @client.destroy()
        @createConnection()
      else
        for Cl in @ethBoardObjects
          Cl.pollDevice()

    # send command for authorisation
    _doAuthorisation: ->
      @pushCommand(0xFF, "auth")

    # send command to request module info
    _requestModuleInfo: ->
      @pushCommand(0xFF, "info")
    
    # send command to request voltage info
    _requestVoltageInfo: ->
      @pushCommand(0xFF, "volt")
    
    # connection end callback
    endCallback: ->
      env.logger.debug("End") if @debug
      for Cl in @ethBoardObjects
        Cl.eventHandler "end"

    # connection error callback
    errorCallback: (error) ->
      env.logger.debug("Error: "+error) if @debug
      for Cl in @ethBoardObjects
        Cl.eventHandler "error"

    # connection close callback
    closeCallback: (has_error) ->
      env.logger.debug("Closed: "+has_error) if @debug
      @isConnected = false      
      for Cl in @ethBoardObjects
        Cl.eventHandler "close"

    # connection connected callback
    connCallback: (socket) ->
      env.logger.debug("Connected") if @debug
      @isConnected = true
      
      @_scheduleUpdate()
      env.logger.info("pw: "+@password)
      if(@password.length > 0)
        env.logger.info("Auth")
        @_doAuthorisation()

      @_requestModuleInfo()
      @_requestVoltageInfo()

      for Cl in @ethBoardObjects
        Cl.eventHandler "connection"
    
    # data callback
    dataCallback: (data) ->
      env.logger.debug("Data ["+@cmdObj.id+":"+@cmdObj.cmd+"] -> ") if @debug
      if @debug
        for i in [0...data.length] by 1
          env.logger.debug("["+i+"]:"+data[i])
      
      if(@cmdObj.cmd is "info")
        switch data[0]
          when 18 then @deviceType = {a: 0, d: 0, r: 2, m: 1.0}
          when 19 then @deviceType = {a: 0, d: 0, r: 8, m: 1.0}
          when 20 then @deviceType = {a: 4, d: 8, r: 4, m: (3.3/1023.0)}
          when 21 then @deviceType = {a: 8, d: 0, r: 20, m: (5.0/1023.0)}
          when 22 then @deviceType = {a: 4, d: 8, r: 4, m: (3.3/1023.0)}
          when 24 then @deviceType = {a: 8, d: 0, r: 20, m: (5.0/1023.0)}
          when 26 then @deviceType = {a: 0, d: 0, r: 2, m: 1.0}
          when 28 then @deviceType = {a: 0, d: 0, r: 8, m: 1.0}

      for Cl in @ethBoardObjects
        Cl.dataHandler(@cmdObj.id, @cmdObj.cmd, data)
      
      @pluginIdle = true
      @sendNextCommand()


  class EthRelay extends env.devices.PowerSwitch

    attributes:
      state: 
        description: "The current state of the switch" 
        type: "boolean"
        labels: ['on', 'off']
      moduleInfo:
        description: "The info of the module"
        type: "string"
      relayVoltage:
        description: "The voltage at the relay"
        type: "number"
        unit: "V"

    constructor: (@config, @plugin, lastState) ->

      # read the config values
      @name = @config.name
      @id = @config.id
      @did = @config.deviceid

      if @did is 0
        env.logger.error "DeviceId can not be zero"
      
      @pulseTime = @config.pulseTime
      @pulseType = @config.pulseType
      @debug = @plugin.config.debug

      @moduleInfo = "not set"
      @relayVoltage = 0.0
      
      if ethBoard.isConnected
        @_setState lastState

      super()

    destroy: () ->
      ethBoard.removeEthBoardDevice @
      super()

    pollDevice: ->
      ethBoard.pushCommand(@did, "check")

    # getter for the voltage attribute
    getRelayVoltage: ->
      return Promise.resolve @relayVoltage
    # getter for the moduleInfo attribute
    getModuleInfo: ->
      return Promise.resolve @moduleInfo

    eventHandler: (typeName) ->
      switch typeName
        when "connection" then env.logger.debug("EthRelay: Connect") if @debug
        when "error" then env.logger.debug("EthRelay: Error") if @debug
        when "end" then env.logger.debug("EthRelay: End") if @debug
        when "close" then env.logger.debug("EthRelay: Close") if @debug

    # helper function to set the value of an attribute
    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value

    # receive data callback
    dataHandler: (id, cmd, data) ->
      if id is not 0xFF and id is not @did
        return

      # moduleInfo response
      if cmd == "info"
        info = "v" + data[0] + ":" + data[1] + ":" + data[2]
        @_setAttribute "moduleInfo", info
        @moduleInfo = info
        env.logger.debug("info: "+ @moduleInfo)
      # voltageInfo response (divide by 10)
      else if cmd == "volt"
        volt = data[0] / 10
        @_setAttribute "relayVoltage", volt
        env.logger.debug("volt: " + volt) if @debug
      # all other receptions are states or cmd acknowledges
      else if data.length > 0
        # last command was check state
        if cmd == "check"
          env.logger.debug("EthRelay["+@did+"]: " + data[0]) if @debug
          if (data[0] & @did) >= @did
            @_setState true
          else
            @_setState false
        # last on/off was received and now is acknowledged
        else if cmd in ["on", "off"]
          if data[0] == 0
            env.logger.debug("Cmd success") if @debug
          else if data[0] == 1
            env.logger.debug("Cmd failed") if @debug

    # change the state of the switch
    changeStateTo: (state) ->
      if @_state is state then return Promise.resolve true
      else return Promise.try( =>
        @_setState state
        cmd = ""
        onPulse = 0
        offPulse = 0
        if @pulseType == "on" or @pulseType == "both"
          onPulse = @pulseTime
        if @pulseType == "on" or @pulseType == "both"
          offPulse = @pulseTime

        if state is true
          ethBoard.pushCommand(@did, "on "+onPulse)
        else if state is false
          ethBoard.pushCommand(@did, "off "+offPulse)
        else
          env.logger.debug("State is " + state) if @debug
      )

#  class  EthDigitalInOut extends env.devices.PowerSwitch
#    constructor: (@config, @plugin, lastState) ->
#      @name = @config.name
#      @id = @config.id
#      @did = @config.deviceid

  class EthAnalogSensor extends env.devices.Sensor

    attributes:
      moduleInfo:
        description: "The info of the module"
        type: "string"
      value:
        description: "The voltage at the analog input"
        type: "number"
        unit: "V"     
    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @did = @config.deviceid
      @voltage = 0
      @moduleInfo = "not set"
      @multiplier = 1.0

      if @did is 0
        env.logger.error "DeviceId can not be zero"

      super()
    
    destroy: () -> 
      ethBoard.removeEthBoardDevice @
      super()

    eventHandler: (typeName) ->
      switch typeName
        when "connection" then env.logger.debug("EthAnalogSensor: Connect") if @debug
        when "error" then env.logger.debug("EthAnalogSensor: Error") if @debug
        when "end" then env.logger.debug("EthAnalogSensor: End") if @debug
        when "close" then env.logger.debug("EthAnalogSensor: Close") if @debug

   # helper function to set the value of an attribute
    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value
    
    # getter for the moduleInfo attribute
    getModuleInfo: ->
      return Promise.resolve @moduleInfo

    pollDevice: ->
      if(ethBoard.deviceType.a > 0)
        ethBoard.pushCommand(@did, "analog")

    getValue: -> 
      return Promise.resolve @voltage

    # receive data callback
    dataHandler: (id, cmd, data) ->
      if id is not 0xFF and id is not @did
        return

      # moduleInfo response
      if cmd == "info"
        if(ethBoard.deviceType.a is 0)
          info = "Device not supported by module"
        else
          info = "v" + data[0] + ":"+ data[1] + ":" + data[2]
          # load the multiplier from the deviceType struct
          @multiplier = ethBoard.deviceType.m

        @_setAttribute "moduleInfo", info
        @moduleInfo = info
        env.logger.debug("info: "+ @moduleInfo)
      # all other receptions are analog responses
      else if data.length > 0
        # last command was check state
        if(cmd == "analog")
          @voltage = data[0] << 8 | data[1]
          @voltage = @voltage * @multiplier
          @_setAttribute "value", @voltage
          env.logger.debug("analog: "+ @voltage)

  # ###Finally
  # Create a instance of my plugin
  ethBoard = new EthBoard
  # and return it to the framework.
  return ethBoard