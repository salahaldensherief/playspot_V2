export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});
const normalize = value => String(value ?? '').trim().toLowerCase()
  .replace(/[ًٌٍَُِّْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه');

// Authentication and database writes are injected; geocoding is optional
// enrichment and must never prevent saving valid coordinates for the caller.
export function createLocationHandler({ authenticate, geocode, loadCities, saveLocation, report = () => {} }) {
  return async request => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    const authorization = request.headers.get('Authorization') ?? '';
    if (!/^Bearer\s+\S+$/i.test(authorization)) return json({ error: 'unauthorized' }, 401);
    let user;
    try { user = await authenticate(authorization); } catch { return json({ error: 'authentication_unavailable' }, 503); }
    if (!user?.id) return json({ error: 'unauthorized' }, 401);
    let body;
    try { body = await request.json(); } catch { return json({ error: 'invalid_request' }, 400); }
    const { latitude, longitude } = body ?? {};
    if (typeof latitude !== 'number' || typeof longitude !== 'number' ||
        !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return json({ error: 'invalid_coordinates' }, 400);
    }
    let city = null;
    try {
      const detected = normalize(await geocode(latitude, longitude));
      if (detected) {
        const cities = await loadCities(authorization);
        // Empty names and substring matches can select an unrelated city.
        city = cities.find(item => [item.name_ar, item.name_en].some(name => {
          const candidate = normalize(name);
          return candidate.length > 0 && candidate === detected;
        })) ?? null;
      }
    } catch { report('location_enrichment_unavailable'); }
    const update = { latitude, longitude, updated_at: new Date().toISOString() };
    if (city) update.city_id = city.id;
    try {
      const saved = await saveLocation(authorization, user.id, update);
      if (!saved) return json({ error: 'location_update_failed' }, 500);
    } catch { report('location_update_failed'); return json({ error: 'location_update_failed' }, 500); }
    return json({ success: true, latitude, longitude, city_id: city?.id ?? null,
      city_name_ar: city?.name_ar ?? null, city_name_en: city?.name_en ?? null });
  };
}

export async function reverseGeocode(latitude, longitude, fetcher = fetch) {
  const urls = [
    `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&lat=${latitude}&lon=${longitude}&accept-language=ar,en`,
    `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${latitude}&longitude=${longitude}&localityLanguage=ar`,
  ];
  for (const url of urls) {
    try {
      const response = await fetcher(url, { signal: AbortSignal.timeout(3000),
        headers: { 'User-Agent': 'PlaySpot-Location-Service/1.2', Accept: 'application/json' } });
      if (!response.ok) continue;
      const data = await response.json();
      const address = data.address ?? {};
      const city = address.city ?? address.town ?? address.municipality ?? address.village ??
        data.city ?? data.locality ?? data.principalSubdivision;
      if (typeof city === 'string' && city.trim()) return city;
    } catch { /* Try the secondary geocoder; coordinates remain usable. */ }
  }
  return null;
}
