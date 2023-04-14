#!/bin/bash
clear

rootDir="/local/lhj/Projects/c_model2"

# ============ check ============
function resultCheck()
{
    checkCnt=10
    for ((loop=0; loop<checkCnt; loop++))
    do
        # file1="testOut/Frame000${loop}/loopfilter_sao_out_check.txt"
        # file2="testOut/Frame000${loop}/loopfilter_sao_data.dat"
        file1="testOut/Frame000${loop}/loopfilter_data.dat"
        file2="testOut/Frame000${loop}/loopfilter_data_ver.dat"
        # file1="testOut/Frame000${loop}/loopfilter_origin_data.dat"
        # file2="testOut/Frame000${loop}/loopfilter_origin_data_ver.dat"
        if [[ -e ${file1} ]] && [[ -e ${file2} ]]; then
            # echo "file1: ${file1}"
            # echo "file2: ${file2}"
            # diff ${file1} ${file2} > /dev/null
            md5Val1=`md5sum ${file1} | awk '{print $1}'`
            md5Val2=`md5sum ${file2} | awk '{print $1}'`
            if [ $md5Val1 = $md5Val2 ]; then
                echo "--> [res]: frame:${loop} file compare pass"
            else
                echo "--> [res]: frame:${loop} file compare faile    vimdiff ${file1} ${file2}"
            fi
        fi
    done
}

# ============ build ============

function buildAv1()
{
    # rm CMake* Makefile aom* cmake_install.cmake config examples gen_src libaom_srcs.* resize_util -r

    # make clean &&
    #     cmake ..  &&
    #     make -j 10
    make clean &&
        cmake -DCMAKE_BUILD_TYPE=Debug ..  &&
        make -j 10
}

function buildHevc()
{
    # rm CMake* Makefile aom* cmake_install.cmake config examples gen_src libaom_srcs.* resize_util -r

    # make clean &&
    #     cmake ..  &&
    #     make -j 10

    # cmake .. -DCMAKE_BUILD_TYPE=Debug -DERR_DETECT=1 -DCONFIG_HARDWARE=1 -DCMAKE_CXX_FLAGS="-Wall" &&
        make clean &&
        cmake .. -DCMAKE_BUILD_TYPE=Debug -DERR_DETECT=1 -DCONFIG_HARDWARE=1 &&
        make -j 10 &&
        make install
}

function buildAvs2()
{
    # rm CMake* Makefile aom* cmake_install.cmake config examples gen_src libaom_srcs.* resize_util -r
    cd Lbuild
    make clean &&
        cmake ../source \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_C_COMPILER=/bin/cc \
        -DCMAKE_CXX_COMPILER=/bin/c++ \
        -DCONFIG_HARDWARE=1 &&
        make -j 10
    cd ..
}

function buildVp9()
{
    # ./config.sh &&
    ./config.sh \
        --disable-vp8 \
        --disable-vp9-encoder \
        --disable-multithread \
        --disable-optimizations \
        --disable-docs \
        --disable-unit-tests \
        --enable-vp9-highbitdepth \
        --enable-debug \
        --enable-debug-libs \
        --disable-mmx \
        --disable-sse \
        --disable-sse2 \
        --disable-sse3 \
        --disable-ssse3 \
        --disable-sse4_1 \
        --disable-avx \
        --disable-avx2 \
        --disable-avx512 \
        --as=yasm \
        --enable-hardware &&
        make clean &&
        make -B
}

function buildAvc()
{
    make clean \
        && make -j 20
}

# ============ run ============

function runAv1Sig()
{
    av1Cmd="./aomdec \
        -i /path/to/video \
        -o testOut/output.yuv \
        -b 0 \
        -e 2 \
        -c av1_vdp_cfg \
        -g av1_cmodel_cfg \
        -f loopfilter=0xFFFFFFFFFFFFFFFF \
        -d testOut"

    if [ "$1" == "gdb" ];then
        gdb --command=debug.gdb --args $av1Cmd
    else
        $av1Cmd
    fi

    echo "cmd: ${av1Cmd}"
}

