# 开发

## 构建与发布

需要 macOS 14 或更新版本、Swift 6 和可用的 Xcode 命令行工具。使用 `scripts/snug help` 查看命令。

| 命令 | 作用 |
| :--- | :--- |
| `scripts/snug check` | 构建全部产物，运行 Swift 和脚本单测。 |
| `scripts/snug app` | 生成通用二进制兼容包 `build/Snug RustDesk.app` 并签名。 |
| `scripts/snug install` | 正常退出已安装的 Snug RustDesk，将新包安装到「应用程序」并打开。 |
| `scripts/snug dist` | 在 `dist/snug-rustdesk/<版本>/` 生成公证后的 DMG、校验值和更新包。 |
| `scripts/snug ship` | 核对派生仓库的版本标签，生成更新清单，上传并验证 GitHub Releases 资产。 |

开发包默认采用 ad-hoc 签名。配置专用的 Developer ID 和公证档案后，可在本机的 `.machine.env` 中启用分发。配置项及格式见 [.machine.env.example](../.machine.env.example)。

发布使用仓库根目录的 `VERSION`。经确认后将同名注释标签 `v<版本>` 推到 `yw42/snug-rustdesk`，然后运行 `scripts/snug ship`。标签说明会用作 Release 和应用内更新说明。发布中断后可以重跑，脚本会复用同一个提交生成的包并核对已公开资产。

## 应用内更新

启用分发后，新构建从 `yw42/snug-rustdesk` 的 GitHub Releases 读取 `update.json`。更新仍复用 `SnugCore/Update` 的分块协议，按需从 `SnugRustDesk-<版本>.pack` 下载本机缺少的块。更新程序在替换本机应用前核对拼装结果的版本与签名。

## RustDesk 只读自检

运行 `scripts/snug rd-check` 查看本机 RustDesk 版本、辅助功能、录屏权限和在线显示器数量。此命令以调试可执行文件的权限运行。应用并装时应在实际包中分别核对授权。

当前会话信号待真机验证。使用菜单栏开始伴侣会话，随后在 RustDesk 客户端选屏，断开后从菜单栏结束会话并还原。输入使用 RustDesk 原生模式。

## 代码结构

代码分为三层，依赖单向向下：

| 目标 | 内容 |
| :--- | :--- |
| `SnugCore` | 纯逻辑：连接判定与会话、屏幕调度（见下）、屏幕适配 `ScreenFit`、机型库 `DeviceCatalog`、手势翻译 `TouchTranslator`、截图 `Screenshots`、还原记录、配置、日志、启动参数、更新包格式。系统能力抽象为协议，测试中使用假实现 |
| `SnugSystem` | 系统层：`CGVirtualDisplay` 建屏与撤屏、辅助进程切换分辨率档位、设主屏与还原排列 `DisplayArrangementService`、辅助功能接口移动窗口、按进程发送字号快捷键、手势事件监听 `TouchTap`、ScreenCaptureKit 截图 |
| `Snug` | 应用层：手动会话、AppController、应用内更新 `Updater`、Snug 屏上的 App 资源库（`Screens/`）、指示条与截图裁剪、设置（屏幕、触控、通用三页）、添加屏幕与屏幕详情、关于、电脑屏的 App 资源库窗口、欢迎页、菜单栏 |

发布工具 `SnugRelease` 只依赖 `SnugCore`，由 `scripts/snug` 调用。

`SnugCore` 的目录依赖单向：`Model`（屏的身份 `ScreenID`、设备的类别和数值等纯值类型）← `Config`、`Persistence` ← `Screens`。配置怎么翻成屏的身份和比例只在 `ScreenPlan` 写一处。

屏幕调度在 `SnugCore/Screens`，分四块，依赖单向：

| 类型 | 管什么 |
| :--- | :--- |
| `ScreenPlan` | 纯函数：按配置和远程状态算出这一刻要哪几块屏（`ScreenWish`；设为主屏的那块只在伴侣会话期间接管主屏），每块给什么行为（`ScreenBehavior.touch`：是不是触屏，即有没有面板、翻不翻译手势、铺不铺满、调不调字号）。行为只在这里按型号的类别定，下游只认它、不认类别；`Desk.State` 把它发布给界面 |
| `ScreenSet` | 屏幕拓扑的唯一来源：加屏、撤屏、换档、换比例、重试、最短在线时间、设为主屏与还原排列 |
| `Desk` | 一块屏上的事：放窗口（手机、平板铺满换档，电脑只挪过来居中）、换档、字号、归位、还原记录（触屏 `placed/<屏 id>.json`，电脑屏挪过来的窗口一个一份），正在做什么按号排（`Desk.Ticket`） |
| `DeskSet` | 管所有 `Desk`：在同一条 `SerialLane` 上排队，处理跨屏的事（窗口从一块屏转到另一块、退出 App 时各屏归位、撤屏前清场、在手机上退出某块屏）；留下的账交给 `LeftBehindLedger`，盯退出和关窗交给 `RequestWatcher` |

