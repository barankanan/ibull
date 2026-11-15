import { createServer } from 'node:http';
import net from 'node:net';

const upstream = new URL(process.env.UPSTREAM ?? '');
const upstreamPort = Number(upstream.port);
let mode = 'forward';

function readHttpMessage(socket) {
  return new Promise((resolve, reject) => {
    let buffer = Buffer.alloc(0);
    const onData = (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      const headerEnd = buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const header = buffer.subarray(0, headerEnd).toString('latin1');
      const match = /content-length:\s*(\d+)/i.exec(header);
      if (match != null) {
        const total = headerEnd + 4 + Number(match[1]);
        if (buffer.length < total) return;
        cleanup();
        resolve(buffer.subarray(0, total));
        return;
      }
      if (/transfer-encoding:\s*chunked/i.test(header)) {
        const end = buffer.indexOf('\r\n0\r\n\r\n', headerEnd);
        if (end < 0) return;
        cleanup();
        resolve(buffer.subarray(0, end + 7));
        return;
      }
      cleanup();
      resolve(buffer.subarray(0, headerEnd + 4));
    };
    const onError = (error) => {
      cleanup();
      reject(error);
    };
    function cleanup() {
      socket.off('data', onData);
      socket.off('error', onError);
    }
    socket.on('data', onData);
    socket.on('error', onError);
  });
}

function connectUpstream() {
  return new Promise((resolve, reject) => {
    const socket = net.connect(upstreamPort, '127.0.0.1');
    socket.once('connect', () => resolve(socket));
    socket.once('error', reject);
  });
}

const proxy = net.createServer((client) => {
  client.on('error', () => {});
  const current = mode;
  if (current === 'cut-request') {
    let buffer = Buffer.alloc(0);
    client.on('data', (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      const headerEnd = buffer.indexOf('\r\n\r\n');
      if (headerEnd >= 0 && buffer.length > headerEnd + 4) client.destroy();
    });
    return;
  }
  if (current === 'blackhole') {
    readHttpMessage(client).catch(() => client.destroy());
    return;
  }
  if (current === 'cut-upstream') {
    readHttpMessage(client).then(async (request) => {
      const upstreamSocket = await connectUpstream();
      upstreamSocket.on('error', () => {});
      upstreamSocket.write(request);
      client.destroy();
      upstreamSocket.destroy();
    }).catch(() => client.destroy());
    return;
  }
  if (current === 'drop-response') {
    readHttpMessage(client).then(async (request) => {
      const upstreamSocket = await connectUpstream();
      upstreamSocket.on('error', () => client.destroy());
      upstreamSocket.write(request);
      await readHttpMessage(upstreamSocket);
      client.destroy();
      upstreamSocket.destroy();
    }).catch(() => client.destroy());
    return;
  }
  readHttpMessage(client).then(async (request) => {
    const upstreamSocket = await connectUpstream();
    upstreamSocket.on('error', () => client.destroy());
    upstreamSocket.write(request);
    const response = await readHttpMessage(upstreamSocket);
    client.write(response);
    client.end();
    upstreamSocket.end();
  }).catch(() => client.destroy());
});

const control = createServer((request, response) => {
  if (request.method !== 'POST' || request.url !== '/mode') {
    response.writeHead(404).end();
    return;
  }
  const chunks = [];
  request.on('data', (chunk) => chunks.push(chunk));
  request.on('end', () => {
    const next = JSON.parse(Buffer.concat(chunks).toString('utf8')).mode;
    if (!['forward', 'cut-request', 'cut-upstream', 'drop-response', 'blackhole'].includes(next)) {
      response.writeHead(400).end();
      return;
    }
    mode = next;
    response.writeHead(200, { 'content-type': 'application/json' }).end('{"ok":true}');
  });
});

proxy.listen(0, '127.0.0.1', () => {
  console.log(`PROXY_PORT ${proxy.address().port}`);
  control.listen(0, '127.0.0.1', () => {
    console.log(`CONTROL_PORT ${control.address().port}`);
  });
});
