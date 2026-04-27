# Pixel-perfect verification harness

Used during the Jekyll → Bridgetown migration to ensure rendered output stays identical.

## Workflow

1. Serve the **baseline** (Jekyll) build:
   ```sh
   cd site/_site && python3 -m http.server 6060
   ```
2. Capture baselines:
   ```sh
   cd verification/scripts && node capture.js --baseline
   ```
3. Build and serve the **candidate** (Bridgetown) build, then:
   ```sh
   node capture.js --bridgetown --base-url=http://127.0.0.1:6061
   ```
4. Compare:
   ```sh
   node diff.js
   ```
   Diff PNGs land in `verification/diff/<viewport>/`. Summary in `verification/diff/summary.json`.

## Layout

```
baseline/<viewport>/<route>.png    # Jekyll outputs (gitignored)
bridgetown/<viewport>/<route>.png  # Bridgetown outputs (gitignored)
diff/<viewport>/<route>.png        # Pixel diffs for failed routes (gitignored)
scripts/                           # Capture and diff scripts (committed)
```

## Acceptance

- **Pages**: each page differs by < 0.1% pixels (configurable via `--threshold=`)
- **Redirects**: target URL matches after stripping `localhost:4000` / `www.causey.app` and trailing slash
