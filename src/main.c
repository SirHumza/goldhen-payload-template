/*
 * main.c - starter GoldHEN payload.
 *
 * Built against the ps4-payload-dev SDK (daemon-world linkage). The SDK calls
 * main(argc, argv) after its own CRT has initialized the kernel log, the
 * runtime linker and the per-firmware patches. Returning non-zero from main
 * is fine; the payload simply ends.
 *
 * printf() is wired to the kernel log. Your first debug channel is klog on
 * TCP :3232 (see docs/DEBUGGING.md). Make the first line unmistakable.
 */

#include <stddef.h>
#include <stdio.h>
#include <string.h>

/*
 * Payloads routinely call system functions that ship no header. The loader
 * resolves the import by symbol name at load time, so all you need is a
 * matching prototype. Do not include app-world SDK headers (orbis/Net.h and
 * friends): linking their libraries kills the payload before main() runs.
 * See docs/LEARNINGS.md, lesson 1.
 */
typedef struct {
  char useless1[45];
  char message[3075];
} notify_request_t;

int sceKernelSendNotificationRequest(int, notify_request_t *, size_t, int);

static void
notify(const char *msg) {
  notify_request_t req;

  memset(&req, 0, sizeof req);
  strncpy(req.message, msg, sizeof req.message - 1);
  sceKernelSendNotificationRequest(0, &req, sizeof req, 0);
}

int
main(int argc, char **argv) {
  printf("payload: start (argc=%d)\n", argc);

  for(int i = 0; i < argc; i++) {
    printf("payload: argv[%d] = %s\n", i, argv[i] ? argv[i] : "(null)");
  }

  notify("payload: hello from GoldHEN");

  printf("payload: done\n");
  return 0;
}
