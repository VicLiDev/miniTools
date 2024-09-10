# `adb shell input`

`adb shell input` 命令用于在 Android 设备上通过命令行模拟输入事件，包括触摸屏操作、
按键事件、文本输入等。通过该命令，可以在无需实际操作设备的情况下模拟用户交互，对于
自动化测试、脚本编写和远程控制非常有用。

以下是对 `adb shell input` 命令的详细介绍，包括如何模拟触屏、事件触发、拖拽等操作。

---
## 基本命令结构
```bash
adb shell input <command> <arguments>
```
- `<command>`：输入操作类型，如 `text`、`keyevent`、`tap`、`swipe` 等。
- `<arguments>`：对应操作所需的参数。
---
## 1. 模拟点击（Tap）
**命令格式：**
```bash
adb shell input tap <x> <y>
```
- `<x>` 和 `<y>`：屏幕上的坐标位置。
- `<x>`：横坐标，屏幕左上角为(0,0)。
- `<y>`：纵坐标，屏幕左上角为(0,0)。

**示例：**
在坐标 (500, 1000) 处点击：
```bash
adb shell input tap 500 1000
```
---
## 2. 模拟滑动（Swipe）
用于模拟从一个坐标滑动到另一个坐标的操作，可用于滑动屏幕或拖拽元素。

**命令格式：**
```bash
adb shell input swipe <x1> <y1> <x2> <y2> [duration(ms)]
```
- `<x1> <y1>`：起始坐标。
- `<x2> <y2>`：结束坐标。
- `[duration(ms)]`：可选参数，滑动持续时间，单位为毫秒。

**示例：**
从坐标 (300, 800) 滑动到 (300, 300)，持续时间 500 毫秒：
```bash
adb shell input swipe 300 800 300 300 500
```
---
## 3. 模拟拖拽操作

拖拽通常需要长按某个位置，然后移动到目标位置。

**步骤：**

1. **长按起始位置**（通过增加持续时间实现）：
   ```bash
   adb shell input swipe <x1> <y1> <x1> <y1> <duration(ms)>
   ```
2. **拖拽到目标位置**：
   ```bash
   adb shell input swipe <x1> <y1> <x2> <y2> <duration(ms)>
   ```

**示例：**

长按坐标 (500, 500) 1 秒，然后拖拽到坐标 (800, 800)：
```bash
 长按
adb shell input swipe 500 500 500 500 1000
 拖拽
adb shell input swipe 500 500 800 800 500
```
---
## 4. 模拟按键事件（KeyEvent）

用于模拟设备的物理按键，如返回键、主页键、音量键等。

**命令格式：**
```bash
adb shell input keyevent <keycode>
```

**常用按键代码：**
- `KEYCODE_HOME` (3)：主页键
- `KEYCODE_BACK` (4)：返回键
- `KEYCODE_MENU` (82)：菜单键
- `KEYCODE_VOLUME_UP` (24)：音量增加
- `KEYCODE_VOLUME_DOWN` (25)：音量减小
- `KEYCODE_POWER` (26)：电源键

**示例：**
模拟按下返回键：
```bash
adb shell input keyevent 4
```
---

## 5. 输入文本

用于在输入框中输入文本内容。

**命令格式：**
```bash
adb shell input text '<string>'
```

**注意事项：**
- 空格需要用 `%s` 表示。
- 特殊字符需要进行 URL 编码。

**示例：**
输入文本 “Hello World!”：
```bash
adb shell input text 'Hello%sWorld%21'
```
---
## 6. 模拟长按

通过将滑动命令的起始和结束坐标设为相同，并增加持续时间来实现长按。

**命令格式：**
```bash
adb shell input swipe <x> <y> <x> <y> <duration(ms)>
```

**示例：**
在坐标 (400, 800) 处长按 2 秒：
```bash
adb shell input swipe 400 800 400 800 2000
```
---
## 7. 模拟滚动（Roll）

用于模拟滚轮滚动事件，主要用于滚动列表或页面。

**命令格式：**
```bash
adb shell input roll <dx> <dy>
```
- `<dx>`：水平滚动距离（正数向右，负数向左）。
- `<dy>`：垂直滚动距离（正数向下，负数向上）。

**示例：**
向上滚动 100 个单位：
```bash
adb shell input roll 0 -100
```
---
## 8. 获取屏幕尺寸

在模拟触摸操作时，了解设备的屏幕分辨率非常重要。

**命令：**
```bash
adb shell wm size
```
**示例输出：**
```
Physical size: 1080x1920
```
---
## 9. 组合操作脚本

