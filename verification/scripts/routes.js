// Route discovery + classification for verification.
// Generated for Phase 0 baseline capture.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const SKIP_DIRS = new Set(['assets', 'images', 'uploads', 'pagefind', 'causey-timeline']);

export function discoverRoutes(siteRoot) {
  const all = [];
  const walk = (dir, urlPrefix) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name.startsWith('.') || SKIP_DIRS.has(entry.name)) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full, `${urlPrefix}${entry.name}/`);
      else if (entry.name === 'index.html') {
        all.push({ route: urlPrefix || '/', file: full });
      } else if (entry.name.endsWith('.html')) {
        // jekyll-redirect-from outputs .html stubs alongside directories.
        // Treat them as redirects keyed by their absolute URL.
        all.push({ route: `${urlPrefix}${entry.name}`, file: full });
      }
    }
  };
  walk(siteRoot, '/');
  return all
    .map(({ route, file }) => {
      const html = fs.readFileSync(file, 'utf8');
      const redirect = extractRedirect(html);
      return { route, file, kind: redirect ? 'redirect' : 'page', target: redirect };
    })
    .sort((a, b) => a.route.localeCompare(b.route));
}

function extractRedirect(html) {
  const m1 = html.match(/<script>\s*location\s*=\s*"([^"]+)"/);
  if (m1) return m1[1];
  const m2 = html.match(/http-equiv="refresh"[^>]*url=([^"'\s>]+)/i);
  if (m2) return m2[1];
  return null;
}

export const VIEWPORTS = [
  { name: 'mobile',  width: 375,  height: 800 },
  { name: 'tablet',  width: 768,  height: 1024 },
  { name: 'desktop', width: 1440, height: 900 },
];

export function routeToFilename(route) {
  if (route === '/') return 'index';
  return route.replace(/^\//, '').replace(/\/$/, '').replace(/\//g, '__');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const siteRoot = path.resolve(__dirname, '../../output');
  const routes = discoverRoutes(siteRoot);
  const pages = routes.filter(r => r.kind === 'page');
  const redirects = routes.filter(r => r.kind === 'redirect');
  console.log(`Discovered ${routes.length} routes: ${pages.length} page, ${redirects.length} redirect`);
  console.log('--- redirects ---');
  for (const r of redirects) console.log(`${r.route} -> ${r.target}`);
}
