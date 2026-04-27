// Capture full-page screenshots of every non-redirect route at 3 viewports.
// Redirect stubs are recorded as { route, target } in the manifest for separate verification.
// Usage: node capture.js [--baseline | --bridgetown] [--base-url=...] [--concurrency=N]
import { chromium } from 'playwright';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { discoverRoutes, VIEWPORTS, routeToFilename } from './routes.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const targetArg = args.find(a => a === '--baseline' || a === '--bridgetown') || '--baseline';
const target = targetArg.replace('--', '');
const baseUrlArg = args.find(a => a.startsWith('--base-url='));
const baseUrl = (baseUrlArg ? baseUrlArg.split('=')[1] : 'http://127.0.0.1:6060').replace(/\/$/, '');
const concurrencyArg = args.find(a => a.startsWith('--concurrency='));
const CONCURRENCY = concurrencyArg ? parseInt(concurrencyArg.split('=')[1], 10) : 4;

// Both targets discover routes from the same Bridgetown build output —
// the legacy Jekyll _site/ tree is gone, and `--baseline` is now used for
// production captures (e.g. https://www.causey.app), not a local Jekyll.
const siteRoot = path.resolve(__dirname, '../../output');
const allRoutes = discoverRoutes(siteRoot);
const pageRoutes = allRoutes.filter(r => r.kind === 'page');
const redirectRoutes = allRoutes.filter(r => r.kind === 'redirect');
console.log(`[capture] target=${target} baseUrl=${baseUrl} pages=${pageRoutes.length} redirects=${redirectRoutes.length} concurrency=${CONCURRENCY}`);

const outRoot = path.resolve(__dirname, `../${target}`);
for (const v of VIEWPORTS) fs.mkdirSync(path.join(outRoot, v.name), { recursive: true });

const ANIMATION_KILLER = `
  *, *::before, *::after {
    animation-duration: 0s !important;
    animation-delay: 0s !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    caret-color: transparent !important;
    scroll-behavior: auto !important;
  }
`;

async function captureOne(browser, route, viewport) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: 'light',
  });
  const page = await context.newPage();
  const url = `${baseUrl}${route}`;
  const filename = `${routeToFilename(route)}.png`;
  const outPath = path.join(outRoot, viewport.name, filename);
  try {
    const resp = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    if (!resp || !resp.ok()) {
      await context.close();
      return { route, viewport: viewport.name, status: resp ? resp.status() : 0, ok: false };
    }
    await page.addStyleTag({ content: ANIMATION_KILLER }).catch(() => {});
    // Trigger lazy-loaded content by scrolling to bottom and back
    await page.evaluate(async () => {
      await new Promise((res) => {
        let y = 0;
        const step = () => {
          window.scrollTo(0, y);
          y += 400;
          if (y < document.body.scrollHeight) setTimeout(step, 30);
          else { window.scrollTo(0, 0); res(); }
        };
        step();
      });
    });
    await page.waitForTimeout(500);
    await page.screenshot({ path: outPath, fullPage: true, animations: 'disabled' });
    await context.close();
    return { route, viewport: viewport.name, status: resp.status(), ok: true, path: outPath };
  } catch (e) {
    await context.close();
    return { route, viewport: viewport.name, status: 0, ok: false, error: e.message };
  }
}

async function main() {
  const browser = await chromium.launch();
  const tasks = [];
  for (const r of pageRoutes) for (const v of VIEWPORTS) tasks.push({ route: r.route, viewport: v });
  console.log(`[capture] ${tasks.length} screenshots queued`);
  const results = [];
  let i = 0;
  const workers = Array.from({ length: CONCURRENCY }, async () => {
    while (i < tasks.length) {
      const idx = i++;
      const t = tasks[idx];
      const start = Date.now();
      const r = await captureOne(browser, t.route, t.viewport);
      const ms = Date.now() - start;
      console.log(`[${idx + 1}/${tasks.length}] ${r.ok ? 'OK ' : 'FAIL'} ${t.viewport.name.padEnd(8)} ${t.route} (${ms}ms)`);
      results.push(r);
    }
  });
  await Promise.all(workers);
  await browser.close();
  const manifest = {
    target,
    baseUrl,
    capturedAt: new Date().toISOString(),
    viewports: VIEWPORTS,
    pages: results,
    redirects: redirectRoutes.map(({ route, target }) => ({ route, target })),
    summary: {
      pageScreenshots: results.length,
      ok: results.filter(r => r.ok).length,
      failed: results.filter(r => !r.ok).length,
      redirects: redirectRoutes.length,
    },
  };
  const manifestPath = path.join(outRoot, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log(`[done] ${manifest.summary.ok}/${manifest.summary.pageScreenshots} screenshots ok, ${manifest.summary.redirects} redirects recorded`);
  console.log(`[done] manifest at ${manifestPath}`);
  if (manifest.summary.failed > 0) process.exit(1);
}

main().catch(e => { console.error(e); process.exit(1); });
