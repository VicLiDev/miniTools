# rk_ker_bd_ini — rkBuildKer.sh 平台构建配置

每个平台一份 ini, 新增平台只需复制一份修改, 无需改动主脚本。
参照 sdk_linux_gen 中"每个板子一个 defconfig"的思路。

## 部署

- git 仓库内: `1.compileRun/02.rk_tools/rk_ker_bd_ini/`
- 运行 `miniTools/init_tools.sh` 后, 软链到 `~/bin/rk_ker_bd_ini`
- rkBuildKer.sh 默认找脚本同目录的 `rk_ker_bd_ini`, 也可用 `--ini-dir <dir>`
  或环境变量 `RK_KER_BD_INI_DIR` 指定

## 字段说明

### [platform]
| key  | 必填 | 说明                      |
|------|------|---------------------------|
| name | 是   | 平台显示名 (选择菜单显示) |
| arch | 是   | arm / arm64               |

### [toolchain]
| key              | 必填 | 说明                                                              |
|------------------|------|-------------------------------------------------------------------|
| path             | 是   | 工具链 bin 目录, 多个候选用 `\| ` 分隔; **所有存在的都加入 PATH** |
| path_android_lt6 | 否   | android 平台且内核 VERSION `< 6` 时使用的工具链                   |
| env              | 否   | 额外环境变量, `KEY=value` 用 `\| ` 分隔 (值支持 `~` 前缀)         |
| make             | 是   | 编译命令模板, 如 `make CROSS_COMPILE=... LLVM=1`                  |

> Rust-for-Linux(Android 16 / kernel 6.12)示例见 `3588_android16.ini`:
> `path` 多目录(clang + rust + bindgen + kernel-build-tools) +
> `env`(RUSTC/BINDGEN/LIBCLANG_PATH/KBUILD_GENDWARFKSYMS_STABLE)。

### [build]
| key            | 必填 | 说明                                                                       |
|----------------|------|----------------------------------------------------------------------------|
| mode           | 否   | build_kernel / build_kmod / auto(检测 mpp Makefile 是否 obj-m, 默认)       |
| config         | 是   | defconfig 列表, 空格分隔; 可含 `${android_config}` 占位符                  |
| target         | 是   | make 目标, 可含 BOOT_IMG=/BOOT_ITS= 等                                     |
| android_config | 否   | android 平台: auto(自动检测 android-*.config) 或直接写如 android-12.config |

### [kmod]
| key | 必填 | 说明                                        |
|-----|------|---------------------------------------------|
| dir | 否   | mode=build_kmod 时模块目录 (相对 kernel 根) |
| ko  | 否   | 生成的 .ko 文件名                           |

### [flash]
| key      | 必填 | 说明                                                          |
|----------|------|---------------------------------------------------------------|
| method   | 否   | 编译后动作: rkut(烧录) / adb(insmod) / none, 默认按 mode 推断 |
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
rkBuildKer_v2.sh                # 交互选择平台 ini
rkBuildKer_v2.sh --ini 3588_android
rkBuildKer_v2.sh --ini /path/to/xxx.ini
rkBuildKer_v2.sh --list         # 列出所有可用 ini
rkBuildKer_v2.sh --env          # 只初始化环境并打印命令, 不编译
rkBuildKer_v2.sh --dir <kernel_path>
rkBuildKer_v2.sh --kernel       # 强制整编内核(默认按 mode/检测)
rkBuildKer_v2.sh --mod          # 强制单编模块
rkBuildKer_v2.sh --dry          # 只打印命令不执行
rkBuildKer_v2.sh --jobs <n>     # 并行度
```
