# Pixel-perfect verification harness

Originally used during the Jekyll → Bridgetown migration; kept around so
new changes can be re-checked against production at any time.

## Workflow

1. Build the **candidate** (current branch) and static-serve `output/`:
   ```sh
   BRIDGETOWN_ENV=production bundle exec bridgetown build
   cd output && python3 -m http.server 6062
   ```
2. Capture the candidate:
   ```sh
   cd verification/scripts
   node capture.js --bridgetown --base-url=http://127.0.0.1:6062
   ```
3. Capture **baseline** from production (or any reference URL):
   ```sh
   node capture.js --baseline --base-url=https://www.causey.app
   ```
4. Compare:
   ```sh
   node diff.js
   ```
   Diff PNGs land in `verification/diff/<viewport>/`. Summary in `verification/diff/summary.json`.

## Layout

```
baseline/<viewport>/<route>.png    # reference build (gitignored)
bridgetown/<viewport>/<route>.png  # candidate build (gitignored)
diff/<viewport>/<route>.png        # pixel diffs for failed routes (gitignored)
scripts/                           # capture and diff scripts (committed)
```

## Acceptance

- **Pages**: each page differs by < 0.1% pixels (configurable via `--threshold=`)
- **Redirects**: target URL matches after stripping `localhost:4000` / `www.causey.app` and trailing slash
