#include "player.h"
#include <string.h>

/* 这是设备当前的旧程序。它包含一个故障。
 * 你的任务不是回答问题，而是直接修改它。 */
int copy_match(uint8_t *out, size_t *used, size_t capacity,
               size_t distance, size_t length) {
    if (!out || !used || !distance || distance > *used ||
        *used > capacity || length > capacity - *used || capacity > 4096)
        return -1;

    /* 故障：读取的是复制开始前的旧快照。
     * 如果复制过程中出现新字节，快照里没有这些字节。 */
    uint8_t snapshot[4096] = {0};
    memcpy(snapshot, out, *used);
    const size_t start = *used;
    for (size_t i = 0; i < length; ++i) {
        out[start + i] = snapshot[start - distance + i];
    }
    *used += length;
    return 0;
}
