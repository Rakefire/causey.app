// Deep inspection — recurse into divs and find which children diverge in size.
import { chromium } from 'playwright';

const route = process.argv[2] || '/terms/';
const browser = await chromium.launch();

async function getSections(port) {
  const ctx = await browser.newContext({ viewport: { width: 375, height: 800 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.goto(`http://127.0.0.1:${port}${route}`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(800);
  const sections = await page.evaluate(() => {
    function walk(el, depth = 0, max = 4, out = []) {
      const r = el.getBoundingClientRect();
      out.push({ depth, tag: el.tagName, id: el.id, cls: (el.className || '').toString().slice(0, 40), h: r.height, w: r.width });
      if (depth >= max) return out;
      for (const c of el.children) walk(c, depth + 1, max, out);
      return out;
    }
    return walk(document.querySelector('.c-content__inner-wrapper'), 0, 1);
  });
  await ctx.close();
  return sections;
}

const a = await getSections(6060);
const b = await getSections(6061);
const N = Math.max(a.length, b.length);
for (let i = 0; i < N; i++) {
  const x = a[i] || {};
  const y = b[i] || {};
  const ind = '  '.repeat(x.depth || y.depth || 0);
  const dx = (x.h || 0).toString().padStart(6);
  const dy = (y.h || 0).toString().padStart(6);
  const diff = Math.abs((x.h || 0) - (y.h || 0));
  const flag = diff > 10 ? '* ' : '  ';
  const wx = (x.w || 0).toFixed(0).padStart(4);
  const wy = (y.w || 0).toFixed(0).padStart(4);
  console.log(`${flag}h:${dx} | ${dy}  w:${wx} | ${wy}  ${ind}${x.tag || y.tag} ${(x.cls || y.cls || '').slice(0, 30)}`);
}
await browser.close();
