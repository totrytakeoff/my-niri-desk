# my-niri-desk

`my-niri-desk` 是一套面向 `Arch Linux` 的 `niri + QuickShell` 桌面预设包。

目标不是只提供零散配置，而是提供一条完整的安装链：

- 安装包
- 拉齐核心依赖
- 执行 `my-niri-desk-apply`
- 直接获得一套可用的 `niri` 第二桌面环境

当前这套预设已经包含：

- `niri` 窗口管理与快捷键
- `QuickShell` 顶栏、灵动岛、侧栏、通知与快捷设置
- `fcitx5` 输入法基础配置
- `hyprlock` 锁屏配置
- `fuzzel` 启动器
- `kitty` 终端配置
- `satty + OCR + wayscrollshot` 截图工具链
- `cliphist + QuickShell` 剪贴板历史
- 默认壁纸目录 `~/.config/wallpaper`

## 特性

- 基于 `niri` 的平铺/浮动混合工作流
- 基于 `QuickShell` 的统一桌面壳层
- 已接通：
  - 普通截图
  - OCR 截图识别
  - 长截图
  - 录音/录屏
  - 取色器
  - 剪贴板历史
- 右侧快捷设置：
  - 网络
  - 蓝牙
  - 音频
- 左侧 companion sidebar：
  - 总览
  - 进程
  - 会话
- 自带默认壁纸与 `matugen` 配色链

## 依赖说明

这个包会直接声明核心运行依赖，不要求你手动逐个补包。

依赖大致分为这些类别：

- 桌面与会话：
  - `niri`
  - `quickshell`
  - `qt6-5compat`
  - `qt6-wayland`
  - `xwayland-satellite`
- 输入法：
  - `fcitx5`
  - `fcitx5-chinese-addons`
- 多媒体与系统后端：
  - `pipewire`
  - `wireplumber`
  - `networkmanager`
  - `bluez`
  - `bluez-utils`
  - `power-profiles-daemon`
  - `upower`
- 截图与工具链：
  - `grim`
  - `slurp`
  - `wl-clipboard`
  - `cliphist`
  - `satty`
  - `tesseract`
  - `ffmpeg`
  - `wf-recorder`
  - `hyprpicker`
- 壁纸与配色：
  - `awww`
  - `matugen`
  - `imagemagick`
- 图标与字体：
  - `ttf-material-symbols-variable`
  - `otf-font-awesome`
  - `ttf-jetbrains-mono-nerd`
  - `adwaita-icon-theme`
- 常用桌面入口：
  - `kitty`
  - `fuzzel`
  - `nautilus`
  - `gnome-control-center`
  - `network-manager-applet`
  - `blueman`
  - `nm-connection-editor`
  - `pavucontrol`

另有少量增强依赖作为可选项：

- `playerctl`
- `cava`
- `noto-fonts-cjk`

完整依赖以 [PKGBUILD](/home/myself/workspace/my-niri-desk/PKGBUILD:1) 为准。

## 安装

### 方式 1：从 AUR 安装

包发布到 AUR 后，直接安装：

```bash
yay -S my-niri-desk
```

或：

```bash
paru -S my-niri-desk
```

### 方式 2：本地构建安装

```bash
cd /path/to/my-niri-desk
./scripts/aur-package.sh
```

## 应用配置

安装包只会把模板和工具装到系统目录，不会自动覆盖你的家目录配置。

安装后请以普通用户执行：

```bash
my-niri-desk-apply
```

这个脚本会：

- 备份你已有的相关配置
- 把模板复制到你的家目录
- 替换 `@HOME@` 之类的用户路径占位符
- 创建运行需要的目录
- 补齐默认壁纸目录 `~/.config/wallpaper`

默认壁纸会被放到：

```bash
~/.config/wallpaper
```

这套目录会被：

- QuickShell 的 `Launcher -> Wallpapers`
- 灵动岛的 `Wallpapers`

直接使用。

## 首次登录

执行完 `my-niri-desk-apply` 后：

1. 注销当前会话
2. 在登录界面选择 `Niri`
3. 重新登录

如果你已经在 `niri` 会话里，也可以先做静态检查：

```bash
niri validate -c ~/.config/niri/config.kdl
fuzzel --check-config
quickshell -p ~/.config/quickshell list --all
```

## 包安装了什么

这个包主要安装以下内容：

- `/usr/bin/wayscrollshot`
- `/usr/bin/my-niri-desk-apply`
- `/usr/share/my-niri-desk/skel`

