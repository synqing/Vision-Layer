/* DOM Bridge — Express + Playwright (persistent context)
 * - Locates DOM elements and returns bounding boxes & innerText.
 * - Uses Playwright locators with auto-waiting (prefer getByRole/getByTestId).
 * - Bounding box is relative to the main frame viewport (per Playwright docs).
 *   Ref: locator.boundingBox() semantics.
 * - Persistent context keeps you logged in between runs (userDataDir).
 *
 * Security: binds to 127.0.0.1 only.
 */

import 'dotenv/config';
import express from 'express';
import morgan from 'morgan';
import { chromium, firefox, webkit } from 'playwright';

const PORT = Number(process.env.DOM_BRIDGE_PORT || 4321);
const USER_DATA_DIR = process.env.USER_DATA_DIR || './user-data';
const BROWSER = (process.env.BROWSER || 'chromium').toLowerCase();
const HEADLESS = process.env.HEADLESS === '0' ? false : true;
const DEFAULT_SEED_URL = process.env.DEFAULT_SEED_URL || 'https://github.com';

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(morgan('tiny'));

let ctx = null; // BrowserContext (persistent)
let page = null; // Single Page reused
let starting = null; // startup lock

function browserType() {
  if (BROWSER === 'firefox') return firefox;
  if (BROWSER === 'webkit') return webkit;
  return chromium;
}

// Ensure persistent context + one page
async function ensureContextAndPage({ headless = HEADLESS } = {}) {
  if (ctx && !ctx.isClosed()) {
    if (page && !page.isClosed()) return { ctx, page };
    page = await ctx.newPage();
    return { ctx, page };
  }
  if (starting) return starting; // prevent races
  starting = (async () => {
    const type = browserType();
    ctx = await type.launchPersistentContext(USER_DATA_DIR, {
      headless,
      viewport: { width: 1440, height: 900 }
    });
    page = await ctx.newPage();
    page.setDefaultTimeout(10000);
    page.setDefaultNavigationTimeout(15000);
    return { ctx, page };
  })();
  const res = await starting;
  starting = null;
  return res;
}

// Build a resilient locator from request
function buildLocator(page, spec) {
  if (spec.testid) return page.getByTestId(spec.testid);
  if (spec.role && spec.name) return page.getByRole(spec.role, { name: spec.name });
  if (spec.locator) return page.locator(spec.locator);
  if (spec.css) return page.locator(`css=${spec.css}`);
  if (spec.text) return page.getByText(spec.text);
  throw new Error('No valid selector provided. Supply one of: testid, role+name, locator, css, text.');
}

// Navigate if url_contains not satisfied
async function ensurePageAt(page, urlContains, seedUrl, waitUntil = 'domcontentloaded') {
  const cur = page.url();
  if (!urlContains) return;
  if (cur && cur.includes(urlContains)) return;
  const target = seedUrl || (urlContains.startsWith('http') ? urlContains : `https://${urlContains}`);
  await page.goto(target, { waitUntil });
}

// Core locate handler
async function doLocate(body) {
  const { app: appBundle, url_contains, seed_url, wait_until, timeout_ms, selector = {}, scroll = true } = body;
  const { page } = await ensureContextAndPage();
  await ensurePageAt(page, url_contains, seed_url || DEFAULT_SEED_URL, wait_until || 'domcontentloaded');

  const loc = buildLocator(page, selector);
  try {
    await loc.waitFor({ state: 'visible', timeout: timeout_ms ?? 8000 });
  } catch (e) {
    if (scroll) {
      try {
        await loc.scrollIntoViewIfNeeded({ timeout: 2000 });
      } catch {}
    }
  }
  const bbox = await loc.boundingBox();
  let innerText = null;
  try {
    innerText = await loc.innerText({ timeout: 1000 });
  } catch {}

  const viewport = page.viewportSize();
  const url = page.url();

  return {
    ok: Boolean(bbox),
    url,
    viewport,
    bbox,
    inner_text: innerText,
    meta: {
      app_bundle: appBundle || null,
      headless: HEADLESS,
      browser: BROWSER
    }
  };
}

// POST /dom/locate
app.post('/dom/locate', async (req, res) => {
  try {
    const result = await doLocate(req.body || {});
    res.json(result);
  } catch (err) {
    console.error(JSON.stringify({ ts: new Date().toISOString(), stage: 'locate', error: String(err) }));
    res.status(400).json({ ok: false, error: String(err) });
  }
});

// POST /dom/text
app.post('/dom/text', async (req, res) => {
  try {
    const { page } = await ensureContextAndPage();
    const { url_contains, seed_url, wait_until, timeout_ms, selector = {} } = req.body || {};
    await ensurePageAt(page, url_contains, seed_url || DEFAULT_SEED_URL, wait_until || 'domcontentloaded');

    const loc = buildLocator(page, selector);
    await loc.waitFor({ state: 'visible', timeout: timeout_ms ?? 8000 });
    const text = await loc.innerText({ timeout: 1500 });
    res.json({ ok: true, text, url: page.url() });
  } catch (err) {
    console.error(JSON.stringify({ ts: new Date().toISOString(), stage: 'text', error: String(err) }));
    res.status(400).json({ ok: false, error: String(err) });
  }
});

// Healthz
app.get('/healthz', async (_req, res) => {
  const healthy = !!ctx && !ctx.isClosed() && !!page && !page.isClosed();
  res.json({
    ok: healthy,
    browser: BROWSER,
    headless: HEADLESS,
    user_data_dir: USER_DATA_DIR,
    page_url: page?.url?.() || null
  });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(JSON.stringify({ ts: new Date().toISOString(), msg: `dom-bridge listening on http://127.0.0.1:${PORT}` }));
});

process.on('SIGINT', async () => {
  try { await page?.close?.(); } catch {}
  try { await ctx?.close?.(); } catch {}
  process.exit(0);
});
