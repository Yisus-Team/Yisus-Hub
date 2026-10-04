const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
let kvClient = null;
let memoryStore = new Map();
const RESERVED_LUA = new Set(['verifier']);
try {
  const { kv } = require('@vercel/kv');
  kvClient = kv;
} catch (e) {
  kvClient = null;
}

const NONCE_TTL = 60;
const POW_DIFFICULTY = 2;
const POW_SUFFIX = '0'.repeat(POW_DIFFICULTY);

function getIp(req) {
  const xvff = req.headers['x-vercel-forwarded-for'];
  if (xvff) return xvff.split(',')[0].trim();
  const xff = req.headers['x-forwarded-for'];
  if (xff) return xff.split(',')[0].trim();
  if (req.headers['x-real-ip']) return req.headers['x-real-ip'];
  if (req.socket && req.socket.remoteAddress) return req.socket.remoteAddress;
  return '127.0.0.1';
}

function isBrowser(req) {
  if (req.headers['sec-fetch-mode'] || req.headers['sec-fetch-site'] || req.headers['sec-fetch-dest']) {
    return true;
  }
  const accept = String(req.headers['accept'] || '');
  const ua = String(req.headers['user-agent'] || '').toLowerCase();
  if (accept.includes('text/html') && (ua.includes('mozilla') || ua.includes('chrome') || ua.includes('safari'))) {
    return true;
  }
  return false;
}

function isBotUA(req) {
  const ua = String(req.headers['user-agent'] || '').toLowerCase();
  const botPatterns = [
    'python-requests', 'python-urllib', 'aiohttp', 'httpx',
    'curl/', 'wget/', 'axios/', 'got (https', 'node-fetch',
    'lune/', 'lune-std-net/',
    'go-http-client', 'java/', 'okhttp', 'request.js',
    'postmanruntime', 'insomnia', 'httpie', 'scrapy',
    'bot', 'crawler', 'spider', 'headless', 'phantom',
    'selenium', 'puppeteer', 'playwright', 'webdriver'
  ];
  for (const p of botPatterns) {
    if (ua.includes(p)) return true;
  }
  if (!ua || ua === '' || ua === '*') return true;
  return false;
}

function isValidJobId(j) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(j));
}

async function isBanned(ip) {
  const key = `sng_ban:${ip}`;
  try {
    const v = await kvClient?.get(key);
    if (v) return true;
  } catch {}
  const e = memoryStore.get(key);
  if (e && e.exp > Date.now()) return true;
  if (e && e.exp <= Date.now()) memoryStore.delete(key);
  return false;
}

async function setBanned(ip, ttlSeconds) {
  const key = `sng_ban:${ip}`;
  const ttl = ttlSeconds || 259200;
  try {
    await kvClient?.set(key, 1, { ex: ttl });
  } catch {}
  memoryStore.set(key, { exp: Date.now() + ttl * 1000 });
}

async function incInvalidPlaceCount(ip) {
  const key = `sng_invalid_place:${ip}`;
  let count = 0;
  try {
    const cur = await kvClient?.get(key);
    count = (Number(cur) || 0) + 1;
    await kvClient?.set(key, count, { ex: 86400 });
  } catch {
    const e = memoryStore.get(key);
    if (e && e.exp > Date.now()) count = (e.count || 0) + 1;
    else count = 1;
    memoryStore.set(key, { count, exp: Date.now() + 86400000 });
  }
  return count;
}

async function incInvalidProofCount(ip) {
  const key = `sng_invalid_proof:${ip}`;
  let count = 0;
  try {
    const cur = await kvClient?.get(key);
    count = (Number(cur) || 0) + 1;
    await kvClient?.set(key, count, { ex: 3600 });
  } catch {
    const e = memoryStore.get(key);
    if (e && e.exp > Date.now()) count = (e.count || 0) + 1;
    else count = 1;
    memoryStore.set(key, { count, exp: Date.now() + 3600000 });
  }
  return count;
}

