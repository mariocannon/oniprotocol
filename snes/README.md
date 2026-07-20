# Oni Pong — SNES homebrew

A simple Pong-style game for the Super Nintendo, written in 65816
assembly as a spinoff of Oni Protocol. Built as a 32KB LoROM `.sfc`
that runs on RetroPie, any SNES emulator, or real hardware via a
flash cart.

![gameplay](screenshot.png)

## How to play

- **D-pad Up/Down** — move your paddle (left side)
- The CPU controls the right paddle. It only reacts once the ball
  crosses midfield, so steep deflections off the edge of your paddle
  can beat it.
- Hitting the ball with the outer thirds of your paddle deflects it
  steeply; the middle returns it flat.
- First to **5 points** wins the match; score pips are shown in the
  top corners and the screen flashes oni-red on every point.

## Running on RetroPie

Copy `onipong.sfc` to the SNES ROM folder on your Pi and restart
EmulationStation:

```sh
scp onipong.sfc pi@retropie:~/RetroPie/roms/snes/
```

(or use the network share: `\\retropie\roms\snes`)

## Building from source

Requires the [cc65](https://cc65.github.io/) suite (`ca65`/`ld65`)
and Python 3:

```sh
sudo apt install cc65   # Debian/Ubuntu
make                    # produces onipong.sfc
```

The build assembles `src/main.s`, links it with the `lorom.cfg`
memory map, and `tools/fix_checksum.py` patches the SNES internal
header checksum in place.

## Layout

| File | Purpose |
| --- | --- |
| `src/main.s` | Entire game: init, NMI/vblank handler, input, physics, AI, OAM |
| `lorom.cfg` | ld65 linker config for a 32KB LoROM cartridge |
| `tools/fix_checksum.py` | Patches the internal header checksum after linking |
| `onipong.sfc` | Prebuilt ROM, ready to copy to RetroPie |
