#include <stdio.h>
#include <stdlib.h>
#include "replace_exe.h"

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s <new_exe_path>\n", argv[0]);
        return 1;
    }

    const char *path = argv[1];

    printf("[C] Trying to replace current executable with: %s\n", path);

    int res = re_self_replace(path);
    if (res != 0) {
        printf("[C] re_self_replace failed!\n");
        return 1;
    }

    printf("[C] Replacement succeeded.\n");

    // Or test deletion instead:
    // int res = re_self_delete();

    return 0;
}