`AppController` 每次感知到变化就调 `ScreenPlan.wishes` 交给 `DeskSet.setWishes`，界面只读 `AppState.desks`（每块屏的状态）。

设计令牌：`design/design-tokens.json` 是界面数值的唯一来源。`Sources/Snug/UI/DesignTokens.swift`（`MacTokens`、`TouchTokens`、`MotionTokens`）由测试生成，不手改；`DesignTokensTests` 校验两边一致。改了令牌后重新生成：

```bash
SNUG_WRITE_TOKENS=1 swift test --filter DesignTokensTests
```

手势翻译分两半：`SnugCore/Touch` 是纯状态机，一次手势只认一块范围 `TouchRegion`（位置与缩放倍数），不依赖哪块屏；`SnugSystem` 中 `TouchTap` 负责监听线程，持有每块屏的范围，按下时按落点选定这次手势用哪一块，`TouchEvents` 负责读入与拼装事件。`AppController` 只决定范围：开着手势时，每块触屏（手机、平板屏）各一块范围，正在裁剪截图的那块除外。新增一种手势时，在状态机里加判定与 `TouchCommand`，在 `TouchEvents` 里拼装要补发的事件，再在 `TouchTap` 按命令分派处补上一支。

## 启动参数

参数有误时会打印用法。

| 参数 | 作用 |
| :--- | :--- |
| `--render-<界面> <目录>` | 将界面渲染为 PNG：`settings` / `welcome` / `about` / `legacy` / `menu` / `screens` / `library` / `update`（不启动监控，不改动屏幕）。`screens` 是 Snug 屏上的面板，覆盖手机竖横、平板竖横；`library` 是电脑屏的 App 资源库窗口 |
| `--preview-screens` | 正常启动，但不等待连接即创建屏幕列表中开着的屏，无需控制端即可查看屏上的列表（**会真实创建屏幕**；设了主屏的同样会设） |
| `--rd-check` | 查看 RustDesk 与本机运行条件（`scripts/snug rd-check` 调用） |
| `--probe-screens <规格…>` | 实测用（多屏的 V1～V12，结论见记忆 project-multi-screen）：每份规格建一块实验屏，打印各档模式与 2 倍是否可用，按 Ctrl-C 撤屏并还原排布。规格是逗号分隔的 `键=值`：`modes=宽x高+…`（必填）、`name`、`serial`（默认用 999000001 起的实验身份）、`cap=像素宽x像素高`、`pattern=on\|off`（校准图）、`main=on`（设为主屏，最多一块）。**会真实创建屏幕**，测试时随测随撤，免得指针跑到看不见的屏上 |
| `--set-mode <屏幕编号> <宽> <高>` | 辅助进程模式：将一块 Snug 的屏切换至该档的 2 倍模式后立即退出（供主程序内部调用；高由主程序按型号的比例算好传入） |
| `--restore-mode <屏幕编号> <模式编号> <宽> <高> <像素宽> <像素高> <刷新率> session\|permanent` | 辅助进程模式：将一块屏幕设回该模式后立即退出，只对当前登录生效或连同永久配置（供主程序内部调用：创建、移除 Snug 的屏时被系统改变模式的屏幕） |

## 数据与日志

| 位置 | 内容 |
| :--- | :--- |
| `~/Library/Application Support/SnugRustDesk/config.json` | 设置，含屏幕列表 `screens`、主屏 `mainScreen`；同时写旧的 `phoneScreen`、`phone`（取第一块竖屏手机屏的值），降级回 2.5 照样能读，过两个大版本再停写。降级的代价：2.5 写盘时丢掉它不认的 `screens`、`mainScreen`、`nextSerialBlock`，再升回来只剩那块手机屏 |
| `~/Library/Application Support/SnugRustDesk/placed/<屏 id>.json` | 各块屏上窗口的还原记录；电脑屏挪过来的窗口一个一份，`placed/<屏 id>~<pid>-<窗口号>.json`。2.5 的 `phone-screen.json` 启动时挪成 `placed/phone.json` 再按它还原；手机屏已经有账时挪成 `placed/phone-2.5.json`，一样还 |
| `~/Library/Application Support/SnugRustDesk/zoom.json` | 各 App 记忆的字号级数 |
| `~/Library/Application Support/SnugRustDesk/left-behind.json` | 在 Snug 之外关闭的窗口待还原的位置与字号（保留两周） |
| `~/Library/Logs/SnugRustDesk.log` | 日志 |

实现细节见 [工作原理](how-it-works.md)。
