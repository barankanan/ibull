import { getAuthedContext } from '../_shared/http.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});
const allowed = new Set(['manageProducts', 'viewOrders', 'manageOrders',
  'manageCampaigns', 'viewFinance', 'manageSupport', 'manageStoreProfile',
  'transferTable', 'splitBill', 'takePartialPayment', 'closeBill',
  'managePrintSettings', 'manageStaff']);
const restaurantOnly = new Set(['transferTable', 'splitBill',
  'takePartialPayment', 'closeBill', 'managePrintSettings']);
const legacyPermissions = new Set(['manageProducts', 'viewOrders', 'manageOrders',
  'manageCampaigns', 'viewFinance', 'manageSupport', 'manageStoreProfile']);
const keptWhenClientOmits = new Set([...restaurantOnly, 'manageStaff']);

const waiterCeiling = new Set(['viewOrders', 'manageOrders', 'manageProducts',
  'manageSupport', 'transferTable', 'takePartialPayment']);
const pageModules = new Set(['dashboard', 'products', 'collections', 'orders',
  'garson', 'system', 'store', 'mallRequests', 'contracts', 'team', 'campaigns',
  'finance', 'achievements', 'reviews', 'support', 'vehicles']);
const triggerPermissions = new Set(['manageProducts', 'viewOrders', 'manageOrders',
  'manageCampaigns', 'viewFinance', 'manageSupport', 'manageStoreProfile',
  'transferTable', 'splitBill', 'takePartialPayment', 'closeBill',
  'managePrintSettings', 'manageStaff']);

function cleanTitle(value: unknown) {
  if (typeof value !== 'string') return '';
  const title = value.trim();
  return title.length > 0 && title.length <= 80 ? title : '';
}

function cleanPages(value: unknown) {
  if (!Array.isArray(value)) return null;
  return [...new Set(value.filter((item): item is string =>
    typeof item === 'string' && pageModules.has(item)))];
}

async function profileColumns(serviceClient: {
  from: (table: string) => { select: (columns: string) => { limit: (count: number) => Promise<{ error: { message?: string } | null }> } };
}) {
  const { error } = await serviceClient.from('store_sub_admins')
    .select('job_title,visible_modules').limit(1);
  return !error;
}

function permissionsFromLegacyClient(
  incoming: string[],
  stored: unknown,
  foodStore: boolean,
  revoked: unknown,
) {
  const explicit = Array.isArray(revoked);
  const revokedNames = new Set(explicit
    ? revoked.filter((name): name is string =>
      typeof name === 'string' && keptWhenClientOmits.has(name))
    : []);
  if (!explicit && incoming.some((name) => keptWhenClientOmits.has(name))) {
    return incoming;
  }
  if (!explicit && !incoming.every((name) => legacyPermissions.has(name))) {
    return incoming;
  }
  const base = incoming.filter((name) => !revokedNames.has(name));
  const existing = Array.isArray(stored) ? stored : [];
  const kept = existing.filter((name): name is string =>
    typeof name === 'string'
    && keptWhenClientOmits.has(name)
    && !base.includes(name)
    && !revokedNames.has(name)
    && (foodStore || !restaurantOnly.has(name)));
  return [...base, ...kept];
}

function isFoodStoreCategory(category: unknown) {
  const normalized = String(category ?? '').trim().toLowerCase();
  if (!normalized) return false;
  const keywords = ['yemek', 'restoran', 'restaurant', 'food', 'kafe', 'cafe',
    'kafeterya', 'lokanta', 'kebap', 'kebab', 'döner', 'doner', 'pide',
    'lahmacun', 'pastane', 'pastahane', 'fast food', 'fastfood', 'yiyecek',
    'içecek', 'mutfak', 'büfe', 'bufe', 'pizza', 'burger', 'sushi',
    'steakhouse', 'balık', 'balik', 'tatlı', 'tatli', 'kahve', 'coffee',
    'çay', 'cay'];
  return keywords.some((keyword) => normalized.includes(keyword));
}