async function issueNonce(ip) {
  const nonce = crypto.randomBytes(24).toString('hex');
  const key = `sng_nonce:${nonce}`;
  const data = { ip, ts: Date.now() };
  try {
    await kvClient?.set(key, JSON.stringify(data), { ex: NONCE_TTL });
  } catch {}
  memoryStore.set(key, { ip, ts: Date.now(), exp: Date.now() + NONCE_TTL * 1000 });
  return nonce;
}

async function consumeNonce(nonce, ip) {
  if (!nonce || typeof nonce !== 'string' || nonce.length < 16 || nonce.length > 128) {
    return false;
  }
  if (!/^[0-9a-f]+$/i.test(nonce)) return false;
  const key = `sng_nonce:${nonce}`;
  let data = null;
  try {
    const raw = await kvClient?.get(key);
    if (raw) {
      data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    }
  } catch {}
  if (!data) {
    const e = memoryStore.get(key);
    if (e && e.exp > Date.now()) data = e;
  }
  if (!data) return false;
  try { await kvClient?.del(key); } catch {}
  memoryStore.delete(key);
  if (data.ip !== ip) return false;
  return true;
}

async function isPlaceValid(placeId) {
  const pid = Number(placeId);
  if (!pid || pid === 0) return false;
  const cacheKey = `sng_place_cache:${pid}`;
  try {
    const cached = await kvClient?.get(cacheKey);
    if (cached === true || cached === 'valid' || cached === 1) return true;
    if (cached === false || cached === 'invalid' || cached === 0) return false;
  } catch {}
  const memCached = memoryStore.get(cacheKey);
  if (memCached && memCached.exp > Date.now()) {
    return !!memCached.data;
  }
  try {
    const res = await fetch(`https://apis.roblox.com/universes/v1/places/${pid}/universe`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });
    if (res.ok) {
      const data = await res.json();
      if (data && (data.universeId || data.universeID)) {
        try { await kvClient?.set(cacheKey, true, { ex: 86400 }); } catch {}
        memoryStore.set(cacheKey, { data: true, exp: Date.now() + 86400000 });
        return true;
      }
    }
    if (res.status === 404 || res.status === 400) {
      try { await kvClient?.set(cacheKey, false, { ex: 86400 }); } catch {}
      memoryStore.set(cacheKey, { data: false, exp: Date.now() + 86400000 });
      return false;
    }
  } catch {}
  try {
    const res2 = await fetch(`https://games.roblox.com/v1/games/multiget-place-details?placeIds=${pid}`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });
    if (res2.ok) {
      const data2 = await res2.json();
      if (Array.isArray(data2) && data2.length > 0 && data2[0].placeId) {
        try { await kvClient?.set(cacheKey, true, { ex: 86400 }); } catch {}
        memoryStore.set(cacheKey, { data: true, exp: Date.now() + 86400000 });
        return true;
      }
      if (Array.isArray(data2) && data2.length === 0) {
        try { await kvClient?.set(cacheKey, false, { ex: 86400 }); } catch {}
        memoryStore.set(cacheKey, { data: false, exp: Date.now() + 86400000 });
        return false;
      }
    }
  } catch {}
  return true;
}

async function getUniverseIdForPlace(placeId) {
  const pid = Number(placeId);
  if (!pid || pid === 0) return null;
  try {
    const res = await fetch(`https://apis.roblox.com/universes/v1/places/${pid}/universe`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });
    if (res.ok) {
      const data = await res.json();
      if (data && (data.universeId || data.universeID)) {
        return data.universeId || data.universeID;
      }
    }
  } catch {}
  return null;
}

async function doesUserExist(userId) {
  const uid = Number(userId);
  if (!uid || uid <= 0) return false;
  const cacheKey = `sng_user_cache:${uid}`;
  try {
    const cached = await kvClient?.get(cacheKey);
    if (cached === true || cached === 'valid' || cached === 1) return true;
    if (cached === false || cached === 'invalid' || cached === 0) return false;
  } catch {}
  const memCached = memoryStore.get(cacheKey);
  if (memCached && memCached.exp > Date.now()) {
    return !!memCached.data;
  }
  try {
    const res = await fetch(`https://users.roblox.com/v1/users/${uid}`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });
    if (res.ok) {
      const data = await res.json();
      if (data && data.id) {
        try { await kvClient?.set(cacheKey, true, { ex: 3600 }); } catch {}
        memoryStore.set(cacheKey, { data: true, exp: Date.now() + 3600000 });
        return true;
      }
    }
    if (res.status === 404) {
      try { await kvClient?.set(cacheKey, false, { ex: 3600 }); } catch {}
      memoryStore.set(cacheKey, { data: false, exp: Date.now() + 3600000 });
      return false;
    }
  } catch {}
  return true;
}

