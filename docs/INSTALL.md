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

