# Changelog

## 1.0.0 – Modern Windows release

Based on the internally tested direct patch v9.

- Added 1920×1080 output
- Added 2160×1440 output
- Added 3840×2160 output
- Added 5120×1440 output
- Added borderless fullscreen-window presentation
- Preserved the original 512×384 / 4:3 game surface
- Added centered aspect-ratio-correct scaling
- Fixed Alt+Tab focus/input/audio behavior by keeping presentation on the original SDL-owned window
- Added an off-screen GDI backbuffer to eliminate visible clear/draw flicker
- Increased SDL_mixer buffer size from 2048 to 4096 samples
- Set default volume to 30%
- Added F9/F10 runtime volume controls in 5-percentage-point steps
- Moved volume attenuation before final mixing to reduce clipping risk
