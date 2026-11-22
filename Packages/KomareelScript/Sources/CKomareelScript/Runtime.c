#include "KomareelScript.h"
#include "quickjs.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct Request {
    char *payload;
    JSValue resolve;
    JSValue reject;
    struct Request *next;
} Request;

struct KRScript {
    JSRuntime *runtime;
    JSContext *context;
    JSValue result;
    Request *head;
    Request *tail;
    unsigned requests;
    uint64_t deadline;
    void *user;
    KRHostCall host;
};

static uint64_t now(void) {
    struct timespec time;
    clock_gettime(CLOCK_MONOTONIC, &time);
    return (uint64_t)time.tv_sec * 1000 + (uint64_t)time.tv_nsec / 1000000;
}

static int interrupt(JSContext *context, void *opaque) {
    KRScript *script = opaque;
    return now() >= script->deadline;
}

static JSValue call(JSContext *context, JSValueConst self, int argc, JSValueConst *argv) {
    KRScript *script = JS_GetContextOpaque(context);
    if (argc != 2) return JS_ThrowTypeError(context, "Expected operation and JSON payload");
    const char *operation = JS_ToCString(context, argv[0]);
    const char *payload = operation ? JS_ToCString(context, argv[1]) : NULL;
    char *output = payload ? script->host(script->user, operation, payload) : NULL;
    if (payload) JS_FreeCString(context, payload);
    if (operation) JS_FreeCString(context, operation);
    if (!output) return JS_ThrowTypeError(context, "Host operation failed");
    JSValue result = JS_NewString(context, output);
    free(output);
    return result;
}

static JSValue request(JSContext *context, JSValueConst self, int argc, JSValueConst *argv) {
    KRScript *script = JS_GetContextOpaque(context);
    if (argc != 1 || script->requests >= 32)
        return JS_ThrowRangeError(context, "Invalid request or request limit reached");

    const char *payload = JS_ToCString(context, argv[0]);
    if (!payload) return JS_EXCEPTION;
    Request *entry = calloc(1, sizeof(*entry));
    if (entry) entry->payload = strdup(payload);
    JS_FreeCString(context, payload);
    if (!entry || !entry->payload) {
        free(entry);
        return JS_ThrowOutOfMemory(context);
    }

    JSValue funcs[2];
    JSValue promise = JS_NewPromiseCapability(context, funcs);
    if (JS_IsException(promise)) {
        free(entry->payload);
        free(entry);
        return promise;
    }

    entry->resolve = funcs[0];
    entry->reject = funcs[1];
    if (script->tail) script->tail->next = entry;
    else script->head = entry;
    script->tail = entry;
    script->requests++;
    return promise;
}

KRScript *kr_script_create(void *user, KRHostCall host) {
    KRScript *script = calloc(1, sizeof(*script));
    if (!script) return NULL;
    script->result = JS_UNDEFINED;
    script->runtime = JS_NewRuntime();
    if (!script->runtime) {
        free(script);
        return NULL;
    }
    JS_SetMemoryLimit(script->runtime, 32 * 1024 * 1024);
    JS_SetMaxStackSize(script->runtime, 512 * 1024);
    JS_SetInterruptHandler(script->runtime, interrupt, script);
    script->context = JS_NewContext(script->runtime);
    if (!script->context) {
        kr_script_destroy(script);
        return NULL;
    }
    script->user = user;
    script->host = host;
    JS_SetContextOpaque(script->context, script);
    JSValue global = JS_GetGlobalObject(script->context);
    int call_status = JS_SetPropertyStr(script->context, global, "__krCall",
                                       JS_NewCFunction(script->context, call, "__krCall", 2));
    int request_status = JS_SetPropertyStr(script->context, global, "__krRequest",
                                          JS_NewCFunction(script->context, request, "__krRequest", 1));
    JS_FreeValue(script->context, global);
    if (call_status < 0 || request_status < 0) {
        kr_script_destroy(script);
        return NULL;
    }
    return script;
}

