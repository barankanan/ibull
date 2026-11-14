import { handleEvidenceRequest } from './verify_print_evidence.mjs';

const port = Number(Deno.env.get('PORT') ?? '0');
Deno.serve({
  port,
  hostname: '127.0.0.1',
  onListen({ port: listening }) {
    console.log(`EVIDENCE_VERIFIER_PORT ${listening}`);
  },
}, (request) => handleEvidenceRequest(request));