function findLuaScript(baseDir, cleanName) {
  if (!fs.existsSync(baseDir)) return null;
  let resolvedBase;
  try {
    resolvedBase = fs.realpathSync(baseDir);
  } catch {
    return null;
  }

  const candidates = [
    path.join(resolvedBase, `${cleanName}.lua`),
    ...fs.readdirSync(resolvedBase)
      .filter(file => file.toLowerCase() === `${cleanName}.lua`)
      .map(file => path.join(resolvedBase, file))
  ];

  for (const candidate of candidates) {
    if (!fs.existsSync(candidate)) continue;
    try {
      const resolvedFile = fs.realpathSync(candidate);
      const relative = path.relative(resolvedBase, resolvedFile);
      if (relative && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative)) {
        return resolvedFile;
      }
    } catch {}
  }
  return null;
}

function buildPowMessage(nonce, jobId, placeId, userId, gameId, counter) {
  return nonce + String(jobId) + String(placeId) + String(userId) + String(gameId) + String(counter);
}

function computePowHash(nonce, jobId, placeId, userId, gameId, counter) {
  const msg = buildPowMessage(nonce, jobId, placeId, userId, gameId, counter);
  return crypto.createHash('sha256').update(msg).digest('hex');
}

function validatePow(nonce, jobId, placeId, userId, gameId, counter) {
  if (typeof counter !== 'number' || counter < 0 || counter > 10000000) return false;
  const hash = computePowHash(nonce, jobId, placeId, userId, gameId, counter);
  if (hash.slice(-POW_DIFFICULTY) !== POW_SUFFIX) return false;
  return true;
}

function setScriptCacheHeaders(res) {
  const value = 'public, max-age=14400, s-maxage=14400, stale-while-revalidate=300';
  res.setHeader('Cache-Control', value);
  res.setHeader('CDN-Cache-Control', value);
  res.setHeader('Vercel-CDN-Cache-Control', value);
}

function readLuaScript(scriptPath) {
  return fs.readFileSync(scriptPath, 'utf8');
}

