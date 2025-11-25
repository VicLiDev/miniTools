/*************************************************************************
    > File Name: rcb_calc.h
    > Author: LiHongjin
    > Mail: 872648180@qq.com
    > Created Time: Mon 24 Nov 2025 05:35:33 PM CST
 ************************************************************************/

#ifndef __RCB_CALC_H__
#define __RCB_CALC_H__

#define DUMP_RES_EN 0

#define ALIGN(x, a)         (((x)+(a)-1)&~((a)-1))
#define RCB_ALLINE_SIZE     (64)
#define RCB_BYTES(bits)     ((int)(ALIGN(((int)ceilf(bits) + 7) / 8, RCB_ALLINE_SIZE)))
#define ARRAY_ELEMS(a)      ((int)(sizeof(a) / sizeof((a)[0])))

#define ROUNDUP(N, M)       ALIGN(M, N)
#define DIVUP(N, M)         ROUNDUP(N, M) / N

typedef enum RET_STATE_e {
    RET_OK     = 0,
    RET_NOK    = -1,
    RET_NOMEM  = -2,
} RET_STAT;

typedef struct vdpu_reg_com_addr_t {
    int reg140_rcb_strmd_row_offset;
    int reg141_rcb_strmd_row_len;
    int reg142_rcb_strmd_tile_row_offset;
    int reg143_rcb_strmd_tile_row_len;
    int reg144_rcb_inter_row_offset;
    int reg145_rcb_inter_row_len;
    int reg146_rcb_inter_tile_row_offset;
    int reg147_rcb_inter_tile_row_len;
    int reg148_rcb_intra_row_offset;
    int reg149_rcb_intra_row_len;
    int reg150_rcb_intra_tile_row_offset;
    int reg151_rcb_intra_tile_row_len;
    int reg152_rcb_filterd_row_offset;
    int reg153_rcb_filterd_row_len;
    int reg154_rcb_filterd_protect_row_offset;
    int reg155_rcb_filterd_protect_row_len;
    int reg156_rcb_filterd_tile_row_offset;
    int reg157_rcb_filterd_tile_row_len;
    int reg158_rcb_filterd_tile_col_offset;
    int reg159_rcb_filterd_tile_col_len;
    int reg160_rcb_filterd_av1_upscale_tile_col_offset;
    int reg161_rcb_filterd_av1_upscale_tile_col_len;
} vdpu_reg_com_addr;

typedef enum vdpu_rcb_type_e {
    RCB_STRMD_IN_ROW,
    RCB_STRMD_ON_ROW,
    RCB_INTER_IN_ROW,
    RCB_INTER_ON_ROW,
    RCB_INTRA_IN_ROW,
    RCB_INTRA_ON_ROW,
    RCB_FLTD_IN_ROW,
    RCB_FLTD_PROT_IN_ROW,
    RCB_FLTD_ON_ROW,
    RCB_FLTD_ON_COL,
    RCB_FLTD_UPSC_ON_COL,
    RCB_BUF_CNT,
} vdpu_rcb_type;

typedef enum vdpu_tile_loc_e {
    VDPU_RCB_IN_TILE_ROW = 0,
    VDPU_RCB_IN_TILE_COL,
    VDPU_RCB_ON_TILE_ROW,
    VDPU_RCB_ON_TILE_COL,
} vdpu_tile_loc ;

typedef enum codec_type_e {
    CODEC_H264,
    CODEC_H265,
    CODEC_H266,
    CODEC_AVS2,
    CODEC_AVS3,
    CODEC_VP9,
    CODEC_AV1,
    CODEC_AV2,
} codec_type;

typedef enum vdpu_rcb_fmt_e {
    RCB_FMT_YUV400 = 0,
    RCB_FMT_YUV420,
    RCB_FMT_YUV422,
    RCB_FMT_YUV444,
    RCB_FMT_BUTT,
} vdpu_rcb_fmt;

typedef struct rcb_tl_info_t {
    int idx;
    int lt_x;
    int lt_y;
    int w;
    int h;
} rcb_tl_info;

typedef struct vdpu_rcb_buf_info_t {
    int reg_idx;
    int size;
    int offset;
} vdpu_rcb_buf_info;

typedef RET_STAT (*vdpu_rcb_calc_f)(void *ctx, int *total_sz);

