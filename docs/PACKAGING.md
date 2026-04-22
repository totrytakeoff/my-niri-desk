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

它只包含平铺文件：

- `PKGBUILD`
- `.SRCINFO`
- `my-niri-desk.install`

AUR 仓库不能包含子目录，因此：

- `payload/`
- `scripts/`

不会直接进入 AUR 仓库。

这些内容由 AUR `PKGBUILD` 从 GitHub tag 源码包中取出。

## 同步 AUR 视图

当你更新了：

- 根目录源码与 payload
- `aur/my-niri-desk/PKGBUILD`
- 根目录 `my-niri-desk.install`

执行：

```bash
./scripts/sync-aur.sh
```

## 本地打包

```bash
./scripts/aur-package.sh
```

它会先刷新 AUR 视图中的：

- `my-niri-desk.install`
- `.SRCINFO`

再执行 `makepkg -f`。
