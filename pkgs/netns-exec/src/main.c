/* This program requires CAP_SYS_ADMIN */

#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/capability.h>

static char *allowed_netns[] = {
    "nb-lnd",
    "nb-lightning-loop",
    "nb-liquidd",
    "nb-joinmarket"
};

int is_netns_allowed(char *netns) {
    int n_allowed_netns = sizeof(allowed_netns) / sizeof(allowed_netns[0]);
    for (int i = 0; i < n_allowed_netns; i++) {
        if (strcmp(allowed_netns[i], netns) == 0) {
            return 1;
        }
    }
    return 0;
}

void print_capabilities() {
    cap_t caps = cap_get_proc();
    printf("Capabilities: %s\n", cap_to_text(caps, NULL));
    cap_free(caps);
}

void drop_capabilities() {
    cap_t caps = cap_get_proc();
    cap_clear(caps);
    cap_set_proc(caps);
    cap_free(caps);
}

int main(int argc, char **argv) {
    char netns_path[256];

    if (argc < 3) {
        printf("usage: %s <netns> <command>\n", argv[0]);
        return 1;
    }

    if (!is_netns_allowed(argv[1])) {
        printf("%s is not an allowed netns.\n", argv[1]);
        return 1;
    }

    if(snprintf(netns_path, sizeof(netns_path), "/var/run/netns/%s", argv[1]) < 0) {
        printf("Path length exceeded for netns %s.\n", argv[1]);
        return 1;
    }

    int fd = open(netns_path, O_RDONLY);
    if (fd < 0) {
        printf("Failed opening netns %s: %d, %s \n", netns_path, errno, strerror(errno));
        return 1;
    }

    if (setns(fd, CLONE_NEWNET) < 0) {
        printf("Failed setns %d, %s \n", errno, strerror(errno));
        return 1;
    }

    /* Drop capabilities */
    #ifdef DEBUG
    print_capabilities();
    #endif
    drop_capabilities();
    #ifdef DEBUG
    print_capabilities();
    #endif

    execvp(argv[2], &argv[2]);
    return 0;
}
