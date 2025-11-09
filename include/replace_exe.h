#ifndef REPLACE_EXE_H
#define REPLACE_EXE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Registers hooks for self-delete functionality (Windows only, no-op on other platforms).
 * Must be called at the start of main() before any other replace_exe functions.
 * @return 0 on success, -1 on failure
 */
int register_hooks(void);

/**
 * Deletes the currently running executable.
 * @return 0 on success, -1 on failure
 */
int self_delete(void);

/**
 * Deletes the currently running executable, excluding a specific path (Windows only).
 * On Windows, uses the parent directory of exclude_path as a fallback location for temporary files.
 * @param exclude_path Path to exclude (null-terminated)
 * @return 0 on success, -1 on failure
 */
int self_delete_excluding_path(const char* exclude_path);

/**
 * Replaces the currently running executable with a new one.
 * @param new_exe_path Path to the new executable (null-terminated)
 * @return 0 on success, -1 on failure
 */
int self_replace(const char* new_exe_path);

#ifdef __cplusplus
}
#endif

#endif /* REPLACE_EXE_H */