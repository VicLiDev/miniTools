/*************************************************************************
    > File Name: main.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Mon 24 Nov 2025 08:09:38 PM CST
 ************************************************************************/

#include <stdio.h>
#include "rcb_calc_com.h"
#include "rcb_calc_vdpu384b.h"

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;
    vdpu_rcb_ctx *ctx = NULL;
    rcb_calc_test_info info = {0};

    vdpu_rcb_calc_init(&ctx);

    info = (rcb_calc_test_info){1920, 1080, 1, RCB_FMT_YUV420, 10, 1, 1, 1, 1, 0, 0, 0};
    // info = (rcb_calc_test_info){1920, 1080, 1, RCB_FMT_YUV444, 10, 1, 1, 1, 1, 0, 0, 0};
    // info = (rcb_calc_test_info){3840, 2160, 1, RCB_FMT_YUV444, 10, 1, 1, 1, 1, 0, 0, 0};
    // info = (rcb_calc_test_info){4096, 2160, 1, RCB_FMT_YUV444, 10, 1, 1, 1, 1, 0, 0, 0};
    // info = (rcb_calc_test_info){7680, 4320, 1, RCB_FMT_YUV444, 10, 1, 1, 1, 1, 0, 0, 0};
    vdpu384b_rcb_h264_test(ctx, &info);
    vdpu384b_rcb_h265_test(ctx, &info);
    vdpu384b_rcb_avs2_test(ctx, &info);
    vdpu384b_rcb_vp9_test(ctx, &info);
    vdpu384b_rcb_av1_test(ctx, &info);

    vdpu_rcb_calc_deinit(ctx);

    return 0;
}