可以将多个命令组合在一起，形成自动化脚本。

**示例：**
模拟打开应用、点击、输入文本并返回桌面：
```bash
 启动应用
adb shell am start -n com.example.app/.MainActivity
 点击某个坐标
adb shell input tap 200 300
 输入文本
adb shell input text 'Test%20Input'
 按返回键
adb shell input keyevent 4
```
---
## 10. 其他注意事项
- **权限要求**：确保设备已开启 USB 调试模式，并信任连接的计算机。
- **坐标定位**：可使用开发者选项中的“指针位置”功能查看实时坐标，辅助确定点击位置。
- **版本兼容性**：某些命令或参数可能在不同 Android 版本中有所差异。
---


# `am`

`am` 是 Android 系统中的 Activity Manager 命令 (`ActivityManager`)，用于从命令行
管理 Android 设备上的应用程序、进程、活动（Activity）等。通过 `adb`（Android Debug
Bridge）可以执行这些命令。它主要用于开发、调试和测试应用程序。

下面是 `am` 命令的一些主要用法和介绍：

## 基本命令结构
```bash
adb shell am <subcommand> <options>
```

其中 `<subcommand>` 是 `am` 的子命令，用于执行具体操作，`<options>` 是该子命令所需的参数。

## 常用子命令及其功能

### 1. **启动 Activity**
用于启动指定的 Activity，类似于点击应用图标启动应用的效果。

```bash
adb shell am start -n <package_name>/<activity_name>
```

- `-n`：指定应用包名和 Activity 名称，格式为 `package_name/activity_name`。

例如：
```bash
adb shell am start -n com.example.myapp/.MainActivity
```
此命令将启动包名为 `com.example.myapp` 的应用，并打开其中的 `MainActivity`。

你也可以通过 intent 启动活动：

```bash
adb shell am start -a <action> -d <data_uri>
```

示例：
```bash
adb shell am start -a android.intent.action.VIEW -d http://www.google.com
```
这个命令会打开浏览器并访问 Google 首页。

### 2. **停止应用**
停止某个应用的所有活动，类似于在应用设置中强行停止应用。

```bash
adb shell am force-stop <package_name>
```

例如：
```bash
adb shell am force-stop com.example.myapp
```

### 3. **启动服务**
启动某个应用中的服务（Service）。

```bash
adb shell am startservice -n <package_name>/<service_name>
```

例如：
```bash
adb shell am startservice -n com.example.myapp/.MyService
```

### 4. **发送广播**
通过 intent 向系统发送广播。

```bash
adb shell am broadcast -a <action> -n <package_name>/<broadcast_receiver>
```

例如：
```bash
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED
```

这个命令发送一个 `BOOT_COMPLETED` 的广播，可以用于触发注册的广播接收器（BroadcastReceiver）。

### 5. **杀死进程**
强制终止指定包名的应用进程。

```bash
adb shell am kill <package_name>
```

例如：
```bash
adb shell am kill com.example.myapp
```

### 6. **清除应用数据**
清除指定应用的所有数据，相当于在设置中点击“清除数据”。

```bash
adb shell am clear <package_name>
```

例如：
```bash
adb shell am clear com.example.myapp
```

### 7. **显示设备的内存使用情况**
显示设备当前的内存使用情况。

```bash
adb shell am dumpheap <package_name> <output_file>
```

你可以将内存转储到指定的文件中。

### 8. **查看 Activity 栈信息**
获取当前设备上的 Activity 栈信息，用于调试或检查当前 Activity 状态。

```bash
adb shell am stack list
```

### 9. **监视系统广播**
监视系统广播的传递情况。

```bash
adb shell am monitor
```

### 10. **终止服务**
停止正在运行的服务。

```bash
adb shell am stopservice -n <package_name>/<service_name>
```

例如：
```bash
adb shell am stopservice -n com.example.myapp/.MyService
```

### 11. **启动 Intent**
通过命令行启动指定的 Intent。

```bash
adb shell am start -a android.intent.action.VIEW -d <url>
```

例如，打开浏览器并访问 URL：
```bash
adb shell am start -a android.intent.action.VIEW -d http://www.google.com
```

## 其他命令
- `am instrument`：运行测试用例。
- `am profile`：启动或停止应用的性能分析。
- `am crash`：触发应用崩溃，用于测试崩溃处理机制。

## 总结
`am` 命令在 Android 系统中提供了对 Activity、Service、Broadcast 等应用组件的直接操作能力，常用于开发、调试和自动化测试。它结合了 Intent 的强大功能，可以在 Android 设备上模拟几乎所有用户操作。
