import { createServer } from 'node:http';
import { handleEvidenceRequest } from './verify_print_evidence.mjs';

const server = createServer(async (req, res) => {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);
  const request = new Request(`http://127.0.0.1${req.url}`, {
    method: req.method,
    headers: req.headers,
    body: req.method === 'GET' || req.method === 'HEAD' ? undefined : body,
  });
  const response = await handleEvidenceRequest(request);
  const payload = Buffer.from(await response.arrayBuffer());
  res.writeHead(response.status, { 'content-type': 'application/json' });
  res.end(payload);
});

server.listen(0, '127.0.0.1', () => {
  const address = server.address();
  console.log(`EVIDENCE_VERIFIER_PORT ${address.port}`);
});