function memberIdOf(body: { id?: unknown }) {
  return typeof body.id === 'string' ? body.id.trim() : '';
}

async function findAuthUserByEmail(email: string) {
  const url = `${Deno.env.get('SUPABASE_URL')}/auth/v1/admin/users?filter=${encodeURIComponent(email)}`;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${key}`, apikey: key },
  });
  if (!response.ok) return null;
  const body = await response.json();
  const users = Array.isArray(body?.users) ? body.users : [];
  return users.find((row: { email?: string }) =>
    String(row.email ?? '').trim().toLowerCase() === email) ?? null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return reply({ ok: false, message: 'POST required' }, 405);
  try {
    const { user, serviceClient } = await getAuthedContext(req);
    const body = await req.json();
    // Policy: no forced first-login change; staff never set passwords. Owner only (below).
    if (body.operation === 'clear_password_change' || body.operation === 'change_staff_password') {
      return reply({ ok: false, message: 'Personel şifresini yalnız işletme sahibi belirleyebilir.' }, 403);
    }
    const { data: store, error: storeError } = await serviceClient.from('stores')
      .select('seller_id, category').eq('seller_id', user.id).maybeSingle();
    const ownerStoreId = !storeError && store ? String(store.seller_id) : '';
    let storeId = ownerStoreId;
    let ceiling = allowed;
    if (!storeId) {
      const { data: actorRows, error: actorError } = await serviceClient.from('store_sub_admins')
        .select('store_id,permissions,status,staff_role')
        .eq('auth_user_id', user.id)
        .eq('status', 'active');
      const actors = Array.isArray(actorRows) ? actorRows : [];
      const actor = actors.length === 1 ? actors[0] : null;
      const held = new Set(Array.isArray(actor?.permissions)
        ? actor.permissions.filter((name: unknown) => typeof name === 'string')
        : []);
      if (actorError || !actor || actor.staff_role !== 'sub_admin' || !held.has('manageStaff')) {
        return reply({ ok: false, message: 'Yalnız işletme sahibi veya personel yetkisi olan alt yönetici personel yönetebilir.' }, 403);
      }
      storeId = String(actor.store_id ?? '');
      ceiling = new Set([...held].filter((name) => allowed.has(name) && name !== 'manageStoreProfile'));
    }
    if (!storeId) return reply({ ok: false, message: 'Yalnız işletme sahibi personel yönetebilir.' }, 403);
    const { data: storeProfile } = ownerStoreId
      ? { data: store }
      : await serviceClient.from('stores').select('category').eq('seller_id', storeId).maybeSingle();
    const foodStore = isFoodStoreCategory(storeProfile?.category);
    if (typeof body.store_id === 'string' && body.store_id !== storeId) {
      return reply({ ok: false, message: 'Başka işletmenin personeli değiştirilemez.' }, 403);
    }

    if (body.operation === 'list_branches') {
      // Read-only. The caller is already limited to its own store above, so a
      // sub-admin with manageStaff sees only that store's active branches.
      const { data: branchRows, error: branchesError } = await serviceClient.from('store_branches')
        .select('id,name,status').eq('store_id', storeId).eq('status', 'active');
      if (branchesError) return reply({ ok: false, message: 'Şubeler okunamadı.' }, 500);
      return reply({ ok: true, branches: Array.isArray(branchRows) ? branchRows : [] });
    }
    if (body.operation === 'activate' || body.operation === 'deactivate') {
      // Policy: only the verified owner gives access back. A sub-admin, even with manageStaff, is refused.
      if (body.operation === 'activate' && !ownerStoreId) {
        return reply({ ok: false, message: 'Personeli yalnız işletme sahibi yeniden etkinleştirebilir.' }, 403);
      }
      const memberId = memberIdOf(body);
      if (!memberId) return reply({ ok: false, message: 'Geçersiz personel kimliği.' }, 400);
      const { data: member, error: memberError } = await serviceClient.from('store_sub_admins')
        .select('id,auth_user_id,permissions,status')
        .eq('store_id', storeId).eq('id', memberId).maybeSingle();
      if (memberError || !member) return reply({ ok: false, message: 'Personel kaydı bulunamadı.' }, 404);
      if (member.auth_user_id && member.auth_user_id === user.id) {
        return reply({ ok: false, message: 'Kendi hesabınız silinemez.' }, 403);
      }
      if (body.operation === 'activate' && !member.auth_user_id) {
        return reply({ ok: false, message: 'Bu eski davet kaydına bağlı hesap yok. Personeli yeniden oluşturun.' }, 409);
      }
      if (body.operation === 'deactivate' && !ownerStoreId) {
        const { data: managers } = await serviceClient.from('store_sub_admins')
          .select('id,permissions').eq('store_id', storeId).eq('status', 'active');
        const activeManagers = (Array.isArray(managers) ? managers : []).filter((row) =>
          Array.isArray(row.permissions) && row.permissions.includes('manageStaff'));
        if (activeManagers.length <= 1 && activeManagers.some((row) => row.id === memberId)) {
          return reply({ ok: false, message: 'Son personel yöneticisi kaldırılamaz.' }, 403);
        }
      }
      const nextStatus = body.operation === 'activate' ? 'active' : 'inactive';
      const { data, error } = await serviceClient.from('store_sub_admins')
        .update({ status: nextStatus }).eq('store_id', storeId).eq('id', memberId)
        .select('id').single();
      if (error || !data) {
        return reply({
          ok: false,
          message: body.operation === 'activate'
            ? 'Personel aktifleştirilemedi.'
            : 'Personel pasifleştirilemedi.',
        }, 400);
      }
      return reply({ ok: true });
    }
    if (body.operation === 'delete') {
      const memberId = memberIdOf(body);
      if (!memberId) return reply({ ok: false, message: 'Geçersiz personel kimliği.' }, 400);
      const { data: member, error: memberLookupError } = await serviceClient.from('store_sub_admins')
        .select('id,auth_user_id,status').eq('store_id', storeId).eq('id', memberId).maybeSingle();
      if (memberLookupError || !member) return reply({ ok: false, message: 'Personel kaydı bulunamadı.' }, 404);
      if (member.auth_user_id && member.auth_user_id === user.id) {
        return reply({ ok: false, message: 'Kendi hesabınız silinemez.' }, 403);
      }
      if (!ownerStoreId) {
        const { data: managers } = await serviceClient.from('store_sub_admins')
          .select('id,permissions').eq('store_id', storeId).eq('status', 'active');
        const activeManagers = (Array.isArray(managers) ? managers : []).filter((row) =>
          Array.isArray(row.permissions) && row.permissions.includes('manageStaff'));
        if (activeManagers.length <= 1 && activeManagers.some((row) => row.id === memberId)) {
          return reply({ ok: false, message: 'Son personel yöneticisi kaldırılamaz.' }, 403);
        }
      }
      const authId = member.auth_user_id;
      const { error: deleteError } = await serviceClient.from('store_sub_admins')
        .delete().eq('store_id', storeId).eq('id', member.id);
      if (deleteError) return reply({ ok: false, message: 'Personel kaydı silinemedi.' }, 400);
      if (!authId) return reply({ ok: true, email_sent: false, auth_removed: false });
      const { count, error: otherError } = await serviceClient.from('store_sub_admins')
        .select('id', { count: 'exact', head: true }).eq('auth_user_id', authId);
      if (otherError) return reply({ ok: false, message: 'Kayıt silindi; diğer üyelikler doğrulanamadı.' }, 500);
      if ((count ?? 0) > 0) return reply({ ok: true, email_sent: false, auth_removed: false });
      const { data: profile, error: profileError } = await serviceClient.from('users')
        .select('id').eq('id', authId).maybeSingle();
      if (profileError || profile) return reply({ ok: true, email_sent: false, auth_removed: false });
      const { error: authDeleteError } = await serviceClient.auth.admin.deleteUser(authId);
      if (authDeleteError) {
        return reply({ ok: false, message: 'Personel kaydı silindi. Auth hesabı silinemedi; sipariş geçmişi duruyor.' }, 500);
      }
      return reply({ ok: true, email_sent: false, auth_removed: true });
    }
    if (body.operation === 'set_temporary_password') {
      // Owner only: a sub-admin with manageStaff is refused here and again in the RPC.
      if (!ownerStoreId) {
        return reply({ ok: false, message: 'Personel şifresini yalnız işletme sahibi belirleyebilir.' }, 403);
      }
      const memberId = memberIdOf(body);
      const password = typeof body.password === 'string' ? body.password : '';
      if (!memberId || password.length < 8 || password.length > 128) {
        return reply({ ok: false, message: 'Geçerli personel ve en az 8 karakterlik şifre gerekli.' }, 400);
      }
      const { error: setError } = await serviceClient.rpc('owner_set_staff_password', {
        p_owner_id: user.id, p_member_id: memberId, p_password: password,
      });
      if (setError) {
        const code = String(setError.code ?? '');
        if (code === 'P0002' || code === '22P02') {
          return reply({ ok: false, message: 'Personel kaydı bulunamadı.' }, 404);
        }
        if (code === '42501') {
          return reply({ ok: false, message: 'Personel şifresini yalnız işletme sahibi belirleyebilir.' }, 403);
        }
        if (code === '23505' || code === '23514') {
          return reply({ ok: false, message: 'Bu hesap bu işletmenin yönetilen personeli değil. Şifre değiştirilmedi.' }, 409);
        }
        if (code === '22023') {
          return reply({ ok: false, message: 'Geçerli personel ve en az 8 karakterlik şifre gerekli.' }, 400);
        }
        return reply({ ok: false, message: 'Şifre kaydedilemedi.' }, 500);
      }
      return reply({ ok: true, password_unchanged: false });
    }
    const permissions = body.permissions;
    if (!Array.isArray(permissions) || !permissions.every((p) => allowed.has(p))) {
      return reply({ ok: false, message: 'Geçersiz yetki listesi.' }, 400);
    }
    if (!foodStore && permissions.some((name) => restaurantOnly.has(name))) {
      return reply({ ok: false, message: 'Bu işletme türünde restoran yetkileri verilemez.' }, 403);
    }
    if (!permissions.every((name) => ceiling.has(name))) {
      return reply({ ok: false, message: 'Sahip olmadığınız yetki verilemez.' }, 403);
    }
    if (body.operation === 'permissions') {
      const memberId = memberIdOf(body);
      if (!memberId) return reply({ ok: false, message: 'Geçersiz personel kimliği.' }, 400);
      const { data: current, error: currentError } = await serviceClient.from('store_sub_admins')
        .select('id,permissions,staff_role,branch_id,auth_user_id')
        .eq('store_id', storeId).eq('id', memberId).maybeSingle();
      if (currentError || !current) return reply({ ok: false, message: 'Personel kaydı bulunamadı.' }, 400);
      if (!ownerStoreId && current.auth_user_id && current.auth_user_id === user.id) {
        return reply({ ok: false, message: 'Personel kendi yetkisini değiştiremez.' }, 403);
      }
      const revoked = body.revoked_permissions;
      if (revoked != null && (!Array.isArray(revoked) || !revoked.every((name: unknown) =>
        typeof name === 'string' && keptWhenClientOmits.has(name)))) {
        return reply({ ok: false, message: 'Yalnız kayıtlı ek yetkiler açıkça kaldırılabilir.' }, 400);
      }
      // The panel always echoes the current role and branch. Only a value that
      // differs from the stored one is a change request (owner-only below).
      const wantsRole = typeof body.staff_role === 'string' && body.staff_role.length > 0 &&
        body.staff_role !== current.staff_role;
      const wantsBranch = typeof body.branch_id === 'string' && body.branch_id.length > 0 &&
        body.branch_id !== current.branch_id;
      if ((wantsRole || wantsBranch) && !ownerStoreId) {
        return reply({ ok: false, message: 'Rol ve şube yalnızca işletme sahibi tarafından değiştirilebilir.' }, 403);
      }
      let nextRole = typeof current.staff_role === 'string' ? current.staff_role : '';
      let nextBranch = typeof current.branch_id === 'string' ? current.branch_id : '';
      if (wantsRole) {
        if (!['waiter', 'sub_admin'].includes(body.staff_role)) {
          return reply({ ok: false, message: 'Geçersiz personel rolü.' }, 400);
        }
        if (!foodStore && body.staff_role === 'waiter') {
          return reply({ ok: false, message: 'Bu işletme türünde garson rolü açılamaz.' }, 400);
        }
        if (current.auth_user_id && current.auth_user_id === user.id) {
          return reply({ ok: false, message: 'Personel kendi rolünü değiştiremez.' }, 403);
        }
        nextRole = body.staff_role;
      }
      if (wantsBranch) {
        const { data: branch, error: branchError } = await serviceClient.from('store_branches')
          .select('id').eq('store_id', storeId).eq('id', body.branch_id).eq('status', 'active').maybeSingle();
        if (branchError || !branch) {
          return reply({ ok: false, message: 'İşletmeye ait aktif şube seçin.' }, 400);
        }
        nextBranch = branch.id;
      }
      const nextPermissions = permissionsFromLegacyClient(
        permissions, current.permissions, foodStore, revoked);
      const roleChanges = wantsRole && body.staff_role !== current.staff_role;
      if (roleChanges && nextRole === 'waiter' && nextPermissions.some((name) => !waiterCeiling.has(name))) {
        return reply({ ok: false, message: 'Garson rolü bu yetkileri taşıyamaz.' }, 403);
      }
      const patch: Record<string, unknown> = {
        permissions: nextPermissions.filter((name) => triggerPermissions.has(name)),
      };
      if (wantsRole) patch.staff_role = nextRole;
      if (wantsBranch) patch.branch_id = nextBranch;
      const title = cleanTitle(body.job_title);
      const pages = cleanPages(body.visible_modules);
      const columnsReady = title || pages ? await profileColumns(serviceClient) : false;
      if (columnsReady && title) patch.job_title = title;
      if (columnsReady && pages) patch.visible_modules = pages;
      const { data, error } = await serviceClient.from('store_sub_admins')
        .update(patch).eq('store_id', storeId).eq('id', memberId)
        .select('id').single();
      return error || !data
        ? reply({ ok: false, message: 'Yetkiler kaydedilemedi.' }, 400)
        : reply({
          ok: true,
          job_title_persisted: Boolean(patch.job_title),
          pages_persisted: Array.isArray(patch.visible_modules),
        });
    }
    if (body.operation !== 'create') return reply({ ok: false, message: 'Geçersiz işlem.' }, 400);
    // Policy: only the verified owner creates a staff account or links an old one again.
    if (!ownerStoreId) {
      return reply({ ok: false, message: 'Personel hesabını yalnız işletme sahibi oluşturabilir veya yeniden bağlayabilir.' }, 403);
    }
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const role = body.staff_role;
    const requestId = typeof body.request_id === 'string' ? body.request_id : '';
    if (!name || name.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
      || password.length < 8 || password.length > 128
      || !['waiter', 'sub_admin'].includes(role) || !requestId || requestId.length > 150) {
      return reply({ ok: false, message: 'Ad, geçerli e-posta, rol ve en az 8 karakterlik geçici şifre gereklidir.' }, 400);
    }
    if (!foodStore && role === 'waiter') {
      return reply({ ok: false, message: 'Bu işletme türünde garson rolü açılamaz.' }, 400);
    }
    const { data: branch, error: branchError } = await serviceClient.from('store_branches')
      .select('id').eq('store_id', storeId).eq('id', body.branch_id).eq('status', 'active').maybeSingle();
    if (branchError || !branch) return reply({ ok: false, message: 'İşletmeye ait aktif şube seçin.' }, 400);
    const { data: existing, error: lookupError } = await serviceClient.from('store_sub_admins')
      .select('id,email,staff_role,branch_id,status').eq('store_id', storeId).eq('creation_request_id', requestId).maybeSingle();
    if (lookupError) return reply({ ok: false, message: 'Personel migration henüz uygulanmamış olabilir.' }, 503);
    if (existing) {
      if (existing.email !== email || existing.staff_role !== role || existing.branch_id !== branch.id || existing.status !== 'active') {
        return reply({ ok: false, message: 'Bu istek kimliği farklı veya pasif bir hesaba ait.' }, 409);
      }
      return reply({ ok: true, id: existing.id, email_sent: false, replay: true });
    }
    const { data: invitedRows, error: invitedError } = await serviceClient.from('store_sub_admins')
      .select('id,auth_user_id,email,status')
      .eq('store_id', storeId)
      .eq('status', 'invited');
    if (invitedError) return reply({ ok: false, message: 'Eski personel kayıtları okunamadı.' }, 503);
    const invited = (Array.isArray(invitedRows) ? invitedRows : []).filter((row) =>
      String(row.email ?? '').trim().toLowerCase() === email && !row.auth_user_id);
    if (invited.length > 1) {
      return reply({ ok: false, message: 'Aynı e-posta için birden fazla davet kaydı var. Önce fazlalıkları silin.' }, 409);
    }
    const title = cleanTitle(body.job_title);
    const pages = cleanPages(body.visible_modules);
    const columnsReady = await profileColumns(serviceClient);
    const safePermissions = permissions.filter((name: string) => triggerPermissions.has(name));
    const membershipFor = (authId: string) => ({
      auth_user_id: authId, display_name: name, email, staff_role: role,
      branch_id: branch.id, permissions: safePermissions, status: 'active',
      creation_request_id: requestId,
      ...(columnsReady && title ? { job_title: title } : {}),
      ...(columnsReady && pages ? { visible_modules: pages } : {}),
    });
    const saveMembership = async (authId: string, invitedRow: { id: string } | null) => {
      const membership = membershipFor(authId);
      const memberQuery = invitedRow
        ? serviceClient.from('store_sub_admins').update(membership)
          .eq('store_id', storeId).eq('id', invitedRow.id).eq('status', 'invited')
        : serviceClient.from('store_sub_admins').insert({ ...membership, store_id: storeId });
      const { data: member, error: memberError } = await memberQuery.select('id').single();
      if (memberError || !member) {
        const text = String(memberError?.message ?? '');
        const safe = ['Şube bu işletmeye ait değil.', 'Geçersiz yetki.', 'Auth kimliği uyuşmuyor.']
          .find((item) => text.includes(item));
        throw new Error(safe ?? 'Üyelik kaydedilemedi.');
      }
      return member.id;
    };
    // Server-only Auth administration. The caller is the owner (checked above).
    const { data: created, error: authError } = await serviceClient.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: { display_name: name },
      app_metadata: { managed_restaurant_staff: true, must_change_password: false, provisioned_by_store_id: storeId },
    });
    if (authError || !created?.user) {
      const listed = await findAuthUserByEmail(email);
      if (!listed?.id) {
        const authMessage = String(authError?.message ?? '');
        const policyRejected = /password|weak|length|karakter|policy/i.test(authMessage);
        return reply({
          ok: false,
          linked: false,
          message: policyRejected
            ? 'Supabase Auth şifre politikası bu şifreyi reddetti. Politika değiştirilmeden daha kısa şifre kaydedilemez.'
            : 'Auth hesabı oluşturulamadı. E-posta kullanımda olabilir veya şifre kuralları sağlanmıyor.',
        }, 409);
      }
      const { data: lookedUp, error: lookupUserError } = await serviceClient.auth.admin.getUserById(listed.id);
      const existingUser = lookedUp?.user ?? listed;
      if (lookupUserError || !existingUser?.id) {
        return reply({ ok: false, linked: false, message: 'Mevcut Auth hesabı doğrulanamadı. Kayıt değiştirilmedi.' }, 503);
      }
      const { data: membershipRows, error: membershipLookupError } = await serviceClient
        .from('store_sub_admins').select('id,store_id,status').eq('auth_user_id', existingUser.id);
      if (membershipLookupError) {
        return reply({ ok: false, message: 'Mevcut üyelikler doğrulanamadı. Kayıt değiştirilmedi.' }, 503);
      }
      const memberships = Array.isArray(membershipRows) ? membershipRows : [];
      if (memberships.some((row) => row.store_id !== storeId)) {
        return reply({
          ok: false,
          linked: false,
          message: 'Bu e-posta başka bir işletmenin personel hesabında kayıtlı. O hesaba dokunulmadı.',
        }, 409);
      }
      const own = memberships.find((row) => row.store_id === storeId);
      if (own) {
        return reply({ ok: true, id: own.id, email_sent: false, replay: true, password_unchanged: true });
      }
      const { data: ownedStore } = await serviceClient.from('stores')
        .select('seller_id').eq('seller_id', existingUser.id).maybeSingle();
      const provisionedBy = existingUser.app_metadata?.provisioned_by_store_id;
      const managed = existingUser.app_metadata?.managed_restaurant_staff === true;
      const proof = managed === true
        && typeof provisionedBy === 'string'
        && provisionedBy === storeId
        && !ownedStore;
      if (!proof || body.confirm_link !== true) {
        return reply({
          ok: false,
          linked: false,
          link_available: proof,
          password_unchanged: true,
          message: proof
            ? 'Bu hesap bu işletme için oluşturulmuş. Üyelik ancak açık onayla bağlanır. Şifre değiştirilmedi ve hesap silinmedi.'
            : 'E-posta eşleşmesi, profil türü veya başka işletmede üyelik olmaması hesabı bağlamak için yeterli değil. Şifre değiştirilmedi ve hesap silinmedi.',
        }, 409);
      }
      try {
        const id = await saveMembership(existingUser.id, invited.length === 1 ? invited[0] : null);
        return reply({
          ok: true,
          id,
          email_sent: false,
          password_unchanged: true,
          linked_existing_auth: true,
          message: 'İşletmenin oluşturduğu hesap, onay üzerine bağlandı. Yazdığınız şifre uygulanmadı.',
        });
      } catch (error) {
        const reason = error instanceof Error ? error.message : 'Üyelik kaydedilemedi.';
        return reply({ ok: false, linked: false, message: reason }, 500);
      }
    }
    const authId = created.user.id;
    try {
      const { error: profileError } = await serviceClient.from('users').upsert({
        id: authId, email, display_name: name, role: 'waiter',
      });
      if (profileError) throw new Error('Personel profili kaydedilemedi.');
      const id = await saveMembership(authId, invited.length === 1 ? invited[0] : null);
      return reply({ ok: true, id, email_sent: false });
    } catch (error) {
      // Compensate only this newly created account; never alter existing users.
      await serviceClient.from('store_sub_admins').delete().eq('auth_user_id', authId).eq('store_id', storeId);
      const { error: profileDeleteError } = await serviceClient.from('users').delete().eq('id', authId);
      const { data: stillThere } = await serviceClient.from('users').select('id').eq('id', authId).maybeSingle();
      if (profileDeleteError || stillThere) {
        return reply({
          ok: false,
          orphan_detected: true,
          message: 'Üyelik kaydedilemedi. Yeni hesap profili durduğu için Auth silinmedi.',
        }, 500);
      }
      const { error: cleanupError } = await serviceClient.auth.admin.deleteUser(authId);
      const reason = error instanceof Error ? error.message : 'Üyelik kaydedilemedi.';
      return reply({ ok: false, message: cleanupError
        ? 'Üyelik kaydedilemedi; yeni Auth hesabı için sunucu temizliği gerekiyor.'
        : `Üyelik kaydedilemedi; yeni Auth hesabı geri alındı. ${reason}` }, 500);
    }
  } catch {
    return reply({ ok: false, message: 'Oturum doğrulanamadı veya işlem tamamlanamadı.' }, 401);
  }
});
