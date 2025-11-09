#ifndef REPLACE_EXE_H
#define REPLACE_EXE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Deletes the currently running executable.
 * @return 0 on success, -1 on failure
 */
int self_delete(void);

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