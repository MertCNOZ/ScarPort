// The frame counter: frames per second and frame time in the top left corner of the game window, from the rate the
// runtime presents at (app::GameInfo::ui gets it every frame). show_fps in the settings starts it on; F9 in the game
// turns it on and off for this run.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <algorithm>
#include <cfloat>
#include <cstdint>
#include <cstdio>

#include <imgui.h>

namespace game {

bool g_show_fps = true;

void FpsOverlay(double fps) {
    // the game shows no cursor: ImGui would set the arrow on every WM_SETCURSOR
    ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;
    if (!g_show_fps) return;
    double ms = fps > 0 ? 1000.0 / fps : 0;
    ImGuiIO& io = ImGui::GetIO();
    float scale = std::max(1.0f, io.DisplaySize.y / 720.0f);
    char text[48];
    std::snprintf(text, sizeof(text), "%.0f FPS  %.1f ms", fps, ms);
    ImFont* font = ImGui::GetFont();
    float size = ImGui::GetFontSize() * 1.4f * scale;
    ImVec2 ts = font->CalcTextSizeA(size, FLT_MAX, 0, text);
    float pad = 6 * scale;
    ImVec2 at(12 * scale, 12 * scale);
    ImDrawList* d = ImGui::GetForegroundDrawList();
    d->AddRectFilled(at, ImVec2(at.x + ts.x + pad * 2, at.y + ts.y + pad * 2), IM_COL32(0, 0, 0, 150), 4 * scale);
    ImU32 colour = fps >= 55 ? IM_COL32(120, 230, 120, 255) : fps >= 28 ? IM_COL32(240, 210, 90, 255)
                                                                       : IM_COL32(240, 100, 90, 255);
    d->AddText(font, size, ImVec2(at.x + pad, at.y + pad), colour, text);
}

// F9 turns the counter on and off; nothing is taken from the game
bool FpsMessage(void*, uint32_t msg, uintptr_t wp, intptr_t lp, intptr_t*) {
    if (msg == WM_KEYDOWN && wp == VK_F9 && !(lp & (1 << 30))) g_show_fps = !g_show_fps;
    return false;
}

}  // namespace game
