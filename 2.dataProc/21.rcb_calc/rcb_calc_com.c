/*************************************************************************
    > File Name: rcb_calc.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Mon 24 Nov 2025 05:16:41 PM CST
 ************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "rcb_calc_com.h"

int vdpu_rcb_type2loc_map[RCB_BUF_CNT] = {
    [RCB_STRMD_IN_ROW]     = VDPU_RCB_IN_TILE_ROW,
    [RCB_STRMD_ON_ROW]     = VDPU_RCB_ON_TILE_ROW,
    [RCB_INTER_IN_ROW]     = VDPU_RCB_IN_TILE_ROW,
    [RCB_INTER_ON_ROW]     = VDPU_RCB_ON_TILE_ROW,
    [RCB_INTRA_IN_ROW]     = VDPU_RCB_IN_TILE_ROW,
    [RCB_INTRA_ON_ROW]     = VDPU_RCB_ON_TILE_ROW,
    [RCB_FLTD_IN_ROW]      = VDPU_RCB_IN_TILE_ROW,
    [RCB_FLTD_PROT_IN_ROW] = VDPU_RCB_IN_TILE_ROW,
    [RCB_FLTD_ON_ROW]      = VDPU_RCB_ON_TILE_ROW,
    [RCB_FLTD_ON_COL]      = VDPU_RCB_ON_TILE_COL,
    [RCB_FLTD_UPSC_ON_COL] = VDPU_RCB_ON_TILE_COL,
};

int vdpu_intra_uv_coef_map[RCB_FMT_BUTT] = {
    [RCB_FMT_YUV400] = 1,
    [RCB_FMT_YUV420] = 2,
    [RCB_FMT_YUV422] = 2,
    [RCB_FMT_YUV444] = 3,
};

int vdpu_filter_row_uv_coef_map[RCB_FMT_BUTT] = {
    [RCB_FMT_YUV400] = 0,
    [RCB_FMT_YUV420] = 1,
    [RCB_FMT_YUV422] = 1,
    [RCB_FMT_YUV444] = 3,
};

int vdpu_filter_col_uv_coef_map[RCB_FMT_BUTT] = {
    [RCB_FMT_YUV400] = 0,
    [RCB_FMT_YUV420] = 1,
    [RCB_FMT_YUV422] = 3,
    [RCB_FMT_YUV444] = 3,
};

RET_STAT vdpu_rcb_calc_init(vdpu_rcb_ctx **ctx)
{
    vdpu_rcb_ctx *p = NULL;
    p = (vdpu_rcb_ctx *)calloc(1, sizeof(vdpu_rcb_ctx));
    p->tile_infos = (rcb_tl_info *)calloc(4, sizeof(rcb_tl_info));
    p->tile_info_cap = 4;
    p->fmt = RCB_FMT_BUTT;
    *ctx = p;

    return RET_OK;
}

RET_STAT vdpu_rcb_calc_deinit(vdpu_rcb_ctx *ctx)
{
    free(ctx->tile_infos);
    free(ctx);
    return RET_OK;
}

RET_STAT vdpu_rcb_reset(vdpu_rcb_ctx *ctx)
{
    ctx->pic_w = 0;
    ctx->pic_h = 0;
    /* tile info */
    ctx->tile_num = 0;
    ctx->tile_dir = 0;
    /* general */
    ctx->fmt = RCB_FMT_BUTT;
    ctx->bit_depth = 0;
    ctx->buf_sz = 0;
    /* h264 */
    ctx->mbaff_flag = 0;
    /* avs2 */
    ctx->alf_en = 0;
    /* av1 */
    ctx->lr_en = 0;
    ctx->upsc_en = 0;

    memset(ctx->buf_info, 0, sizeof(vdpu_rcb_buf_info) * RCB_BUF_CNT);

    return RET_OK;
}

