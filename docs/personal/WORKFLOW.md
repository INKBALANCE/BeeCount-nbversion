# 个人分支开发规范

本仓库是 BeeCount 的个人魔改分支，**只给自己用**。规范的目的不是流程表演，
而是让每次改动可回滚、每次发版可追溯、每一条红线都不靠记性。

---

## 1. 分支模型

| 分支 | 用途 | 规则 |
|---|---|---|
| `main` | 上游快照基线 | **只读**。除合并/对齐上游外不提交。`pre-commit` 钩子会拦截 |
| `1.0.0` | 一期开发分支 | 一期所有改动都在这里；发版从这条分支出 |
| `feat/*` `fix/*` | 临时分支（可选） | 大改动时开，完成后合回 `1.0.0` |

> 分支名 `1.0.0` 表示"一期"，与版本号无关。版本号随每次发版递增：`1.0.1`、`1.0.2`……

## 2. 提交规范

Conventional Commits，作用域用模块名：

```
feat(recurring): 支持仅工作日触发
fix(update): 修正 Release asset 选择
chore(ci): 增加发版流水线
docs(personal): 补充流程规范
refactor(personal): 收口功能开关
```

一条铁律：**一个提交只做一件事**。改功能别顺手格式化整个文件，否则回滚时会连带
撤掉无关改动，也会让后续与上游对齐时冲突面积失控。

## 3. 版本号规则

`pubspec.yaml` 里：

```yaml
version: 1.0.1+10001
```

- 前半段是**版本名**，App 内"检查更新"用它比较大小，必须递增。
- 后半段是**构建号（versionCode）**，Android 安装时用它判断新旧，必须单调递增。
- 构建号统一按 `主*10000 + 次*100 + 修` 计算：`1.0.1 → 10001`，`1.0.2 → 10002`，
  `1.1.0 → 10100`。这样版本名和构建号永远同步，不用单独记。

发版才递增，日常提交不动版本号。

## 4. 发布流程

```
改代码 → flutter analyze → flutter build apk --release --flavor prod
      → 提交(commit) → 【获得授权后】push 1.0.0
      → GitHub Actions: Personal Release → 自动打 tag v1.0.1 + 建 Release + 上传 APK
      → 手机上"我的 → 关于 → 检查更新" → 下载 → 系统安装器覆盖安装，数据保留
```

发版前必须在本地构建通过。CI 只做重复劳动，不承担"第一次发现编译不过"的职责。

只想拿个包测试、不发布时：跑 `Personal Release` 并把 `dry_run` 勾上，
产物放在 Actions 的 Artifacts 里，不会建 tag、不会建 Release。

> 注意：不要再手工构建带 `--dart-define=CI_VERSION=xxx` 的包发给自己装。
> 应用内"检查更新"是拿这个值和 Release 的 tag 比大小的，写成非版本号
> （比如 `personal`）会让更新提示永久失效，且不会有任何报错。

### 4.1 仓库必须做的两项设置（一次性）

**① 默认分支改为 `1.0.0`**

Settings → General → Default branch → 切到 `1.0.0`。

这不是偏好问题，是硬限制：GitHub 规定 `workflow_dispatch`（Action 页面上的
"Run workflow" 按钮）**只对默认分支上存在的流水线文件生效**。
`personal-release.yml` 只在 `1.0.0` 上，默认分支若是 `main`，
Actions 侧边栏根本不会出现 "Personal Release"，也就没法手动发版。

改完之后侧边栏里旧的 "Personal APK" 会自动消失（该文件在 `1.0.0` 上已删除），
"Release" / "Beta Release" 也会消失（`on` 已改成 `workflow_call`，无法手动触发）。

**② Secrets 保持 4 个**

`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` /
`ANDROID_KEY_ALIAS`（值 `beecount`）/ `ANDROID_KEY_PASSWORD`。

`dry_run` 勾选时不上传 Release，但**仍需要 keystore**（否则构建出的包签名不对，
装了会丢数据），所以 Secrets 不能省。

### 4.2 上游流水线的处理

`release.yml`、`beta-release.yml` 在本分支已改为 `on: workflow_call`，
即：不出现在 "Run workflow" 里，也不会被 tag 推送触发。

原因：`release.yml` 原本监听所有 tag，`personal-release.yml` 每次发版都会推
`v1.0.1` 这类 tag，必然连锁触发它，然后卡在 "Reject Beta and check stable source"
（它只在 `main` 分支、且需要上游商店凭证才能跑）——每次发版多一个红色失败。


## 5. 红线（违反任何一条都可能丢数据或污染上游）

1. **未经明确授权，不执行 `git push`。** 只允许本地 `commit`。
   `pre-push` 钩子会拦截，需要 `ALLOW_PUSH=1` 才能通过。
2. **不直接向 `main` 提交**，改动只进 `1.0.0` 或特性分支。
3. **不更换 keystore，不修改 alias。** 换 keystore = 换应用身份 = 新包装不上旧版
   = 只能卸载重装 = 账本清零。alias 只是密钥库内部标签，与 App 名字无关。
4. **`*.jks` / `*.keystore` / `key.properties` 永不入库。** 已在 `.gitignore` 兜底。
5. **不向官方仓库推送任何东西。** `upstream` 的 push 地址已设为 `no_push_disabled`。
6. **不修改 `applicationId`**（`com.inkbalance.watercount`）和 Dart 包名（`beecount`）。
   前者改了就变成另一个 App，后者要改 590 个文件的 import，收益为零。

## 6. 回滚

```bash
git log --oneline            # 找到目标提交
git revert <sha>             # 生成反向提交，保留历史（推荐）
git reset --hard <sha>       # 仅限尚未推送的本地提交
```

已发布版本若出问题：递增版本号重新发版，**不要删除已发布的 Release**——
用户设备上可能已经装过，删除只会让更新检查拿到 404。

## 7. 与上游对齐

本仓库是快照导入，没有上游 git 历史，**不能用 merge/rebase 同步**。正确做法：

```bash
git fetch upstream main --depth=1
git diff HEAD:pubspec.yaml upstream/main:pubspec.yaml   # 先看上游改了什么
# 按文件挑需要的内容，手工合进 1.0.0，逐项构建验证
```

与上游对齐是高风险操作，一次只合一个模块，合完立刻构建。

## 8. 机器强制项

仓库本地已配置两个钩子（在 `.git/hooks/`，不随仓库分发，换机器需重新装）：

| 钩子 | 作用 |
|---|---|
| `pre-commit` | 在 `main` 分支上拒绝提交 |
| `pre-push` | 拒绝推送，除非本次命令带 `ALLOW_PUSH=1` |

授权后的正常推送方式：

```bash
ALLOW_PUSH=1 git push origin 1.0.0
```
