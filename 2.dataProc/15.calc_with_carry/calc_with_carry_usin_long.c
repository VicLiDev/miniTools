/*************************************************************************
    > File Name: calc_with_carry_usin_long.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Thu 12 Sep 20:36:17 2024
 ************************************************************************/

/*
 * 程序说明：
 * 计算给定一个字节数据串的和，字节数据串在求和时，不是以byte为单位，而是以当前
 * 系统的long int为单位，这是为了提高计算效率，例如：0xAB，0xCD，0xEF，0xGH，会
 * 作为0xGHEFCDAB来计算求和，而不是单个字节求和。
 *
 * 计算的结果放在一个result数组中，这个数组也是long int类型的，如果有进位，就会
 * 向数组后边的元素，即高位，进行进位，如果超过数组的最大进位值，则会报错
 *
 * 字节数据串使用随机数生成
 *
 * 在 dump_data_list 和 dump_res 的过程中，会打印到终端，同时也会存放到文件中，
 * 以便进行校验
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <strings.h>
#include <string.h>

/*
 * 32位系统的长度为32bit，64位系统的长度位64bit
 * 因此，long int 可以代表当前系统的最大bit长度
 */
typedef unsigned long int BASE_TYPE;
// 当前平台的指针需要几个byte表示
// __SIZEOF_POINTER__

#define DEBUG_EN 0

#define DATA8_LEN 10000
#define RES_LEN 2
#define DATA_FILE_NAME "data.txt"
#define RES_FILE_NAME "result.txt"

