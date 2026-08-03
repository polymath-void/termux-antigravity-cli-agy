/*
 * bootstrapper/main.c - Native Bionic C Launcher for Google Antigravity CLI on Termux
 * 
 * Clears environment variable conflicts (LD_PRELOAD, GODEBUG), configures dynamic
 * link paths for glibc compatibility on Android, and launches core engine (agy.va39).
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

    if (access(target_bin, F_OK) != 0) {
        fprintf(stderr, "[agy-bootstrapper] Error: Core engine binary '%s' not found.\n", target_bin);
        fprintf(stderr, "Ensure both 'agy' and 'agy.va39' reside in the same directory.\n");
        return 1;
    }

    /* Clear interfering Android Termux environment variables */
    unsetenv("LD_PRELOAD");

    /* Ensure SSL certificate environment variable is set if missing */
    if (!getenv("SSL_CERT_FILE")) {
        char cert_path[PATH_MAX];
        char *prefix = getenv("PREFIX");
        if (prefix) {
            snprintf(cert_path, sizeof(cert_path), "%s/etc/tls/cert.pem", prefix);
        } else {
            snprintf(cert_path, sizeof(cert_path), "/data/data/com.termux/files/usr/etc/tls/cert.pem");
        }
        if (access(cert_path, F_OK) == 0) {
            setenv("SSL_CERT_FILE", cert_path, 1);
        }
    }

    /* Ensure TMPDIR is set */
    if (!getenv("TMPDIR")) {
        char *prefix = getenv("PREFIX");
        if (prefix) {
            char tmp_path[PATH_MAX];
            snprintf(tmp_path, sizeof(tmp_path), "%s/tmp", prefix);
            setenv("TMPDIR", tmp_path, 1);
        } else if (access("/data/data/com.termux/files/usr/tmp", F_OK) == 0) {
            setenv("TMPDIR", "/data/data/com.termux/files/usr/tmp", 1);
        }
    }

    /* Build execv arguments */
    char **new_argv = malloc((argc + 1) * sizeof(char *));
    if (!new_argv) {
        perror("[agy-bootstrapper] Error: Memory allocation failed");
        return 1;
    }

    new_argv[0] = target_bin;
    for (int i = 1; i < argc; i++) {
        new_argv[i] = argv[i];
    }
    new_argv[argc] = NULL;

    execv(target_bin, new_argv);

    perror("[agy-bootstrapper] Error: execv failed to launch agy.va39");
    free(new_argv);
    return 1;
}
