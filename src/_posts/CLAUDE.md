# Writing blog posts

Guide for drafting posts in `src/_posts/`. This file is on the build's
`exclude` list in `config/initializers.rb`; keep it there, or it ships as
`/CLAUDE.md`.

**Readers:** executive directors, staff and board members at nonprofits (food
banks, libraries, chambers, churches, community organizations), and the
consultants who coach them through a strategic plan. They are busy, not
technical, and use Causey between meetings. Write for the person preparing for
next week's board meeting.

## Steps for a feature post

1. **Verify.** Every sentence about the product is true of what has shipped.
   The product repo is `~/github/causey`: read the PR body
   (`gh pr view N --json title,body`) and spot-check the code. Tiers live in
   `app/models/abilities/organization_ability.rb`, who-can-do-what in
   `app/policies/`, flag-gated features in `config/feature_flags.yml` (a
   feature behind a flag has not shipped to everyone; tell the person asking).
   Done when each claim maps to code or a merged PR; cut any claim that
   doesn't.
2. **Draft** in the voice and structure below.
3. **Front matter** from the template; check the site rules at the end.
4. **Humanize.** Run the `humanizer` skill over the post, then reread it
   against this file.

## Voice

- **Founder's voice.** Feature posts are by Ricky: "I" for his own reactions,
  "we" for the team. From the refresh post: "I kept going back to it, and kept
  wishing the rest of Causey felt that way." / "We took what made the Overview
  work, wrote it down as a small set of rules..."
- **Reader's problem first.** Open on a moment the reader knows, then the
  feature: "When it is time to prepare for a board meeting, review progress
  with leadership, or understand what changed over the last quarter..."
- **Calm and concrete.** Plain words, contractions, short paragraphs (one to
  three sentences). Announce plainly: "So we gave Causey a fresh coat of
  paint. It's live today." The 2024 roundups ("We're thrilled to unveil",
  "game-changer", "You asked, we delivered!") are the register to move away
  from.
- **Explain the why.** Readers trust a reason: "Rather than require every
  Causey customer to use the same AI provider, we chose to make plan
  information easy to extract..."
- **What they see, in their words.** Describe the screen and the benefit, with
  UI labels exactly as the app prints them. Implementation stays out: "the
  page updates in place", never "Turbo morph"; "Causey keeps 90 days of
  history", never "a nightly reaper".
- **Honest limits.** State who can use it and on which tiers, plainly, near
  the end: "The Contributor role is available on Core and Solid plans."
- **Essays** (Thanksgiving, year-end, strategy habits) use the same voice;
  product mentions there are light and practical ("score your metrics"),
  never a pitch.
- **Warm close.** Thank readers and invite a reply: "If something looks off...
  please tell us at [help@causey.app](mailto:help@causey.app). We read every
  note." Point to `https://help.causey.app/` for how-to.

## Structure

- 400–750 words.
- An unheaded opening of two to four short paragraphs that ends on what's new.
- Two to five sections under `## **Title Case Heading**`.
- Parallel items get a bold lead-in sentence: "**More room to breathe.**
  Pages that used to feel crowded now have consistent spacing..."
- Bullets for capability lists (what someone can and can't do).
- A closing section with availability, where to learn more, and thanks.

## Front matter

```yaml
---
title: "Plain Headline in Title Case"
categories:
  - features
  - Strategy Execution
author_staff_member: 171c91e1-2e04-443c-8c5c-ea8c68a3f596
date: 2026-11-23 06:00:00 +0000
content_blocks:
SEO_options:
  title: Search Title of 70 Characters or Fewer
  description: >-
    One or two sentences, 160 characters or fewer, unique on the site.
  image:
  prevent_indexing: false
blurb: >-
  The card text on /blog/: what changed and why it helps, in two sentences.
---
```

- `author_staff_member` is the `_id` from `src/_staff_members/`: Ricky
  Chilcott (`171c91e1-…`) for feature posts, Joana Constantino (`cfcf24d9-…`)
  for partner stories and news.
- Each category becomes a `/category/<slug>/` page, so reuse existing ones:
  `features`, `news`, `Strategy Execution`, `Nonprofit Strategy`,
  `Nonprofit Operations`, `Strategic Leadership`, `Consulting & Advisory`.
- Quote a `title` that contains a colon.
- `SEO_options.image` takes a file in `src/uploads/`; leave it empty until the
  screenshot exists (the site's default share image fills in).

## Formatting

- Headings: `## **Heading**` and `### **Subheading**`. The layout renders
  `title` as the page's one `h1`, so the body starts at `##`.
- UI labels: buttons, menu items and fields in quotes, as the app prints
  them ("Email me a sign-in link", "Chart Style"); pages and tabs capitalized
  without quotes (the Overview tab, Settings, the Members page). Bold stays
  for headings and lead-ins.
- Screenshots: `![What the screenshot shows](/uploads/name.jpg){: width="1400" height="900"}`,
  a 1400x900 JPG in `src/uploads/`. Until the file exists, leave a comment
  where it goes: `<!-- SCREENSHOT: Overview tab for a sample food-bank plan, 1400x900 -->`.
- External links: `[text](https://...){: target="_blank" rel="noopener"}`
  with straight quotes.
- Internal links: `/slug/`, the post's filename without the date, e.g.
  `/introducing-the-contributor-role/`.
- Help center: link `https://help.causey.app/`, or an article URL you have
  opened and confirmed.
- Optional tip box: `> **Causey Pro Tip:** ...`

## Facts and names

- Quotes, testimonials, statistics and customer names come from a real
  source: a published post, a partner's own words, or the person's go-ahead.
  The Community Food Bank of Southern Arizona is public in the Contributor
  post.
- Name tiers as the pricing page does: Basic, Lite, Core, Solid.

## Scheduling

Bridgetown skips future-dated posts, and `.github/workflows/pages.yml`
rebuilds the site daily from a 06:00 UTC cron (it usually runs around 06:20).
Date a post `YYYY-MM-DD 06:00:00 +0000` and give the filename the same date:
it publishes that morning, so a PR of scheduled posts can merge any time
before the first date. One post per day.

## Site rules (`test/test_site.rb`)

Every indexable page must pass these. CI builds without `--future`, so it
skips scheduled posts. Check them yourself:

```sh
BRIDGETOWN_ENV=test bundle exec bridgetown build --future
BRIDGETOWN_ENV=test bundle exec ruby -Itest test/test_site.rb
bundle exec rake test   # what CI runs; rebuilds without --future
```

Keep `BRIDGETOWN_ENV=production` for deploys: locally it pings IndexNow.

- `<title>` is `SEO_options.title` if set, else `title` (plus " — Causey"
  when the title is 51 characters or fewer). It must be 70 characters or
  fewer and unique site-wide.
- The meta description is `SEO_options.description`, else `blurb`, cut to
  160 characters. It must be unique site-wide.
- Exactly one `h1` per page.
- Every image has alt text, width and height, and a file that exists.
- Internal links resolve to a built page.
