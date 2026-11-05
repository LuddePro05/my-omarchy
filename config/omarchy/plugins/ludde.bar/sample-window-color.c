#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <spawn.h>
#include <libgen.h>

extern char **environ;

int main(int argc, char *argv[]) {
    // If called without window geometry arguments, fall back to sample-window-color.py
    if (argc < 5) {
        char exe_path[1024];
        ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
        if (len > 0) {
            exe_path[len] = '\0';
            char *dir = dirname(exe_path);
            char py_script[1024];
            snprintf(py_script, sizeof(py_script), "%s/sample-window-color.py", dir);
            if (access(py_script, X_OK) == 0 || access(py_script, R_OK) == 0) {
                char *py_args[] = { "python3", py_script, NULL };
                execvp("python3", py_args);
            }
        }
        printf("#181824\n");
        return 0;
    }

    int at_x = atoi(argv[1]);
    int at_y = atoi(argv[2]);
    int w = atoi(argv[3]);
    int h = atoi(argv[4]);

    if (w <= 0 || h <= 0) {
        printf("#181824\n");
        return 0;
    }

    int step = h / 20;
    if (step > 8) step = 8;
    if (step < 2) step = 2;
    int y = at_y + step;

    char geom[64];
    snprintf(geom, sizeof(geom), "%d,%d %dx1", at_x, y, w);

    int pipefd[2];
    if (pipe(pipefd) != 0) {
        printf("#181824\n");
        return 0;
    }

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDOUT_FILENO);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);

    char *const grim_args[] = { "grim", "-g", geom, "-t", "ppm", "-", NULL };
    pid_t pid;
    if (posix_spawnp(&pid, "grim", &actions, NULL, grim_args, environ) != 0) {
        posix_spawn_file_actions_destroy(&actions);
        close(pipefd[0]);
        close(pipefd[1]);
        printf("#181824\n");
        return 0;
    }
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);

    FILE *f = fdopen(pipefd[0], "rb");
    if (!f) {
        close(pipefd[0]);
        waitpid(pid, NULL, 0);
        printf("#181824\n");
        return 0;
    }

    // Read PPM header: "P6\n<w> <h>\n255\n"
    char magic[3] = {0};
    if (fread(magic, 1, 2, f) != 2 || magic[0] != 'P' || magic[1] != '6') {
        fclose(f);
        waitpid(pid, NULL, 0);
        printf("#181824\n");
        return 0;
    }

    int pw = 0, ph = 0, maxval = 0;
    int c;
    while ((c = fgetc(f)) != EOF && (c == ' ' || c == '\n' || c == '\r' || c == '\t'));
    if (c == '#') {
        while ((c = fgetc(f)) != EOF && c != '\n');
    } else if (c != EOF) {
        ungetc(c, f);
    }
    if (fscanf(f, "%d %d", &pw, &ph) != 2) {
        fclose(f);
        waitpid(pid, NULL, 0);
        printf("#181824\n");
        return 0;
    }
    while ((c = fgetc(f)) != EOF && (c == ' ' || c == '\n' || c == '\r' || c == '\t'));
    if (c != EOF) ungetc(c, f);
    if (fscanf(f, "%d", &maxval) != 1) {
        fclose(f);
        waitpid(pid, NULL, 0);
        printf("#181824\n");
        return 0;
    }
    fgetc(f); // single whitespace char after maxval

    size_t total_bytes = (size_t)pw * 3;
    unsigned char *px = malloc(total_bytes);
    if (!px) {
        fclose(f);
        waitpid(pid, NULL, 0);
        printf("#181824\n");
        return 0;
    }

    size_t read_bytes = fread(px, 1, total_bytes, f);
    fclose(f);
    waitpid(pid, NULL, 0);

    size_t num_pixels = read_bytes / 3;
    if (num_pixels == 0) {
        free(px);
        printf("#181824\n");
        return 0;
    }

    // 16-step quantization buckets (16 * 16 * 16 = 4096)
    static unsigned int bucket_counts[4096];
    static unsigned long long bucket_r[4096];
    static unsigned long long bucket_g[4096];
    static unsigned long long bucket_b[4096];
    memset(bucket_counts, 0, sizeof(bucket_counts));
    memset(bucket_r, 0, sizeof(bucket_r));
    memset(bucket_g, 0, sizeof(bucket_g));
    memset(bucket_b, 0, sizeof(bucket_b));

    int max_bucket = 0;
    unsigned int max_count = 0;

    for (size_t i = 0; i < num_pixels; i++) {
        unsigned char r = px[i * 3];
        unsigned char g = px[i * 3 + 1];
        unsigned char b = px[i * 3 + 2];
        int b_idx = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
        bucket_counts[b_idx]++;
        bucket_r[b_idx] += r;
        bucket_g[b_idx] += g;
        bucket_b[b_idx] += b;
        if (bucket_counts[b_idx] > max_count) {
            max_count = bucket_counts[b_idx];
            max_bucket = b_idx;
        }
    }
    free(px);

    if (max_count == 0) {
        printf("#181824\n");
        return 0;
    }

    int avg_r = (int)(bucket_r[max_bucket] / max_count);
    int avg_g = (int)(bucket_g[max_bucket] / max_count);
    int avg_b = (int)(bucket_b[max_bucket] / max_count);

    printf("#%02x%02x%02x\n", avg_r, avg_g, avg_b);
    return 0;
}
