// Compare baseline screenshots against bridgetown screenshots, page by page.
// Usage: node diff.js [--threshold=0.001] [--pixel-threshold=0.1]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import { VIEWPORTS } from './routes.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const fracArg = args.find(a => a.startsWith('--threshold='));
const pxArg = args.find(a => a.startsWith('--pixel-threshold='));
// Failing fraction: max share of diffed pixels per image (0.001 = 0.1%)
const FAIL_FRAC = fracArg ? parseFloat(fracArg.split('=')[1]) : 0.001;
// Pixelmatch per-pixel similarity (0.1 = strict)
const PIX_THRESH = pxArg ? parseFloat(pxArg.split('=')[1]) : 0.1;

const baselineRoot = path.resolve(__dirname, '../baseline');
const candidateRoot = path.resolve(__dirname, '../bridgetown');
const diffRoot = path.resolve(__dirname, '../diff');

function readPng(file) {
  return PNG.sync.read(fs.readFileSync(file));
}

function pad(a, b) {
  // Match canvases by padding shorter image with white at the bottom.
  const w = Math.max(a.width, b.width);
  const h = Math.max(a.height, b.height);
  const out = (img) => {
    if (img.width === w && img.height === h) return img;
    const out = new PNG({ width: w, height: h });
    // Fill white
    for (let i = 0; i < out.data.length; i += 4) {
      out.data[i] = 255; out.data[i+1] = 255; out.data[i+2] = 255; out.data[i+3] = 255;
    }
    for (let y = 0; y < img.height; y++) {
      for (let x = 0; x < img.width; x++) {
        const src = (img.width * y + x) << 2;
        const dst = (w * y + x) << 2;
        out.data[dst] = img.data[src];
        out.data[dst+1] = img.data[src+1];
        out.data[dst+2] = img.data[src+2];
        out.data[dst+3] = img.data[src+3];
      }
    }
    return out;
  };
  return [out(a), out(b)];
}

function compareOne(file, viewport) {
  const baselineFile = path.join(baselineRoot, viewport, file);
  const candidateFile = path.join(candidateRoot, viewport, file);
  if (!fs.existsSync(candidateFile)) return { file, viewport, ok: false, reason: 'candidate-missing' };
  if (!fs.existsSync(baselineFile)) return { file, viewport, ok: false, reason: 'baseline-missing' };
  let a = readPng(baselineFile);
  let b = readPng(candidateFile);
  const sizeMatched = a.width === b.width && a.height === b.height;
  if (!sizeMatched) [a, b] = pad(a, b);
  const diff = new PNG({ width: a.width, height: a.height });
  const numDiff = pixelmatch(a.data, b.data, diff.data, a.width, a.height, { threshold: PIX_THRESH, includeAA: false });
  const total = a.width * a.height;
  const frac = numDiff / total;
  const ok = frac <= FAIL_FRAC;
  if (!ok) {
    fs.mkdirSync(path.join(diffRoot, viewport), { recursive: true });
    fs.writeFileSync(path.join(diffRoot, viewport, file), PNG.sync.write(diff));
  }
  return { file, viewport, ok, numDiff, total, frac, sizeMatched };
}

function main() {
  const baselineManifest = JSON.parse(fs.readFileSync(path.join(baselineRoot, 'manifest.json'), 'utf8'));
  const candidateManifestPath = path.join(candidateRoot, 'manifest.json');
  if (!fs.existsSync(candidateManifestPath)) {
    console.error(`[diff] candidate manifest not found: ${candidateManifestPath}`);
    process.exit(2);
  }
  const candidateManifest = JSON.parse(fs.readFileSync(candidateManifestPath, 'utf8'));

  // Compare redirects
  const redirCmp = compareRedirects(baselineManifest.redirects, candidateManifest.redirects);

  const rows = [];
  for (const v of VIEWPORTS) {
    const dir = path.join(baselineRoot, v.name);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.png'))) {
      rows.push(compareOne(f, v.name));
    }
  }
  const failed = rows.filter(r => !r.ok);
  const passed = rows.filter(r => r.ok);
  const sortedFails = [...failed].sort((a, b) => (b.frac || 0) - (a.frac || 0));

  console.log(`\n=== Pixel diff summary ===`);
  console.log(`thresholds: per-pixel=${PIX_THRESH}, page-fail-fraction=${FAIL_FRAC}`);
  console.log(`pages compared: ${rows.length}`);
  console.log(`PASS: ${passed.length}`);
  console.log(`FAIL: ${failed.length}`);
  if (sortedFails.length) {
    console.log(`\nTop 30 failures:`);
    for (const r of sortedFails.slice(0, 30)) {
      const pct = r.frac != null ? (r.frac * 100).toFixed(3) + '%' : 'N/A';
      const reason = r.reason ? ` (${r.reason})` : '';
      console.log(`  ${pct.padStart(8)} ${r.viewport.padEnd(8)} ${r.file}${reason}`);
    }
  }

  console.log(`\n=== Redirect target comparison ===`);
  console.log(`baseline redirects: ${baselineManifest.redirects.length}`);
  console.log(`candidate redirects: ${candidateManifest.redirects.length}`);
  console.log(`matching: ${redirCmp.matching}`);
  console.log(`mismatched: ${redirCmp.mismatched.length}`);
  console.log(`missing in candidate: ${redirCmp.missing.length}`);
  console.log(`extra in candidate: ${redirCmp.extra.length}`);
  for (const r of redirCmp.mismatched) console.log(`  MISMATCH ${r.route}: baseline=${r.baseline} candidate=${r.candidate}`);
  for (const r of redirCmp.missing) console.log(`  MISSING  ${r.route} -> ${r.target}`);
  for (const r of redirCmp.extra) console.log(`  EXTRA    ${r.route} -> ${r.target}`);

  const summary = {
    comparedAt: new Date().toISOString(),
    thresholds: { perPixel: PIX_THRESH, pageFailFraction: FAIL_FRAC },
    pages: { compared: rows.length, pass: passed.length, fail: failed.length, failures: sortedFails },
    redirects: redirCmp,
  };
  fs.writeFileSync(path.join(diffRoot, 'summary.json'), JSON.stringify(summary, null, 2));
  console.log(`\nsummary at verification/diff/summary.json`);
  if (failed.length || redirCmp.mismatched.length || redirCmp.missing.length || redirCmp.extra.length) process.exit(1);
}

function normalizeRedirect(target) {
  if (!target) return target;
  return target
    .replace(/^https?:\/\/(localhost(:\d+)?|127\.0\.0\.1(:\d+)?|www\.causey\.app)/, '')
    .replace(/\/$/, '');
}

function compareRedirects(baseline, candidate) {
  const bm = new Map(baseline.map(r => [r.route, r.target]));
  const cm = new Map(candidate.map(r => [r.route, r.target]));
  const matching = [];
  const mismatched = [];
  const missing = [];
  const extra = [];
  for (const [route, baseTarget] of bm) {
    if (!cm.has(route)) { missing.push({ route, target: baseTarget }); continue; }
    const candTarget = cm.get(route);
    if (normalizeRedirect(baseTarget) === normalizeRedirect(candTarget)) matching.push(route);
    else mismatched.push({ route, baseline: baseTarget, candidate: candTarget });
  }
  for (const [route, candTarget] of cm) {
    if (!bm.has(route)) extra.push({ route, target: candTarget });
  }
  return { matching: matching.length, mismatched, missing, extra };
}

main();
