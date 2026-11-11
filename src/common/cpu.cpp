// The game's threads all run on one host core, as on the single CPU Xbox, by default: code written for one CPU
// often guards shared data with plain counters (IndyPort hung on such a render lock with its threads in parallel).
// One modern core is many times the console's 733 MHz; the renderer, audio and other host threads keep the rest.
// SCAR_NOPIN=1 runs them unpinned.
#include <cstdint>
#include <cstdlib>

#include "core/log.h"
#include "kernel/kernel.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace game {

void PinGuestThreads() {
    if (std::getenv("SCAR_NOPIN")) {
        LOGR("cpu: game threads not pinned (SCAR_NOPIN)");
        return;
    }
    DWORD_PTR process = 0, system = 0;
    if (!GetProcessAffinityMask(GetCurrentProcess(), &process, &system) || !process) return;
    // the second CPU the process may use, else the first: CPU 0 takes most of the system's interrupts
    DWORD_PTR first = process & (~process + 1);
    DWORD_PTR rest = process & ~first;
    DWORD_PTR pick = rest ? rest & (~rest + 1) : first;
    kernel::g_guest_affinity = uint64_t(pick);
    LOGR("cpu: game threads on CPU mask %llX", (unsigned long long)pick);
}

}  // namespace game
