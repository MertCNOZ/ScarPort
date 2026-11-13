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

## Menus: text and hand-found D3D symbols (2026-11-11)

- **Text drawn as dark blocks**: D3DDevice_SetPalette was not found by the signatures, so P8 (palettized) font
  textures had no palette. Found by its stores to CDevice_Palettes (+0xF98): **0x254740** (ret 8, RenderWare calls it
  at 0xB18BF). Text reads right with it.
- **Crash on START (null read at guest 4)**: RenderWare's im2D (0xBF1D8) writes raw NV2A commands through
  D3DDevice_BeginPush **0x256B60** (MakeSpace, then room for count + 1 dwords) and D3DDevice_EndPush **0x256B80**
  (stores the end at CDevice_Push, ret 4). Named, the runtime's HLE runs the pushed commands.
- **Menu strings showed other strings' glyphs** ("New Profileile", "BACKCT"): a string's vertices were overwritten by
  the next string before the draw was taken ("Delete Profile" kept "ile" after "New Profile" landed on its first 11
  quads; "SELECT" -> "BACK" + "CT"). The library waits on the vertex buffer's GPU time stamp before refilling it in
  D3D_BlockOnNonSurfaceResource, which the runtime replaces with a real wait, but the signatures missed it: found as
  **0x257120** (BlockOnTime 0x256D70 on the fence [res+8] with 0x10, or the device time when the resource is
  referenced, 0x780000). All menu text is right now.
- Remaining text detail: glyph edges show a bit of the neighbouring glyph at 2x render scale (bilinear on the font
  sheet); not caused by ui_upscale. For the graphics step.
- After the title screen the game shows its own language choice (flags: Spanish, English, Italian, ...; English lit
  with XC_LANGUAGE 1), then PROFILE MANAGEMENT (New/Load/Save/Delete Profile). B on that menu goes back to the title:
  a profile is required. `tools/ap_to_title.sh` skips the intro movies with A, checking the title text by pixels.

## Profile, test scripts, the track selection crash (2026-11-12)

- Test profile: none existed, so one profile "PLAYER" was made on purpose (New Profile, default name, no skill
  points) and saved (Profile Management > Save Profile > first slot): `hdd/E/UDATA/4c530002/A783C6F6400F`
  (savedata.dat, SaveMeta.xbx); `13AE7C41BB63` holds the game's settings.dat. Backups in `out/save_backups/`.
- Scripts: `tools/ap_to_title.sh` (intro movies skipped with A, title text checked by pixels), `tools/ap_to_main.sh`
  (START, language English, Load Profile, first slot), `tools/ap_to_tracksel.sh` (Instant Action, Laguna Seca lit).
  `tools/checkpx.ps1 -Mode yellow` checks SCAR's lit menu lines. PROFILE MANAGEMENT starts with the cursor on no
  visible line when a save exists: up, up = New Profile, down = Load Profile.
- Crash logs now name the module and offset (`in SCAR.dll+561CE3`, sdk main.cpp); `tools/addr2func.py` maps it to
  the recompiled function.
