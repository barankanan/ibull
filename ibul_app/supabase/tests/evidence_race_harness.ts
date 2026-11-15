import {
  inspectEvidenceRequest,
  submitEvidenceOrder,
} from '../functions/verify-lan-print-evidence/verify_print_evidence.mjs';

const port = Number(Deno.env.get('PORT') ?? '0');
Deno.serve({
  port,
  hostname: '127.0.0.1',
  onListen({ port: listening }) {
    console.log(`RACE_HARNESS_PORT ${listening}`);
  },
}, async (request) => {
  const inspection = await inspectEvidenceRequest(request);
  if (inspection.response) return inspection.response;
  if (inspection.accepted) {
    await new Promise((resolve) => setTimeout(resolve, 800));
  }
  return submitEvidenceOrder(inspection);
});