RET_STAT vdpu_rcb_add_tile_info(vdpu_rcb_ctx *ctx, rcb_tl_info *tile_info)
{
    rcb_tl_info *tl_infos = NULL;
    rcb_tl_info *p = NULL;

    tl_infos = ctx->tile_infos;
    if (ctx->tile_num >= ctx->tile_info_cap) {
        ctx->tile_info_cap += 4;
        tl_infos = (rcb_tl_info *)realloc(tl_infos, sizeof(rcb_tl_info) * ctx->tile_info_cap);
        if (!tl_infos) {
            printf("realloc failed\n");
            return RET_NOMEM;
        }
        ctx->tile_infos = tl_infos;
    }
    p = &tl_infos[ctx->tile_num++];
    memcpy(p, tile_info, sizeof(rcb_tl_info));

    return RET_OK;
}

RET_STAT vdpu_rcb_dump_tile_info(vdpu_rcb_ctx *ctx)
{
    int i;
    rcb_tl_info *p = ctx->tile_infos;

    for (i = 0; i < ctx->tile_num; i++) {
        printf("tile %d: idx %d lt(%d,%d) w %d h %d\n",
                i, p[i].idx, p[i].lt_x, p[i].lt_y, p[i].w, p[i].h);
    }

    return RET_OK;
}

#define VDPU_RCB_ACCESSORS(type, field) \
    type vdpu_rcb_get_##field(vdpu_rcb_ctx *ctx) \
    { \
        return ((vdpu_rcb_ctx*)ctx)->field; \
    } \
    void vdpu_rcb_set_##field(vdpu_rcb_ctx *ctx, type v) \
    { \
        ((vdpu_rcb_ctx*)ctx)->field = v; \
    }

VDPU_RCB_ACCESSORS(int, pic_w)
VDPU_RCB_ACCESSORS(int, pic_h)
VDPU_RCB_ACCESSORS(int, tile_dir)
VDPU_RCB_ACCESSORS(vdpu_rcb_fmt, fmt)
VDPU_RCB_ACCESSORS(int, bit_depth)
VDPU_RCB_ACCESSORS(int, mbaff_flag)
VDPU_RCB_ACCESSORS(int, alf_en)
VDPU_RCB_ACCESSORS(int, lr_en)
VDPU_RCB_ACCESSORS(int, upsc_en)

int vdpu_rcb_get_len(vdpu_rcb_ctx *ctx, vdpu_tile_loc loc, int *len)
{
    rcb_tl_info *tile_p = NULL;
    int i = 0;
    int res = 0;
    int ret = 0;

    tile_p = ctx->tile_infos;

    if (loc == VDPU_RCB_IN_TILE_ROW) {
        for (i = 0, res = 0; i < ctx->tile_num; i++)
            res = res < tile_p[i].w ? tile_p[i].w : res;
    } else if (loc == VDPU_RCB_IN_TILE_COL) {
        printf("invalid tile loc %d\n", loc);
        ret = -1;
    } else if (loc == VDPU_RCB_ON_TILE_ROW) {
        res = ctx->pic_w;
    } else if (loc == VDPU_RCB_ON_TILE_COL) {
        if (ctx->tile_dir == 0) { /* left to right  */
            for (i = 0, res = 0; i < ctx->tile_num; i++)
                res = res < tile_p[i].h ? tile_p[i].h : res;
        } else { /* top to bottom */
            res = ctx->pic_h;
        }
    } else {
        printf("invalid tile loc %d\n", loc);
        ret = -1;
    }
    *len = res;

    return ret;
}