- Save times show UTC (20:45 for a 23:45 local save): the runtime's clock, to look at later.
- **Crash ~2 s after entering TRACK SELECTION (null read at guest 0x50 in 0x16C480)**, how it was traced with TEMP hooks:
  - 0x16C480 sets the filter of a sprite's texture [obj+0x68]; the sprite (vtable 0x2CFD78, made by 0xD0030 ->
    0x16CCA0(id)) has none: the texture lookup by sprite id 0x168EB0 failed for id **A9504859 = laguna_big_02**
    (iconsTrackSelBig.lib in GfxPak.mix, a TXT1 text resource list; its 88 textures are bStatic 0, loaded on demand).
  - The id comes from a 21 frame animation table (0x4EFF0: [obj+0x14] entries of (key, sprite id), index [obj+0x0C]):
    the track preview slideshow, frame 2.
  - On demand load: 0x194900 -> 0xA7EF0("IS_TrkSelBig_Laguna02") -> RwStreamRead (0xAAC70) of the chunk header gets 0
    bytes: RW errors 5 (end of stream), 0x8000001A, 0x16. Laguna01 loaded at screen entry; Laguna02 fails.
  - The txd is a virtual file inside GfxPak.mix (read function 0x1013F0, mode [f+0x44]) whose position is already
    at its size (0x80A8) when read; its data comes through a second, asynchronous GfxPak.mix handle (options 0x48 =
    FILE_NO_INTERMEDIATE_BUFFERING | NON_DIRECTORY, the .mix files are otherwise opened with 0x60 = synchronous)
    that a prefetcher (0xE6464, 0xE6D49) reads in 32 KiB chunks with OVERLAPPED.
  - With g_pending_async_io those reads return STATUS_PENDING (data already there, ov.InternalHigh 0x8000); the
    stream's poller (device +0x3C = 0x1D9370, called from 0x1D8B7B and 0x1D94C3) backs off (mode [s+0x28] 2, 4, 5)
    and calls GetOverlappedResult (0x92708) only at mode 5, so each chunk takes about 3 frames, and the prefetcher
    keeps refilling the same window (0x980000..0x9B0000). Open question: why the virtual file sees its end instead
    of waiting for the prefetched data.
  - `SCAR_NOPENDING=1` (game_info.cpp) turns pending off for comparison: then the boot deadlocks again right after
    the intro (opening Music/XBOX/M2.rws, also an async 0x48 file), so pending is needed for the music stream.
  - Solved, see "Track selection fixed" below.

## Track selection fixed; in the race (2026-11-12)

- **Root cause of the track selection crash: the runtime moved the file pointer of overlapped files.** At the
  track selection screen the game opens GfxPak.mix a second time for overlapped reads (options 0x48) and streams the
  preview pictures (IS_TrkSelBig_<track>01..04, bStatic 0) through a chunked reader:
  - the client 0xE5360 asks for 32 KiB, then the rest (168 bytes) of each 0x80A8 byte texture dictionary;
  - the reader 0xE62B0 (messages 2 open, 4 seeked, 5 read done) reads 32 KiB chunks aligned down from the file's
    offset into its buffer [ctx+0x130] and copies to the client (0xE6AC0, 0xE6573);
  - the stream (0x1D8F70, device table [stream+0x38]+0x28) reads with ReadFile + OVERLAPPED at its own position
    [stream+8] and, when a read completes (inline at 0x1D906C or in the poller 0x1D9370 at 0x1D9425), seeks the
    stream forward by the bytes read (device +0x10, relative).
  - The runtime's Transfer also set the file's position to offset + bytes for every file. NT keeps a current byte
    offset only for synchronous file objects (FILE_SYNCHRONOUS_IO_*); with both, every second chunk was read
    0x8000 too far on (traced: the chunk meant for 0xA10000 held the bytes of 0xA18000). The picture's dictionary
    then held old bytes at its end, the RW read stopped at a bad chunk header (RW errors 5, 0x8000001A, 0x16), the
    lookup by sprite id (A9504859 = laguna_big_02) failed and a sprite with no texture crashed 0x16C480.
  - Fix (sdk patch, files.cpp): `File::synchronous` from the create options; only such files move `pos`.
  - Ruled out on the way: the I/O timing (sync, pending, completion delayed 3-20 ms, data arriving late: all failed
    the same way before the fix), CPU pinning (SCAR_NOPIN), the texture packs.
- The sdk patch keeps an opt-in `kernel::g_pending_async_io_delay_us` (completion and data on a host thread after
  that many microseconds); SCAR does not need it (`SCAR_IO_DELAY_US` for tests). Pending reads stay on: without them
  the boot still deadlocks after the intro (`SCAR_NOPENDING=1`).
- **Race reached and driven** (autopilot only): Instant Action > Laguna Seca > Alfa 147 (first car) > race with 7
  AI cars, HUD (position, lap, timer, rev counter, gear, km/h) drawn right. Right trigger accelerates, the left stick
  steers (turned the car around: "WRONG WAY!"). The gearbox stayed in 1st only because the test never reached the
  shift point (see the test tools notes).
