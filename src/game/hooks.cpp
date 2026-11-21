// Hooks for default.xbe. A strong definition replaces the recompiled function at that address, for example:
//
// #include "xdk/hle.h"
//
// X86_EXTERN_FUNC(__imp__sub_00012345);
// X86_FUNC(sub_00012345) {
//     __imp__sub_00012345(ctx, base);  // the original
// }
#include <algorithm>
#include <cstdlib>
#include <cstdint>
#include <unordered_map>
#include <mutex>
#include <bit>

#include "app/app.h"
#include "core/log.h"
#include "kernel/kernel.h"
#include "xdk/d3d8.h"
#include "xdk/hle.h"

namespace game {
extern uint32_t g_draw_distance;  // game_info.cpp: draw_distance in the settings, percent
extern bool g_hud_edges;          // game_info.cpp: hud_edges in the settings
}

namespace {
// a screen camera's raster: [camera+0x60], its type at raster+0x20 (2 rwRASTERTYPECAMERA, 5 a camera texture)
bool ScreenCamera(uint8_t* base, uint32_t camera) {
    uint32_t raster = camera ? X86_MEM32(camera + 0x60) : 0;
    return raster && X86_MEM8(raster + 0x20) == 2;
}
// the far planes this code set, per camera: a camera whose far plane is not one of them still has the game's
std::unordered_map<uint32_t, float> g_far_set;
std::mutex g_far_lock;
}  // namespace

// Draw distance: RwCameraSetFarClipPlane 0xAE930(camera, far) stores the far plane at camera+0x84 and rebuilds the
// projection and frustum. For a screen camera it is scaled by draw_distance (25-400 %), so the track's far geometry
// inside the frustum is drawn further out; 100 leaves the game's value. The race camera gets its far plane when it
// is made, before it has its raster, so the view window hook below scales it too, once it is known as a screen camera.
X86_EXTERN_FUNC(__imp__sub_000AE930);
X86_FUNC(sub_000AE930) {
    uint32_t camera = X86_MEM32(ctx.esp + 4);
    uint32_t percent = std::clamp(game::g_draw_distance, 25u, 400u);
    if (percent != 100 && ScreenCamera(base, camera)) {
        float far = X86_MEMF32(ctx.esp + 8) * float(percent) / 100.0f;
        X86_MEMF32(ctx.esp + 8) = far;
        std::lock_guard<std::mutex> lock(g_far_lock);
        g_far_set[camera] = far;
    }
    __imp__sub_000AE930(ctx, base);
}

// the game's far plane of a screen camera scaled, if this code has not done it (see above)
void ScaleFarPlane(X86Context& ctx, uint8_t* base, uint32_t camera) {
    uint32_t percent = std::clamp(game::g_draw_distance, 25u, 400u);
    if (percent == 100) return;
    float far = X86_MEMF32(camera + 0x84);
    {
        std::lock_guard<std::mutex> lock(g_far_lock);
        auto it = g_far_set.find(camera);
        if (it != g_far_set.end() && it->second == far) return;
    }
    LOGR("view: far clip %.1f -> %.1f (camera %08X)", far, far * float(percent) / 100.0f, camera);
    uint32_t esp = ctx.esp, eax = ctx.eax, ecx = ctx.ecx, edx = ctx.edx;
    X86_PUSH32(std::bit_cast<uint32_t>(far));  // scaled by the hook
    X86_PUSH32(camera);
    X86_PUSH32(0);  // return address, unused
    sub_000AE930(ctx, base);
    ctx.esp = esp;
    ctx.eax = eax;
    ctx.ecx = ecx;
    ctx.edx = edx;
}

// the cameras made at 0x18A600 with their view window from 0x18A748: the one the 2D layer and the race HUD are drawn
// with (3D quads at z 1 in front of it)
namespace {
std::mutex g_hud_mu;
uint32_t g_hud_cameras[4] = {};
void RememberHudCamera(uint32_t camera) {
    std::lock_guard<std::mutex> l(g_hud_mu);
    for (uint32_t& c : g_hud_cameras) {
        if (c == camera) return;
        if (!c) {
            c = camera;
            return;
        }
    }
}
bool IsHudCamera(uint32_t camera) {
    std::lock_guard<std::mutex> l(g_hud_mu);
    for (uint32_t c : g_hud_cameras)
        if (c && c == camera) return true;
    return false;
}

// the HUD at the screen's edges: RwCameraBeginUpdate (0x99AF0, a tail jump to the camera's driver function) and
// RwCameraEndUpdate (0x99B20) for the HUD camera set gpu::State::anchor while it draws, and the backend moves each
// piece left or right of the centre to that edge on a widened view (gpu/d3d12.cpp). Its 2D layer (menus, an
// orthographic projection) is left alone, so menus stay in the middle. The dead zone keeps the lap timer and
// messages in the middle together: 0.3 of the 4:3 half width either side.
constexpr uint32_t kHudDeadZone = 300;
void SetHudAnchor(bool on) {
    std::lock_guard<std::recursive_mutex> l(d3d::Lock());
    d3d::State().anchor = on && game::g_hud_edges ? kHudDeadZone : 0;
    d3d::State().hud = on ? 1 : 0;  // the scene effects (ssao, bloom) run before the HUD's first draw
}
}  // namespace


