/*************************************************************************
    > File Name: 13.map_mbaff_raster_idx.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com 
    > Created Time: Thu Jul 27 11:42:54 2023
 ************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define PIC_WIDTH_IN_MBS 8

static int map_MBAFF_idx_to_raster_idx(int MBAFF_idx)
{
    int cur_double_line_begin;
    int cur_double_line_rem;
    int raster_idx;

    cur_double_line_begin = MBAFF_idx / PIC_WIDTH_IN_MBS / 2 * PIC_WIDTH_IN_MBS * 2;
    cur_double_line_rem = cur_double_line_begin ? MBAFF_idx % cur_double_line_begin : MBAFF_idx;

    raster_idx = cur_double_line_begin + (cur_double_line_rem % 2) * PIC_WIDTH_IN_MBS
                 + cur_double_line_rem / 2;
    return raster_idx;
}

static int map_raster_idx_to_MBAFF_idx(int raster_idx)
{
    int cur_double_line_begin;
    int cur_double_line_rem;
    int mbaff_idx;

    cur_double_line_begin = raster_idx / PIC_WIDTH_IN_MBS / 2 * PIC_WIDTH_IN_MBS * 2;
    cur_double_line_rem = cur_double_line_begin ? raster_idx % cur_double_line_begin : raster_idx;
    if (cur_double_line_rem < PIC_WIDTH_IN_MBS) // top
        mbaff_idx = cur_double_line_begin + (cur_double_line_rem % PIC_WIDTH_IN_MBS) * 2;
    else // bottom
        mbaff_idx = cur_double_line_begin + (cur_double_line_rem % PIC_WIDTH_IN_MBS) * 2 + 1;

    return mbaff_idx;
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;
    int mb_x, mb_y;
    int mb_idx;

    printf("raster idx -> mbaff idx:\n");
    mb_idx = 0;
    for (mb_y = 0; mb_y < PIC_WIDTH_IN_MBS * 2; mb_y++) {
        for (mb_x = 0; mb_x < PIC_WIDTH_IN_MBS; mb_x++)
            printf(" %3d ", map_raster_idx_to_MBAFF_idx(mb_idx++));
        printf("\n");
    }

    printf("\nraster idx -> mbaff idx -> raster idx:\n");
    mb_idx = 0;
    for (mb_y = 0; mb_y < PIC_WIDTH_IN_MBS * 2; mb_y++) {
        for (mb_x = 0; mb_x < PIC_WIDTH_IN_MBS; mb_x++)
            printf(" %3d ", map_MBAFF_idx_to_raster_idx(map_raster_idx_to_MBAFF_idx(mb_idx++)));
        printf("\n");
    }

    return 0;
}