RET_STAT vdpu_rcb_get_extra_size(vdpu_rcb_ctx *ctx, vdpu_tile_loc loc, int *extra_sz)
{
    int i;
    int tl_row_num = 0;
    int tl_col_num = 0;
    int buf_size = 0;

    for (i = 0; i < ctx->tile_num; i++) {
        if (ctx->tile_infos[i].lt_y == 0)
            tl_row_num++;
        if (ctx->tile_infos[i].lt_x == 0)
            tl_col_num++;
    }

    if (loc == VDPU_RCB_ON_TILE_ROW)
        buf_size = (tl_row_num - 1) * 64;
    else if (loc == VDPU_RCB_ON_TILE_COL)
        buf_size = (tl_col_num - 1) * 64;
    else
        buf_size = 0;

    *extra_sz = buf_size;

    return RET_OK;
}

int vdpu_rcb_reg_info_update(vdpu_rcb_ctx *ctx, vdpu_rcb_type type, int idx, float sz)
{
    int extra_sz = 0;
    int result = 0;
    vdpu_tile_loc loc = vdpu_rcb_type2loc_map[type];

    vdpu_rcb_get_extra_size(ctx, loc, &extra_sz);
    result = RCB_BYTES(sz) + extra_sz;
    ctx->buf_info[type].reg_idx = idx;
    ctx->buf_info[type].offset = ctx->buf_sz;
    ctx->buf_info[type].size = result;
    ctx->buf_sz += result;

    return result;
}

int vdpu_rcb_get_total_size(vdpu_rcb_ctx *ctx)
{
    return ctx->buf_sz;
}

RET_STAT vdpu_rcb_register_calc_handle(vdpu_rcb_ctx *ctx, vdpu_rcb_calc_f func)
{
    ctx->calc_func = func;

    return RET_OK;
}

RET_STAT vdpu_rcb_calc_exec(vdpu_rcb_ctx *ctx, int *total_sz)
{
    if (ctx->calc_func) {
        return ctx->calc_func(ctx, total_sz);
    } else {
        printf("error: The compute function is not registered\n");
        return RET_NOK;
    }
}


void vdpu_setup_rcb(vdpu_rcb_ctx *ctx, vdpu_reg_com_addr *reg, int fd)
{
    vdpu_rcb_buf_info *info = ctx->buf_info;

    reg->reg140_rcb_strmd_row_offset           = fd;
    reg->reg142_rcb_strmd_tile_row_offset      = fd;
    reg->reg144_rcb_inter_row_offset           = fd;
    reg->reg146_rcb_inter_tile_row_offset      = fd;
    reg->reg148_rcb_intra_row_offset           = fd;
    reg->reg150_rcb_intra_tile_row_offset      = fd;
    reg->reg152_rcb_filterd_row_offset         = fd;
    reg->reg154_rcb_filterd_protect_row_offset = fd;
    reg->reg156_rcb_filterd_tile_row_offset    = fd;
    reg->reg158_rcb_filterd_tile_col_offset    = fd;
    reg->reg160_rcb_filterd_av1_upscale_tile_col_offset = fd;

    reg->reg141_rcb_strmd_row_len            =  info[RCB_STRMD_IN_ROW].size;
    reg->reg143_rcb_strmd_tile_row_len       =  info[RCB_STRMD_ON_ROW].size;
    reg->reg145_rcb_inter_row_len            =  info[RCB_INTER_IN_ROW].size;
    reg->reg147_rcb_inter_tile_row_len       =  info[RCB_INTER_ON_ROW].size;
    reg->reg149_rcb_intra_row_len            =  info[RCB_INTRA_IN_ROW].size;
    reg->reg151_rcb_intra_tile_row_len       =  info[RCB_INTRA_ON_ROW].size;
    reg->reg153_rcb_filterd_row_len          =  info[RCB_FLTD_IN_ROW].size;
    reg->reg155_rcb_filterd_protect_row_len  =  info[RCB_FLTD_PROT_IN_ROW].size;
    reg->reg157_rcb_filterd_tile_row_len     =  info[RCB_FLTD_ON_ROW].size;
    reg->reg159_rcb_filterd_tile_col_len     =  info[RCB_FLTD_ON_COL].size;
    reg->reg161_rcb_filterd_av1_upscale_tile_col_len = info[RCB_FLTD_UPSC_ON_COL].size;
}