// Widescreen (Hor+) and field of view. RwCameraSetViewWindow 0xAEB30(camera, vw) stores the view window at
// camera+0x68 (reciprocals +0x70) and marks the camera's frame dirty, so the projection and the frustum's clip planes
// are made from it as the camera begins its next update. A screen camera (frame buffer raster [camera+0x60] of type
// 2, rwRASTERTYPECAMERA; type at raster+0x20) draws with the game's window (its base) times WideFactor * fov across
// and fov down. It is applied where 0xAEB30 is called, as before (the menus read the window straight back; widened
// any later they were laid out for 4:3 and drawn off to the right), and again where the camera begins its update
// (0x99AF0, below): restarting a race wrote the plain 4:3 window without 0xAEB30 (issue #1). A window equal to the
// one this code wrote is the game's own read back, not a new base, so it is never widened twice. Cameras drawing to a
// texture (type 5: reflections, mirrors) keep their view. The fov setting (70-120, percent of the game's view) scales
// both extents alike, except for the camera the 2D layer and the race HUD are drawn with (its view window set from
// 0x18A748): the HUD is 3D quads in front of it and would shrink with a wider view.
namespace {
// per camera: the window the game stored (base) and the widened one this code wrote
struct ViewWindow {
    float base_x = 0, base_y = 0, set_x = 0, set_y = 0;
    bool set = false;
};
std::unordered_map<uint32_t, ViewWindow> g_views;
std::mutex g_views_lock;

// the window a screen camera draws with, from what the game stores now (x, y): a value equal to the one this code
// stored is the game's own read back, not a new base
void TargetView(uint32_t camera, bool hud, float x, float y, float& tx, float& ty) {
    float k = app::WideFactor();
    float f = hud ? 1.0f : float(std::clamp(app::Get().fov, 70u, 120u)) / 100.0f;
    std::lock_guard<std::mutex> lock(g_views_lock);
    ViewWindow& v = g_views[camera];
    if (!v.set || x != v.set_x || y != v.set_y) {
        v.base_x = x;
        v.base_y = y;
    }
    tx = v.base_x * k * f;
    ty = v.base_y * f;
    v.set_x = tx;
    v.set_y = ty;
    v.set = true;
}
}  // namespace

X86_EXTERN_FUNC(__imp__sub_000AEB30);
X86_FUNC(sub_000AEB30) {
    uint32_t camera = X86_MEM32(ctx.esp + 4), vw = X86_MEM32(ctx.esp + 8);
    uint32_t raster = camera ? X86_MEM32(camera + 0x60) : 0;
    uint8_t type = raster ? X86_MEM8(raster + 0x20) : 0;
    bool hud = X86_MEM32(ctx.esp) == 0x18A748;
    if (hud) RememberHudCamera(camera);
    float x = vw ? X86_MEMF32(vw) : 0, y = vw ? X86_MEMF32(vw + 4) : 0, tx = x, ty = y;
    bool widen = vw && type == 2;
    if (widen) TargetView(camera, hud || IsHudCamera(camera), x, y, tx, ty);
    static int logged = 0;
    if (logged++ < 8)
        LOGR("view: camera %08X raster %08X type %u %dx%d window %.4f x %.4f -> %.4f x %.4f (from %08X)", camera, raster,
             type, raster ? X86_MEM32(raster + 0xC) : 0, raster ? X86_MEM32(raster + 0x10) : 0, x, y, tx, ty,
             X86_MEM32(ctx.esp));
    // the caller's own values are put back after the call: it may set the camera again from them
    if (widen) {
        X86_MEMF32(vw) = tx;
        X86_MEMF32(vw + 4) = ty;
    }
    __imp__sub_000AEB30(ctx, base);
    if (widen) {
        X86_MEMF32(vw) = x;
        X86_MEMF32(vw + 4) = y;
    }
    if (type == 2) ScaleFarPlane(ctx, base, camera);
}

namespace {
void WidenView(X86Context& ctx, uint8_t* base, uint32_t camera) {
    float cx = X86_MEMF32(camera + 0x68), cy = X86_MEMF32(camera + 0x6C), tx, ty;
    TargetView(camera, IsHudCamera(camera), cx, cy, tx, ty);
    if (tx == cx && ty == cy) return;
    static int logged = 0;
    if (logged++ < 16) LOGR("view: camera %08X window %.4f x %.4f -> %.4f x %.4f", camera, cx, cy, tx, ty);
    uint32_t esp = ctx.esp, eax = ctx.eax, ecx = ctx.ecx, edx = ctx.edx;
    ctx.esp -= 16;
    uint32_t vw = ctx.esp;
    X86_MEMF32(vw) = tx;
    X86_MEMF32(vw + 4) = ty;
    X86_PUSH32(vw);
    X86_PUSH32(camera);
    X86_PUSH32(0);  // return address, unused
    __imp__sub_000AEB30(ctx, base);
    ctx.esp = esp;
    ctx.eax = eax;
    ctx.ecx = ecx;
    ctx.edx = edx;
}
}  // namespace

X86_EXTERN_FUNC(__imp__sub_00099AF0);
X86_FUNC(sub_00099AF0) {
    {
        uint32_t camera = X86_MEM32(ctx.esp + 4);
        if (camera && ScreenCamera(base, camera)) {
            WidenView(ctx, base, camera);
            ScaleFarPlane(ctx, base, camera);
        }
    }
    if (IsHudCamera(X86_MEM32(ctx.esp + 4))) SetHudAnchor(true);
    __imp__sub_00099AF0(ctx, base);
}

X86_EXTERN_FUNC(__imp__sub_00099B20);
X86_FUNC(sub_00099B20) {
    if (IsHudCamera(X86_MEM32(ctx.esp + 4))) SetHudAnchor(false);
    __imp__sub_00099B20(ctx, base);
}
