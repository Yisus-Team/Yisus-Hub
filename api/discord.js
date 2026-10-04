const DEV_IDS = [
  '1500676999247823039',
  '1464804782567850075',
  '1480715251107500064'
];

const LOOKUP_BASE = 'https://discord-lookup.lookupbotdc.workers.dev/search/';
const CACHE_SECONDS = 3 * 60 * 60;

function discordCdnUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 'cdn.discordapp.com'
      ? url.href
      : null;
  } catch {
    return null;
  }
}

async function fetchProfile(id) {
  try {
    const response = await fetch(LOOKUP_BASE + encodeURIComponent(id), {
      headers: { Accept: 'application/json' }
    });

    if (!response.ok) return null;

    const data = await response.json();
    const user = data.user || {};
    if (user.id !== id) return null;

    return {
      id,
      name: user.global_name || user.username || 'Usuario de Discord',
      avatar: discordCdnUrl(data.avatar_url || data.avatar_url_gif),
      banner: discordCdnUrl(data.banner_url_gif || data.banner_url)
    };
  } catch {
    return null;
  }
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const profiles = (await Promise.all(DEV_IDS.map(fetchProfile))).filter(Boolean);

  if (!profiles.length) {
    res.setHeader('Cache-Control', 'no-store');
    return res.status(502).json({ error: 'No se pudieron cargar los perfiles de Discord.' });
  }

  const cdnCache = `public, max-age=${CACHE_SECONDS}, stale-while-revalidate=300, stale-if-error=86400`;
  res.setHeader('Cache-Control', 'public, max-age=0, must-revalidate');
  res.setHeader('CDN-Cache-Control', cdnCache);
  res.setHeader('Vercel-CDN-Cache-Control', cdnCache);

  return res.status(200).json({ profiles });
};
