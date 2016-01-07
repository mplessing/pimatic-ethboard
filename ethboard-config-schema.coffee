# ethboard configuration options
module.exports = {
  title: "ethboard config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug message to the pimatic log"
      type: "boolean"
      default: false
    host:
      description: "The host of the EthBoard"
      type: "string"
      default: "192.168.0.200"
    port:
      description: "The port of the EthBoard"
      type: "number"
      default: 17498
    pingInterval:
      description: "The check interval in seconds for the EthBoard"
      type: "number"
      default: 60
    password:
      description: "The password to authenticate to the EthBoard"
      type: "string"
      default: ""
}