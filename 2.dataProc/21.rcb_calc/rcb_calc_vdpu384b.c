/*************************************************************************
    > File Name: rcb_calc_vdpu384b.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Tue 25 Nov 2025 10:15:04 AM CST
 ************************************************************************/

#include <stdio.h>
#include "rcb_calc_com.h"
#include "rcb_calc_vdpu384b.h"


static RET_STAT vdpu384b_rcb_h264_calc_rcb_bufs(void *context, int *total_size)
{
    vdpu_rcb_ctx *ctx = (vdpu_rcb_ctx *)context;
    float cur_bit_size = 0;
    int cur_uv_para = 0;
    int bit_depth = ctx->bit_depth;
    int in_tl_row = 0;
    int on_tl_row = 0;
    int on_tl_col = 0;
    vdpu_rcb_fmt rcb_fmt;

    /* vdpu384b fix 10bit */
    bit_depth = 10;

    vdpu_rcb_get_len(ctx, VDPU_RCB_IN_TILE_ROW, &in_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_ROW, &on_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_COL, &on_tl_col);
    rcb_fmt = vdpu_rcb_get_fmt(ctx);

    /* RCB_STRMD_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_IN_ROW, 140, cur_bit_size);

    /* RCB_STRMD_ON_ROW */
    cur_bit_size = 0;
    /*
     * For all spec, the hardware connects all in-tile rows of strmd to the on-tile.
     * Therefore, only strmd on-tile needs to be configured, and there is no need to
     * configure strmd in-tile.
     *
     * Versions with issues: swan1126b (384a version), shark/robin (384b version).
     */
    if (ctx->pic_w > 4096)
        cur_bit_size = DIVUP(16, in_tl_row) * 158 * (1 + ctx->mbaff_flag);
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_ON_ROW, 142, cur_bit_size);

    /* RCB_INTER_IN_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(4, in_tl_row) * 92 * (1 + ctx->mbaff_flag);
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_IN_ROW, 144, cur_bit_size);

    /* RCB_INTER_ON_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(4, on_tl_row) * 92 * (1 + ctx->mbaff_flag);
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_ON_ROW, 146, cur_bit_size);

    /* RCB_INTRA_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (in_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_IN_ROW, 148, cur_bit_size);

    /* RCB_INTRA_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (on_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_ON_ROW, 150, cur_bit_size);

    /* RCB_FLTD_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(16, in_tl_row) * (1.2 * bit_depth + 0.5)
                   * (( 6 + 3 * cur_uv_para) * (1 + ctx->mbaff_flag)
                      + 2 * cur_uv_para + 1.5);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_IN_ROW, 152, cur_bit_size);

    /* RCB_FLTD_PROT_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_PROT_IN_ROW, 154, cur_bit_size);

    /* RCB_FLTD_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(16, on_tl_row) * (1.2 * bit_depth + 0.5)
                   * (( 6 + 3 * cur_uv_para) * (1 + ctx->mbaff_flag)
                      + 2 * cur_uv_para + 1.5);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_ROW, 156, cur_bit_size);

    /* RCB_FLTD_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_COL, 158, cur_bit_size);

    /* RCB_FLTD_UPSC_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_UPSC_ON_COL, 160, cur_bit_size);

    *total_size = vdpu_rcb_get_total_size(ctx);

    return RET_OK;
}


static RET_STAT vdpu384b_rcb_h265_calc_rcb_bufs(void *context, int *total_size)
{
    vdpu_rcb_ctx *ctx = (vdpu_rcb_ctx *)context;
    float cur_bit_size = 0;
    int cur_uv_para = 0;
    int bit_depth = ctx->bit_depth; int in_tl_row = 0;
    int on_tl_row = 0;
    int on_tl_col = 0;
    vdpu_rcb_fmt rcb_fmt;

    /* vdpu384b fix 10bit */
    bit_depth = 10;

    vdpu_rcb_get_len(ctx, VDPU_RCB_IN_TILE_ROW, &in_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_ROW, &on_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_COL, &on_tl_col);
    rcb_fmt = vdpu_rcb_get_fmt(ctx);

    /* RCB_STRMD_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_IN_ROW, 140, cur_bit_size);

    /* RCB_STRMD_ON_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_ON_ROW, 142, cur_bit_size);

    /* RCB_INTER_IN_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(8, in_tl_row) * 174;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_IN_ROW, 144, cur_bit_size);

    /* RCB_INTER_ON_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(8, on_tl_row) * 174;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_ON_ROW, 146, cur_bit_size);

    /* RCB_INTRA_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (in_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_IN_ROW, 148, cur_bit_size);

    /* RCB_INTRA_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (on_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_ON_ROW, 150, cur_bit_size);

    /* RCB_FLTD_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, in_tl_row) * (1.2 * bit_depth + 0.5 )
                   * (7.5 + 5 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_IN_ROW, 152, cur_bit_size);

    /* RCB_FLTD_PROT_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_PROT_IN_ROW,  154, cur_bit_size);

    /* RCB_FLTD_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, on_tl_row) * (1.2 * bit_depth + 0.5)
                   * (7.5 + 5 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_ROW, 156, cur_bit_size);

    /* RCB_FLTD_ON_COL */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_col_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, on_tl_row) * (1.6 * bit_depth + 0.5)
                   * (16.5 + 5.5 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_COL, 158, cur_bit_size);

    /* RCB_FLTD_UPSC_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_UPSC_ON_COL, 160, cur_bit_size);

    *total_size = vdpu_rcb_get_total_size(ctx);

    return RET_OK;
}


static RET_STAT vdpu384b_rcb_avs2_calc_rcb_bufs(void *context, int *total_size)
{
    vdpu_rcb_ctx *ctx = (vdpu_rcb_ctx *)context;
    float cur_bit_size = 0;
    int cur_uv_para = 0;
    int bit_depth = ctx->bit_depth;
    int in_tl_row = 0;
    int on_tl_row = 0;
    int on_tl_col = 0;
    vdpu_rcb_fmt rcb_fmt;

    /* vdpu384b fix 10bit */
    bit_depth = 10;

    vdpu_rcb_get_len(ctx, VDPU_RCB_IN_TILE_ROW, &in_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_ROW, &on_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_COL, &on_tl_col);
    rcb_fmt = vdpu_rcb_get_fmt(ctx);

    /* RCB_STRMD_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_IN_ROW, 140, cur_bit_size);

    /* RCB_STRMD_ON_ROW */
    cur_bit_size = 0;
    /*
     * For all spec, the hardware connects all in-tile rows of strmd to the on-tile.
     * Therefore, only strmd on-tile needs to be configured, and there is no need to
     * configure strmd in-tile.
     *
     * Versions with issues: swan1126b (384a version), shark/robin (384b version).
     */
    if (ctx->pic_w > 8192)
        cur_bit_size = DIVUP(64, in_tl_row) * 112;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_ON_ROW, 142, cur_bit_size);

    /* RCB_INTER_IN_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(8, in_tl_row) * 166;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_IN_ROW, 144, cur_bit_size);

    /* RCB_INTER_ON_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(8, on_tl_row) * 166;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_ON_ROW, 146, cur_bit_size);

    /* RCB_INTRA_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (in_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_IN_ROW, 148, cur_bit_size);

    /* RCB_INTRA_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (on_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_ON_ROW, 150, cur_bit_size);

    /* RCB_FLTD_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, in_tl_row) * (1.2 * bit_depth + 0.5)
                   * (12 + 5 * cur_uv_para + 1.5 * ctx->alf_en);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_IN_ROW, 152, cur_bit_size);

    /* RCB_FLTD_PROT_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_PROT_IN_ROW,  154, cur_bit_size);

    /* RCB_FLTD_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, on_tl_row) * (1.2 * bit_depth + 0.5)
                   * (12 + 5 * cur_uv_para + 1.5 * ctx->alf_en);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_ROW, 156, cur_bit_size);

    /* RCB_FLTD_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_COL, 158, cur_bit_size);

    /* RCB_FLTD_UPSC_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_UPSC_ON_COL, 160, cur_bit_size);

    *total_size = vdpu_rcb_get_total_size(ctx);

    return RET_OK;
}


static RET_STAT vdpu384b_rcb_vp9_calc_rcb_bufs(void *context, int *total_size)
{
    vdpu_rcb_ctx *ctx = (vdpu_rcb_ctx *)context;
    float cur_bit_size = 0;
    int cur_uv_para = 0;
    int bit_depth = ctx->bit_depth;
    int in_tl_row = 0;
    int on_tl_row = 0;
    int on_tl_col = 0;
    vdpu_rcb_fmt rcb_fmt;

    /* vdpu384b fix 10bit */
    bit_depth = 10;

    vdpu_rcb_get_len(ctx, VDPU_RCB_IN_TILE_ROW, &in_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_ROW, &on_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_COL, &on_tl_col);
    rcb_fmt = vdpu_rcb_get_fmt(ctx);

    /* RCB_STRMD_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_IN_ROW, 140, cur_bit_size);

    /* RCB_STRMD_ON_ROW */
    cur_bit_size = 0;
    if (ctx->pic_w > 4096)
        cur_bit_size = DIVUP(64, on_tl_row) * 250;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_ON_ROW, 142, cur_bit_size);

    /* RCB_INTER_IN_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(64, in_tl_row) * 2368;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_IN_ROW, 144, cur_bit_size);

    /* RCB_INTER_ON_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(64, on_tl_row) * 2368;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_ON_ROW, 146, cur_bit_size);

    /* RCB_INTRA_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (in_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_IN_ROW, 148, cur_bit_size);

    /* RCB_INTRA_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (on_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_ON_ROW, 150, cur_bit_size);

    /* RCB_FLTD_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, in_tl_row) * (1.2 * bit_depth + 0.5)
                   * (17.5 + 8 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_IN_ROW, 152, cur_bit_size);

    /* RCB_FLTD_PROT_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_PROT_IN_ROW,  154, cur_bit_size);

    /* RCB_FLTD_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, on_tl_row) * (1.2 * bit_depth + 0.5)
                   * (17.5 + 8 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_ROW, 156, cur_bit_size);

    /* RCB_FLTD_ON_COL */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_col_uv_coef_map[rcb_fmt];
    if (ctx->tile_dir == 0)
        cur_bit_size = ROUNDUP(64, on_tl_col) * (1.6 * bit_depth + 0.5)
                       * (17.75 + 8 * cur_uv_para);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_COL, 158, cur_bit_size);

    /* RCB_FLTD_UPSC_ON_COL */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_UPSC_ON_COL, 160, cur_bit_size);

    *total_size = vdpu_rcb_get_total_size(ctx);

    return RET_OK;
}

