# SCAR - Squadra Corse Alfa Romeo: port notes

Developer notes for the PC port (statically recompiled with TGP482's Xbox XBE Recomp, `sdk/`). Method and tools come
from IndyPort (github.com/MertCNOZ/IndyPort, `D:\Game Setups\Indy`); its PORT_NOTES.md has the background for most
runtime topics (XDK symbols, render states, sound, widescreen).

## Game image (2026-11-11)

- `SCAR - Squadra Corse Alfa Romeo (Europe) (En,Fr,De,Es,It).xiso.iso`, 497,876,992 bytes, extracted to `assets/`
  with `tools/xiso_extract.py` (57 files, 474 MiB).
- default.xbe: title "SCAR", title id **0x4C530002** (saves in `hdd\E\UDATA\4c530002`), base 0x10000, entry
  0x91EA1 (retail key), game regions World/PAL.
- **XDK 5849** for every library (XAPILIB, D3D8, D3DX8, XGRAPHC, DSOUND, XBOXKRNL, LIBCMT, LIBCPMT, XMV). The SDK
  already has 5849 signatures and `xdk/5849/layout.toml`, so no layout work as for Indy's 5120.
- Sections: .text 0x2227E8, DSOUND, D3D, D3DX, XGRPH, WMADEC, XMV, XPP, .rdata, .data, DOLBY. No XNET section.
- Data: `*.MIX` archives (CARS, GFXPAK, SFX, MENU, Tracks/*.MIX per track), music as `Music/XBOX/*.rws`
  (RenderWare audio streams), 18 movies as `Movies/XBOX/*.xmv` (XMV, decoded by the recompiled XMV/WMADEC code).
  `Saves/` on the disc holds default images (settingsimg.xbx, extradata.xbx, baddataimg.xbx).

## XDK symbols (2026-11-11)

`xbe_symbols` found 152 of 243 functions and 11 of 12 data symbols (11 DirectSound methods by .XTLID). Missing (0,
the host traps if called): Bink*, networking (WSA*, XNet*, sockets), several D3DDevice methods (SetIndices, SetPalette,
SetVertexShaderConstant1, Begin/EndPush, SetTile, ...), some DirectSound buffer/stream setters, crt sin/cos/sqrt/...
Find any that the game really calls by hand when the first boot traps on one (IndyPort method: `tools/align_symbols.py`,
callers in the generated code).

## Console settings the runtime reports (2026-11-11)

`sdk/runtime/kernel/xboxkrnl.cpp` ExQueryNonVolatileSetting: XC_LANGUAGE 1 (English), video flags widescreen (when the
output is 3:2 or wider) + 480p, factory AV region NTSC-M, game region 1 (North America). The game's language therefore
comes from XC_LANGUAGE (Xbox codes: 1 English, 3 German, 4 French, 5 Spanish, 6 Italian); a `language` setting is
planned. To check: whether this PAL title accepts the NTSC-M/60 Hz report and whether its speed depends on it.

## Setup (2026-11-11)

- `sdk/` is the XboxXBERecomp submodule (commit af21842, cloned from IndyPort's checkout, remote = GitHub).
- `sdk-patches/0001-runtime-indyport-features.patch`: IndyPort's SDK patch without its `xdk/5120` layout (settings for
  aspect, FOV, FXAA, CAS sharpening, UI upscale, video filter, texture packs, game path; guest thread affinity;
  NtSetInformationFile rename of an open file; wait/delay tracing; capture details). Game specific parts of those
  (the Hor+ HUD narrowing) stay inactive until this game's projection hook exists; first boots run with `aspect = 1`.
- Host side `src/common`: autopilot, watch, pad map and CPU pinning from IndyPort (`SCAR_AUTOPILOT`, `SCAR_WATCH`,
  `SCAR_NOPIN`); `game_info.cpp` names the game (exe SCAR.exe, game code SCAR.dll).
