/* Real C execution trace for Data Rescue / GZIP training.
 * STEP n means: call the player's copy_match on a fresh copy of the prefix
 * with requested match length n. It is a real prefix-probe execution, not
 * an instruction-level debugger. No simulated output bytes are used. */
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "player.h"

typedef struct {
    const char *name;
    const char *prefix;
    size_t distance;
    size_t length;
    const char *expected;
} TestCase;
static const TestCase TESTS[4] = {
    {"GREENHOUSE", "HELLO", 5, 3, "HELLOHEL"},
    {"MEDICAL", "ABC", 3, 6, "ABCABCABC"},
    {"MINE", "X", 1, 7, "XXXXXXXX"},
    {"ARCHIVE", "NODE-", 5, 10, "NODE-NODE-NODE-"}
};
static void dump_hex(const uint8_t *bytes, size_t used) {
    for (size_t j = 0; j < used; ++j) printf("%02X", bytes[j]);
}
static int perform(const TestCase *t, size_t length, int case_id, int is_step) {
    /* Padding detects accidental writes beyond the output capacity. */
    uint8_t buf[160] = {0};
    const size_t cap = 128;
    memset(buf + cap, 0xA5, sizeof buf - cap);
    size_t used = strlen(t->prefix);
    memcpy(buf, t->prefix, used);
    int rc = copy_match(buf, &used, cap, t->distance, length);
    int guard_ok = 1;
    for (size_t i = cap; i < sizeof buf; ++i) if (buf[i] != 0xA5) guard_ok = 0;
    size_t visual = used <= cap ? used : cap;
    if (is_step) {
        printf("STEP|%d|%zu|%d|%zu|%d|", case_id, length, rc, used, guard_ok);
        dump_hex(buf, visual);
        putchar('\n');
        return guard_ok;
    }
    const size_t expected_len = strlen(t->expected);
    int pass = guard_ok && rc == 0 && used == expected_len &&
               memcmp(buf, t->expected, expected_len) == 0;
    printf("CASE|%d|%d|%d|%zu|", case_id, pass, rc, used);
    dump_hex(buf, visual);
    putchar('\n');
    return pass;
}
static int invalid_test(int which) {
    uint8_t buf[24] = {'A', 'B', 'C', 0};
    memset(buf + 8, 0xC9, sizeof buf - 8);
    size_t used = 3;
    size_t distance = which == 0 ? 0 : 3;
    size_t len = which == 0 ? 2 : 6;
    int rc = copy_match(buf, &used, 8, distance, len);
    int pass = rc != 0 && used == 3 && memcmp(buf, "ABC", 3) == 0;
    for (size_t i = 8; i < sizeof buf; ++i) if (buf[i] != 0xC9) pass = 0;
    printf("GUARD|%d|%d\n", which, pass);
    return pass;
}
int main(void) {
    puts("PROTO|TRACE2");
    int passed = 0;
    for (int i = 0; i < 4; ++i) {
        size_t length = TESTS[i].length;
        for (size_t k = 1; k <= length; ++k) perform(&TESTS[i], k, i, 1);
        passed += perform(&TESTS[i], length, i, 0);
    }
    int safe = invalid_test(0) + invalid_test(1);
    printf("SUMMARY|%d|4|%d|2\n", passed, safe);
    return (passed == 4 && safe == 2) ? 0 : 1;
}
