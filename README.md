# Road Fighter Remake – Modern Windows Patch

A modern Windows compatibility patch for the 2003 **Road Fighter Remake** by Santi Ontañón and the original Retro Remakes team.

This project keeps the original game logic and 512×384 software rendering intact, while making the Windows build much nicer to use on current displays.

> **Unofficial fan project.** This repository is not affiliated with or endorsed by Konami.

## Features

- Borderless fullscreen-window presentation
- Modern output resolutions:
  - 1920×1080
  - 2160×1440
  - 3840×2160
  - 5120×1440
- Correct 4:3 aspect ratio with centered pillarboxing instead of image stretching
- Audio buffer increased from 2048 to 4096 samples to reduce short crackles/underruns
- Default master volume reduced to **30%** of the original level
- Runtime volume control:
  - **F9** – volume down by 5 percentage points
  - **F10** – volume up by 5 percentage points

## Download / Run

The ready-to-play Windows package is in [`release/`](release/).

1. Download and extract `RoadFighter.zip`.
2. Do **not** run it from inside the ZIP file.
3. Start the resolution you want:
   - `START - 1920x1080.cmd`
   - `START - 2160x1440.cmd`
   - `START - 3840x2160.cmd`
   - `START - 5120x1440.cmd`
4. Use **F9/F10** at any time to change the volume.

The patched executables are unsigned 32-bit Windows binaries. Because the patch modifies executable code directly, some antivirus products may apply heuristic warnings. SHA-256 hashes are included in the release directory so the files can be verified.

## Display behavior

This patch deliberately does **not** change the original game's logical resolution or gameplay viewport. Road Fighter still renders internally at **512×384 (4:3)** and the completed frame is scaled into the selected modern output resolution.

That means 16:9 and 32:9 displays use black side bars rather than stretching the image. This is modern resolution support, not a true widescreen/FOV modification.

## Preview

These are original in-game assets included with the remake, provided here as a quick visual preview:

| ![Alt text](/screenshots/title-artwork.jpg?raw=true "Title Artwork") | ![Alt text](/screenshots/game-map.png?raw=true "Game Map") |
| -------------------------------- |:-----------------------------------------:|

### Screenshots

| ![Alt text](/screenshots/main-menu.png?raw=true "Main Menu") | ![Alt text](/screenshots/gameplay1.png?raw=true "Gameplay 1") | ![Alt text](/screenshots/gameplay2.png?raw=true "Gameplay 2") | ![Alt text](/screenshots/gameplay3.png?raw=true "Gameplay 3") |
| :--- | :---: | ---: | --- |

## The OGs ❤️

Huge thanks to the people who made and preserved the remake in the first place:

- **Santi Ontañón** – programming
- **Miikka Poikela** – graphics
- **Jorrith Schaap** – music / SFX
- **Jason Eames**, Miikka Poikela, Jorrith Schaap and Santi Ontañón – beta testing
- **Manuel Bilderbeek** – Linux port work
- **Carlos Donizete Froes (coringao)** – later maintenance and preservation on GitLab
- The **Retro Remakes** community

The preserved upstream project is here:

**https://gitlab.com/coringao/roadfighter**

Without the original developers and the people who kept the source available, this modern Windows patch would not exist.

## Technical notes

The modern patch is a direct PE32 binary modification of the original 2003 Windows executable. The injected code:

- keeps the original 512×384 SDL surface;
- turns the SDL-owned window into a borderless popup at the selected output size;
- scales the completed frame into an off-screen GDI backbuffer;
- presents each frame to the visible window with a single `BitBlt`;
- intercepts the SDL event path for F9/F10 volume changes;
- increases the SDL_mixer audio buffer to 4096 samples;
- attenuates music and mixer channels before final mixing.

The patch source and reproducible build script live in [`patch-source/`](patch-source/). The build script verifies the SHA-256 of the expected original executable before modifying it.

## Source and licensing

The upstream Road Fighter Remake states that the project as a whole is distributed under the **GNU General Public License, version 2 or later**. This repository therefore uses **GPL-2.0-or-later**, not MIT.

See [`LICENSE`](LICENSE), [`SOURCE.md`](SOURCE.md) and [`CREDITS.md`](CREDITS.md).

Third-party libraries and assets remain subject to their respective original licenses and copyright notices.

## Disclaimer

Road Fighter is a Konami title. This repository contains an unofficial compatibility modification for an unofficial fan remake. It is not affiliated with Konami and makes no claim to the Road Fighter trademark or original Konami intellectual property.
