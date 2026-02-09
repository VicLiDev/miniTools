/*************************************************************************
    > File Name: rcb_calc_vdpu384b.h
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Tue 25 Nov 2025 11:13:55 AM CST
 ************************************************************************/

#ifndef __RCB_CALC_VDPU384B_H__
#define __RCB_CALC_VDPU384B_H__

#include "rcb_calc_com.h"

typedef struct rcb_calc_test_info_t {
    int                 pic_w;
    int                 pic_h;

    int                 tile_cnt;

    /* general */
    vdpu_rcb_fmt        fmt;
    int                 bit_depth;
    /* h264 */
    int                 mbaff_flag;
    /* avs2 */
    int                 alf_en;
    /* av1 */
    int                 lr_en;
    int                 upsc_en;

    int                 sram_sz;
    int                 ddr_sz;
    int                 total_sz;
} rcb_calc_test_info;

RET_STAT vdpu384b_rcb_h264_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info);
RET_STAT vdpu384b_rcb_h265_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info);
RET_STAT vdpu384b_rcb_avs2_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info);
RET_STAT vdpu384b_rcb_vp9_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info);
RET_STAT vdpu384b_rcb_av1_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info);

#endif /* RCB_CALC_VDPU384B_H__ */
