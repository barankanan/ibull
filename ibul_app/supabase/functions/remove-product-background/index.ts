import {
  errorResponse,
  getAuthedContext,
  jsonResponse,
  mapCaughtError,
  parseJson,
} from '../_shared/http.ts';

type RemoveBackgroundRequest = {
  imageBase64?: string;
};

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse('METHOD_NOT_ALLOWED', 'POST only', 405);
  }

  try {
    const apiKey = Deno.env.get('REMOVE_BG_API_KEY')?.trim();
    if (!apiKey) {
      return errorResponse(
        'NOT_CONFIGURED',
        'Background removal service is not configured.',
        501,
      );
    }

    await getAuthedContext(req);
    const body = await parseJson<RemoveBackgroundRequest>(req);
    const encoded = body.imageBase64?.trim();
    if (!encoded) {
      return errorResponse('INVALID_INPUT', 'imageBase64 is required.', 400);
    }

    const binary = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
    if (binary.length === 0) {
      return errorResponse('INVALID_INPUT', 'imageBase64 is empty.', 400);
    }

    const form = new FormData();
    form.append(
      'image_file',
      new Blob([binary], { type: 'application/octet-stream' }),
      'product.png',
    );
    form.append('size', 'auto');
    form.append('format', 'png');

    const upstream = await fetch('https://api.remove.bg/v1.0/removebg', {
      method: 'POST',
      headers: {
        'X-Api-Key': apiKey,
      },
      body: form,
    });

    if (!upstream.ok) {
      const detail = await upstream.text();
      return errorResponse(
        'UPSTREAM_FAILED',
        'Background removal upstream failed.',
        502,
        { status: upstream.status, detail: detail.slice(0, 500) },
      );
    }

    const resultBytes = new Uint8Array(await upstream.arrayBuffer());
    return jsonResponse({
      ok: true,
      imageBase64: bytesToBase64(resultBytes),
      mimeType: 'image/png',
    });
  } catch (error) {
    return mapCaughtError(error);
  }
});
