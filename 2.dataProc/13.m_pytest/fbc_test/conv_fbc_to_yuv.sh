#!env bash
#########################################################################
# File Name: conv_fbc_to_yuv.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 11 Apr 2024 10:35:16 AM CST
#########################################################################

# usaeg: ./conv_fbc_to_yuv.sh <roodir inc FrameN> <size> <8/10(bit)>
# ex: bash conv_fbc_to_yuv.sh <path to FrameN>  3840x2160 8

fbcHead="filterd_pp_out_afbc_head_data.dat"
fbcPayload="filterd_pp_out_afbc_payload_data.dat"
mergedata="afbc.dat"
convBinTool="${HOME}/Projects/miniTools/2.dataProc/15.conv_str_bin"
convBinFile="afbc.bin"
convYuvTool="wine ${HOME}/test/format_trans.exe"
convYuvFile="afbc.yuv"
mergeYuv="afbc_conv.yuv"

function conv_data2yuv()
{
    oldDir=`pwd`
    wkDir=$1
    size="$2"
    bitDep=$3

    cd ${wkDir}

    if [[ ! -e ${fbcHead} || ! -e ${fbcPayload} ]]; then
        echo "head file: ${fbcHead} maybe not exist!"
        echo "payload file: ${fbcPayload} maybe not exist!"
        exit 1
    else
        cat ${fbcHead} > ${mergedata}
        cat ${fbcPayload} >> ${mergedata}
    fi 
    
    echo "======> wkdir: ${wkDir} <======"
    echo "======> convert to bin"
    cmd="$convBinTool  -i ${mergedata} -o ${convBinFile} -b"
    echo "cmd: $cmd"
    $cmd
    
    echo "======> convert to yuv"
    cmd="${convYuvTool} -i ${convBinFile} -D ${size}_yuv420${bitDep}b_0_${size}_yuv420${bitDep}b_2_0_0 -o ${convYuvFile} -n 1"
    echo "cmd: $cmd"
    $cmd

    cd ${oldDir}
}


function main()
{
    RootDir=$1
    size=$2
    bitDep=$3

    cd $RootDir
    FrmDirList=(`find -maxdepth 1 -type d | grep Frame | sort`)

    if [ -e "${RootDir}/${mergeYuv}" ]; then
        rm ${RootDir}/${mergeYuv}
    fi
    for ((i = 0; i < ${#FrmDirList[@]}; i++))
    do
        conv_data2yuv "${FrmDirList[${i}]}" "${size}" "${bitDep}"
        cat ${FrmDirList[${i}]}/${convYuvFile} >> ${RootDir}/${mergeYuv}
    done

    cp ${RootDir}/${mergeYuv} ${HOME}/test/
}



main $@
