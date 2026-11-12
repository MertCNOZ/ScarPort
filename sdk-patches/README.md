# Local XboxXBERecomp changes

`build.bat` applies these to the `sdk` submodule (once; a patch already in place is skipped). Regenerate after
changing the SDK:

```
git -C sdk add -N <new files>
git -C sdk diff > sdk-patches/0001-runtime-indyport-features.patch
```

- `0001-runtime-indyport-features.patch`: IndyPort's runtime changes (github.com/MertCNOZ/IndyPort) without its XDK
  5120 layout: settings (aspect, FOV, FXAA, sharpening, UI upscale, video filter, texture packs, game path), guest
  thread affinity, renaming an open file, wait/delay tracing (`XBE_TRACE_WAIT`, `XBE_TRACE_DELAY`), richer captures.
- SCAR additions: `tv_standard` and `language` settings (PAL AV region and 50 Hz modes, XC_LANGUAGE);
  `kernel::g_pending_async_io` (overlapped reads return STATUS_PENDING) with an optional completion delay;
  only synchronous file objects keep a current byte offset; crash logs name module+offset; file opens log their
  create options and handle.