static int vdpu_compare_rcb_size(const void *a, const void *b)
{
    int val = 0;
    vdpu_rcb_buf_info *p0 = (vdpu_rcb_buf_info *)a;
    vdpu_rcb_buf_info *p1 = (vdpu_rcb_buf_info *)b;

    val = (p0->size > p1->size) ? -1 : 1;

    return val;
}

RET_STAT vdpu_set_rcbinfo(vdpu_rcb_buf_info *rcb_info)
{
    dev_rcb_info_cfg rcb_cfg;
    int i;
    vdpu_rcb_set_mode set_rcb_mode = RCB_SET_BY_PRIORITY_MODE;
    int rcb_priority[RCB_BUF_CNT] = {
        RCB_FLTD_IN_ROW,
        RCB_INTER_IN_ROW,
        RCB_INTRA_IN_ROW,
        RCB_STRMD_IN_ROW,
        RCB_INTER_ON_ROW,
        RCB_INTRA_ON_ROW,
        RCB_STRMD_ON_ROW,
        RCB_FLTD_ON_ROW,
        RCB_FLTD_ON_COL,
        RCB_FLTD_UPSC_ON_COL,
        RCB_FLTD_PROT_IN_ROW,
    };
    /*
     * RCB_SET_BY_SIZE_SORT_MODE: by size sort
     * RCB_SET_BY_PRIORITY_MODE: by priority
     */

    switch (set_rcb_mode) {
    case RCB_SET_BY_SIZE_SORT_MODE : {
        vdpu_rcb_buf_info info[RCB_BUF_CNT];

        memcpy(info, rcb_info, sizeof(info));
        qsort(info, ARRAY_ELEMS(info),
              sizeof(info[0]), vdpu_compare_rcb_size);

        for (i = 0; i < ARRAY_ELEMS(info); i++) {
            rcb_cfg.reg_idx = info[i].reg_idx;
            rcb_cfg.size = info[i].size;
            if (rcb_cfg.size > 0) {
                /* ioctl to kernel */
            } else
                break;
        }
    } break;
    case RCB_SET_BY_PRIORITY_MODE : {
        vdpu_rcb_buf_info *info = rcb_info;
        int index = 0;

        for (i = 0; i < ARRAY_ELEMS(rcb_priority); i ++) {
            index = rcb_priority[i];

            rcb_cfg.reg_idx = info[index].reg_idx;
            rcb_cfg.size = info[index].size;
            if (rcb_cfg.size > 0) {
                /* ioctl to kernel */
            }
        }
    } break;
    default:
        break;
    }

    return RET_OK;
}

RET_STAT vdpu_rcb_dump_rcb_result(vdpu_rcb_ctx *ctx)
{
    if (!DUMP_RES_EN)
        return RET_OK;

    int i;
    vdpu_rcb_buf_info *info = ctx->buf_info;
    char rcb_descs[RCB_BUF_CNT][32] = {
        "RCB_STRMD_IN_ROW",
        "RCB_STRMD_ON_ROW",
        "RCB_INTER_IN_ROW",
        "RCB_INTER_ON_ROW",
        "RCB_INTRA_IN_ROW",
        "RCB_INTRA_ON_ROW",
        "RCB_FLTD_IN_ROW",
        "RCB_FLTD_PROT_IN_ROW",
        "RCB_FLTD_ON_ROW",
        "RCB_FLTD_ON_COL",
        "RCB_FLTD_UPSC_ON_COL",
    };

    for (i = 0; i < RCB_BUF_CNT; i++) {
        printf("rcb buf %2d: desc %-24s reg_idx %3d size %-8d offset %-4d\n",
                  i, rcb_descs[i], info[i].reg_idx, info[i].size, info[i].offset);
    }

    return RET_OK;
}
