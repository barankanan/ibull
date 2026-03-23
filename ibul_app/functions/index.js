const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { createClient } = require("@supabase/supabase-js");

admin.initializeApp();

const runtimeConfig = functions.config ? functions.config() : {};
const SUPABASE_URL =
  process.env.SUPABASE_URL || runtimeConfig?.supabase?.url || "";
const SUPABASE_SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY || runtimeConfig?.supabase?.service_role_key || "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  logger.warn("SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY tanimli degil.");
}

const supabase = createClient(SUPABASE_URL || "", SUPABASE_SERVICE_ROLE_KEY || "");

function normalize(value) {
  return (value || "")
    .toLowerCase()
    .trim()
    .replaceAll("ı", "i")
    .replaceAll("ş", "s")
    .replaceAll("ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("ö", "o")
    .replaceAll("ç", "c")
    .replace(/\s+/g, " ");
}

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function buildBody(interestType, term, storeName) {
  if (interestType === "favorite") {
    return `Begendigin urun "${term}", "${storeName}" magazasinda mevcut. Gormek ister misin?`;
  }
  if (interestType === "cart") {
    return `Sepete ekledigin urun "${term}", "${storeName}" magazasinda mevcut. Gormek ister misin?`;
  }
  if (interestType === "saved") {
    return `Kaydettigin urun "${term}", "${storeName}" magazasinda mevcut. Gormek ister misin?`;
  }
  return `Aradigin urun "${term}", "${storeName}" magazasinda mevcut. Gormek ister misin?`;
}

exports.sendNearbyInterestPush = onSchedule(
  {
    schedule: "*/1 * * * *",
    timeZone: "Europe/Istanbul",
    region: "europe-west1",
  },
  async () => {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      logger.error("Supabase env eksik.");
      return;
    }

    const nowIso = new Date().toISOString();
    const locationFreshSince = new Date(Date.now() - 20 * 60 * 1000).toISOString();
    const [{ data: locations, error: locErr }, { data: stores, error: storeErr }, { data: products, error: prodErr }] =
      await Promise.all([
        supabase
          .from("user_live_locations")
          .select("user_id, latitude, longitude, updated_at")
          .gte("updated_at", locationFreshSince)
          .limit(500),
        supabase
          .from("stores")
          .select("seller_id, business_name, store_lat, store_lng, logo_url")
          .not("store_lat", "is", null)
          .not("store_lng", "is", null),
        supabase.from("products").select("seller_id, name, brand").not("seller_id", "is", null),
      ]);

    if (locErr || storeErr || prodErr) {
      logger.error("Veri cekim hatasi", { locErr, storeErr, prodErr });
      return;
    }

    const storesSafe = stores || [];
    const productsSafe = products || [];

    const productsBySeller = new Map();
    for (const p of productsSafe) {
      const sellerId = String(p.seller_id || "");
      if (!sellerId) continue;
      if (!productsBySeller.has(sellerId)) productsBySeller.set(sellerId, []);
      productsBySeller.get(sellerId).push(normalize(`${p.name || ""} ${p.brand || ""}`));
    }

    let sentCount = 0;
    for (const loc of locations || []) {
      const userId = loc.user_id;
      if (!userId) continue;

      const [{ data: tokens }, { data: interests }] = await Promise.all([
        supabase
          .from("push_device_tokens")
          .select("token")
          .eq("user_id", userId)
          .eq("is_active", true),
        supabase
          .from("user_product_interests")
          .select("interest_type, term")
          .eq("user_id", userId)
          .limit(150),
      ]);

      if (!tokens || tokens.length === 0 || !interests || interests.length === 0) {
        continue;
      }

      let selectedPayload = null;
      for (const s of storesSafe) {
        const dMeters = haversineMeters(
          Number(loc.latitude),
          Number(loc.longitude),
          Number(s.store_lat),
          Number(s.store_lng),
        );
        if (dMeters > 100) continue;

        const sellerId = String(s.seller_id || "");
        const storeText = productsBySeller.get(sellerId) || [];
        if (storeText.length === 0) continue;

        for (const i of interests) {
          const term = normalize(i.term || "");
          if (!term || term.length < 2) continue;
          const matched = storeText.some((t) => t.includes(term));
          if (!matched) continue;

          const { data: recent } = await supabase
            .from("push_notification_logs")
            .select("id")
            .eq("user_id", userId)
            .eq("seller_id", sellerId)
            .eq("interest_type", i.interest_type || "searched")
            .eq("term", i.term)
            .limit(1);

          if (recent && recent.length > 0) continue;

          selectedPayload = {
            sellerId,
            storeName: s.business_name || "Magaza",
            storeLogoUrl: s.logo_url || "",
            interestType: i.interest_type || "searched",
            term: i.term || "",
            distanceMeters: Math.round(dMeters),
          };
          break;
        }
        if (selectedPayload) break;
      }

      if (!selectedPayload) continue;

      const body = buildBody(
        selectedPayload.interestType,
        selectedPayload.term,
        selectedPayload.storeName,
      );

      for (const t of tokens) {
        const token = t.token;
        if (!token) continue;
        try {
          const messageId = await admin.messaging().send({
            token,
            notification: {
              title: selectedPayload.storeName,
              body,
            },
            data: {
              storeName: selectedPayload.storeName,
              sellerId: selectedPayload.sellerId,
              storeLogoUrl: selectedPayload.storeLogoUrl,
              interestType: selectedPayload.interestType,
              term: selectedPayload.term,
              initialStoreProductQuery: selectedPayload.term,
              sentAt: nowIso,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "ibul_nearby_store_channel",
                sound: "default",
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: {
                aps: {
                  sound: "default",
                  category: "nearby_store",
                },
              },
            },
          });

          await supabase.from("push_notification_logs").insert({
            user_id: userId,
            token,
            seller_id: selectedPayload.sellerId,
            store_name: selectedPayload.storeName,
            interest_type: selectedPayload.interestType,
            term: selectedPayload.term,
            distance_meters: selectedPayload.distanceMeters,
            payload: { messageId, body },
          });
          sentCount += 1;
        } catch (e) {
          logger.error("FCM gonderim hatasi", { userId, token, error: String(e) });
        }
      }
    }

    logger.info("Cron tamamlandi", { sentCount });
  },
);
