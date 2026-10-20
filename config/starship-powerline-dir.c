#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <math.h>

typedef struct {
    const char *name;
    const char *icon;
} IconRule;

static const IconRule ICON_RULES[] = {
    {"videos", ""},
    {"pictures", "󰉏"},
    {"documents", "󰲂"},
    {"downloads", "󰉍"},
    {"music", "󱍙"},
    {"projects", ""},
    {"omasend", ""},
    {"tries", ""},
    {"work", ""},
    {"desktop", "󰇄"},
    {"developer", "󰲋"},
    {".config", ""},
    {".ssh", "󰢬"},
    {".git", ""},
    {"node_modules", ""},
    {"hypr", "󰌽"},
    {"omarchy", "󰣇"},
    {"alacritty", "󰞷"},
    {"kitty", "󰞷"},
    {"ghostty", "󰞷"},
    {"eza", ""},
    {"starship", "󱆃"},
    {"lth", "󰑴"},
    {"ai_funsies", "󰚩"},
    {"claude-desktop-native", "󰚩"},
    {"go", ""},
    {"src", ""},
    {"bin", ""},
    {NULL, NULL}
};

/* Color gradient points:
 * C_DARK: Deep navy blue (#1e3a5f, 30, 58, 95) matching Arch logo and Starship deep_blue.
 * C_PEAK: Medium ocean blue (#487ec4, 72, 126, 196) at the middle of the terminal.
 * C_GIT: Catppuccin mocha yellow (#f9e2af, 249, 226, 175) for the git section.
 * C_GIT_FG: Dark crust text (#11111b, 17, 17, 27) for high contrast on yellow. */
static const int C_DARK[3]   = {30, 58, 95};
static const int C_PEAK[3]   = {72, 126, 196};
static const int C_GIT[3]    = {249, 226, 175};
static const int C_GIT_FG[3] = {17, 17, 27};

static void interp_color(int dst[3], double t) {
    if (t < 0.0) t = 0.0;
    if (t > 1.0) t = 1.0;
    dst[0] = C_DARK[0] + (int)((C_PEAK[0] - C_DARK[0]) * t);
    dst[1] = C_DARK[1] + (int)((C_PEAK[1] - C_DARK[1]) * t);
    dst[2] = C_DARK[2] + (int)((C_PEAK[2] - C_DARK[2]) * t);
}

