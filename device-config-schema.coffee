module.exports = {
  title: "ethboard device config schemas"
  EthRelay: {
    title: "EthRelay config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      id:
        description: "The id of the device"
        type: "string"
      name:
        description: "The name of the device"
        type: "string"
      deviceid:
        description: "The deviceid of the device"
        type: "number"
        default: 0
      pulseType:
        description: "The pulsed commands (on, off, both)"
        type: "string"
        enum: ["none", "on", "off", "both"]
        default: "none"
      pulseTime:
        description: "Time for a relay pulse (1 = 100ms)"
        type: "number"
        default: 0
  }
}