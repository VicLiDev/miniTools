import os
import time
import numpy as np
import cv2

supported_formats = ('yv12', 'iyuv', 'i420', 'nv12', 'nv21')

def yuv_import(filename, dims, frm_num, startfrm):
    fp = open(filename, "rb")
    blk_size = np.prod(dims) * 3/2
    fp.seek(int(blk_size) * startfrm, 0)
    y = []
    u = []
    v = []
    d00 = dims[0] // 2
    d01 = dims[1] // 2
    print(d00)
    print(d01)
    for i in range(frm_num):
        # 每次读数据前要清零，不然会保存第一次读到的数据
        yt = np.zeros((dims[0], dims[1]), np.uint8, "c")
        ut = np.zeros((d00, d01), np.uint8, "c")
        vt = np.zeros((d00, d01), np.uint8, "c")
        for m in range(dims[0]):
            for n in range(dims[1]):
                #print(m, n)
                yt[m, n] = ord(fp.read(1))
        for m in range(d00):
            for n in range(d01):
                ut[m, n] = ord(fp.read(1))
        for m in range(d00):
            for n in range(d01):
                vt[m, n] = ord(fp.read(1))
        y = y + [yt]
        u = u + [ut]
        v = v + [vt]

        print("file:%-15s cur frm:%-3d   cur file loc:%d "%(filename, i, fp.tell()))
    fp.close()
    return (y, u, v)

def get_bits_per_pixel(pixformat):
    # all currently supported formats are 420
    return 12

def compare_matrix(mat1, mat2):
    if ((mat1.shape[0] != mat2.shape[0]) | (mat1.shape[1] != mat2.shape[1])):
        print("mat1 and mat2 shape is not equal")
        print("mat1 shape is: ", mat1.shape)
        print("mat2 shape is: ", mat2.shape)
        return False
    mat_tmp = mat1 - mat2
    return np.all(mat_tmp == 0) # True:equal False:not equal

def display_yuv(data, frame_rate):
    # convert yuv to rgb and display
    # https://stackoverflow.com/questions/60729170/python-opencv-converting-planar-yuv-420-image-to-rgb-yuv-array-format   第一个回答
    # print("data type is: ", type(data))
    # print("data[0] type is: ", type(data[0]))
    # print("data[0][0] type is: ", type(data[0][0]))
    for i in range(frame_num):
        row = data[0][0].shape[0]
        col = data[0][0].shape[1]
        tmp = np.vstack((data[0][i], data[1][i].reshape(row//4, col), data[2][i].reshape(row//4, col)))
        rgb_tmp = cv2.cvtColor(tmp, cv2.COLOR_YUV2BGR_I420);
        text = "cur frame: " + str(i+1)
        # cv2.putText(img, text, org, fontFace, fontScale, color, thickness=None, lineType=None, bottomLeftOrigin=None)
        # img：操作的图片数组
        # text：需要在图片上添加的文字
        # fontFace：字体风格设置
        # fontScale：字体大小设置
        # color：字体颜色设置
        # thickness：字体粗细设置
        cv2.putText(rgb_tmp, text, (0,20), cv2.FONT_HERSHEY_SIMPLEX, 0.7,(0,255,0), 1, cv2.LINE_AA)
        cv2.imshow("rgb data", rgb_tmp)
        # time.sleep(1/frame_rate)
        cv2.waitKey(int(1000/frame_rate))
        
    # yy = data[0][0]
    # cv2.imshow("y data", yy)
    # yu = data[1][0]
    # cv2.imshow("u data", yu)
    # yv = data[2][0]
    # cv2.imshow("v data", yv)


def compare_yuv_data(data1, data2):
    y_list_size = len(data1[0])
    u_list_size = len(data1[1])
    v_list_size = len(data1[2])
    if ((y_list_size != len(data2[0])) | (y_list_size != len(data2[0])) | (y_list_size != len(data2[0]))) :
        print("data1 and data2 size is not equal")
        return False

    for i in range(y_list_size):
        if compare_matrix(data1[0][i], data2[0][i]) == False:
            print("data1 and data2 y matrix is not equal!")
            return False

    for i in range(u_list_size):
        if compare_matrix(data1[1][i], data2[1][i]) == False:
            print("data1 and data2 u matrix is not equal!")
            return False

    for i in range(v_list_size):
        if compare_matrix(data1[2][i], data2[2][i]) == False:
            print("data1 and data2 v matrix is not equal!")
            return False

    return True


if __name__ == "__main__":
    filename = "yuvvideo.yuv"
    pixformat = ""
    width = 720
    height = 480
    file_size = os.stat(filename).st_size
    frame_size = width * height * get_bits_per_pixel(pixformat) / 8 # bytes
    frame_num = int(file_size / frame_size)
    frame_rate = 25
    print("file size: ", )
    print("frame size: ", frame_size)
    print("frame number: ", frame_num)

    filename2 = "yuvvideo2.yuv"

    data = yuv_import(filename, (height, width), frame_num, 0)
    data2 = yuv_import(filename2, (height, width), int(os.stat(filename2).st_size / frame_size), 0)
    display_yuv(data, frame_rate)
    # compare matrix
    if compare_matrix(data[0][0], data2[0][1]):
        print("main: matrix1 and matrix2 is equal")
    else:
        print("main: matrix1 and matrix2 is not equal")

    # compare date
    if compare_yuv_data(data, data2):
        print("main: data1 and data2 is equal")
    else:
        print("main: data1 and data2 is not equal")

    cv2.waitKey(0)
