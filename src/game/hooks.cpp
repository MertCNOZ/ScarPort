// Hooks for default.xbe. A strong definition replaces the recompiled function at that address, for example:
//
// #include "xdk/hle.h"
//
// X86_EXTERN_FUNC(__imp__sub_00012345);
// X86_FUNC(sub_00012345) {
//     __imp__sub_00012345(ctx, base);  // the original
// }
#include <cstdint>

#include "app/app.h"
#include "core/log.h"
#include "kernel/kernel.h"

#include "xdk/hle.h"



// Widescreen without stretching (Hor+): RwCameraSetViewWindow 0xAEB30(camera, &viewWindow) stores the view window's
// half extents (tangents of the half angles) at camera+0x68 and their reciprocals at +0x70; RenderWare builds the
// projection and the frustum's clip planes from them. For a camera drawing to the screen (frame buffer raster
// [camera+0x60] of type 2, rwRASTERTYPECAMERA; type at raster+0x20), the horizontal extent is widened by
// app::WideFactor while the call runs, so the view is wider and nothing at the new edges is culled; the caller's
// own value is put back, so a camera set again from what it read keeps its size. Cameras drawing to a texture
// (type 5) keep their view.
X86_EXTERN_FUNC(__imp__sub_000AEB30);
X86_FUNC(sub_000AEB30) {
    uint32_t camera = X86_MEM32(ctx.esp + 4), vw = X86_MEM32(ctx.esp + 8);
    uint32_t raster = camera ? X86_MEM32(camera + 0x60) : 0;
    uint8_t type = raster ? X86_MEM8(raster + 0x20) : 0;
    float k = app::WideFactor();
    float x = vw ? X86_MEMF32(vw) : 0;
    bool widen = vw && k != 1.0f && type == 2;
    static int logged = 0;
    if (logged++ < 8)
        LOGR("view: camera %08X raster %08X type %u %dx%d window %.4f x %.4f%s (from %08X)", camera, raster, type,
             raster ? X86_MEM32(raster + 0xC) : 0, raster ? X86_MEM32(raster + 0x10) : 0, x, vw ? X86_MEMF32(vw + 4) : 0.0f,
             widen ? " widened" : "", X86_MEM32(ctx.esp));
    if (widen) X86_MEMF32(vw) = x * k;
    __imp__sub_000AEB30(ctx, base);
    if (widen) X86_MEMF32(vw) = x;
}
