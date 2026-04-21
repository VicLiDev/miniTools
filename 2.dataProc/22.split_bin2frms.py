#!/usr/bin/env python
#########################################################################
# File Name: 22.split_bin2frms.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 21 Apr 2026 10:00:00 AM CST
#########################################################################

"""
Split a binary file evenly into multiple frames.

Supports two modes:
  1. By frame count: specify how many frames to split into
  2. By frame size:  specify bytes per frame

ex:
  ./22.split_bin2frames.py input.bin -n 10          # split into 10 frames
  ./22.split_bin2frames.py input.bin -s 4096        # each frame 4096 bytes
  ./22.split_bin2frames.py input.bin -n 10 -o out/  # output to out/ dir
"""

import argparse
import os
import sys


def split_bin_to_frames(input_file: str, output_dir: str, frame_count: int = 0,
                        frame_size: int = 0, prefix: str = "frame"):
    with open(input_file, 'rb') as f:
        data = f.read()

    total_size = len(data)

    if frame_count > 0:
        if total_size % frame_count != 0:
            print(f"Error: file size ({total_size}) is not divisible by frame count ({frame_count})")
            sys.exit(1)
        frame_size = total_size // frame_count
        actual_frames = frame_count
    elif frame_size > 0:
        if total_size % frame_size != 0:
            print(f"Error: file size ({total_size}) is not divisible by frame size ({frame_size})")
            sys.exit(1)
        actual_frames = total_size // frame_size
    else:
        print("Error: must specify either -n (frame count) or -s (frame size)")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    # derive output filename extension from input file
    _, ext = os.path.splitext(input_file)
    if not ext:
        ext = ".bin"

    for i in range(actual_frames):
        start = i * frame_size
        end = start + frame_size
        out_path = os.path.join(output_dir, f"{prefix}_{i:04d}{ext}")
        with open(out_path, 'wb') as f:
            f.write(data[start:end])

    print(f"Input : {input_file} ({total_size} bytes)")
    print(f"Output: {output_dir}/")
    print(f"Frame size: {frame_size} bytes")
    print(f"Frames: {actual_frames}")


def main():
    parser = argparse.ArgumentParser(
        description="Split a binary file evenly into multiple frames.\n"
                    "  ex: ./<exe> input.bin -n 10\n"
                    "      ./<exe> input.bin -s 4096\n"
                    "      ./<exe> input.bin -n 10 -o out/",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument("input_file", help="Input binary file path")
    parser.add_argument("-n", "--frame-count", type=int, default=0,
                        help="Number of frames to split into")
    parser.add_argument("-s", "--frame-size", type=int, default=0,
                        help="Bytes per frame")
    parser.add_argument("-o", "--output-dir", default="frames",
                        help="Output directory (default: frames/)")
    parser.add_argument("-p", "--prefix", default="frame",
                        help="Output filename prefix (default: frame)")

    args = parser.parse_args()

    if args.frame_count == 0 and args.frame_size == 0:
        parser.error("must specify either -n (frame count) or -s (frame size)")

    split_bin_to_frames(
        args.input_file,
        output_dir=args.output_dir,
        frame_count=args.frame_count,
        frame_size=args.frame_size,
        prefix=args.prefix,
    )


if __name__ == "__main__":
    main()
