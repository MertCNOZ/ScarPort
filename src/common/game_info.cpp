// What the runtime asks of the game: names, settings and the hooks into the host (input, window, overlay).
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <atomic>

#include <toml++/toml.hpp>

#include "app/app.h"
#include "core/input.h"
#include "core/log.h"

namespace game {
void PinGuestThreads();                       // cpu.cpp
void StartAutopilot();                        // autopilot.cpp
void StartWatch();                            // watch.cpp
void AutopilotPad(int port, input::Pad& pad);  // autopilot.cpp
void LoadPadMap(const void* table);            // pad_map.cpp
void SavePadMap(void* table);
void MapPad(int port, input::Pad& pad);
uint32_t g_rumble = 100;  // percent of the game's rumble

// the controller's rumble scaled by the rumble setting
void Rumble(int, uint16_t& left, uint16_t& right) {
    if (g_rumble >= 100) return;
    left = uint16_t(uint32_t(left) * g_rumble / 100);
    right = uint16_t(uint32_t(right) * g_rumble / 100);
}

void Load(const void* table) { LoadPadMap(table); }
void Save(void* table) { SavePadMap(table); }

// before the window and boot: guest threads on one core, the autopilot if SCAR_AUTOPILOT is set
void Init() {
    PinGuestThreads();
    StartAutopilot();
    StartWatch();
}

// the controller's buttons as mapped in the settings, then the autopilot's presses on top; a real controller
// plugging in or out is logged
void Pad(int port, input::Pad& pad) {
    static std::atomic<bool> real[4];
    if (port >= 0 && port < 4 && real[port].exchange(pad.connected) != pad.connected)
        LOGR("input: controller %s on port %d", pad.connected ? "connected" : "disconnected", port + 1);
    MapPad(port, pad);
    AutopilotPad(port, pad);
}
}  // namespace game

const app::GameInfo app::kGame = {
    .title = L"SCAR - Squadra Corse Alfa Romeo",  // window and splash
    .short_title = L"SCAR",                        // message boxes
    .name = L"SCAR",                               // window classes, crash dumps, handover event
    .log = "scar",                                 // log file prefix
    .settings = "settings.toml",                   // settings file beside the exe
    .splash = L"splash",                           // optional splash.png or splash.bmp beside the exe
    .missing = L"The game was not found. Open ScarPort.exe and choose your disc image (.iso) or the folder of the "
               L"extracted game (with default.xbe), or put either in the assets folder beside the game.",
    .images = {{"default.xbe", "SCAR"}},  // each recompiled xbe and its exe, for title launches
    .options = {{"rumble", nullptr, &game::g_rumble}},
    .load = game::Load,
    .save = game::Save,
    .init = game::Init,
    .loaded = nullptr,
    .window = nullptr,
    .message = nullptr,
    .ui = nullptr,
    .pad = game::Pad,
    .rumble = game::Rumble,
};