static int get_terminal_width(void) {
    struct winsize ws;
    if (ioctl(STDERR_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) return ws.ws_col;
    if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) return ws.ws_col;
    int fd = open("/dev/tty", O_RDONLY);
    if (fd >= 0) {
        if (ioctl(fd, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
            close(fd);
            return ws.ws_col;
        }
        close(fd);
    }
    const char *env_c = getenv("COLUMNS");
    if (env_c) {
        int c = atoi(env_c);
        if (c > 0) return c;
    }
    return 80;
}

typedef struct {
    int is_git;
    char branch[128];
    int is_dirty;
} GitInfo;

static GitInfo get_git_info(const char *pwd) {
    GitInfo info;
    memset(&info, 0, sizeof(info));
    char curr[4096];
    snprintf(curr, sizeof(curr), "%s", pwd);

    while (curr[0]) {
        char cand[8192];
        snprintf(cand, sizeof(cand), "%s/.git", curr);

        struct stat st;
        if (stat(cand, &st) == 0) {
            char head_path[8192] = {0};
            if (S_ISDIR(st.st_mode)) {
                snprintf(head_path, sizeof(head_path), "%s/HEAD", cand);
            } else if (S_ISREG(st.st_mode)) {
                FILE *f = fopen(cand, "r");
                if (f) {
                    char line[4096];
                    if (fgets(line, sizeof(line), f)) {
                        char *p = line;
                        while (*p == ' ' || *p == '\t') p++;
                        if (strncmp(p, "gitdir:", 7) == 0) {
                            p += 7;
                            while (*p == ' ' || *p == '\t') p++;
                            char *end = p + strlen(p) - 1;
                            while (end >= p && (*end == '\n' || *end == '\r' || *end == ' ')) {
                                *end = '\0';
                                end--;
                            }
                            if (p[0] == '/') {
                                snprintf(head_path, sizeof(head_path), "%s/HEAD", p);
                            } else {
                                snprintf(head_path, sizeof(head_path), "%s/%s/HEAD", curr, p);
                            }
                        }
                    }
                    fclose(f);
                }
            }

            if (head_path[0]) {
                FILE *hf = fopen(head_path, "r");
                if (hf) {
                    char hline[256];
                    if (fgets(hline, sizeof(hline), hf)) {
                        char *p = hline;
                        while (*p == ' ' || *p == '\t') p++;
                        char *end = p + strlen(p) - 1;
                        while (end >= p && (*end == '\n' || *end == '\r' || *end == ' ')) {
                            *end = '\0';
                            end--;
                        }
                        if (strncmp(p, "ref: refs/heads/", 16) == 0) {
                            snprintf(info.branch, sizeof(info.branch), "%s", p + 16);
                            info.is_git = 1;
                        } else if (strlen(p) >= 7) {
                            snprintf(info.branch, 8, "%s", p);
                            info.is_git = 1;
                        }
                    }
                    fclose(hf);
                }
            }

            if (info.is_git) {
                char cmd[8192];
                snprintf(cmd, sizeof(cmd), "git -C \"%s\" diff-index --quiet HEAD -- 2>/dev/null", curr);
                int ret = system(cmd);
                if (ret != 0) {
                    info.is_dirty = 1;
                }
            }
            break;
        }

        char *slash = strrchr(curr, '/');
        if (!slash || slash == curr) break;
        *slash = '\0';
    }
    return info;
}

/* Calculate color based on column position:
 * Dark on the sides (col 0 and col W-1), light in the middle of the terminal (col W/2) */
static void get_column_color(int dst[3], double col, int term_width) {
    double mid = (double)term_width / 2.0;
    double dist = (col < mid) ? col : ((double)term_width - 1.0 - col);
    if (dist < 0.0) dist = 0.0;
    double t = pow(dist / mid, 0.75);
    interp_color(dst, t);
}

int main(int argc, char *argv[]) {
    int is_right = (argc > 1 && strcmp(argv[1], "--right") == 0);
    int term_width = get_terminal_width();
    if (term_width < 40) term_width = 80;

    const char *pwd = getenv("PWD");
    const char *home = getenv("HOME");
    char path_buf[4096];

    if (!pwd) {
        if (!getcwd(path_buf, sizeof(path_buf)))
            return 0;
        pwd = path_buf;
    }

    if (!is_right) {
        /* LEFT SIDE: Subdirectories + Git within the main header */
        char segments[128][256];
        int seg_count = 0;

        if (home && strcmp(pwd, home) == 0) {
            strcpy(segments[seg_count++], "~");
        } else if (home && strncmp(pwd, home, strlen(home)) == 0 && pwd[strlen(home)] == '/') {
            strcpy(segments[seg_count++], "~");
            const char *p = pwd + strlen(home) + 1;
            while (*p) {
                const char *slash = strchr(p, '/');
                size_t len = slash ? (size_t)(slash - p) : strlen(p);
                if (len > 0 && len < 255 && seg_count < 128) {
                    memcpy(segments[seg_count], p, len);
                    segments[seg_count][len] = '\0';
                    seg_count++;
                }
                if (!slash) break;
                p = slash + 1;
            }
        } else {
            strcpy(segments[seg_count++], "/");
            const char *p = (*pwd == '/') ? pwd + 1 : pwd;
            while (*p) {
                const char *slash = strchr(p, '/');
                size_t len = slash ? (size_t)(slash - p) : strlen(p);
                if (len > 0 && len < 255 && seg_count < 128) {
                    memcpy(segments[seg_count], p, len);
                    segments[seg_count][len] = '\0';
                    seg_count++;
                }
                if (!slash) break;
                p = slash + 1;
            }
        }

        /* Check git status to integrate into main header */
        GitInfo git = get_git_info(pwd);

        /* Arch logo sits at columns 0..5 (C_DARK #1e3a5f) */
        int prev_c[3] = {C_DARK[0], C_DARK[1], C_DARK[2]};
        double cur_col = 6.0;

        for (int i = 0; i < seg_count; i++) {
            const char *part = segments[i];

            /* Icons: match rule, home (󰋜), or default folder () */
            const char *icon = "";
            if (strcmp(part, "~") == 0) {
                icon = "󰋜";
            } else if (strcmp(part, "/") == 0) {
                icon = "󰌽";
            } else {
                for (int r = 0; ICON_RULES[r].name; r++) {
                    if (strcasecmp(part, ICON_RULES[r].name) == 0) {
                        icon = ICON_RULES[r].icon;
                        break;
                    }
                }
            }

            /* Add slash between subdirectories: parents get trailing slash */
            const char *slash = (i < seg_count - 1 && strcmp(part, "/") != 0) ? "/" : "";

            /* Visible length:
             * For i == 0: 1 space before icon, 1 space after icon, name, slash/space
             * For i > 0: tight directly against arrow, icon, 1 space, name, slash/space */
            int visible_len = (i == 0) ? ((int)strlen(part) + 4) : ((int)strlen(part) + 3);

            double start_col = cur_col + 1.0;
            double end_col = start_col + (double)visible_len - 1.0;
            double center_col = (start_col + end_col) / 2.0;

            int curr_c[3];
            double t = (seg_count <= 1) ? 0.6 : (0.15 + 0.85 * (double)i / (double)(seg_count - 1));
            interp_color(curr_c, t);

            /* Powerline arrow into this segment */
            printf("\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm",
                   prev_c[0], prev_c[1], prev_c[2],
                   curr_c[0], curr_c[1], curr_c[2]);

            /* Segment content:
             * Tight spacing: no space after slash so slash goes directly into arrow.
             * Subdirectories after the first start directly with the icon without leading space. */
            if (i == 0) {
                if (strlen(slash) > 0) {
                    printf("\033[1;38;2;255;255;255m %s %s%s", icon, part, slash);
                } else {
                    printf("\033[1;38;2;255;255;255m %s %s ", icon, part);
                }
            } else {
                if (strlen(slash) > 0) {
                    printf("\033[1;38;2;255;255;255m%s %s%s", icon, part, slash);
                } else {
                    printf("\033[1;38;2;255;255;255m%s %s ", icon, part);
                }
            }

            prev_c[0] = curr_c[0];
            prev_c[1] = curr_c[1];
            prev_c[2] = curr_c[2];
            cur_col = end_col + 1.0;
        }

        /* Git inside main header: yellow background with dark text */
        if (git.is_git) {
            char git_label[160];
            if (git.is_dirty) {
                snprintf(git_label, sizeof(git_label), "%s *", git.branch);
            } else {
                snprintf(git_label, sizeof(git_label), "%s", git.branch);
            }

            /* Powerline arrow into yellow git segment */
            printf("\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm",
                   prev_c[0], prev_c[1], prev_c[2],
                   C_GIT[0], C_GIT[1], C_GIT[2]);

            /* Git icon and branch in bold dark text on yellow background */
            printf("\033[1;38;2;%d;%d;%dm  %s ", C_GIT_FG[0], C_GIT_FG[1], C_GIT_FG[2], git_label);

            prev_c[0] = C_GIT[0];
            prev_c[1] = C_GIT[1];
            prev_c[2] = C_GIT[2];
        }

        /* Triangular arrow exiting main header into fill line */
        printf("\033[38;2;%d;%d;%dm\033[49m\033[0m", prev_c[0], prev_c[1], prev_c[2]);
    } else {
        /* RIGHT SIDE: User and Time headers */
        const char *user = getenv("USER");
        if (!user) user = "user";

        time_t rawtime;
        struct tm *info;
        char time_str[64];
        time(&rawtime);
        info = localtime(&rawtime);
        strftime(time_str, sizeof(time_str), "%T", info);

        int user_len = (int)strlen(user) + 4;
        int time_len = (int)strlen(time_str) + 4;

        double time_end = (double)term_width - 2.0;
        double time_start = time_end - (double)time_len + 1.0;
        double time_center = (time_start + time_end) / 2.0;

        double user_end = time_start - 2.0;
        double user_start = user_end - (double)user_len + 1.0;
        double user_center = (user_start + user_end) / 2.0;

        int user_c[3];
        get_column_color(user_c, user_center, term_width);

        int time_c[3];
        get_column_color(time_c, time_center, term_width);

        /* Arrow from fill line into User */
        printf("\033[38;2;%d;%d;%dm\033[49m", user_c[0], user_c[1], user_c[2]);

        /* User segment */
        printf("\033[48;2;%d;%d;%dm\033[1;38;2;255;255;255m %s 󰋜 ",
               user_c[0], user_c[1], user_c[2], user);

        /* Arrow from User into Time */
        printf("\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm",
               time_c[0], time_c[1], time_c[2],
               user_c[0], user_c[1], user_c[2]);

        /* Time segment */
        printf("\033[48;2;%d;%d;%dm\033[1;38;2;255;255;255m %s 󰥔 ",
               time_c[0], time_c[1], time_c[2], time_str);

        /* Closing arrow pointing right into margin */
        printf("\033[38;2;%d;%d;%dm\033[49m\033[0m", time_c[0], time_c[1], time_c[2]);
    }

    return 0;
}
