# Modern Windows patch source

This directory contains the source for the v9 binary modification used by the public 1.0.0 Windows package.

## Build

Requirements:

- Python 3
- GNU binutils (`as`, `ld`, `objcopy`, `nm`)
- the original 2003 Windows `RoadFighter.exe`

Run:

```bash
python build_patch.py /path/to/RoadFighter-original.exe --output dist
```

The expected original EXE SHA-256 is hard-coded in the builder. The script intentionally refuses unknown binaries to avoid patching the wrong offsets.

The assembly is linked at virtual address `0x42E200` and the patch adds a writable `.rfdata` PE section for mutable state. Five original import thunks are redirected to the inject: video mode, flip/presentation, SDL_mixer open, music hook and SDL event polling.