其中 `/usr/share/my-niri-desk/skel` 是这套桌面配置模板的系统载荷。

## 升级策略

升级包后，你的家目录配置不会被自动覆盖。

如果你希望把包里的新版模板重新同步到家目录，请手动再次执行：

```bash
my-niri-desk-apply
```

脚本会先备份旧配置，再复制新模板。

## 开发同步

仓库里提供了一个维护脚本，用来检查本机配置和 `payload/skel` 是否漂移：

```bash
./scripts/sync-local-config.sh
```

常用用法：

```bash
./scripts/sync-local-config.sh status
./scripts/sync-local-config.sh diff
./scripts/sync-local-config.sh diff niri/config.kdl
./scripts/sync-local-config.sh diff .config/niri/scripts/screenshot-screen.sh
./scripts/sync-local-config.sh pull
./scripts/sync-local-config.sh push
./scripts/sync-local-config.sh status --include-wallpaper
./scripts/sync-local-config.sh pull --dry-run
```

说明：

- `status`：只检查差异，发现漂移时返回非零。
- `diff`：输出从仓库模板到本机配置的 unified diff，`-` 为仓库，`+` 为本机。
- `status/diff` 可以追加路径参数，只检查指定受管目录或文件；例如 `niri/config.kdl` 会自动展开为 `.config/niri/config.kdl`。
- `pull`：把仓库 `payload/skel` 同步回本机对应配置目录。
- `push`：把本机配置同步回仓库 `payload/skel`。
- `pull/push` 都会对受管目录使用 `rsync --delete`，并按内容 checksum 判断是否需要同步。
- 默认不包含 `~/.config/wallpaper`，避免把个人壁纸文件误同步到仓库。

## 当前范围

这个包的目标是提供一套稳定、完整、可继续迭代的第一版桌面环境。

当前更适合：

- 作为 `GNOME` 之外的第二桌面
- 作为 `niri` 的开箱即用预设
- 作为后续继续迭代的个人/共享配置基线

它不包含你的个人应用生态，例如：

- `QQ`
- `微信`
- `WPS`
- `OrcaSlicer`

这些会保持为用户自行安装。

## 已知说明

- 少量系统图标仍依赖 icon theme 名称解析，不同机器上可能存在个别图标差异。
- 中文字体风格在不同机器上可能略有不同，功能不受影响。
- 当前推荐在真实 Arch 环境或具备正常 Wayland/3D 支持的环境中使用。

## 仓库结构

- `payload/`
  配置与资源源文件
- `scripts/`
  应用与打包辅助脚本
- `docs/`
  安装、打包、发布说明
- `aur/my-niri-desk/`
  AUR 发布视图

## 文档

- [安装说明](/home/myself/workspace/my-niri-desk/docs/INSTALL.md:1)
- [打包说明](/home/myself/workspace/my-niri-desk/docs/PACKAGING.md:1)
- [发布流程](/home/myself/workspace/my-niri-desk/docs/RELEASE.md:1)

## AUR / 本地打包流程

同步 AUR 视图：

```bash
./scripts/sync-aur.sh
```

本地打包：

```bash
./scripts/aur-package.sh
```

推送到本地 AUR 仓库 clone：

```bash
./scripts/aur-push.sh /path/to/local/aur/repo
```

## GitHub CI/CD

仓库已预留 GitHub Actions 发布流程：

- 推送到 `main` / `master`
  - 自动构建包
  - 自动更新一个 `rolling` 预发布 release
- 推送形如 `v*` 的 tag
  - 自动构建包
  - 自动生成对应版本 release

release 附件会包含可直接安装的 Arch 包：

```bash
sudo pacman -U ./my-niri-desk-<version>-<rel>-x86_64.pkg.tar.zst
```

## 当前仓库内容

- [PKGBUILD](/home/myself/workspace/my-niri-desk/PKGBUILD:1)
- [my-niri-desk.install](/home/myself/workspace/my-niri-desk/my-niri-desk.install:1)
- [my-niri-desk-apply](/home/myself/workspace/my-niri-desk/scripts/my-niri-desk-apply:1)
- [payload/skel](/home/myself/workspace/my-niri-desk/payload/skel)

## 许可证

本仓库的打包与配置内容按仓库后续声明处理。

第三方组件保持各自上游许可证，例如：

- `wayscrollshot`
- `QuickShell`
- `niri`
