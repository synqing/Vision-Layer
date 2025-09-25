/* Opens a headful persistent browser so you can log in to GitHub once.
 * Reuses USER_DATA_DIR; server will then run headless with the same profile.
 */
import 'dotenv/config';
import { chromium, firefox, webkit } from 'playwright';

const USER_DATA_DIR = process.env.USER_DATA_DIR || './user-data';
const BROWSER = (process.env.BROWSER || 'chromium').toLowerCase();
const START_URL = process.env.DEFAULT_SEED_URL || 'https://github.com/login';

function browserType() {
  if (BROWSER === 'firefox') return firefox;
  if (BROWSER === 'webkit') return webkit;
  return chromium;
}

const type = browserType();

const ctx = await type.launchPersistentContext(USER_DATA_DIR, {
  headless: false,
  viewport: { width: 1440, height: 900 }
});
const page = await ctx.newPage();
await page.goto(START_URL, { waitUntil: 'domcontentloaded' });

console.log('\n[dom-bridge] A headful browser window is open.');
console.log('[dom-bridge] Log into GitHub (and any other sites you need), then press Ctrl+C here to exit.\n');
process.stdin.resume();

process.on('SIGINT', async () => {
  await page.close().catch(()=>{});
  await ctx.close().catch(()=>{});
  process.exit(0);
});
