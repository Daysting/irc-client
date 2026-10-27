import http from 'node:http';
import tls from 'node:tls';
import {WebSocketServer,WebSocket} from 'ws';
import {validateLine} from '../dist/protocol.mjs';
export function createRelay({origins=(process.env.ALLOWED_ORIGINS||'').split(',').filter(Boolean),connect=tls.connect}={}){
 const host='irc.daysting.com',port=6697;
 if(!origins.length)throw Error('Set ALLOWED_ORIGINS to the exact HTTPS web client origin.');
 if(!Number.isInteger(port)||port<1||port>65535)throw Error('Invalid IRC_PORT.');
 const server=http.createServer((req,res)=>{res.writeHead(req.url==='/health'?200:404,{'Content-Type':'text/plain'});res.end(req.url==='/health'?'DaystingIRC relay ready\n':'Not found\n');});
 const wss=new WebSocketServer({noServer:true,maxPayload:4096,perMessageDeflate:false,handleProtocols:protocols=>protocols.has('text.ircv3.net')?'text.ircv3.net':false});
 const perIP=new Map();
 server.on('upgrade',(req,socket,head)=>{const ip=req.socket.remoteAddress;if(req.url!=='/irc'||!origins.includes(req.headers.origin)||wss.clients.size>=100||(perIP.get(ip)||0)>=8){socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return;}perIP.set(ip,(perIP.get(ip)||0)+1);wss.handleUpgrade(req,socket,head,ws=>{ws.once('close',()=>{const n=(perIP.get(ip)||1)-1;if(n)perIP.set(ip,n);else perIP.delete(ip);});wss.emit('connection',ws,req);});});
 wss.on('connection',ws=>{let connected=false,buffer='',queue=[],count=0,bytes=0,alive=true;
 const upstream=connect({host,port,servername:host,rejectUnauthorized:true},()=>{connected=true;upstream.setTimeout(0);for(const line of queue)upstream.write(line+'\r\n');queue=[];});upstream.setEncoding('utf8');upstream.setTimeout(15000);const fail=reason=>{if(ws.readyState===WebSocket.OPEN)ws.close(1011,reason);upstream.destroy();};upstream.on('timeout',()=>fail('IRC connection timed out'));upstream.on('error',()=>fail('IRC TLS connection failed'));upstream.on('close',()=>{if(ws.readyState===WebSocket.OPEN)ws.close(1000,'IRC server disconnected');});
 upstream.on('data',chunk=>{buffer+=chunk;if(buffer.length>65536){fail('Server frame limit exceeded');return;}let i;while((i=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,i).replace(/\r$/,'');buffer=buffer.slice(i+1);if(ws.readyState===WebSocket.OPEN){if(ws.bufferedAmount>262144){fail('Client too slow');return;}ws.send(line);}}});
 ws.on('message',(data,binary)=>{try{if(binary)throw Error();const text=data.toString();bytes+=Buffer.byteLength(text);const lines=text.replace(/\r?\n$/,'').split(/\r?\n/);count+=lines.length;if(count>30||bytes>16384)throw Error();for(const line of lines){validateLine(line);if(!connected){if(queue.length>=12)throw Error();queue.push(line);}else{if(upstream.writableLength>65536)throw Error();upstream.write(line+'\r\n');}}}catch{ws.close(1008,'Invalid command or rate limit exceeded');upstream.destroy();}});
 ws.on('error',()=>upstream.destroy());ws.on('pong',()=>alive=true);const heartbeat=setInterval(()=>{count=0;bytes=0;if(!alive){ws.terminate();return;}alive=false;ws.ping();},30000);ws.on('close',()=>{clearInterval(heartbeat);queue=[];upstream.destroy();});
 });
 server.on('close',()=>{for(const ws of wss.clients)ws.terminate();wss.close();});return server;
}
if(process.argv[1]&&import.meta.url===new URL('file://'+process.argv[1]).href){const server=createRelay();server.listen(Number(process.env.PORT||8787),process.env.BIND_HOST||'127.0.0.1',()=>console.log('DaystingIRC relay listening on '+JSON.stringify(server.address())));}
