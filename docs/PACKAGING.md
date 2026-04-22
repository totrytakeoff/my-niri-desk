# 打包说明

这个仓库采用双视图结构：

- 根目录：开发主仓库
- `aur/my-niri-desk`：AUR 发布视图

## 根目录职责

根目录保留：

- `payload/`
- `scripts/`
- `README.md`
- `docs/`
- `PKGBUILD`
- `.SRCINFO`
- `my-niri-desk.install`

## AUR 视图职责

`aur/my-niri-desk` 用于：

- 本地 AUR 风格构建
- 真正推送到 AUR 仓库

它包含：

- `PKGBUILD`
- `.SRCINFO`
- `my-niri-desk.install`
- `payload/`
- `scripts/`

其中 `scripts/` 只保留：

- `my-niri-desk-apply`

## 同步 AUR 视图

当根目录的这些文件更新后：

- `payload/`
- `scripts/`
- `PKGBUILD`
- `.SRCINFO`
- `my-niri-desk.install`

执行：

```bash
./scripts/sync-aur.sh
```

## 本地打包

```bash
./scripts/aur-package.sh
```

它会先同步 `aur/my-niri-desk`，再执行 `makepkg -f`。
