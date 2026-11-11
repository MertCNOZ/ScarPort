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

## First boot (2026-11-11)

1. **Exit at start, KeBugCheck 0 at 0x217E0A.** That is the CRT exit path (0x217E20 -> doexit -> KeBugCheck): 0x49070
   calls the engine start 0x1675E0, which returned 0x4008, and exits with code 3 on any result above 0x4000. TEMP
   return-value hooks walked it down: 0x1675E0 -> 0x1672C0 (RenderWare engine init/open/start) -> 0xA7030 (open) ->
   0xA6F70 -> the RW Xbox device system function 0xB68B0 (device block 0x2EC080, [+4]), request 0 (open) ->
   0xB59F0, which looks for the requested video mode in the D3D mode list (Direct3D_GetAdapterModeCount 0x2582C0,
   EnumAdapterModes 0x258360) and fails without a match.
   - Requested: 640x480, refresh **50**, flags 0x40/0x20. The runtime reported an NTSC-M console (AV region
     0x00400100), so D3D listed only 60 Hz modes.
   - Fix (sdk patch): settings `tv_standard` (0 NTSC-M, 1 PAL-I 50 Hz, 2 PAL-I with PAL60) and `language` (XC_LANGUAGE).
     PAL reports AV region 0x00800300 (PAL-I, 50 Hz) in ExQueryNonVolatileSetting 0x103, the EEPROM image and
     AvSendTVEncoderOption's capabilities, game region 4; PAL60 adds video flag 0x00400000. With PAL D3D lists
     640x480/720x480/640x576 at 50 Hz and RenderWare opens. SCAR's default (game_info.cpp Load) is 1.
2. **Indirect call to 0x2195F0** (a CRT string routine, not found as a function): added to `[functions]`.
3. **Black screen after the intro movie: self-deadlock on the stream lock.** The main thread waited forever in
   0x205B10 on the semaphore [0x324DF8] (WaitForSingleObject wrapper 0x93FB9, release 0x93EFD = ReleaseSemaphore),
   which it already held. TEMP hooks on the wrappers with kernel::LogGuestStack showed the nesting: 0x205B10 (a file
   device's message handler, lock held) -> 0x1D8970 (stream read through a vtable) -> 0x1D8F70, which calls
   ReadFile (0x9373D) with an OVERLAPPED; if ReadFile returns TRUE it calls the completion 0x1D9900 at once, which
   calls back into 0x205B10 -> lock again. Only ReadFile = FALSE with ERROR_IO_PENDING (0x3E5) defers the
   completion. On the console DVD reads are pending; the runtime finished them and returned STATUS_SUCCESS.
   - Fix (sdk patch): `kernel::g_pending_async_io` (opt in, SCAR sets it in game_info.cpp Init). Files opened without
     FILE_SYNCHRONOUS_IO_* remember `async`; their reads and writes still complete at once (IoStatus, event, APC)
     but return STATUS_PENDING (0x103). The title sees the result on its next poll, outside its lock.
4. Result: intro movies play (XMV, recompiled decoder; colours look washed out, to check), then the title screen
   "Please press START to begin" in English. Its text draws as dark blocks: next.

- Build note: the runtime rebuilds the game code in the exe (~5.5 min) when SCAR.dll looks older than SCAR.exe or its
  stamp (`out/build/release/compiler/work/SCAR/built.txt`) names another exe. `tools/dev_build.ps1` builds with
  cmake, deletes that stamp and touches the DLL.