static void remove_request(KRScript *script) {
    Request *entry = script->head;
    script->head = entry->next;
    if (!script->head) script->tail = NULL;
    JS_FreeValue(script->context, entry->resolve);
    JS_FreeValue(script->context, entry->reject);
    free(entry->payload);
    free(entry);
}

void kr_script_destroy(KRScript *script) {
    JS_UpdateStackTop(script->runtime);
    while (script->head) remove_request(script);
    if (script->context) {
        JS_FreeValue(script->context, script->result);
        JS_FreeContext(script->context);
    }
    JS_FreeRuntime(script->runtime);
    free(script);
}

static void copy_value(JSContext *context, JSValue value, char **output) {
    const char *str = JS_ToCString(context, value);
    if (str) {
        *output = strdup(str);
        JS_FreeCString(context, str);
    }
}

static KRScriptStatus exception(JSContext *context, char **output) {
    JSValue error = JS_GetException(context);
    copy_value(context, error, output);
    JS_FreeValue(context, error);
    return KRScriptFailed;
}

KRScriptStatus kr_script_compile(const char *source, size_t size, char **output) {
    KRScript *script = kr_script_create(NULL, NULL);
    if (!script) return KRScriptFailed;
    script->deadline = now() + 1500;
    JSContext *context = script->context;
    JSValue compiled = JS_Eval(context, source, size, "main.js", JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_COMPILE_ONLY);
    KRScriptStatus result = JS_IsException(compiled) ? exception(context, output) : KRScriptDone;
    JS_FreeValue(context, compiled);
    kr_script_destroy(script);
    return result;
}

static KRScriptStatus poll(KRScript *script, char **output) {
    JSContext *context = script->context;
    for (;;) {
        JSPromiseStateEnum state = JS_PromiseState(context, script->result);
        if (state != JS_PROMISE_PENDING) {
            JSValue result = JS_PromiseResult(context, script->result);
            copy_value(context, result, output);
            JS_FreeValue(context, result);
            return state == JS_PROMISE_FULFILLED ? KRScriptDone : KRScriptFailed;
        }
        if (interrupt(context, script)) {
            *output = strdup("Source script exceeded its execution deadline");
            return KRScriptFailed;
        }
        JSContext *job = context;
        int status = JS_ExecutePendingJob(script->runtime, &job);
        if (status < 0) return exception(job, output);
        if (status == 0) {
            if (script->head) {
                *output = strdup(script->head->payload);
                return KRScriptWaiting;
            }
            *output = strdup("Source script is waiting without a pending request");
            return KRScriptFailed;
        }
    }
}

KRScriptStatus kr_script_start(KRScript *script, const char *source, size_t size,
                              const char *invocation, char **output) {
    JS_UpdateStackTop(script->runtime);
    script->deadline = now() + 1500;
    JSContext *context = script->context;
    JSValue init = JS_Eval(context, source, size, "main.js", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(init)) return exception(context, output);
    JS_FreeValue(context, init);
    script->result = JS_Eval(context, invocation, strlen(invocation), "host.js", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(script->result)) return exception(context, output);
    if (!JS_IsPromise(script->result)) {
        *output = strdup("Source invocation did not return a promise");
        return KRScriptFailed;
    }
    return poll(script, output);
}

KRScriptStatus kr_script_resume(KRScript *script, const char *result, int rejected, char **output) {
    JS_UpdateStackTop(script->runtime);
    script->deadline = now() + 1500;
    JSContext *context = script->context;
    Request *entry = script->head;
    if (!entry) return KRScriptFailed;
    JSValue arg = JS_NewString(context, result);
    if (JS_IsException(arg)) return exception(context, output);
    JSValue response = JS_Call(context, rejected ? entry->reject : entry->resolve, JS_UNDEFINED, 1, &arg);
    JS_FreeValue(context, arg);
    remove_request(script);
    if (JS_IsException(response)) return exception(context, output);
    JS_FreeValue(context, response);
    return poll(script, output);
}
