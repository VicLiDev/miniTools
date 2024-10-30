/*************************************************************************
    > File Name: 15.conv_str_bin.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Wed 10 Apr 2024 05:39:26 PM CST
 ************************************************************************/

/*
 * long int strtol (const char* str, char** endptr, int base);
 * 参数说明：str 为要转换的字符串，endstr 为第一个不能转换的字符的指针，base 为字符串 str 所采用的进制。
 * 返回值：返回转换后的长整型数；
 * 函数说明：
 *     1. strtol() 会将参数 str 字符串根据参数 base 来转换成长整型数(long)。
 *     2. 参数 base 范围从2 至36，或0。
 *     3. 参数base 代表 str 采用的进制方式，如 base=10 则采用10 进制，若base=16 则采用16 进制等。
 *     4. strtol() 会扫描参数 str 字符串，跳过前面的空白字符（例如空格，tab缩进等，可以通过 isspace() 函数来检测），
 *        直到遇上数字或正负符号才开始做转换，再遇到非数字或字符串结束时(’\0’)结束转换，并将结果返回。
 * 
 * 注意：
 *     1. 当 base= 0 时，默认采用 10 进制转换，但如果遇到 '0x' / '0X' 前置字符则会
 *        使用 16 进制转换，遇到 '0' 前置字符则会使用 8 进制转换。
 *     2. 若endptr !=NULL，则会将遇到的不符合条件而终止的字符指针由 endptr 传回；
 *     3. 若 endptr = NULL，则表示该参数无效，或不使用该参数。
 *     4. 如果不能转换或者 str 为空字符串，那么返回 0(0L)；
 *     5. 如果转换得到的值超出 long int 所能表示的范围，函数将返回 LONG_MAX 或 LONG_MIN
 *        （在 limits.h 头文件中定义），并将 errno 的值设置为 ERANGE。
 * 
 * ANSI C 规范定义了 stof()、atoi()、atol()、strtod()、strtol()、strtoul() 共6个可以将字符串转换为数字的函数。
 * 另外在 C99 / C++11 规范中又新增了5个函数，分别是 atoll()、strtof()、strtold()、strtoll()、strtoull()。
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>

#define DEBUG_EN 1

#define DUMP_INFO(...) \
    do { \
        if (DEBUG_EN) { \
            printf(__VA_ARGS__); \
        } \
    } while (0)

#define BYTE_IN_STR(str) ((int)(strlen(str) + 1) / 2)
#define DUMP_BUF(buf, cnt) \
    do { \
        int i; \
        if (DEBUG_EN) { \
            for (i = 0; i < cnt; i++) { \
                printf("0x%02x ", buf[i] & 0xFF); \
            } \
        } \
    } while (0)

typedef struct cmd_paras_t {
    char *fn_in;
    char *fn_out;
    FILE *fp_in;
    FILE *fp_out;
    // 0: not specified
    // 1: convert str to bin
    // 2: convert bin to str
    int conv_mode;
    int align_bit; // only for bin to str
} cmd_paras;

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
    DUMP_INFO("convert str to hex\n");
    memcpy(str, instr, strlen(instr));
    flip_string(str);
    loop_cnt = strlen(str);

    DUMP_INFO("in  str: %s\n", instr);
    DUMP_INFO("out buf: ");
    for (i = 0; i < loop_cnt; i++) {
        c_tmp = str[i];
        if (i % 2 == 0)
            outbuf[i / 2] = (strtol(&c_tmp, &endptr, 16) & 0xF);
        else
            outbuf[i / 2] |= (strtol(&c_tmp, &endptr, 16) & 0xF) << 4;
    }
    DUMP_BUF(outbuf, BYTE_IN_STR(str));
    DUMP_INFO("\n\n");

    return 0;
}

static int convert_hex_to_str(char *inbuf, char *outstr, int cnt)
{
    int i;

    DUMP_INFO("convert hex to str\n");
    DUMP_INFO("in  buf: ");
    DUMP_BUF(inbuf, cnt);
    DUMP_INFO("\n");

    for (i = 0; i < cnt; i++) {
        sprintf(outstr + i * 2, "%1x", inbuf[i] & 0xF);
        sprintf(outstr + i * 2 + 1, "%1x", (inbuf[i] >> 4) & 0xF);
    }
    flip_string(outstr);
    DUMP_INFO("out str: %s\n\n", outstr);

    return 0;
}

int proc_cmd_paras(int argc, char* argv[], cmd_paras *paras)
{
    int opt;
    char *string = "i:o:bsa:";

    while ((opt = getopt(argc, argv, string))!= -1)
    { 
        switch(opt){
            case 'i':
                paras->fn_in = optarg;
                break;
            case 'o':
                paras->fn_out = optarg;
                break;
            case 'b':
                paras->conv_mode = 1;
                break;
            case 's':
                paras->conv_mode = 2;
                break;
            case 'a':
                paras->align_bit = atoi(optarg);
                break;
            default:
                printf("usage: ./exe -i <input> -o <output> -b/s(str2bin/bin2str) -a(align bit of bin2str)\n");
                exit(1);
                break;
        }
    }  

    if (!paras->fn_in || ! paras->fn_out || paras->conv_mode == 0) {
        printf("usage: ./exe -i <input> -o <output> -b/s(str2bin/bin2str) -a(align bit of bin2str)\n");
        exit(1);
    }
    if ((paras->conv_mode == 2) && (paras->align_bit == 0)) {
        printf("usage: ./exe -i <input> -o <output> -b/s(str2bin/bin2str) -a(align bit of bin2str)\n");
        exit(1);
    }

    printf("input  file: %s\n", paras->fn_in);
    printf("output file: %s\n", paras->fn_out);
    if (paras->conv_mode == 2)
        printf("mode: convert str to bin");
    if (paras->conv_mode == 3)
        printf("mode: convert bin to str");

    return 0;
}


static int conv_str2hex_file(cmd_paras *cmd_p)
{
    char instr[64];
    char outbuf[64];

    cmd_p->fp_in = fopen(cmd_p->fn_in, "r");
    cmd_p->fp_out = fopen(cmd_p->fn_out, "w");

    while (fgets(instr, sizeof(instr), cmd_p->fp_in)) {
        instr[strcspn(instr, "\n")] = '\0';
        convert_str_to_hex(instr, outbuf);
        fwrite(outbuf, 1, BYTE_IN_STR(instr), cmd_p->fp_out);
    }

    fclose(cmd_p->fp_in);
    fclose(cmd_p->fp_out);

    return 0;
}

static int conv_hex2str_file(cmd_paras *cmd_p)
{
    char inbuf[64];
    char outstr[64];
    int rd_cnt;
    int align = cmd_p->align_bit / 8;

    memset(outstr, 0, sizeof(outstr));

    cmd_p->fp_in = fopen(cmd_p->fn_in, "rb");
    cmd_p->fp_out = fopen(cmd_p->fn_out, "w");

    while (1) {
        rd_cnt = fread(inbuf, sizeof(char), align, cmd_p->fp_in);
        if (!rd_cnt)
            break;
        convert_hex_to_str(inbuf, outstr, rd_cnt);
        fprintf(cmd_p->fp_out, "%s\n", outstr);
    }

    fclose(cmd_p->fp_in);
    fclose(cmd_p->fp_out);

    return 0;
}

int main(int argc, char* argv[])
{
    cmd_paras cmd_p;

    memset(&cmd_p, 0, sizeof(cmd_p));
    proc_cmd_paras(argc, argv, &cmd_p);

    if (cmd_p.conv_mode == 1)
        conv_str2hex_file(&cmd_p);
    if (cmd_p.conv_mode == 2)
        conv_hex2str_file(&cmd_p);

    return 0;
}