module.exports = async function handler(req, res) {
  const ip = getIp(req);
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (await isBanned(ip)) {
    return res.status(403).json({ error: 'Banned' });
  }
  if (isBrowser(req)) {
    res.setHeader('Location', '/protection');
    return res.status(302).end();
  }
  const botDetected = isBotUA(req);

  if (req.method === 'POST') {
    const rlKey = `sng_rl:${ip}`;
    let count = 0;
    if (kvClient) {
      try {
        count = (await kvClient.get(rlKey)) || 0;
      } catch {
        const e = memoryStore.get(rlKey);
        count = e && e.exp > Date.now() ? e.count : 0;
      }
    } else {
      const e = memoryStore.get(rlKey);
      count = e && e.exp > Date.now() ? e.count : 0;
    }
    if (count >= 8) return res.status(429).json({ error: 'Rate limited' });
    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch { body = {}; }
    }
    const i = body.i;
    const j = body.j;
    const g = body.g;
    const p = body.p;
    const u = body.u;
    const uni = body.uni ?? body.universeId ?? body.gameId ?? body.univ ?? null;
    const nonce = body.n;
    const powCounter = body.pw;
    if (!j || !isValidJobId(j) || typeof i !== 'number' || i <= 0 || !g) {
      return res.status(400).json({ error: 'Invalid' });
    }
    if (typeof p !== 'number' || typeof u !== 'string') {
      return res.status(400).json({ error: 'Invalid payload' });
    }
    if (p === 0 || uni === 0) {
      return res.status(403).json({ error: 'Studio not allowed' });
    }

    if (!nonce || powCounter === undefined || powCounter === null) {
      if (botDetected) {
        return res.status(403).json({ error: 'Blocked' });
      }
      return res.status(403).json({ error: 'Missing proof' });
    }

    const nonceOk = await consumeNonce(nonce, ip);
    if (!nonceOk) {
      if (botDetected) {
        return res.status(403).json({ error: 'Blocked' });
      }
      const ic = await incInvalidProofCount(ip);
      return res.status(403).json({ error: 'Invalid nonce', c: ic });
    }

    const powOk = validatePow(nonce, j, p, i, uni, powCounter);
    if (!powOk) {
      if (botDetected) {
        return res.status(403).json({ error: 'Blocked' });
      }
      const ic = await incInvalidProofCount(ip);
      return res.status(403).json({ error: 'Invalid proof', c: ic });
    }

    const placeOk = await isPlaceValid(p);
    if (!placeOk) {
      const invalidCount = await incInvalidPlaceCount(ip);
      if (invalidCount >= 3) {
        await setBanned(ip, 259200);
      }
      return res.status(403).json({ error: 'Invalid PlaceId' });
    }

    const serverUniverseId = await getUniverseIdForPlace(p);
    if (serverUniverseId !== null) {
      const clientUni = Number(uni);
      const serverUniNum = Number(serverUniverseId);
      if (clientUni !== serverUniNum) {
        if (botDetected) {
          return res.status(403).json({ error: 'Blocked' });
        }
        const ic = await incInvalidProofCount(ip);
        return res.status(403).json({ error: 'Universe mismatch', c: ic });
      }
    }

    const userExists = await doesUserExist(i);
    if (userExists === false) {
      if (botDetected) {
        return res.status(403).json({ error: 'Blocked' });
      }
      const ic = await incInvalidProofCount(ip);
      return res.status(403).json({ error: 'Invalid user', c: ic });
    }

    const cleanG = String(g).replace(/[^a-zA-Z0-9_-]/g, '').toLowerCase();
    if (RESERVED_LUA.has(cleanG)) return res.status(404).send('Not found');
    const baseDir = path.join(process.cwd(), 'private', 'lua');
    const finalPath = findLuaScript(baseDir, cleanG);
    if (!finalPath) return res.status(404).send('Not found');
    let rateLimitStored = false;
    if (kvClient) {
      try {
        await kvClient.set(rlKey, count + 1, { ex: 60 });
        rateLimitStored = true;
      } catch {}
    }
    if (!rateLimitStored) {
      memoryStore.set(rlKey, { count: count + 1, exp: Date.now() + 60000 });
    }
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.status(200).send(readLuaScript(finalPath));
  }

  const gameRaw = req.query.game || 'launcher';
  const cleanGameRaw = String(gameRaw).replace(/[^a-zA-Z0-9_-]/g, '').toLowerCase();
  if (RESERVED_LUA.has(cleanGameRaw)) return res.status(404).send('Not found');
  const baseDir = path.join(process.cwd(), 'private', 'lua');
  if (!findLuaScript(baseDir, cleanGameRaw)) {
    return res.status(404).send('Not found');
  }
  if (botDetected) {
    return res.status(403).send('Blocked');
  }
  if (String(req.query.download || '') === '1') {
    const downloadPath = findLuaScript(baseDir, cleanGameRaw);
    if (!downloadPath) return res.status(404).send('Not found');
    setScriptCacheHeaders(res);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.status(200).send(readLuaScript(downloadPath));
  }
  const unifiedPath = path.join(process.cwd(), 'private', 'lua', 'verifier.lua');
  if (!fs.existsSync(unifiedPath)) {
    return res.status(404).send('Verifier not found');
  }
  const unifiedSrc = fs.readFileSync(unifiedPath, 'utf8');
  const nonce = await issueNonce(ip);
  const safeName = cleanGameRaw.replace(/"/g, '');
  const bootstrap = `_G.YSH_GAME = "${safeName}"\n_G.SNG_NONCE = "${nonce}"\n_G.SNG_POW_DIFF = ${POW_DIFFICULTY}\n` + unifiedSrc;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  return res.status(200).send(bootstrap);
};
