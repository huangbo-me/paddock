#ifndef PD_DISPLAY_SAFETY_H
#define PD_DISPLAY_SAFETY_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
// Unknown system state must never authorize releasing the supporting screen.
static inline bool PDCanReleaseSupport(bool hasAnchor, bool interfaceKnown, bool classificationKnown,
                                      uint32_t anchor, const uint32_t *online, size_t onlineCount,
                                      const uint32_t *sidecar, size_t sidecarCount) {
    if (!hasAnchor) return true;
    if (!interfaceKnown || !classificationKnown || !anchor) return false;
    for (size_t i = 0; i < onlineCount; i++) {
        if (online[i] == anchor) continue;
        bool isSidecar = false;
        for (size_t j = 0; j < sidecarCount; j++) if (online[i] == sidecar[j]) isSidecar = true;
        if (!isSidecar) return true;
    }
    return false;
}
#endif
