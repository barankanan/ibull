import {
  type AuthedContext,
  errorResponse,
  getAuthedContext,
  jsonResponse,
  mapCaughtError,
} from '../_shared/http.ts';

const PROFILE_BUCKETS = ['store-images', 'seller-documents'] as const;

async function removePrefix(
  serviceClient: AuthedContext['serviceClient'],
  bucket: string,
  prefix: string,
) {
  const { data, error } = await serviceClient.storage.from(bucket).list(prefix, {
    limit: 100,
  });
  if (error || !data?.length) return;
  const paths = data.map((entry) => `${prefix}/${entry.name}`);
  await serviceClient.storage.from(bucket).remove(paths);
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return errorResponse('METHOD_NOT_ALLOWED', 'POST required.', 405);
    }

    const { user, serviceClient } = await getAuthedContext(req);
    const userId = user.id;
    const warnings: string[] = [];

    for (const bucket of PROFILE_BUCKETS) {
      try {
        await removePrefix(serviceClient, bucket, userId);
      } catch (error) {
        warnings.push(
          `${bucket}:${error instanceof Error ? error.message : 'cleanup_failed'}`,
        );
      }
    }

    const { error: profileError } = await serviceClient
      .from('users')
      .delete()
      .eq('id', userId);
    if (profileError) {
      warnings.push(`users:${profileError.message}`);
    }

    const { error: authError } = await serviceClient.auth.admin.deleteUser(userId);
    if (authError) {
      return errorResponse(
        'AUTH_DELETE_FAILED',
        'Auth kullanıcısı silinemedi.',
        500,
        { message: authError.message, warnings },
      );
    }

    return jsonResponse({
      ok: true,
      deleted_auth_user: true,
      warnings,
    });
  } catch (error) {
    return mapCaughtError(error);
  }
});
