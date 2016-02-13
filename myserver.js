var net = require('net');

var PORT = 17498;
var inout = 0x0000;
var auth = 0;
var cmd = 0;
var server = net.createServer(function(socket) {
  console.log('server connected');
  console.log('remote - ' + socket.remoteAddress + ':' + socket.remotePort);
  console.log('local - ' + socket.localAddress + ':' + socket.localPort);
  
  socket.setEncoding('utf8');

  // socket.setTimeout(15000);
  socket.on('data', function(data) {
    console.log('server receive data');
    console.log('data: ' + data.charCodeAt(0));

    if(data.charCodeAt(0) == 0x10)
    {
      socket.write(String.fromCharCode(20)+String.fromCharCode(1)+String.fromCharCode(1));
    }
    else if(data.charCodeAt(0) == 0x20)
    {
      socket.write(String.fromCharCode(0));
      inout |= data.charCodeAt(1);
      console.log("on: " + data.charCodeAt(1) + " : " + inout);
    }
    else if(data.charCodeAt(0) == 0x21)
    {
      socket.write(String.fromCharCode(0)); 
      inout &= ~(data.charCodeAt(1));
      console.log("off: " + ~(data.charCodeAt(1)) + " : " + inout);
    }
    else if(data.charCodeAt(0) == 0x24)
    {
      socket.write(""+inout);
      console.log("getout: " + inout);
    }
    else if(data.charCodeAt(0) == 0x25)
    {
      socket.write(String.fromCharCode(0x00)+String.fromCharCode(0x30));
      console.log("getin");
    }
    else if(data.charCodeAt(0) == 0x32)
    {
      socket.write(String.fromCharCode(0x01)+String.fromCharCode(0x23));
      console.log("analog");
    }
    else if(data.charCodeAt(0) == 0x78)
    {
      socket.write(String.fromCharCode(124));
      console.log("volt");
    }
    else if(data.charCodeAt(0) == 0x79)
    {
      socket.write(String.fromCharCode(1));
      console.log("passwd: " + data)
      auth = 1;
    }
    else if(data.charCodeAt(0) == 0x7A)
    {
      if(auth == 1)
        socket.write(String.fromCharCode(30));
      else
        socket.write(String.fromCharCode(0));
      console.log("auth time");
    }
    else if(data.charCodeAt(0) == 0x7B)
    {
      auth = 0;
      console.log("logout");
    }
    else 
    {
      console.log("nothing");
    }
  });
  
  socket.on('end', function() {
    console.log('server connection end');
  });
  
  socket.on('close', function() {
    console.log('server connection close');
  });
  
  socket.on('timeout', function() {
    console.log('server connection timeout');
  });
  
  socket.on('error', function() {
    console.log('server connection error');
  });
  
  //setInterval(function() {
  //    console.log('flushed: ', socket.write('keep alive'));
  // }, 3000);
});
  
  server.on('listening', function() {
    console.log('TCP socket server running on port ' + PORT);
  });
  
  server.on('close', function() {
    console.log('server close');
  });
  
  server.on('error', function(e) {
    console.log('server error:', e);
  });
  
  server.listen(PORT);
