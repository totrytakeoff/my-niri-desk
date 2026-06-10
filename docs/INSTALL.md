# 安装说明

## AUR 安装

发布到 AUR 后：

```bash
yay -S my-niri-desk
```

或：

```bash
paru -S my-niri-desk
```

## 本地构建安装

在仓库根目录执行：

```bash
./scripts/aur-package.sh
```

或手动：

```bash
cd aur/my-niri-desk
makepkg -si
```

## 应用桌面配置

包安装后，以普通用户执行：

```bash
my-niri-desk-apply
```

它会：

- 备份已有配置
- 把模板复制到家目录
- 替换 `@HOME@`
- 创建运行目录
- 补齐 `~/.config/wallpaper`
- 载入用户态 systemd 配置，并启用 `quickshell.service`

## 桌面 OOM 防护

安装包提供 `configure-desktop-oomd`，用于让 `systemd-oomd` 对桌面应用和后台任务提前介入，避免 swap 被打满后再触发全局 OOM：

```bash
sudo configure-desktop-oomd --apply
```

查看状态：

```bash
oomctl
```

期望看到 `Swap Used Limit: 75.00%`，并且 `app.slice` / `background.slice` 出现在受监控 cgroup 列表里。

说明：

- QuickShell 会作为 `quickshell.service` 运行。
- niri 快捷键、会话恢复脚本和 QuickShell 工具按钮会尽量通过 `desk-app-run` 启动独立 systemd user 单元。
- QuickShell launcher 的应用主列表保留原生 `.desktop` 启动方式，避免 Zed、VSCode 等单实例应用在 transient service 下启动异常。

## 首次进入 Niri

1. 注销当前会话
2. 选择 `Niri`
3. 重新登录

## 静态验证

```bash
niri validate -c ~/.config/niri/config.kdl
fuzzel --check-config
quickshell -p ~/.config/quickshell list --all
```
