# BIG BLOCKS — a RetroPie theme for kids (ages 5–10)

A deliberately **super-simple** EmulationStation theme. Games show up as
**big box-art blocks** in a grid, and the one you're on glows with a bright
purple frame. Little readers just pick the picture they like and press the
button.

Inspired by the classic SNES box-art carousel look.

![Style: purple, big blocks, minimal text]

## What it looks like

- **Pick a console** screen: one big console name at a time, swipe left/right.
- **Choose a game** screen: a grid of large box-art blocks (4 across, 2 rows),
  the selected one zooms and glows purple. The game's name is shown big at the
  bottom.
- Minimal text, big fonts, high contrast — nothing to read or configure while
  playing.

## Install

1. Copy the whole `retropie-kids-theme` folder onto your Pi, into the
   EmulationStation themes directory, renamed to `big-blocks` (any name works):

   ```bash
   # from another machine (adjust the address / path to your Pi)
   scp -r retropie-kids-theme pi@retropie.local:/home/pi/.emulationstation/themes/big-blocks
   ```

   Or clone/copy it directly on the Pi to either of these locations:

   - `/etc/emulationstation/themes/big-blocks/`  (system-wide), or
   - `~/.emulationstation/themes/big-blocks/`    (just your user)

2. In EmulationStation press **Start → UI SETTINGS → THEME SET** and choose
   **big-blocks**.

## ⭐ Important — turn on the big-blocks grid

The grid of large box art is EmulationStation's **Grid** gamelist view. Turn it
on once so every console uses it:

**Start → UI SETTINGS → GAMELIST VIEW STYLE → GRID**

(If you leave it on "automatic" you'll get a plain list instead of the blocks.)

## Get the box art (so the blocks aren't just placeholders)

The blocks display each game's scraped image. If a game has no art yet you'll
see a friendly purple **PLAY!** placeholder.

To fill in the real art: **Start → SCRAPER → SCRAPE NOW** (or use
[Skraper](https://www.skraper.net/) on a PC). Choose **Box** / **2D box** art
for the best-looking blocks.

## Tweaks for parents

Open `theme.xml` and look in the `<view name="grid">` section:

- **Blocks per screen** — change `<autoLayout>4 2</autoLayout>` (columns rows).
  Try `3 2` for even bigger blocks, or `5 3` to fit more.
- **How much the selected block grows** — `<autoLayoutSelectedZoom>1.10</...>`.
- **Titles at the top** — edit the `CHOOSE A GAME` / `PICK A CONSOLE` text.
- **Colors** — the purple is `8B5CF6`; search-and-replace it if you want a
  different favourite colour. The background/frames are PNGs in `art/`.

## What's in here

```
theme.xml            the whole design (all views)
art/                 background, tile frames, placeholder art
<system folders>/     one tiny theme.xml each, so every console uses the design
README.md            this file
```

Each console folder (e.g. `snes/`, `nes/`, `gba/`) just contains a 4-line
`theme.xml` that includes the root design, which is how EmulationStation applies
one look to every system.

## Compatibility

Written for RetroPie's EmulationStation (theme `formatVersion` 7). Unknown
elements are ignored on older builds, so it degrades gracefully.
