# PicklePro AI — Product Plan

*Working title. Alternatives: DinkCoach, RallyIQ, PickleIQ, KitchenCoach.*

An AI pickleball coach delivered as a web app. Players upload video of themselves
playing; the app analyzes their technique, positioning, and shot selection, then
returns a scored breakdown with concrete tips and drills. Monetized as a
subscription. Modeled on Wrestle AI (ImproveScape LLC) — "Wrestler Harder, Train
Smarter" — but for the fastest-growing sport in the US.

---

## 1. Why this, why now

- Pickleball has ~50M+ US players and has been the fastest-growing sport for
  four straight years. Most players are recreational adults (3.0–4.0 skill
  level) with disposable income and no access to affordable coaching.
- A human pickleball lesson runs $50–100/hour. An AI coach at $10–20/month is
  a 10x cheaper substitute for the "what am I doing wrong?" question.
- Wrestle AI validates the model in a much smaller sport: 1.9K ratings at 4.8
  stars with a simple loop — record → analyze → score → tips → daily challenges.
  Pickleball's addressable market is far larger and skews toward players who
  already film their games (rec-center and tournament culture).

### Competitive landscape

| Product | Sport | What it does | Gap we exploit |
|---|---|---|---|
| Wrestle AI | Wrestling | Video analysis, performance score, challenges | Different sport; mobile-only |
| PB Vision | Pickleball | Full-match stats/tracking from court-mounted video | Stats-heavy, not coaching-first; requires full-court setup |
| SwingVision | Tennis | Shot tracking, line calls | Tennis, iOS-only |
| OnForm / Coach's Eye style | Multi | Human coach annotates your video | Needs a human; slow turnaround |
| YouTube / free content | — | Generic tips | Not personalized |

**Positioning:** the coaching-first product. Not "here are your match stats" —
"here are the 3 things costing you points, and the drill to fix each one this
week." Works with casual phone video, not just perfect court-mounted footage.

---

## 2. Target users

1. **Improver (core persona).** 30–65, plays 2–4x/week at 3.0–4.0 level, wants
   to move up a rating bracket. Willing to pay for progress. This is who the
   MVP serves.
2. **Competitive amateur.** 4.0+, plays tournaments, wants shot-selection and
   matchup analysis. Higher tier / later.
3. **Coach / club.** Uses the tool with students; multi-player accounts. B2B
   expansion, not MVP.

---

## 3. Product

### Core loop (MVP)

1. **Upload** a clip (30 sec – 10 min) from a phone — behind-the-baseline or
   sideline angle. Guided capture instructions ("prop your phone here").
2. **Analyze** — pipeline detects the player, tracks pose and ball, segments
   rallies and shots (serve, return, drive, dink, drop, volley, lob).
3. **Report** — the deliverable, mirroring what makes Wrestle AI's results
   screen compelling:
   - **Performance Score** (e.g., 7.4/10) with a confidence indicator.
   - **Skill breakdown** by category: serve, return, third shot, dinking,
     volleys, court positioning, footwork/split-step.
   - **Top 3 fixes**, each with a plain-language explanation, a timestamped
     video moment showing the issue, and a recommended drill.
   - **Annotated clips**: skeleton overlay / kitchen-line positioning markers
     on the key moments.
4. **Improve** — drill library mapped to weaknesses; re-upload next week and
   see the score trend.

### Retention features (fast follow, still v1.x)

- **Progress tracking**: score history per skill, streaks, "you improved your
  third-shot drop from 5.1 → 6.3."
- **Challenge of the day** (straight from the Wrestle AI playbook): "Record 20
  third-shot drops; AI counts makes and grades consistency." Points + streaks.
- **Ask the coach**: chat with an AI coach that has your analysis history as
  context ("why do I keep getting passed at the net?").

### Later (v2+)

- Doubles awareness: partner positioning, stacking, who-takes-the-middle.
- Full-match stats mode (rally length, unforced errors, shot maps) — meets PB
  Vision on their turf once coaching is established.
- Opponent scouting from tournament footage.
- Coach/club accounts with rosters and shared libraries.
- Native mobile apps (the web app is mobile-first from day one, so this is
  packaging, not a rebuild).

### Explicitly out of scope for MVP

Live/real-time analysis, line calling, multi-camera setups, social feed,
Android/iOS native apps.

---

## 4. AI/analysis pipeline (planning-level design)

Two-stage architecture — computer vision extracts *facts*, an LLM turns facts
into *coaching*:

1. **Ingest**: upload → transcode/normalize (720p, 30fps) → store.
2. **CV extraction** (GPU worker, async job):
   - Player detection + tracking (identify "you" — user taps themselves in the
     first frame if multiple people).
   - Pose estimation per frame (MediaPipe/RTMPose-class model).
   - Ball tracking + court line detection (homography → real court coordinates,
     kitchen line distance, baseline depth).
   - Shot segmentation + classification (contact-point events → serve / return /
     drive / dink / drop / volley / lob), rally boundaries.
3. **Metrics layer**: derived numbers per shot and per session — paddle-side
   balance, contact height, split-step timing, distance behind kitchen line at
   net, transition-zone dwell time, shot-depth distribution, consistency.
4. **Coaching layer (LLM — Claude)**: metrics + shot log + skill-level context
   go into a structured prompt with a pickleball coaching rubric; output is the
   scored report, top-3 fixes, and drill assignments as structured JSON the UI
   renders. The LLM never sees raw video — only extracted facts — which keeps
   costs predictable and output grounded.
5. **Render**: annotated highlight clips (overlay skeleton + court markers on
   the 5–10 key moments only, not the whole video).

