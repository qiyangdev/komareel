#ifndef KOMAREEL_SCRIPT_H
#define KOMAREEL_SCRIPT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct KRScript KRScript;
typedef char *(*KRHostCall)(void *user, const char *operation, const char *json);

typedef enum {
    KRScriptFailed = -1,
    KRScriptDone = 0,
    KRScriptWaiting = 1
} KRScriptStatus;

KRScript *kr_script_create(void *user, KRHostCall host);
void kr_script_destroy(KRScript *script);
KRScriptStatus kr_script_compile(const char *source, size_t size, char **output);
KRScriptStatus kr_script_start(KRScript *script, const char *source, size_t size,
                               const char *invocation, char **output);
KRScriptStatus kr_script_resume(KRScript *script, const char *result, int rejected,
                                char **output);

#ifdef __cplusplus
}
#endif

#endif
