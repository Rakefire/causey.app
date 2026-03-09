# Causey Website

Jekyll + Bookshop component-based site for causey.app.

## Development

- `npm start` runs the dev server on localhost:4000 (port may vary, check output)
- Site source is in `site/`, components in `component-library/components/`
- SCSS follows BEM naming, uses CSS variables for theming (see `site/_data/themes.yml`)

## Brand Guidelines

Brand guide PDF: `Causey - Brand Standards or Guidelines.pdf` (in repo root)

### Colors

| Name   | Pantone | Hex       | RGB               |
|--------|---------|-----------|-------------------|
| Red    | 7626C   | `#cb3727` | R 203 G 55 B 39   |
| Yellow | 137C    | `#faa21b` | R 250 G 162 B 27  |

### Secondary Colors (Design System)

CSS variables prefixed `--mm-`. Used across the site for theming and UI elements.

| Name        | Hex       | Pantone | RGB                 |
|-------------|-----------|---------|---------------------|
| Light Gold  | `#fdd671` | 127C    | R 253 G 214 B 113  |
| Teal        | `#1d988c` | 7473C   | R 29 G 152 B 140   |
| Dark Navy   | `#243746` | 303C    | R 36 G 55 B 70     |
| Green       | `#46b978` | 7479C   | R 70 G 185 B 120   |
| Cream       | `#f8f0e1` | 7527C   | R 248 G 240 B 225  |
| Warm Gray   | `#686158` | 405C    | R 104 G 97 B 88    |
| Purple      | `#634b78` | 7664C   | R 99 G 75 B 120    |

### Logo Variants

- **Logo (no tag)**: Icon + "causey" wordmark (primary usage, no tagline)
- **Wordmark**: "causey" text only (red with yellow "y")
- **Icon**: Splash/droplet mark only

### Logo Usage Rules

- Use logo as: single color, white, black, or the full color combination
- No colors other than the approved palette above
- Inverted (white) versions exist for use on red or yellow backgrounds

## Screenshots

When using Playwright or browser tools to take screenshots, save them to `.screenshots/` directory (gitignored). Do not save screenshots to the project root.

```
.screenshots/   # All browser automation screenshots go here
```
