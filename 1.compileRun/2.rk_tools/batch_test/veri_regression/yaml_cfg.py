#!/usr/bin/env python
#########################################################################
# File Name: yaml_cfg.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 24 May 10:30:54 2025
#########################################################################

import yaml
import os
from datetime import datetime
from typing import List, Dict, Optional, Generator, Tuple, Any

class YamlCfgService:
    def __init__(self, cfg_path: str):
        self.cfg_path: str = cfg_path
        self.config: Dict[str, Any] = {}

        if not os.path.exists(cfg_path):
            raise FileNotFoundError(f"YAML config not found: {cfg_path}")
        with open(cfg_path, 'r') as f:
            self.config = yaml.safe_load(f)
        self.modified: bool = False # 标记是否有变更

    def dec_get_support(self, plt) -> List[str]:
        for entry in self.config.get('dec_support', []):
            if entry['platform'] == plt:
                return entry.get('support', [])
        return []

    def dec_get_all_paths(self) -> List[str]:
        return [entry['path'] for entry in self.config.get('dec_infos', [])]

    def dec_get_tags_for_path(self, path: str) -> List[str]:
        for entry in self.config.get('dec_infos', []):
            if entry['path'] == path:
                return entry.get('tags', [])
        return []

    def dec_get_videos_for_path(self, path: str) -> List[Dict[str, Any]]:
        for entry in self.config.get('dec_infos', []):
            if entry['path'] == path:
                return entry.get('videos', [])
        return []

    def dec_get_video_by_name(self, path: str, name: str) -> Optional[Dict[str, Any]]:
        for video in self.dec_get_videos_for_path(path):
            if video.get("name") == name:
                return video
        return None

    def dec_get_all_videos(self) -> Generator[Tuple[str, Dict[str, Any]], None, None]:
        for entry in self.config.get("dec_infos", []):
            path = entry["path"]
            for video in entry.get("videos", []):
                yield path, video

    def dec_set_video_property(self, path: str, video_name: str, key: str, value: Any) -> None:
        video = self.dec_get_video_by_name(path, video_name)
        if video is not None:
            if key not in video or video.get(key) != value:
                video[key] = value
                self.modified = True
                print(f"Updated {path}/{video_name}: set {key} = {value}")
        else:
            raise ValueError(f"Video '{video_name}' not found in path '{path}'")

    def save(self, out_fname: Optional[str] = None, output_dir: Optional[str] = None) -> None:
        if not self.modified:
            print("No changes to save.")
            return

        timestamp = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
        fname = f"config_{timestamp}.yaml"
        if len(out_fname) > 0:
            fname = out_fname
        output_path = os.path.join(output_dir or os.path.dirname(self.cfg_path), fname)

        with open(output_path, 'w') as f:
            yaml.safe_dump(self.config, f, sort_keys=False)

        print(f"Saved updated config to: {output_path}")
        self.modified = False


def main():
    cfg_srv = YamlCfgService("config.yaml")

    # 获取所有路径
    paths = cfg_srv.dec_get_all_paths()
    print(paths)

    # 获取某路径下的标签
    print(cfg_srv.dec_get_tags_for_path(paths[0]))

    # 获取某路径下所有视频
    videos = cfg_srv.dec_get_videos_for_path(paths[0])
    for video in videos:
        print(video["name"])

    # 获取某路径下指定名称的视频
    first_strm_name = videos[0]["name"]
    video = cfg_srv.dec_get_video_by_name(paths[0], first_strm_name)
    if video:
        print(video.get("width", "--"), video.get("md5", "--"))

    # 遍历所有视频
    for path, video in cfg_srv.dec_get_all_videos():
        print(f"{path}/{video['name']}")

    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "spec", "h264")
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "width", 1920)
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "height", 1088)
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "pix_fmt", "yuv420")
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "bit_depth", "10")
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "md5", "abc123def456")
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "ref_yuv", "None")
    cfg_srv.dec_set_video_property(paths[0], first_strm_name, "verify_info", "/ref/video1.chk")
    cfg_srv.save()

    pass

if __name__ == "__main__":
    main()
