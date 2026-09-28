# GitHub Actions 构建指南

不用装 Flutter、不用装 Android Studio，把代码推到 GitHub，云端自动出 APK。

---

## 一、三步走

### 第 1 步：在 GitHub 上建一个空仓库

打开 https://github.com/new ，仓库名随便（比如 `moyue-reader`），**不要勾选** "Add a README" / ".gitignore" / "License"，保持空仓库。

建好后页面会给出一个地址，形如：

```
https://github.com/你的用户名/moyue-reader.git
```

### 第 2 步：把代码推上去

在本机进入项目目录执行：

```bash
cd moyue_reader

git init
git add .
git commit -m "feat: 墨阅 Reader 首个版本"

git branch -M main
git remote add origin https://github.com/你的用户名/moyue-reader.git
git push -u origin main
```

> 如果 GitHub 要求认证：用 Personal Access Token 当密码（GitHub 网页 → Settings → Developer settings → Personal access tokens → 勾 `repo`），或直接用 `gh auth login`。

### 第 3 步：看结果、下 APK

推送完成后，打开仓库页面的 **Actions** 标签页，会看到一条正在跑的工作流。

大约 **6–12 分钟**（首次会慢些，因为要下载 Gradle 依赖）后变绿：

1. 点进那次运行
2. 页面最下方 **Artifacts** 区域
3. 下载 `墨阅Reader-debug` → 解压得到 `.apk`
4. 传到手机，允许「未知来源安装」，装上即可跑

---

## 二、工作流做了什么

| 阶段 | 内容 |
|---|---|
| `check` | 生成 `android/` → 注入网络权限 → 校验 minSdk → `flutter analyze` → `flutter test`（含覆盖率） |
| `build-apk` | 打 Debug 包；打 tag 或手动勾选时再打 Release 包 + 分架构包 |
| `summary` | 在 Actions 页面输出一张结果表，一眼看清哪个阶段挂了 |

几个关键设计，说明一下为什么：

- **仓库里没有 `android/` 目录**：只提交了纯 Dart 代码，平台目录由 CI 现场 `flutter create` 生成。好处是不会把几百个模板文件塞进 git，也不会和不同 Flutter 版本的模板打架。
- **自动注入 `INTERNET` 权限**：Edge-TTS 和 AI 都要联网，而 Flutter 官方模板**默认不带这个权限**，不注入的话装到手机上听书会静默失败。
- **`minSdk` 自动校验**：`flutter_tts` / `just_audio` 要求 23+。新版 Flutter 模板用 `flutter.minSdkVersion`（默认 24，够用）；老模板写死 21，会自动改成 23。
- **`analyze` 用 `--no-fatal-infos --no-fatal-warnings`**：只让编译错误阻断流程，lint 告警不阻断，避免模板噪声把 CI 卡死。想严格一点，本地跑 `flutter analyze` 即可。

---

## 三、触发 Release 包

Debug 包每次推送都打。Release 包有两种触发方式：

```bash
# 方式一：打 tag（会顺带创建 GitHub Release 并附上 APK）
git tag v1.0.0
git push origin v1.0.0
```

方式二：Actions 页面 → 右上角 **Run workflow** → 勾选 `build_release` → 运行。

---

## 四、首次 CI 可能失败怎么办

大概率不会，但如果红了，按这个顺序排查：

1. **点进失败的步骤看红色日志**，把报错贴出来
2. 常见的是第三方包的 API 版本漂移（比如某个构造函数在新版改了名）——这类问题必须看到真实报错才能修
3. 如果只是 lint 告警爆红，说明 analyze 那步被 CI 机器上的严格规则卡了，可以临时改成 `flutter analyze` 后面再加 `--no-fatal-warnings`（已加）

依赖版本都写在 `pubspec.yaml` 里，如需对齐某个 Flutter 版本，改文件顶部的 `environment` 和 workflow 里的 `FLUTTER_VERSION` 即可（两处保持一致）。

---

## 五、上架应用商店：配置签名（可选）

未配置签名时，`flutter build apk --release` 会用 **debug keystore** 兜底——包能装能跑，但**不能上架**。

要上架，需要配置签名：

1. 生成 keystore（**文件务必自己备份，丢了就无法更新应用**）：
   ```bash
   keytool -genkey -v -keystore ~/moyue.jks -keyalg RSA -keysize 2048 -validity 10000 -alias moyue
   ```

2. 把 keystore 用 base64 编码：
   ```bash
   base64 -w 0 ~/moyue.jks
   ```

3. 在 GitHub 仓库 → **Settings → Secrets and variables → Actions** 里加 4 个 secret：
   | Secret 名 | 值 |
   |---|---|
   | `KEYSTORE_BASE64` | 上一步的 base64 串 |
   | `KEYSTORE_PASSWORD` | keystore 密码 |
   | `KEY_ALIAS` | `moyue` |
   | `KEY_PASSWORD` | key 密码 |

4. 创建 `android/key.properties` 的生成步骤，加到 workflow 的构建前：
   ```yaml
   - name: 写入签名配置
     run: |
       echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/moyue.jks
       cat > android/key.properties <<EOF
       storeFile=../app/moyue.jks
       storePassword=${{ secrets.KEYSTORE_PASSWORD }}
       keyAlias=${{ secrets.KEY_ALIAS }}
       keyPassword=${{ secrets.KEY_PASSWORD }}
       EOF
   ```

---

## 六、打 iOS 包

iOS 必须用 macOS 环境，GitHub 的 `macos-latest` runner **按分钟计费且倍率高**（对私有仓库），公开仓库免费。

如需 iOS，在 workflow 里加一个 job：

```yaml
build-ios:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.35.1'
        channel: 'stable'
        cache: true
    - run: flutter create --platforms=ios --project-name moyue_reader --org com.moyue .
    - run: flutter build ios --release --no-codesign   # 不签名，仅验证能编过
```

正式上架还需要 Apple Developer 账号 + 证书配置，建议本地 Xcode 处理。

---

## 七、常用操作

| 想做的事 | 命令 |
|---|---|
| 改版本号 | 编辑 `pubspec.yaml` 的 `version: 1.0.0+1`，`+` 前是版本名、后是构建号 |
| 只跑测试不打包 | Actions → Run workflow → 取消勾选 `build_release` |
| 省 runner 时长 | 仓库 Settings → Actions → 设置用量上限；已配置 `concurrency` 自动取消重复任务 |
| 本地也跑一遍 | 见 README 4.1，用 `./setup_env.sh` 装好 Flutter 后 `flutter test` |
