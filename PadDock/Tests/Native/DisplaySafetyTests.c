#include "../../Sources/Bridge/DisplaySafety.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    uint32_t sole[] = {10, 20}, external[] = {10, 20, 30}, sidecar[] = {20};
    assert(!PDCanReleaseSupport(true, false, true, 10, sole, 2, sidecar, 1));
    assert(!PDCanReleaseSupport(true, true, false, 10, sole, 2, sidecar, 1));
    assert(!PDCanReleaseSupport(true, true, true, 10, sole, 2, sidecar, 1));
    assert(PDCanReleaseSupport(true, true, true, 10, external, 3, sidecar, 1));
    assert(!PDCanReleaseSupport(true, true, true, 10, NULL, 0, sidecar, 1));
    assert(PDCanReleaseSupport(false, false, false, 0, NULL, 0, NULL, 0));
    puts("Display safety: 6 assertions passed");
}
