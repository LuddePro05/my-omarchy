#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <dirent.h>
#include <sys/socket.h>
#include <sys/un.h>

static const char *const prefixes[] = {
    "openwindow>>",
    "closewindow>>",
    "destroyworkspace>>",
    "destroyworkspacev2>>",
    "activewindow>>",
    "activewindowv2>>",
    "fullscreen>>",
    "workspace>>",
    "workspacev2>>",
    "focusedmon>>",
    "changefloatingmode>>",
    "movewindow>>",
    "movewindowv2>>"
};
#define NUM_PREFIXES (sizeof(prefixes) / sizeof(prefixes[0]))

static int matches_prefix(const char *line) {
    for (size_t i = 0; i < NUM_PREFIXES; i++) {
        size_t len = strlen(prefixes[i]);
        if (strncmp(line, prefixes[i], len) == 0) return 1;
    }
    return 0;
}

int main(void) {
    signal(SIGPIPE, SIG_IGN);

    const char *xdg = getenv("XDG_RUNTIME_DIR");
    char default_xdg[64];
    if (!xdg || !xdg[0]) {
        snprintf(default_xdg, sizeof(default_xdg), "/run/user/%u", (unsigned)getuid());
        xdg = default_xdg;
    }

    const char *sig = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    char found_sig[256] = {0};

    if (!sig || !sig[0]) {
        char hypr_dir[512];
        snprintf(hypr_dir, sizeof(hypr_dir), "%s/hypr", xdg);
        DIR *d = opendir(hypr_dir);
        if (d) {
            struct dirent *ent;
            while ((ent = readdir(d)) != NULL) {
                if (ent->d_name[0] == '.') continue;
                char test_sock[1024];
                snprintf(test_sock, sizeof(test_sock), "%s/%s/.socket2.sock", hypr_dir, ent->d_name);
                if (access(test_sock, F_OK) == 0) {
                    snprintf(found_sig, sizeof(found_sig), "%s", ent->d_name);
                    sig = found_sig;
                    break;
                }
            }
            closedir(d);
        }
    }

    if (!sig || !sig[0]) {
        fprintf(stderr, "hypr-events: HYPRLAND_INSTANCE_SIGNATURE not set and no active Hyprland socket found\n");
        return 1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (snprintf(addr.sun_path, sizeof(addr.sun_path), "%s/hypr/%s/.socket2.sock", xdg, sig) >= (int)sizeof(addr.sun_path)) {
        fprintf(stderr, "hypr-events: socket path exceeds sockaddr_un limit\n");
        return 1;
    }

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("hypr-events socket");
        return 1;
    }

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        perror("hypr-events connect");
        close(fd);
        return 1;
    }

    FILE *fp = fdopen(fd, "r");
    if (!fp) {
        perror("hypr-events fdopen");
        close(fd);
        return 1;
    }

    char *line = NULL;
    size_t len = 0;
    while (getline(&line, &len, fp) != -1) {
        if (matches_prefix(line)) {
            if (fputs(line, stdout) == EOF || fflush(stdout) == EOF) break;
        }
    }

    free(line);
    fclose(fp);
    return 0;
}