typedef struct vdpu_rcb_ctx_t {
    int                 pic_w;
    int                 pic_h;

    /* tile info */
    rcb_tl_info         *tile_infos;
    int                 tile_num;
    int                 tile_info_cap;
    int                 tile_dir;   /* 0: left to right, 1: top to bottom */

    /* general */
    vdpu_rcb_fmt        fmt;
    int                 bit_depth;
    int                 buf_sz;
    /* h264 */
    int                 mbaff_flag;
    /* avs2 */
    int                 alf_en;
    /* av1 */
    int                 lr_en;
    int                 upsc_en;

    vdpu_rcb_calc_f     calc_func;
    vdpu_rcb_buf_info   buf_info[RCB_BUF_CNT];
} vdpu_rcb_ctx;

typedef struct dev_rcb_info_cfg_t {
    int reg_idx;
    int size;
} dev_rcb_info_cfg;

typedef enum vdpu_rcb_set_mode_e {
    RCB_SET_BY_SIZE_SORT_MODE,
    RCB_SET_BY_PRIORITY_MODE,
} vdpu_rcb_set_mode;

extern int vdpu_rcb_type2loc_map[RCB_BUF_CNT];
extern int vdpu_intra_uv_coef_map[RCB_FMT_BUTT];
extern int vdpu_filter_row_uv_coef_map[RCB_FMT_BUTT];
extern int vdpu_filter_col_uv_coef_map[RCB_FMT_BUTT];

RET_STAT vdpu_rcb_calc_init(vdpu_rcb_ctx **ctx);
RET_STAT vdpu_rcb_calc_deinit(vdpu_rcb_ctx *ctx);
RET_STAT vdpu_rcb_reset(vdpu_rcb_ctx *ctx);
RET_STAT vdpu_rcb_add_tile_info(vdpu_rcb_ctx *ctx, rcb_tl_info *tile_info);
RET_STAT vdpu_rcb_dump_tile_info(vdpu_rcb_ctx *ctx);

void vdpu_rcb_set_pic_w(vdpu_rcb_ctx *ctx, int pic_w);
int vdpu_rcb_get_pic_w(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_pic_h(vdpu_rcb_ctx *ctx, int pic_h);
int vdpu_rcb_get_pic_h(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_tile_dir(vdpu_rcb_ctx *ctx, int tile_dir);
int vdpu_rcb_get_tile_dir(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_fmt(vdpu_rcb_ctx *ctx, vdpu_rcb_fmt fmt);
vdpu_rcb_fmt vdpu_rcb_get_fmt(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_bit_depth(vdpu_rcb_ctx *ctx, int bit_depth);
int vdpu_rcb_get_bit_depth(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_mbaff_flag(vdpu_rcb_ctx *ctx, int mbaff_flag);
int vdpu_rcb_get_mbaff_flag(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_alf_en(vdpu_rcb_ctx *ctx, int alf_en);
int vdpu_rcb_get_alf_en(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_lr_en(vdpu_rcb_ctx *ctx, int lr_en);
int vdpu_rcb_get_lr_en(vdpu_rcb_ctx *ctx);
void vdpu_rcb_set_upsc_en(vdpu_rcb_ctx *ctx, int upsc_en);
int vdpu_rcb_get_upsc_en(vdpu_rcb_ctx *ctx);

int vdpu_rcb_get_len(vdpu_rcb_ctx *ctx, vdpu_tile_loc loc, int *len);
RET_STAT vdpu_rcb_get_extra_size(vdpu_rcb_ctx *ctx, vdpu_tile_loc loc, int *extra_sz);
int vdpu_rcb_reg_info_update(vdpu_rcb_ctx *ctx, vdpu_rcb_type type, int idx, float sz);
int vdpu_rcb_get_total_size(vdpu_rcb_ctx *ctx);
int vdpu_rcb_register_calc_handle(vdpu_rcb_ctx *ctx, vdpu_rcb_calc_f func);
int vdpu_rcb_calc_exec(vdpu_rcb_ctx *ctx, int *total_sz);
void vdpu_setup_rcb(vdpu_rcb_ctx *ctx, vdpu_reg_com_addr *reg, int fd);
RET_STAT vdpu_set_rcbinfo(vdpu_rcb_buf_info *rcb_info);
RET_STAT vdpu_rcb_dump_rcb_result(vdpu_rcb_ctx *ctx);

#endif /* RCB_CALC_H__ */