#define debug_log(fmt, ...) \
    do { \
        if (DEBUG_EN) \
            printf("DEBUG: "fmt, ## __VA_ARGS__); \
    } while (0)

#define byte_in_str(str) ((int)(strlen(str) + 1) / 2)
#define dump_buf(buf, cnt) \
    do { \
        int i; \
        if (DEBUG_EN) { \
            for (i = 0; i < cnt; i++) { \
                printf("0x%02x ", buf[i] & 0xFF); \
            } \
            printf("\n"); \
        } \
    } while (0)

static void gen_data8(unsigned char **data8_list, int len)
{
    unsigned char *data_list = calloc(1, len);
    int loop = 0;

    for (loop = 0; loop < len; loop++) {
        data_list[loop] = rand() % 256;
    }
    *data8_list = data_list;

    return;
}

static int flip_str_by_byte(char *str)
{
    int len = strlen(str);
    int loop = 0;

    if (len % 2 != 0)
        return -1;

    for (loop = 0; loop < len / 2; loop += 2) {
        char tmp;
        tmp = str[loop];
        str[loop] = str[len - loop - 2];
        str[len - loop - 2] = tmp;

        tmp = str[loop + 1];
        str[loop + 1] = str[len - loop - 1];
        str[len - loop - 1] = tmp;

    }

    return 0;
}

static int dump_data_list(unsigned char *data8_list, int len, char *data_f_name, int w_file_en)
{
#define STR_TMP_CNT 100
    int loop = 0;
    char str[STR_TMP_CNT] = {0};
    int str_idx = 0;
    FILE *file;

    /* 按照 byte 打印数据 */
    debug_log("byte:\n");
    for (loop = 0; loop < len; loop++)
        /* 这里的 hh 表示参数是一个 char 类型的值（或更小的整数类型）*/
        // printf("0x%02hhX\n", data8_list[loop]);
        // printf("0x%02X\n", (unsigned char)data8_list[loop]);
        debug_log("0x%02X\n", data8_list[loop]);

    /* 按照BASE_TYPE打印数据 */
    if (w_file_en) {
        file = fopen(data_f_name, "w");
        if (file == NULL) {
            perror("Error opening file");
            return -1;
        }
    }
    debug_log("BASE_TYPE:\n");
    for (loop = 0; loop < len; loop++) {
        str_idx += sprintf(&str[str_idx], "%02X", data8_list[loop]);
        if (!((loop + 1) % sizeof(BASE_TYPE)) || (loop == len - 1)) {
            if (loop || (loop == len - 1)) {
                flip_str_by_byte(str);
                debug_log("0x%s\n", str);
                if (file)
                    fprintf(file, "0x%s\n", str);
            }
            memset(str, 0, STR_TMP_CNT);
            str_idx = 0;
        }
    }
    if (w_file_en)
        fclose(file);

    return 0;
}

static int dump_res(BASE_TYPE *result, int consume, char *res_f_name, int append)
{
    int loop = 0;
    FILE *file;
    char result_str[500] = {0};
    int result_str_idx = 0;

    printf("result: 0x");
    result_str_idx += sprintf(result_str, "0x");
    for (loop = consume - 1; loop >= 0; loop--) {
        /* *是一个占位符，它会被随后的参数替换，指定了字段的最小宽度。*/
        printf("%0*lx", (int)(2 * sizeof(result[loop])), result[loop]);
        result_str_idx += sprintf(&result_str[result_str_idx], "%0*lx",
                (int)(2 * sizeof(result[loop])), result[loop]);
    }
    printf("\n");
    result_str_idx += sprintf(&result_str[result_str_idx], "\n");

    printf("result: %s\n", result_str);

    /* dump result to file */
    /* 打开文件用于写入，这会自动清空文件内容 */
    if (append)
        file = fopen(res_f_name, "a");
    else
        file = fopen(res_f_name, "w");
    if (file == NULL) {
        perror("Error opening file");
        return 1;
    }

    fprintf(file, "%s", result_str);

    fflush(file);
    fclose(file);

    return 0;
}

static int flip_string(char *str)
{
    int len = strlen(str);
    int i, j;

    for (i = 0, j = len - 1; i <= j; i++, j--) {
        // swapping characters
        char c = str[i];
        str[i] = str[j];
        str[j] = c;
    }

    return 0;
}

static int convert_str_to_hex(char *instr, char *outbuf)
{
    int i, loop_cnt;
    char str[64] = {0};
    char *endptr, c_tmp;

    loop_cnt = strlen(instr);
    debug_log("convert str to hex\n");
    memcpy(str, instr, strlen(instr));
    flip_string(str);
    loop_cnt = strlen(str);

    debug_log("in     str: %s\n", instr);
    debug_log("fliped str: %s\n", str);
    debug_log("out    buf: ");
    for (i = 0; i < loop_cnt; i++) {
        c_tmp = str[i];
        if (i % 2 == 0)
            outbuf[i / 2] = (strtol(&c_tmp, &endptr, 16) & 0xF);
        else
            outbuf[i / 2] |= (strtol(&c_tmp, &endptr, 16) & 0xF) << 4;
    }
    dump_buf(outbuf, byte_in_str(str));

    return 0;
}

static void release_data8(unsigned char **data8_list)
{
    free(*data8_list);
    *data8_list = NULL;

    return;
}

static int calc_carry(BASE_TYPE *res, int res_cap_cnt, int *consume)
{
    BASE_TYPE old_val;

    (*consume)++;
    if (*consume <= res_cap_cnt) {
        res++;
        old_val = *res;
        (*res)++;
        if (*res < old_val) {
            /* Handling new carry */
            debug_log("handling new carry cap:%d consume:%d\n", res_cap_cnt, *consume);
            return calc_carry(res, res_cap_cnt, consume);
        } else {
            /* normal finish */
            debug_log("normal finish cap:%d consume:%d\n", res_cap_cnt, *consume);
            return 0;
        }
    } else {
        /* res_cap_cnt is not enough */
        debug_log("res_cap_cnt is not enough cap:%d consume:%d\n", res_cap_cnt, *consume);
        return -1;
    }
}

/*
 * res_cap_cnt: 当前存放结果的空间，如果消耗超过该空间，则无法正常计算
 * consume: 当前计算用到res单元的数量，有进位就算用到了
 */

static int calc_sum_with_carry(unsigned char *data8_list, int byte_len,
                        BASE_TYPE *res, int res_cap_cnt, int *consume)
{
    BASE_TYPE *data = (BASE_TYPE *)data8_list;
    int loop, ret;
    int loop_cnt = byte_len / sizeof(BASE_TYPE);
    BASE_TYPE remain_data = 0;
    BASE_TYPE old_val;
    int cur_consume = 0;
    int max_consume = 0;

    for (loop = 0; loop < loop_cnt; loop++) {
        old_val = *res;
        *res += *data++;
        cur_consume = 1;
        if (*res < old_val) {
            ret = calc_carry(res, res_cap_cnt, &cur_consume);
            if (ret) {
                printf("ERROR: res space is not enough, cur:%d", res_cap_cnt);
                return -1;
            }
        }
        max_consume = cur_consume > max_consume ? cur_consume : max_consume;
    }

    if (byte_len % sizeof(BASE_TYPE)) {
        memcpy(&remain_data, data, byte_len % sizeof(BASE_TYPE));
        old_val = *res;
        *res += remain_data;
        cur_consume = 1;
        if (*res < old_val) {
            ret = calc_carry(res, res_cap_cnt, &cur_consume);
            if (ret) {
                printf("ERROR: res space is not enough, cur:%d", res_cap_cnt);
                return -1;
            }
        }
        max_consume = cur_consume > max_consume ? cur_consume : max_consume;
    }

    *consume = max_consume;

    return 0;
}

int main(int argc, char *argv[])
{
    unsigned char *data8_list;
    int data8_len = DATA8_LEN;
    BASE_TYPE result[RES_LEN] = {0};
    int consume;
    int ret = 0;

    if (argc == 2)
        data8_len = atoi(argv[1]);

    gen_data8(&data8_list, data8_len);
    dump_data_list(data8_list, data8_len, DATA_FILE_NAME, 1);

    ret = calc_sum_with_carry(data8_list, data8_len, result, RES_LEN, &consume);

    if (!ret)
        ret = dump_res(result, consume, RES_FILE_NAME, 0);

    release_data8(&data8_list);


    /* reload result */
    {
        FILE *file;
        char in[100];
        char out[100];
        size_t len;

        file = fopen(RES_FILE_NAME, "r");
        if (file == NULL) {
            perror("Error opening file");
            return 1;
        }
        /* 从文件中读取一行 */
        if (fgets(in, sizeof(in), file) != NULL) {
            /* 输出读取的字符串 */
            printf("Read from file: %s", in);
        } else {
            printf("Error reading from file.\n");
        }


        /* fscanf 停止规则
         * 1. 空白字符：默认情况下，fscanf 遇到空格、换行符等空白字符时会停止读取，
         *    例如 %s。
         * 2. 指定最大字符数：可以在格式控制符中指定最大读取字符数，例如 %5s，表示
         *    最多读取 5 个字符。
         * 3. scanset []：通过 [^] 指定一个排除集合，读取字符直到遇到集合中的字符，
         *    例如 %[^!] 表示读取直到遇到 !。
         */
        /* 从文件中读取字符串，遇到空格会停止 */
        if (fscanf(file, "%99s", in) == 1) {
            printf("Read from file: %s\n", in);
        } else {
            printf("Error reading from file.\n");
        }

        // 查找换行符的位置
        len = strlen(in);
        if (len > 0 && in[len - 1] == '\n') {
            in[len - 1] = '\0';  // 将换行符替换为字符串终止符
        }

        convert_str_to_hex(in, out);

        fclose(file);
    }

    return 0;
}
