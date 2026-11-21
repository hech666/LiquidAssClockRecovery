/* Manual semantic recovery from LiquidAss 6.6.7 arm64e.
 * Evidence: fieldmaps_asm.txt, fieldmap_init.txt.
 * This is one dependency, not a complete clock implementation.
 * Darwin-only flags and F_SETPROTECTIONCLASS are intentional.
 */
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

/* The binary calls its shared jailbreak-path wrapper at arm64e 0x4168.
 * Its implementation is not reconstructed in this file; provide it when linking.
 * Deliberately do not replace it with a hardcoded jailbreak root. */
extern const char *LGRecoveredResolveJBPath(const char *path, char *buffer);
static char sandyPathBuffer[4096]; /* local reconstruction storage, original size unverified */
static void *editorMap, *posterMap;
static dispatch_once_t profileOnce;
static int profileReady;
static void ensureProfile(void) {
    dispatch_once(&profileOnce, ^{
        const char *paths[] = {LGRecoveredResolveJBPath("/usr/lib/libsandy.dylib", sandyPathBuffer),
            "/var/jb/usr/lib/libsandy.dylib", "/usr/lib/libsandy.dylib"};
        for (unsigned i = 0; i < 3; ++i) {
            void *library = dlopen(paths[i], RTLD_NOW | RTLD_LOCAL);
            if (!library) continue;
            int (*apply)(const char *) = (int (*)(const char *))dlsym(library, "libSandy_applyProfile");
            if (apply) profileReady = apply("dylv.liquidass.clock-editor") == 0;
            break;
        }
    });
}
static void *mapField(const char *path, size_t length, int create, void **cached) {
    if (*cached) return *cached;
    if (create) { ensureProfile(); if (!profileReady) return 0; }
    /* Both modes use O_CREAT and a read/write mapping in the original. */
    int fd = open(path, O_RDWR | O_CREAT | O_NOFOLLOW, 0600);
    if (fd < 0) return 0;
    struct stat st;
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_uid != getuid() ||
        (st.st_mode & 077) || (create ? ftruncate(fd, length) != 0 : st.st_size != (off_t)length)) {
        close(fd); return 0;
    }
    /* Darwin command 64, protection class 4, as observed in assembly. */
    if (fcntl(fd, 64, 4) < 0) { close(fd); return 0; }
    void *p = mmap(0, length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (p == MAP_FAILED) return 0;
    return *cached = p;
}
void *LGClockEditorFieldMap(int create) {
    return mapField("/var/mobile/Library/Accessibility/liquidglass-clock-editor-field.bin",
        0x400040, create, &editorMap);
}
void *LGClockPosterFieldMap(int create, unsigned index) {
    if (index >= 16) return 0;
    unsigned char *p = mapField("/var/mobile/Library/Accessibility/liquidglass-clock-poster-fields.bin",
        0x4000400, create, &posterMap);
    return p ? p + (size_t)index * 0x400040 : 0;
}
