# 发布流程

## GitHub 主仓库

主仓库负责：

- 源配置
- 文档
- 打包模板
- 脚本
- payload

不提交：

- `src/`
- `pkg/`
- `*.pkg.tar.zst`
- 本地 `wayscrollshot/` clone/cache

## GitHub Release

建议把构建好的包上传到 GitHub Release：

- `my-niri-desk-<version>-<rel>-x86_64.pkg.tar.zst`

当前仓库已经内置 GitHub Actions：

- 推送到 `main/master`
  - 自动构建
  - 更新 `rolling` 预发布
- 推送 `v*` tag
  - 自动构建
  - 生成正式版本 release

因此常规发布可以直接走：

1. 提交并推送到 `main`
2. 等待 `rolling` release 自动更新
3. 需要正式版时打 tag，例如：

```bash
git tag v0.1.0
git push origin v0.1.0
```

## AUR

真正用于 AUR 的内容位于：

```bash
aur/my-niri-desk
```

## 推荐发布顺序

1. 修改配置/依赖
2. 更新 `.SRCINFO`
3. 执行：

```bash
./scripts/sync-aur.sh
./scripts/aur-package.sh
```

4. 在测试机验证
5. 提交 GitHub
6. 上传 GitHub Release
7. 推送 `aur/my-niri-desk` 到 AUR

注意：

- AUR 仓库是平铺结构
- 不能直接把 `payload/`、`scripts/` 作为子目录推上去
- AUR `PKGBUILD` 需要从 GitHub tag 源码包拉取这些内容
