#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "replace_exe.h"

int main(int argc, char **argv) {
    // Must be called first on Windows
    init();
    if (argc < 2) {
        printf("Usage: %s <delete|replace> [path]\n", argv[0]);
        printf("  delete: Delete the current executable\n");
        printf("  replace <path>: Replace current executable with the one at <path>\n");
        return 1;
    }

    const char *command = argv[1];

    if (strcmp(command, "delete") == 0) {
        printf("[C] Trying to delete current executable...\n");
        int res = self_delete();
        if (res != 0) {
            printf("[C] self_delete failed!\n");
            return 1;
        }
        printf("[C] Deletion succeeded.\n");
    } else if (strcmp(command, "replace") == 0) {
        if (argc < 3) {
            printf("Error: replace command requires a path argument\n");
            printf("Usage: %s replace <path>\n", argv[0]);
            return 1;
        }
        const char *path = argv[2];
        printf("[C] Trying to replace current executable with: %s\n", path);
        int res = self_replace(path);
        if (res != 0) {
            printf("[C] self_replace failed!\n");
            return 1;
        }
        printf("[C] Replacement succeeded.\n");
    } else {
        printf("Error: Unknown command '%s'\n", command);
        printf("Usage: %s <delete|replace> [path]\n", argv[0]);
        return 1;
    }

    return 0;
}
