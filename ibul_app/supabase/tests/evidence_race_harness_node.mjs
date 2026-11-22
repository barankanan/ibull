// Node twin of evidence_race_harness.ts for machines without Deno.
// Same verifier module, same 800 ms hold between verification and submit.
import { createServer } from 'node:http';
import {
  inspectEvidenceRequest,
  submitEvidenceOrder,
} from '../functions/verify-lan-print-evidence/verify_print_evidence.mjs';

const server = createServer(async (req, res) => {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const request = new Request(`http://127.0.0.1${req.url}`, {
    method: req.method,
    headers: req.headers,
    body: req.method === 'GET' || req.method === 'HEAD' ? undefined : Buffer.concat(chunks),
  });
  const inspection = await inspectEvidenceRequest(request);
  let response = inspection.response;
  if (!response) {
    if (inspection.accepted) {
      await new Promise((resolve) => setTimeout(resolve, 800));
    }
    response = await submitEvidenceOrder(inspection);
  }
  const payload = Buffer.from(await response.arrayBuffer());
  res.writeHead(response.status, { 'content-type': 'application/json' });
  res.end(payload);
});

server.listen(Number(process.env.PORT ?? '0'), '127.0.0.1', () => {
  console.log(`RACE_HARNESS_PORT ${server.address().port}`);
});
