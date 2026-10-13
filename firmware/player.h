#ifndef PLAYER_H
#define PLAYER_H
#include <stdint.h>
#include <stddef.h>
/* 0 = 复制成功，非零 = 输入无效或空间不足。
 * out: 输出缓冲区。used: 当前已写入的字节数。
 * distance: 向后查找的距离。length: 需要复制的字节数。
 */
int copy_match(uint8_t *out, size_t *used, size_t capacity,
               size_t distance, size_t length);
#endif