static RET_STAT vdpu384b_rcb_av1_calc_rcb_bufs(void *context, int *total_size)
{
    vdpu_rcb_ctx *ctx = (vdpu_rcb_ctx *)context;
    float cur_bit_size = 0;
    int cur_uv_para = 0;
    int bit_depth = ctx->bit_depth;
    int in_tl_row = 0;
    int on_tl_row = 0;
    int on_tl_col = 0;
    vdpu_rcb_fmt rcb_fmt;

    /* vdpu384b fix 10bit */
    bit_depth = 10;

    vdpu_rcb_get_len(ctx, VDPU_RCB_IN_TILE_ROW, &in_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_ROW, &on_tl_row);
    vdpu_rcb_get_len(ctx, VDPU_RCB_ON_TILE_COL, &on_tl_col);
    rcb_fmt = vdpu_rcb_get_fmt(ctx);

    /* RCB_STRMD_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_IN_ROW, 140, cur_bit_size);

    /* RCB_STRMD_ON_ROW */
    cur_bit_size = 0;
    /*
     * For all spec, the hardware connects all in-tile rows of strmd to the on-tile.
     * Therefore, only strmd on-tile needs to be configured, and there is no need to
     * configure strmd in-tile.
     *
     * Versions with issues: swan1126b (384a version), shark/robin (384b version).
     */
    cur_bit_size = DIVUP(8, in_tl_row) * 100;
    vdpu_rcb_reg_info_update(ctx, RCB_STRMD_ON_ROW, 142, cur_bit_size);

    /* RCB_INTER_IN_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(64, in_tl_row) * 2752;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_IN_ROW, 144, cur_bit_size);

    /* RCB_INTER_ON_ROW */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(64, on_tl_row) * 2752;
    vdpu_rcb_reg_info_update(ctx, RCB_INTER_ON_ROW, 146, cur_bit_size);

    /* RCB_INTRA_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (in_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_IN_ROW, 148, cur_bit_size);

    /* RCB_INTRA_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_intra_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(512, (on_tl_row * (bit_depth + 2)
                   * (1 + ctx->mbaff_flag) * cur_uv_para));
    vdpu_rcb_reg_info_update(ctx, RCB_INTRA_ON_ROW, 150, cur_bit_size);

    /* RCB_FLTD_IN_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, in_tl_row) * (1.2 * bit_depth + 0.5)
                   * (12.5 + 6 * cur_uv_para + 1.5 * ctx->lr_en);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_IN_ROW, 152, cur_bit_size);

    /* RCB_FLTD_PROT_IN_ROW */
    cur_bit_size = 0;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_PROT_IN_ROW,  154, cur_bit_size);

    /* RCB_FLTD_ON_ROW */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_row_uv_coef_map[rcb_fmt];
    cur_bit_size = ROUNDUP(64, on_tl_row) * (1.2 * bit_depth + 0.5)
                   * (12.5 + 6 * cur_uv_para + 1.5 * ctx->lr_en);
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_ROW, 156, cur_bit_size);

    /* RCB_FLTD_ON_COL */
    cur_bit_size = 0;
    cur_uv_para = vdpu_filter_col_uv_coef_map[rcb_fmt];
    if (ctx->tile_dir == 0)
        cur_bit_size = ROUNDUP(64, on_tl_col) * (1.6 * bit_depth + 0.5)
                       * (14 + 7 * cur_uv_para + (14 + 12.5 * cur_uv_para) * ctx->lr_en
                          + ( ctx->upsc_en ? (8.5 + 7 * cur_uv_para) : (5 + 1 * cur_uv_para)));
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_ON_COL, 158, cur_bit_size);

    /* RCB_FLTD_UPSC_ON_COL */
    cur_bit_size = 0;
    cur_bit_size = DIVUP(64, on_tl_col) * bit_depth * 22;
    vdpu_rcb_reg_info_update(ctx, RCB_FLTD_UPSC_ON_COL, 160, cur_bit_size);

    *total_size = vdpu_rcb_get_total_size(ctx);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_test_setup_base_info(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    rcb_tl_info tl_info;

    /* update general info */
    vdpu_rcb_set_pic_w(ctx, info->pic_w);
    vdpu_rcb_set_pic_h(ctx, info->pic_h);
    vdpu_rcb_set_fmt(ctx, info->fmt);
    vdpu_rcb_set_bit_depth(ctx, info->bit_depth);

    /* add tile info */
    /* Simplify the calculation. */
    tl_info.lt_x = 0;
    tl_info.lt_y = 0;
    tl_info.w = info->pic_w;
    tl_info.h = info->pic_h;
    vdpu_rcb_set_tile_dir(ctx, 0);
    vdpu_rcb_add_tile_info(ctx, &tl_info);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_calc_sram_ddr_sz(vdpu_rcb_ctx *ctx)
{
    int i = 0;
    int sram_sz = 0;
    int ddr_sz = 0;
    vdpu_rcb_buf_info *buf_info = ctx->buf_info;

    for (i = 0; i < RCB_BUF_CNT; i++) {
        if (vdpu_rcb_type2loc_map[i] == VDPU_RCB_IN_TILE_ROW)
            sram_sz += buf_info[i].size;
        else
            ddr_sz += buf_info[i].size;
    }

    printf("sram_sz:%-8d ddr_sz:%-8d total_sz:%-8d\n", sram_sz, ddr_sz, ctx->buf_sz);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_h264_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    vdpu_reg_com_addr regs;

    vdpu_rcb_reset(ctx);

    vdpu384b_rcb_test_setup_base_info(ctx, info);

    /* update cur spec info */
    vdpu_rcb_set_mbaff_flag(ctx, info->mbaff_flag);

    vdpu_rcb_register_calc_handle(ctx, vdpu384b_rcb_h264_calc_rcb_bufs);
    vdpu_rcb_calc_exec(ctx, &info->total_sz);
    vdpu_setup_rcb(ctx, &regs, -1);

    vdpu_rcb_dump_rcb_result(ctx);

    vdpu384b_rcb_calc_sram_ddr_sz(ctx);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_h265_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    vdpu_reg_com_addr regs;

    vdpu_rcb_reset(ctx);

    vdpu384b_rcb_test_setup_base_info(ctx, info);

    vdpu_rcb_register_calc_handle(ctx, vdpu384b_rcb_h265_calc_rcb_bufs);
    vdpu_rcb_calc_exec(ctx, &info->total_sz);
    vdpu_setup_rcb(ctx, &regs, -1);

    vdpu_rcb_dump_rcb_result(ctx);

    vdpu384b_rcb_calc_sram_ddr_sz(ctx);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_avs2_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    vdpu_reg_com_addr regs;

    vdpu_rcb_reset(ctx);

    vdpu384b_rcb_test_setup_base_info(ctx, info);

    /* update cur spec info */
    vdpu_rcb_set_alf_en(ctx, info->alf_en);

    vdpu_rcb_register_calc_handle(ctx, vdpu384b_rcb_avs2_calc_rcb_bufs);
    vdpu_rcb_calc_exec(ctx, &info->total_sz);
    vdpu_setup_rcb(ctx, &regs, -1);

    vdpu_rcb_dump_rcb_result(ctx);

    vdpu384b_rcb_calc_sram_ddr_sz(ctx);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_vp9_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    vdpu_reg_com_addr regs;

    vdpu_rcb_reset(ctx);

    vdpu384b_rcb_test_setup_base_info(ctx, info);

    vdpu_rcb_register_calc_handle(ctx, vdpu384b_rcb_vp9_calc_rcb_bufs);
    vdpu_rcb_calc_exec(ctx, &info->total_sz);
    vdpu_setup_rcb(ctx, &regs, -1);

    vdpu_rcb_dump_rcb_result(ctx);

    vdpu384b_rcb_calc_sram_ddr_sz(ctx);

    return RET_OK;
}

RET_STAT vdpu384b_rcb_av1_test(vdpu_rcb_ctx *ctx, rcb_calc_test_info *info)
{
    vdpu_reg_com_addr regs;

    vdpu_rcb_reset(ctx);

    vdpu384b_rcb_test_setup_base_info(ctx, info);

    /* update cur spec info */
    vdpu_rcb_set_lr_en(ctx, info->lr_en);
    vdpu_rcb_set_upsc_en(ctx, info->upsc_en);

    vdpu_rcb_register_calc_handle(ctx, vdpu384b_rcb_av1_calc_rcb_bufs);
    vdpu_rcb_calc_exec(ctx, &info->total_sz);
    vdpu_setup_rcb(ctx, &regs, -1);

    vdpu_rcb_dump_rcb_result(ctx);

    vdpu384b_rcb_calc_sram_ddr_sz(ctx);

    return RET_OK;
}
