# Source availability

This project consists of two parts:

1. the original Road Fighter Remake; and
2. the Modern Windows binary patch contained in this repository.

## Upstream source

The preserved upstream source repository is:

https://gitlab.com/coringao/roadfighter

The 1.0.0 source used as the reference for reverse engineering can be viewed at:

https://gitlab.com/coringao/roadfighter/-/tree/1.0.0

The upstream project identifies its overall license as **GNU GPL version 2 or later**.

## Modern patch source

The exact patch source is in [`patch-source/`](patch-source/):

- `rf_patch_v9.s` – 32-bit x86 injected assembly
- `build_patch.py` – portable PE patch/rebuild script
- `rf_patch_v9.disasm` – disassembly of the built inject for inspection
- `PE-VALIDATION-v9.txt` – validation notes from the development build

The build script requires the original 2003 Windows `RoadFighter.exe` with SHA-256:

`7a9adb389e1e367edd82b2503afeeea3b523bd6bac2c363a522166f6e64a2773`

It refuses to patch a different executable.

## Rebuilding the four patched executables

On a system with Python 3 and GNU binutils (`as`, `ld`, `objcopy`, `nm`):

```bash
python patch-source/build_patch.py /path/to/RoadFighter-original.exe --output dist
```

The script produces:

- `RoadFighter-1920x1080.exe`
- `RoadFighter-2160x1440.exe`
- `RoadFighter-3840x2160.exe`
- `RoadFighter-5120x1440.exe`

The portable rebuild script was verified against the distributed v9 executables and produced byte-identical files.

## Distribution note

If you redistribute the compiled game package, keep the GPL license, original credits/notices and corresponding patch source available with the binaries. For the most conservative GPL distribution setup, mirror the exact upstream source revision used by the binary alongside your release rather than relying only on a third-party source link.
