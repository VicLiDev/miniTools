# rk_ker_bd_ini — rkBuildKer.sh 平台构建配置

每个平台一份 ini, 新增平台只需复制一份修改, 无需改动主脚本。
参照 sdk_linux_gen 中"每个板子一个 defconfig"的思路。

## 部署

- git 仓库内: `04.spec_tools/01.rk_tools/01.rk_tools/rk_ker_bd_ini/`
- 运行 `miniTools/init_tools.sh` 会软链本目录到 `~/bin/rk_ker_bd_ini`
- 安装后的命令名为 `rkBuildKer.sh` (仓库内实现是 `rkBuildKer_v2.sh`)
- 固定从 `~/bin/rk_ker_bd_ini` 读取, 也可用 `--ini <path>` 直接指定单个 ini

## 字段说明

### [platform]
| key  | 必填 | 说明                      |
|------|------|---------------------------|
| name | 是   | 平台显示名 (选择菜单显示) |
| arch | 是   | arm / arm64 / riscv       |

### [toolchain]
| key              | 必填 | 说明                                                                    |
|------------------|------|-------------------------------------------------------------------------|
| path             | 是   | 工具链 bin 目录, 多个候选用 `\| ` 分隔; **所有存在的都加入 PATH**       |
| path_android_lt6 | 否   | android 平台且内核 VERSION `< 6` 时使用的工具链                         |
| cc               | 是   | 编译器族: `clang` / `gcc`; 只用于定位/校验编译器                        |
| cross            | 是   | 交叉前缀如 `aarch64-linux-gnu-`; **必填**, 本机编译也显式写 host 前缀   |
| extra            | 否   | make 额外参数; **clang 必须写 `LLVM=1 LLVM_IAS=1`**                     |
| env              | 否   | 额外环境变量, `KEY=value` 用 `\| ` 分隔 (值支持 `~`)                    |

> make 命令不再写在 ini 里, 只由字段机械拼接(无隐含策略):
> `make CROSS_COMPILE=<cross> [<extra>]`。
> `check_toolchain` 校验三件事: `<path>/clang`(或 `<path>/<cross>gcc`) 存在、
> `cross` 与 `arch` 匹配(clang 平台)、`cc` 与 `extra` 的编译器开关一致
> (`cc=clang` 必须有 `LLVM=`, `cc=gcc` 不能有)。
> 因此 clang 平台的 `extra` 必须写 `LLVM=1 LLVM_IAS=1`, 示例:
> `extra = LLVM=1 LLVM_IAS=1` 或 `extra = LT0=none LLVM=1 LLVM_IAS=1`。

> clang 平台的 `cross` 也要显式写: 它不用于查找编译器, 只决定 clang 的
> `--target=`。5.12 之前的内核没有架构表兜底, 空值会生成 `--target=`
> 并报 "unknown target triple"; arm32/riscv 的架构表默认值还与工具链
> ABI 不一致(`gnueabi` vs `gnueabihf`、`gnu` vs `musl`)。

> 若工具链里只有带前缀的 clang(如 `aarch64-linux-gnu-clang`), `cc` 仍写
> `clang`, 但 `extra` 必须写成 `CC=aarch64-linux-gnu-clang` 且**不要**写
> `LLVM=1`(LLVM=1 会把它固定成无前缀的 `clang`)。此时校验查找的也是
> `<path>/<cross>clang`。

> 本机编译(x86 等)同样要写 `cross`: 不带前缀虽然能跑, 但会静默落到主机
> gcc, 主机编译器与内核 `.config` 不一致时报的是一堆无关的编译错误。
> 脚本不做"空前缀 = 主机 gcc"的回退, 缺 `cross` 直接报
> `FAILED - no CROSS_COMPILE in [toolchain]`, 本机编译请显式写 host 前缀
> (如 `cross = x86_64-linux-gnu-`)。

> Rust-for-Linux(Android 16 / kernel 6.12)示例见 `rk3588_android16.ini`:
> `path` 多目录(clang + rust + bindgen + kernel-build-tools) +
> `env`(RUSTC/BINDGEN/LIBCLANG_PATH/KBUILD_GENDWARFKSYMS_STABLE,
> 以及 kernel-build-tools 的 LD_LIBRARY_PATH/HOSTCFLAGS/HOSTLDFLAGS)。

### [build]
| key            | 必填 | 说明                                                                       |
|----------------|------|----------------------------------------------------------------------------|
| config         | 是   | defconfig 列表, 空格分隔; 可含 `${android_config}` 占位符                  |
| target         | 是   | make 目标, 可含 BOOT_IMG=/BOOT_ITS= 等                                     |
| android_config | 否   | android 平台: auto(自动检测 android-*.config) 或直接写如 android-12.config |

> 构建方式(build_kernel / build_kmod)不属于平台配置: 默认检测 mpp Makefile
> 是否有 obj-m, 有则交互选择, 也可用 `--kernel` / `--mod` 强制。

### [kmod]
| key | 必填 | 说明                                        |
|-----|------|---------------------------------------------|
| dir | 否   | 单编模块时模块目录 (相对 kernel 根)         |
| ko  | 否   | 生成的 .ko 文件名                           |

### [flash]
| key      | 必填 | 说明                                                          |
|----------|------|---------------------------------------------------------------|
| method   | 否   | 编译后动作: rkut(烧录) / adb(insmod) / none, 默认按构建方式推断 |
| boot_img | 否   | rkut 时烧录的镜像名 (默认 boot.img)                           |
| reset    | 否   | rkut 烧录后是否复位设备 (true/false)                          |
| push_dir | 否   | adb 时 ko 推送目录 (默认 /data)                               |

### [config_patch] (可选)
编译前对 .config 的 sed 修改, 按键序执行:
```
[config_patch]
1 = s/# CONFIG_XXX is not set/CONFIG_XXX=y/g
2 = s/.../.../g
```

## 示例(demo)

`demo/` 目录下放了 3 个带注释的参考模板, 覆盖不同平台的字段差异:

| demo 文件                      | 对应平台                   | 关键差异                                           |
|--------------------------------|----------------------------|----------------------------------------------------|
| `demo/demo_linux.ini`          | Linux(gcc)                 | gcc 工具链, 无 android_config                      |
| `demo/demo_android.ini`        | Android ≤14 / kernel ≤6.1  | clang + `path_android_lt6` + `auto` 探测           |
| `demo/demo_android16_rust.ini` | Android 16 / 6.12          | 多目录 path + `env`(Rust) + 显式 android-16.config |

新增平台时复制对应 demo 改名即可(注: demo 在 `demo/` 子目录,
不会被 `--list` 列出)。

## 使用

```
rkBuildKer.sh                   # 交互选择平台 ini
rkBuildKer.sh --ini rk3588_android
rkBuildKer.sh --ini /path/to/xxx.ini
rkBuildKer.sh --list         # 列出所有可用 ini
rkBuildKer.sh --env          # 只初始化环境并打印命令, 不编译
rkBuildKer.sh --dir <kernel_path>
rkBuildKer.sh --kernel       # 强制整编内核(默认按 mpp obj-m 检测/交互选择)
rkBuildKer.sh --mod          # 强制单编模块
rkBuildKer.sh --dry          # 只打印命令不执行
rkBuildKer.sh --jobs <n>     # 并行度
```