- **Game speed**: the race timer runs at real time (11.52 s in 11.51 s of wall time). Full throttle for 5 s from
  the green light gives the same place and speed (49-50 km/h, rev limit in 1st) at fps_cap 60 and 30, so the
  simulation is time based, not frame based. The runtime presents at 60 fps with a 60 Hz vertical blank while the
  game asked for a 50 Hz (PAL) mode; that does not change the game's speed.
- Tests: `tools/ap_race_accel.sh` (from track selection into the race, 5 s full throttle, HUD crops by
  `tools/crop_hud.ps1`).

## Test tools round two (2026-11-12)

- `tools/backup_saves.sh [label]`: saves to `out/save_backups/<date>_<time>[_label]`, keeps the newest 20 it made.
- `tools/ap_to_race.sh`: one command from nothing to the green light (backup, start with autopilot, intro, Load
  Profile, Instant Action, Laguna Seca, first car); refuses to run while a SCAR.exe is open (the player's).
- Autopilot: `trigger <lt|rt|a|b|x|y|black|white> <0..1> <seconds>` presses an analog button part way (merged with a
  real controller by taking the larger value), `release` drops everything still held.
- Seen with it (race start, Alfa 147): rt 0.3 for 3 s -> 4 km/h with the gear shown as N; full rt for 2 s more ->
  24 km/h in 1st; lt 0.5 for 2 s -> 11 km/h. Not a fault (user, 2026-11-12): the automatic gearbox shifts up only near
  the red line (about 7000 rpm for the 147), which the short test presses never reached; "Auto Transmission" is On in
  Options > Driving Help. The user played with a real gamepad: all buttons and the triggers work.
- A play session by the user (8 minutes, real controller) logged no error and exited cleanly.
- Decided: no steering wheel support; controls are gamepad (SDL3) and keyboard.

## Graphics: widescreen, movies, FOV, draw distance (2026-11-12)

- Display settings come from the runtime (display_mode, width/height, render_percent, fps_cap, vsync,
  anisotropic_filtering); tested windowed 1280x960 and 1600x900.
- **RenderWare camera functions** (SSE code, found from a caller that sets a view window from fptan, 0x18FA59):
  RwCameraSetViewWindow **0xAEB30** (view window at camera+0x68, reciprocals +0x70), RwCameraSetNearClipPlane
  **0xAE870** (+0x80), RwCameraSetFarClipPlane **0xAE930** (+0x84). Camera frame buffer raster at camera+0x60, raster
  type byte at raster+0x20 (2 camera, 5 camera texture), width/height at +0xC/+0x10.
- **Hor+** (hooks.cpp): the view window's x is scaled by app::WideFactor while 0xAEB30 runs, for cameras on a type 2
  raster; the caller's value is put back. Cameras seen: the boot camera (window 0.5 x 0.375, from 0x18A748: the 2D
  layer and the race HUD, 3D quads in front of it), the race camera (0.3821 x 0.2866, from 0x15F37F), a 512x128
  camera texture (from 0x18FA74, untouched).