**Cost envelope (order of magnitude):** a 5-minute video ≈ 2–4 min on a spot
GPU (~$0.03–0.10) + one LLM call (~$0.05–0.15) + storage/transcode pennies.
Call it **≤ $0.50 per analysis** all-in at small scale — comfortably inside a
$14.99/mo subscription with fair-use caps.

**Cold-start pragmatism:** MVP can ship with off-the-shelf pose models + a
rules/heuristics metrics layer and LLM coaching. No custom model training
required to launch. Collect labeled data (user uploads + consented usage) to
fine-tune shot classification later — that becomes the moat.

---

## 5. Tech stack (recommendation, not code)

- **Frontend**: Next.js (mobile-first responsive web app; PWA installable so it
  feels app-like on phones). Tailwind. Dark, bold aesthetic like Wrestle AI.
- **Backend/data**: Supabase — auth, Postgres, storage for uploads, edge
  functions for light API work. (Already available in this workspace.)
- **Video/GPU workers**: separate async job service on Modal / Replicate /
  RunPod — Supabase queues the job, worker pulls video from storage, writes
  results back. Never process video in request/response.
- **LLM**: Claude API for the coaching layer and "Ask the coach" chat.
- **Payments**: Stripe subscriptions (web checkout avoids the 30% app-store
  cut — a real advantage of webapp-first over Wrestle AI's IAP model).
- **Video delivery**: Mux or Cloudflare Stream for playback of annotated clips.

### Data model (top-level entities)

`users` → `subscriptions` → `videos` (upload metadata, status) → `analyses`
(scores, metrics JSON, report JSON) → `shots` (per-shot rows for trends) →
`drills` (library) → `assignments` (user ↔ drill ↔ status) → `challenges` /
`challenge_attempts` (streaks/points).

Privacy notes: videos are personal data of the user *and bystanders* — private
by default, clear retention policy (e.g., raw video deleted after 90 days on
free tier, kept while subscribed on paid), consent checkbox for using footage
to improve models, easy delete-everything.

---

## 6. Subscription model

Freemium with a hard-to-resist first analysis:

| Tier | Price | What's included |
|---|---|---|
| **Free** | $0 | 1 full analysis on signup, then 1 per month; watermarked clips; teaser report (score + 1 fix, rest blurred) |
| **Pro** | $14.99/mo or $119/yr | 8 analyses/mo, full reports, drill plans, progress tracking, challenges |
| **Elite** | $29.99/mo or $249/yr | 30 analyses/mo, doubles analysis (when shipped), Ask-the-coach chat priority, longer video limits |

- Anchor free→Pro conversion on the blurred report ("see your other 2 fixes").
- Annual pricing pushed hard at checkout (retention + cash flow).
- Later: club/coach tier at $79–149/mo for 5–20 seats.

**Rough unit economics:** Pro user doing 6 analyses/mo costs ≈ $3 in
compute + LLM against $14.99 revenue → ~80% gross margin before overhead,
improving as the pipeline gets optimized.

**North-star metric:** weekly analyzed videos per active subscriber (proxy for
habit). Guardrails: free→paid conversion ≥ 5%, month-3 retention ≥ 60%,
analysis turnaround < 10 min, "was this tip useful?" thumbs-up ≥ 70%.

---

## 7. Roadmap

**Phase 0 — Validate (2–4 weeks, before heavy build)**
- Landing page + waitlist; run $200–500 of ads into pickleball Facebook groups
  / subreddits to test messaging and price sensitivity.
- Concierge MVP: 20–50 players email a video; pipeline is run semi-manually
  (off-the-shelf pose tools + Claude-drafted report reviewed by a human/coach).
  This validates the *report format* — the actual product — before automation.

**Phase 1 — MVP (6–10 weeks)**
- Auth, upload, automated pipeline v1 (pose + heuristics + LLM report),
  report UI with annotated key moments, Stripe subscriptions, free-tier teaser.
- Singles, one camera angle, videos ≤ 5 min.

**Phase 2 — Retention (4–6 weeks)**
- Progress trends, drill library + assignments, challenge of the day, streaks,
  Ask-the-coach chat, email re-engagement ("time for this week's check-in").

**Phase 3 — Depth & growth**
- Doubles/positioning analysis, match stats mode, referral program
  ("give a free analysis, get a free month"), club/coach pilot, PWA polish →
  optional native wrappers.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| CV accuracy on messy phone video (bad angles, lighting, multiple courts) | Guided capture flow; pre-flight video quality check with instant feedback ("move camera higher"); confidence score on every report; free re-run if analysis fails |
| Generic-feeling advice ("bend your knees") | Ground every tip in a timestamped moment + a number ("on 7 of 9 net points you stood 4 ft behind the kitchen line"); rubric-driven prompts per skill level |
| PB Vision or SwingVision pivots into coaching | Move fast on coaching UX + habit loop; their DNA is stats/tracking, ours is coaching |
| Analysis costs blow up | Hard caps per tier, downsampled processing, key-moments-only rendering, spot GPUs |
| Users churn after fixing their one big flaw | Challenges/streaks, weekly check-in cadence, progressing skill curriculum (there's always a next level in pickleball) |
| Privacy complaints (bystanders in footage) | Private-by-default, retention limits, face-blur option later, clear ToS |

---

## 9. Open decisions (need your call before build)

1. **Name + domain** — shortlist above; check trademark/USPTO and domains.
2. **Phase 0 concierge test first, or straight to MVP build?** (Strongly
   recommend the concierge test — it's cheap and de-risks the report format.)
3. **Price points** — $14.99 vs $19.99 Pro; test on the waitlist landing page.
4. **Solo build vs. contracting the CV pipeline** — the GPU/CV worker is the
   only genuinely specialized piece; everything else is standard SaaS.
