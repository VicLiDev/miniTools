/*************************************************************************
    > File Name: ctumpa.c
    > Author: LiHongjin
    > Mail: 872648180@qq.com 
    > Created Time: Wed Feb 15 19:51:17 2023
 ************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void file(int w, int h, int *buf)
{
    int x, y;

    for (y = 0; y < h; y++)
        for (x = 0; x < w; x++)
            buf[x + y * w] = x + y * w;
    
    return;
}

void dump(int w, int h, int *buf)
{
    int x, y;

    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            printf("%-5d ", buf[x + y * w]);
        }
        printf("\n");
    }
}

// calc_type
//      1: raster loc to zorder loc
//      2: zorder loc to raster loc
// intput x, y and output x, y use same general idx
void mapCalc(int w, int x, int y, int *mx, int *my, int calc_type)
{
    int genIdx = 0;
    int rem = 0;
    int bit_shift = 0;
    int run = 1;

    *mx = 0;
    *my = 0;
    if (calc_type == 0) { // map raster to zorder
        // calc gen idx
        genIdx = x + y * w;
        bit_shift = 0;
        // calc idx in zorder
        do {
            rem = (genIdx >> (bit_shift * 2)) % 4;
            *mx = *mx + (rem % 2 << bit_shift);
            *my = *my + (rem / 2 << bit_shift);
            bit_shift++;
            run = (genIdx >> (bit_shift * 2)) == 0 ? 0 : 1;
        } while (run);
    } else { // map zorder to raster
        bit_shift = 0;
        // calc gen idx
        do {
            rem = (x >> bit_shift) % 2;
            genIdx += rem << (bit_shift * 2);
            run = rem == 0 ? 0 : 1;
            rem = (y >> bit_shift) % 2;
            genIdx += rem << (bit_shift * 2 + 1);
            run = (x >> bit_shift == 0 && y >> bit_shift == 0) ? 0 : 1;
            bit_shift++;
        } while (run);
        // zorder x,y to rasterIdx
        *mx = genIdx % w;
        *my = genIdx / w;
    }

    return;
}


void mapToZorder(int w, int h, int *raster_buf, int *zorder_buf)
{
    int x, y;
    int mx, my;

    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            mapCalc(w, x, y, &mx, &my, 0);
            zorder_buf[mx + my * w] = raster_buf[x + y * w];
        }
    }

    return;
}

void mapToRaster(int w, int h, int *zorder_buf, int *raster_buf)
{
    int x, y;
    int mx, my;

    for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
            mapCalc(w, x, y, &mx, &my, 1);
            raster_buf[mx + my * w] = zorder_buf[x + y * w];
        }
    }

    return;
}

void mapTest(int w, int h)
{
    int unit_cnt = 128 * 128; // 0x4000  16384
    int *raster_buf = NULL;
    int *zorder_buf = NULL;

    raster_buf = (int *)malloc(sizeof(int) * unit_cnt);
    zorder_buf = (int *)malloc(sizeof(int) * unit_cnt);
    memset(raster_buf, 0, sizeof(int) * unit_cnt);
    memset(zorder_buf, 0, sizeof(int) * unit_cnt);

    file(w, h, raster_buf);
    printf("======> orign data (raster order) <======\n");
    dump(w, h, raster_buf);
    printf("\n");

    mapToZorder(w, h, raster_buf, zorder_buf);
    printf("======> map to zorder <======\n");
    dump(w, h, zorder_buf);
    printf("\n");

    mapToRaster(w, h, zorder_buf, raster_buf);
    printf("======> map to raster order <======\n");
    dump(w, h, raster_buf);
    printf("\n");

    free(raster_buf);
    free(zorder_buf);
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;
    // mapTest(4, 4);
    mapTest(16, 16);
    // mapTest(128, 128);
    return 0;
}