- **2D layers stay 4:3** (sdk d3d12.cpp): RenderWare's Im2D and fonts are fixed function draws (vs 0x142, XYZ +
  diffuse + tex in console pixels) under an orthographic projection, not XYZRHW, so the HUD narrowing missed them.
  Such draws ("ortho_draw_") on the main target narrower than 90% of the screen now get hud.xy like XYZRHW ones
  (applied to the wvp's x/y columns); they count as screen draws for ui_upscale and the movie filter too. The menu
  bars and full screen backgrounds stay full width.
- **Movies** (sdk): XMV frames are 640x480 YUY2 linear textures drawn with a vertex program (vs B0001321); the movie
  check now also takes YUV textures in any draw, and hud.xy moved from the XYZRHW vertex code into the shared
  epilogue (q.xy scaled in clip space), so program draws can be fitted. Movies show 4:3 with side bars. The menu
  backgrounds are movies too, so menus have side bars while their title/bottom bars span the screen.
- **FOV** (`fov`, 70-120 %): both view window extents scaled for screen cameras except the HUD camera (0x18A748);
  `app::g_hud_follows_fov` (new sdk flag, IndyPort's behaviour by default) is false for SCAR, so the runtime does not
  scale the 2D layer either. Tested at 115: wider scene, HUD unchanged.
- **Draw distance** (`draw_distance`, 25-400 %, game option in settings.toml): the far plane of screen cameras
  scaled in 0xAE930; the race camera gets its far plane (100) when made, before it has a raster, so the view window
  hook also scales it once it is known as a screen camera (calls the setter, remembers what it set per camera).
  Tested at 200: race camera 100 -> 200, others 2000 -> 4000.
- Seen: a small grey square at the top left of TRACK SELECTION on a widened view (an item off screen at 4:3 brought
  in by the narrowing). Scripts: tools/checkpx.ps1 and crop_hud.ps1 now map 4:3 coordinates to any window size;
  ap_to_title.sh presses A at most 12 times.
- Text: the doubled glyph edges seen on the first boots ("PPlease") were the stale vertex data fixed by
  D3D_BlockOnNonSurfaceResource; menu and HUD text is clean at 4:3 and 16:9.
- Movie colours: sampled 123 intro frames, Y mostly 16..235 (a few 0/246 overshoots): XMV output is studio range,
  so the runtime's BT.601 studio range YUY2 conversion is right; the bright look is the intro's own white.
- Checked after these changes: 4:3 (1280x960) and 16:9 (1600x900) both reach the race with no error.
- Decided (user): menu background movies stay 4:3 with side bars on a widened view (no zoom to fill).

## Launcher, ScarPort.exe (2026-11-12)

- From IndyPort's launcher (`D:\Game Setups\Indy\launcher`, see portkit/LAUNCHER_REFERENCE.md): CMake target
  `ScarLauncher` (OUTPUT_NAME ScarPort) beside SCAR.exe, Win32 + D3D11 + Dear ImGui, SDL3 for controllers.
- Adapted: names (ScarPort 0.1.0, SCAR.exe, title id 4c530002), graphite and red colours, the game's buttons (LT
  brake, RT accelerate; the rest as set in the game's own Controllers > Configuration), Game page: game language
  (English, Français, Deutsch, Español, Italiano -> `game_language`, XC_LANGUAGE 1/4/3/5/6), texts and About
  (no affiliation with Milestone, Black Bean Games, Alfa Romeo, Microsoft), update repo MertCNOZ/ScarPort (not created
  yet: the check fails quietly), SCARPORT_UPDATE_URL for tests. Removed for now: the keyboard and mouse section and
  the button icon packs (the port has no keyboard input or icon packs yet).
- The runtime's game language key is `game_language` (it was `language`, which the launcher uses for its own UI
  language).
- Art: placeholder banner and icon drawn by `tools/make_launcher_art.ps1` (no game or brand images); to be replaced
  with free to use art.
- Game side: `show_fps` option and F9 toggle, frame counter drawn with ImGui from the runtime's fps (src/common/fps.cpp).
- Translations: 18 new entries in tools/lang_table.py (Turkish, Russian), launcher/lang_table.inc regenerated.
- Checked: opens, Turkish UI from Windows' language, finds the extracted game in assets, reads settings.toml. The
  user tests the pages and Play.

## Car reflections: the environment cube from render targets (2026-11-13)

- The car body draws (fixed function, vs B0166331/B0166311) take t1 = 82E9C000, a 128x128 X8R8G8B8 cube (one level,
  face stride 0x10000) with texgen `reflect(normalize(vp), vn)` times texture matrix 1; the combiner adds
  `t1 * tfactor` to the paint. Each frame the game renders three faces of it as render targets: face 0 (82E9C000, a
  side view), face 2 (82EBC000, the sky) and face 4 (82EDC000, a horizontal view). Faces 1, 3 and 5 are never
  rendered in a race (no target at their address in the whole run).
- The runtime bound render targets only for 2D textures; a cube was decoded from guest memory, which holds nothing of
  what the GPU drew (targets are not read back), so the reflection added black. `BindTargetCube` (d3d12.cpp): for a
  cube with any face that is a colour target of the cube's size, a host cube of the targets' host size (render scale:
  288x288 at 2.25) gets each face copied in when its target was written since the last copy (`Target::written`, a
  write count set by draws and clears); faces without a target are cleared black once, as the console's memory there
  is. Log line `cube 82E9C000 128x128: faces from targets 0-2-4-`.
- Checked against a run without it: sky and track highlights on the roof, boot and bumpers, which were flat red.
- 834E9080 (512x512) is not glass: draw 0476 copies the back buffer mirrored into it and two draws with ps B0101A10
  map it, the rear view mirror; it was bound as a target already.

## Race HUD at the screen's edges (2026-11-13)

- The race HUD is 3D quads (fixed function, vs B0166301, one draw per glyph or piece, each placed by its world
  matrix; the quads themselves are local, e.g. 0..0.042 x 0..0.017 at z 1) drawn with the camera made at 0x18A600
  whose view window is set from 0x18A748 (the same camera draws the 2D layer of the menus, under an orthographic
  projection). On a widened view (Hor+) it stayed in the 4:3 area in the middle.
- RwCameraBeginUpdate is **0x99AF0** and RwCameraEndUpdate **0x99B20** (both tail jumps through the camera's driver
  table, `jmp [ecx+eax+0x10]` / `+0x14`). hooks.cpp remembers the HUD camera from the view window hook and, while it
  draws, sets `gpu::State::anchor` (a new last field of the runtime's State, so the render thread gets it with the
  rest) to the dead zone, 300/1000 of the 4:3 half width.
- The backend (d3d12.cpp, Draw): for a draw with anchor set, the fixed function's transform, not pretransformed and
  not orthographic, on the main target, the vertices' clip x span under world x view x projection (NdcSpanX now
  divides by w, which is 1 for the orthographic case) gives the piece's centre in 4:3 units; left of the dead zone it
  moves left by 1 - 1/WideFactor in clip space, right of it right by as much (hud.z, folded into the wvp's x column as
  x + shift * w). Pieces inside the dead zone (the lap timer, messages in the middle) stay. Each glyph moves alone,
  so a text crossing the dead zone's edge would come apart; none of the race HUD does.
