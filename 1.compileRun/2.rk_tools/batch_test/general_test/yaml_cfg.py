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
                print(f"Updated {path} / {video_name}: set {key} = {value}")
        else:
            raise ValueError(f"Video '{video_name}' not found in path '{path}'")

    def save(self, output_dir: Optional[str] = None) -> None:
        if not self.modified:
            print("No changes to save.")
            return

        timestamp = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
        fname = f"config_{timestamp}.yaml"
        output_path = os.path.join(output_dir or os.path.dirname(self.cfg_path), fname)

        with open(output_path, 'w') as f:
            yaml.safe_dump(self.config, f, sort_keys=False)

        print(f"Saved updated config to: {output_path}")
        self.modified = False


def main():
    cfg_srv = YamlCfgService("config.yaml")

    # 获取所有路径
    print(cfg_srv.dec_get_all_paths())

    # 获取某路径下的标签
    print(cfg_srv.dec_get_tags_for_path("/videos/test1"))

    # 获取某路径下所有视频
    videos = cfg_srv.dec_get_videos_for_path("/videos/test1")
    for video in videos:
        print(video["name"])

    # 获取某路径下指定名称的视频
    video1 = cfg_srv.dec_get_video_by_name("/videos/test1", "video1.h264")
    print(video1["width"], video1.get("md5"))

    # 遍历所有视频
    for path, video in cfg_srv.dec_get_all_videos():
        print(f"{path}/{video['name']}")

    cfg_srv.dec_set_video_property("/videos/test1", "video1.h264", "height", 1088)
    cfg_srv.dec_set_video_property("/videos/test1", "video1.h264", "spec", "h264")
    cfg_srv.dec_set_video_property("/videos/test2", "video3.h264", "height", 1088)
    cfg_srv.save()

    pass

if __name__ == "__main__":
    main()