function runAv1Batch()
{
    bash ~/Projects/batch_test.sh av1 /test_data/Allegro_AV1 \
        && bash ~/Projects/batch_test.sh av1 /test_data/Allegro_AV1_2020_09_28 \
        && bash ~/Projects/batch_test.sh av1 /test_data/movie_video_testdata/av1
}

function runHevcSig()
{
    hevcCmd="./hm \
        -i /path/to/video \
        -b 0 \
        -e 10 \
        -g hevc_cmodel_cfg \
        -f loopfilter=0xFFFFFFFFFFFFFFFF,decctl=0x7 \
        -d testOut"

    if [ "$1" == "gdb" ];then
        gdb --command=debug.gdb --args $hevcCmd
    else
        $hevcCmd
    fi
    echo "cmd: ${hevcCmd}"
}

function runHevcBatch()
{
    bash ~/Projects/batch_test.sh hevc /test_data/allegro_hevc_stream 732 \
        && bash ~/Projects/batch_test.sh hevc /test_data/argon_streams_hevc_rockchip \
        && bash ~/Projects/batch_test.sh hevc /test_data/argon_streams_hevc_rockchip2 \
        && bash ~/Projects/batch_test.sh hevc /test_data/argon_streams_hevc_rockchip4 \
        && bash ~/Projects/batch_test.sh hevc /test_data/customer_error_stream/h265 \
        && bash ~/Projects/batch_test.sh hevc /test_data/error_stream_rk/err_stream_265 \
        && bash ~/Projects/batch_test.sh hevc /test_data/fpga_packet/normal_resolution/hevc \
        && bash ~/Projects/batch_test.sh hevc /test_data/fpga_packet/super_resolution/encoder_test/hevc \
        && bash ~/Projects/batch_test.sh hevc /test_data/fpga_packet/super_resolution/hevc \
        && bash ~/Projects/batch_test.sh hevc /test_data/hm-15.0-anchors \
        && bash ~/Projects/batch_test.sh hevc /test_data/mvc_stream_rk/H.265_mvc_stream \
        && bash ~/Projects/batch_test.sh hevc /test_data/movie_video_testdata/hevc \
        && bash ~/Projects/batch_test.sh hevc /test_data/super_resolution_stream/hevc \
        && bash ~/Projects/batch_test.sh hevc /test_data/super_resolution_stream/encoder_test/hevc
}

function runAvs2Sig()
{
    avs2Cmd="./Lbuild/bin/ldecod \
        -i /path/to/video \
        -o output/rec.yuv \
        -b 1 \
        -e 3 \
        -c source/bin/avs2_vdp_dec_cfg \
        -g source/bin/avs2_file_cmodel_cfg \
        -d testOut"

    if [ "$1" == "gdb" ];then
        gdb --command=debug.gdb --args $avs2Cmd
    else
        $avs2Cmd
    fi
    echo "cmd: ${avs2Cmd}"
}

function runAvs2Batch()
{
    bash ~/Projects/batch_test.sh avs2 /test_data/AVS2_allegro \
        && bash ~/Projects/batch_test.sh avs2 /test_data/avs2_rockchip \
        && bash ~/Projects/batch_test.sh avs2 /test_data/avs2_standard_workgroup \
        && bash ~/Projects/batch_test.sh avs2 /test_data/error_stream_rk/avs2_err_stream \
        && bash ~/Projects/batch_test.sh avs2 /test_data/fpga_packet/normal_resolution/avs2 \
        && bash ~/Projects/batch_test.sh avs2 /test_data/fpga_packet/super_resolution/avs2 \
        && bash ~/Projects/batch_test.sh avs2 /test_data/super_resolution_stream/avs2
}

function runVp9Sig()
{
    vp9Cmd="./vpxdec \
        -i /path/to/video \
        -o testOut/rec.yuv \
        -b 0 \
        -e 2 \
        -c vp9_vdp_cfg \
        -g vp9_cmodel_cfg \
        -f loopfilter=0xFFFFFFFFFFFFFFFF \
        -d testOut"

    if [ "$1" == "gdb" ];then
        gdb --command=debug.gdb --args $vp9Cmd
    else
        $vp9Cmd
    fi
    echo "cmd: ${vp9Cmd}"
}