- The pause menu (the 2D layer) stays in the middle. Setting `hud_edges` (on by default; launcher: Graphics, Text and
  HUD, "HUD at the screen edges"). Checked at 1920x1080: position and lap top left, best and last top right, track
  map left, speedometer bottom left, timer in the middle; with hud_edges = false all as before.

## Modern Xbox button icons: overlays on the menu atlases (2026-11-13)

- The game's A/B/X/Y icons are coloured gems (18x23 texels, two of each per atlas, normal and lit) inside the menu
  atlases, beside PlayStation icons, PC key caps and other menu art (512x128 b17b1f7c7bdae1f0, f21ef600f853b196;
  512x256 fa4e4282afbc6613; 512x512 9bb686564c6f0e2c, de07cd17538dd95b, keys from a texture dump of the menus,
  track and car selection and a race). Replacing the whole atlas would ship the game's art.
- SDK texture packs take overlays: `<size>_<key>_overlay.png`. texturedumper::Overlay (called from LatchPackKey for
  every texture, not only screen space ones) makes the player's own texture (its ui_upscale copy when that is on,
  else bilinear) at the overlay's size and keeps the overlay's pixel wherever its alpha is not 0; alpha 1/255 pixels
  clear what is under them. The result is handed out by Take like an upscaled copy.
- tools/find_button_gems.ps1 finds the gems in dumps (connected solid patches, saturated, by hue; boxes 17-19 wide
  are the gems, smaller hits are font digits). tools/make_button_icons.ps1 (rewritten from IndyPort's, same Face
  drawing) writes one overlay per atlas at 4x: each gem's box plus 1 texel cleared (GDI+ needs SourceCopy for the
  alpha 1 fill, blending turned it into 0) and a dark round button with the coloured letter drawn in it. CMake's
  texture_packs target copies packs/ to textures/packs; texture_packs defaults to modern_buttons when the settings
  file has no key; launcher Controls, Button icons: Modern Xbox / Original Xbox.
- Checked: track selection and main menu prompts show the new A and B buttons, no gem left around them. Atlases of
  screens not dumped yet (options, results, multiplayer) keep their gems until their boxes are added.
