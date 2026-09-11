/*
 * bootstrapper/main.c - Native Bionic C Launcher for Google Antigravity CLI on Termux
 * 
 * Clears environment variable conflicts (LD_PRELOAD, GODEBUG), configures dynamic
 * link paths for glibc compatibility on Android, locates the glibc dynamic loader,
 * and launches core engine (agy.va39).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <limits.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

int main(int argc, char *argv[]) {
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len == -1) {
        perror("[agy-bootstrapper] Error: Unable to resolve executable path");
        return 1;
    }
    exe_path[len] = '\0';

    char *dir = dirname(exe_path);
    char target_bin[PATH_MAX];
    snprintf(target_bin, sizeof(target_bin), "%s/agy.va39", dir);

    char *prefix = getenv("PREFIX");
    if (!prefix || prefix[0] == '\0') {
        prefix = "/data/data/com.termux/files/usr";
    }

    if (access(target_bin, F_OK) != 0) {
        /* Fallback: If running under glibc-runner or ld.so, dirname(exe_path) resolves to glibc/lib.
           Fallback to checking the standard Termux bin path */
        snprintf(target_bin, sizeof(target_bin), "%s/bin/agy.va39", prefix);
    }

    if (access(target_bin, F_OK) != 0) {
        fprintf(stderr, "[agy-bootstrapper] Error: Core engine binary '%s' not found.\n", target_bin);
        fprintf(stderr, "Ensure both 'agy' and 'agy.va39' reside in the same directory.\n");
        return 1;
    }

    /* Clear interfering Android Termux environment variables */
    unsetenv("LD_PRELOAD");

    /* Ensure Go DNS networking compatibility in Termux glibc */
    if (!getenv("GODEBUG")) {
        setenv("GODEBUG", "netdns=cgo", 1);
    }

    /* Ensure SSL certificate environment variable is set if missing */
    if (!getenv("SSL_CERT_FILE")) {
        char cert_path[PATH_MAX];
        snprintf(cert_path, sizeof(cert_path), "%s/etc/tls/cert.pem", prefix);
        if (access(cert_path, F_OK) == 0) {
            setenv("SSL_CERT_FILE", cert_path, 1);
        }
    }

    /* Ensure TMPDIR is set */
    if (!getenv("TMPDIR")) {
        char tmp_path[PATH_MAX];
        snprintf(tmp_path, sizeof(tmp_path), "%s/tmp", prefix);
        if (access(tmp_path, F_OK) == 0) {
            setenv("TMPDIR", tmp_path, 1);
        }
    }

    /* Locate glibc dynamic linker */
    char glibc_lib[PATH_MAX];
    snprintf(glibc_lib, sizeof(glibc_lib), "%s/glibc/lib", prefix);

    const char *candidate_loaders[] = {
        "ld-linux-aarch64.so.1",
        "ld.so",
        "ld-linux-x86-64.so.2",
        "ld-linux-armhf.so.3",
        NULL
    };

    char loader_path[PATH_MAX] = "";
    for (int i = 0; candidate_loaders[i] != NULL; i++) {
        char test_path[PATH_MAX];
        snprintf(test_path, sizeof(test_path), "%s/%s", glibc_lib, candidate_loaders[i]);
        if (access(test_path, X_OK) == 0 || access(test_path, F_OK) == 0) {
            strncpy(loader_path, test_path, sizeof(loader_path) - 1);
            break;
        }
    }

    /* If not found in glibc/lib, also check glibc/bin/ld.so */
    if (loader_path[0] == '\0') {
        char test_path[PATH_MAX];
        snprintf(test_path, sizeof(test_path), "%s/glibc/bin/ld.so", prefix);
        if (access(test_path, X_OK) == 0 || access(test_path, F_OK) == 0) {
            strncpy(loader_path, test_path, sizeof(loader_path) - 1);
        }
    }

    /* 1. Primary execution path: Direct Glibc Dynamic Linker */
    if (loader_path[0] != '\0') {
        char **new_argv = malloc((argc + 4) * sizeof(char *));
        if (!new_argv) {
            perror("[agy-bootstrapper] Error: Memory allocation failed");
            return 1;
        }

        new_argv[0] = loader_path;
        new_argv[1] = "--library-path";
        new_argv[2] = glibc_lib;
        new_argv[3] = target_bin;
        for (int i = 1; i < argc; i++) {
            new_argv[3 + i] = argv[i];
        }
        new_argv[3 + argc] = NULL;

        execv(loader_path, new_argv);
        /* If execv returns, it failed; free and fall through */
        free(new_argv);
    }

    /* 2. Fallback execution path: glibc-runner */
    char runner_path[PATH_MAX];
    snprintf(runner_path, sizeof(runner_path), "%s/bin/glibc-runner", prefix);
    if (access(runner_path, X_OK) == 0) {
        char **new_argv = malloc((argc + 2) * sizeof(char *));
        if (new_argv) {
            new_argv[0] = runner_path;
            new_argv[1] = target_bin;
            for (int i = 1; i < argc; i++) {
                new_argv[1 + i] = argv[i];
            }
            new_argv[1 + argc] = NULL;

            execv(runner_path, new_argv);
            free(new_argv);
        }
    }

    /* 3. Fallback execution path: QEMU user emulation (legacy 32-bit userlands) */
    char qemu_path[PATH_MAX];
    snprintf(qemu_path, sizeof(qemu_path), "%s/bin/qemu-aarch64", prefix);
    if (access(qemu_path, X_OK) == 0) {
        char **new_argv = malloc((argc + 5) * sizeof(char *));
        if (new_argv) {
            new_argv[0] = qemu_path;
            new_argv[1] = "-L";
            new_argv[2] = prefix;
            new_argv[3] = target_bin;
            for (int i = 1; i < argc; i++) {
                new_argv[3 + i] = argv[i];
            }
            new_argv[3 + argc] = NULL;

            execv(qemu_path, new_argv);
            free(new_argv);
        }
    }

    /* 4. Direct invocation fallback */
    char **direct_argv = malloc((argc + 1) * sizeof(char *));
    if (direct_argv) {
        direct_argv[0] = target_bin;
        for (int i = 1; i < argc; i++) {
            direct_argv[i] = argv[i];
        }
        direct_argv[argc] = NULL;
        execv(target_bin, direct_argv);
        free(direct_argv);
    }

    fprintf(stderr, "[agy-bootstrapper] Error: Cannot execute '%s'.\n", target_bin);
    fprintf(stderr, "[agy-termux] Glibc loader was not found or failed to execute.\n");
    fprintf(stderr, "[agy-termux] Please install glibc in Termux:\n");
    fprintf(stderr, "  pkg install -y glibc-repo glibc\n");
    return 1;
}