function runVp9Batch()
{
    bash ~/Projects/batch_test.sh vp9 /test_data/argon_streams_vp9_rockchip \
        && bash ~/Projects/batch_test.sh vp9 /test_data/fpga_packet/normal_resolution/vp9 \
        && bash ~/Projects/batch_test.sh vp9 /test_data/fpga_packet/super_resolution/vp9 \
        && bash ~/Projects/batch_test.sh vp9 /test_data/super_resolution_stream/vp9
}

function runAvcSig()
{
    avcCmd="./build/jm \
        -i /path/to/video \
        -b 0 \
        -e 3 \
        -g build/h264_cmodel_cfg \
        -d build"

    if [ "$1" == "gdb" ];then
        gdb --command=debug.gdb --args $avcCmd
    else
        $avcCmd
    fi
    echo "cmd: ${avcCmd}"
}

function runAvcBatch()
{
    bash ~/Projects/batch_test.sh avc /test_data/allegro_h264_stream \
        && bash ~/Projects/batch_test.sh avc /test_data/customer_error_stream/h264 \
        && bash ~/Projects/batch_test.sh avc /test_data/error_stream_rk/err_stream_264 \
        && bash ~/Projects/batch_test.sh avc /test_data/fpga_packet/normal_resolution/h264 \
        && bash ~/Projects/batch_test.sh avc /test_data/fpga_packet/super_resolution/encoder_test/h264 \
        && bash ~/Projects/batch_test.sh avc /test_data/fpga_packet/super_resolution/h264 \
        && bash ~/Projects/batch_test.sh avc /test_data/super_resolution_stream/h264
        # && bash ~/Projects/batch_test.sh avc /test_data/super_resolution_stream/encoder_test/h264
}

case $1 in
    "av1")
        if [ "$2" = "b" ]; then
            buildAv1
        fi
        if [ $? -eq 0 ]; then
            if [ "$3" = "batch" ]; then
                runAv1Batch
            else
                runAv1Sig $3
            fi
        fi
        ;;
    "hevc")
        if [ "$2" = "b" ]; then
            buildHevc
        fi
        if [ $? -eq 0 ]; then
            if [ "$3" = "batch" ]; then
                runHevcBatch
            else
                runHevcSig $3
            fi
        fi
        ;;
    "avs2")
        if [ "$2" = "b" ]; then
            buildAvs2
        fi
        if [ $? -eq 0 ]; then
            if [ "$3" = "batch" ]; then
                runAvs2Batch
            else
                runAvs2Sig $3
            fi
        fi
        ;;
    "vp9")
        if [ "$2" = "b" ]; then
            buildVp9
        fi
        if [ $? -eq 0 ]; then
            if [ "$3" = "batch" ]; then
                runVp9Batch
            else
                runVp9Sig $3
            fi
        fi
        ;;
    "avc")
        if [ "$2" = "b" ]; then
            buildAvc
        fi
        if [ $? -eq 0 ]; then
            if [ "$3" = "batch" ]; then
                runAvcBatch
            else
                runAvcSig $3
            fi
        fi
        ;;
    "bt")
        cd "${rootDir}/c_model_av1/build/" && buildAv1 && runAv1Sig
        read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ];then exit 0; fi

        cd "${rootDir}/c_model_avs2/RD19.5/" && buildAvs2 && runAvs2Sig
        read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ];then exit 0; fi

        cd "${rootDir}/c_model_h264_v2/jm18.6/" && buildAvc && runAvcSig
        read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ];then exit 0; fi

        cd "${rootDir}/c_model_hevc_v2/build/" && buildHevc && runHevcSig
        read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ];then exit 0; fi

        cd "${rootDir}/c_model_vp9_10bit/libvpx-1.11.0/build/" && buildVp9 && runVp9Sig
        ;;
    *)
        echo "unsupport proc"
        ;;
esac

# resultCheck
