Validator 验证正确性
Regression 回归

项目取名:
RegressGuard
（Regression + Guard）
"回归守卫"，突出验证和保护作用。

VeriRegression
（Verification + Regression）
"验证回归"，直接表明核心功能。

AutoValidate
（Automated + Validation）
"自动验证"，强调自动化测试。

设计目标
1. 支持多种校验方式：
   a. 直接比较当前解码得到的yuv数据的md5值与之前解码得到的md5值
   b. 比较当前解码得到的yuv数据，与ffmpeg解码得到的yuv数据差异
   c. 使用demo生成的校验文件进行比较

2. 配置文件使用yaml
   a. 对于需要执行解码的数据源的目录放在配置文件中
   b. 每个路径下，可能有多个视频源文件，需要记录视频源文件对应的校验信息，例如旧的 md5值，和软件生成的文件路径等
   c. 每个路径下，需要有一些标签，例如 base,用户测试基础的解码，sys标签用于测试sys模块，且每个路径可能有多个标签


结构设计
yuv_checker/
├── main.py                  # 主程序入口
├── config.yaml              # 配置文件
├── decoder.py               # 解码模块
├── encoder.py               # 编码模块
├── verifier.py              # 各种校验逻辑
├── utils.py                 # 工具函数
└── checker/
    ├── md5_checker.py       # MD5 比对模块
    ├── diff_checker.py      # YUV 差异比对模块
    └── demo_checker.py      # demo 校验文件比对模块
