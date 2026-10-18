/* ───────── 先读这里：参数是什么 ─────────
 * 评分程序（trace_harness.c，只读）会先准备好一块"输出缓冲区"，再调用你的 copy_match()。
 *
 *   out       输出缓冲区，一个字节数组。里面前 *used 个字节是已经输出的数据
 *             （例如 "ABC"）。你要把新字节写到 out[*used] 开始的位置。
 *   used      指针，指向"已写入字节数"。写完后你必须把它增加 length。
 *   capacity  out 最多能放多少字节。写超过会破坏内存，评分程序会检测。
 *   distance  从当前末尾向后数几个字节，那里就是要复制的起点。
 *   length    一共要复制多少个字节。
 *
 * 例：out="ABC", *used=3, distance=3, length=6
 *     第一次复制 out[0]='A' → "ABCA"，再复制 out[1]、out[2]……
 *     最终 "ABCABCABC"，*used 变成 9。
 * 返回 0 表示成功；参数不合法或空间不足时返回非零，且不要改动 out。
 * 点击上方 player.h / trace_harness.c 标签可以查看（只读）完整代码。 */

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
