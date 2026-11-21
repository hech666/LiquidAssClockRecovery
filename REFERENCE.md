# LiquidAss 公开时钟源码参考

此目录及 ../SourceReference 均为公开旧版参考，**不是当前 6.6.7 源码，不能据此声称已恢复或取得 6.6.7 时间模块源码**。未修改 package/。

## 来源、版本与许可

- 仓库：https://github.com/winaviation-tweaks/liquidass
- 固定 main 提交：3656bb1d3f09d3e1ed7ea5132ddf04a270934ea8，提交时间 2026-11-13T13:24:19Z；control 标记版本 **0.1.1-2b**。main HEAD 不等同于该版本发布 tag 的提交。
- legacy HEAD：fcf8de1ab79744fda95a445843cf3e67db8e2a13，2026-07-01T06:49:22Z；control 版本 **0.0.9a**。仅取得版本元数据，未将 legacy 源码混入参考目录。
- 已查询公开 refs、全部返回的 tags/releases；包含 5.1.testers、6.alpha、7.alpha、7.1.alpha、7.2.alpha、8.alpha、8.1.alpha、nightly、0.0.9a、0.1.0b、0.1.1b、0.1.1-2b，**未发现 6.6.7 标签或发布记录**。6.alpha 不能当作 6.6.7。
- 主许可为 CC BY-NC 4.0（https://creativecommons.org/licenses/by-nc/4.0/）；保留原 LICENSE、NOTICES.md 和作者归属。NOTICES 中 RWB 的 MIT 声明不代表时钟源码整体采用 MIT。
- Git 完整克隆超时；压缩包下载中断，残包已移除。改用 GitHub Git Blob API 成功下载所列源码，15 个参考文件逐一计算并比对 Git blob SHA-1，全部匹配固定提交树；SOURCE_MANIFEST.json 同时记录 SHA-256。不是完整仓库或完整 Git 历史副本。

## 时间范围与文件范围

- GitHub path history 对 Hooks/Clock.x 返回 5 条提交，覆盖 **2026-08-10T06:31:38Z 至 2026-09-11T11:09:26Z**；后者为最近修改时钟路径的提交 5784d59ef6cc1c6a4d2f9d84a6321a9bc71dcac6。此为路径历史时间范围，不是 6.6.7 的开发时间范围。下载快照固定于上述 2026-11-13 main commit。
- ../SourceReference/Hooks/Clock.x：完整 84,949 字节，包含时间/日期标签 hook、自定义日期格式、字形路径与遮罩发布、变量字体加载与轴参数、布局避让、通知列表联动及初始化。字体相关源码 LGClockFontStore 位于该文件内，没有伪造独立字体源文件。
- 实际直接依赖：Shared/LGGlassKit.h/.x（开关、host/玻璃注册、重载）、LGHostRegistry.h（Clock host/filter 配置）、LGLensRectState.h（遮挡矩形共享）、LGLiveBackdropView.h/.m（玻璃视图、CAFilter、偏好缓存）。
- 传递依赖：Shared/LGCoverSheetState.h；外部函数实现位于 Shared/LGSharedSupport.h/.m，包括 LG_prefBool/Float/String、LGDebugLoggingEnabled、LGLog 和偏好重载。保留共享文件原文以维持证据和依赖完整性，内部可能含其他 host 常量或通用工具，未另复制菜单、控制中心、应用图标等业务模块。
- 跨进程 renderer：LiquidAssBackboardd/Tweak.mm、LGSymbolResolver.h/.mm。Clock.x 发布 liquidglass-clock-mask-shared.bin，renderer 读取时钟 mask 并上传 Metal texture；renderer 为多个 host 共用的完整源文件，未擅自截断或假装它是时钟独立实现。
- 未引用的 LGFramework.h/.m、LGLiquidMotion.h 以及主 Tweak.x 已从参考源码中排除。reference/upstream 的 control、Makefile、README.md 仅用于版本、构建和出处核对，不是 SourceReference 的构建入口。

## 缺口与二进制恢复范围

- 未取得任何可确认属于 **6.6.7** 的公开源文件。需要以当前 6.6.7 二进制为依据，逐函数进行语义恢复，覆盖时间/日期 hook、实际共享依赖、renderer/shader、config/偏好键及默认值、字体加载与轴映射、初始化与构建依赖。旧版源码仅用于命名、调用关系和实现思路参考，不能替代当前二进制证据或直接标为 6.6.7 源码。
- 不需要用户上传原始源码；当前二进制中尚未验证的逻辑应明确记录为恢复缺口，不能依据旧版补写后宣称与 6.6.7 一致。
- 字体资源已从用户上传的 deb 提取到 ../clock_resources/SFAdaptiveSoftNumeric-VF.otf，无需再次下载。SourceReference 保留 Clock.x 内完整字体加载源码，字体二进制资源留在 clock_resources，以区分当前包资源与旧版源码参考。字体本身许可仍需独立核实，仓库主许可不能自动代替字体许可。
- UIKit/CoreText/QuartzCore/CoreGraphics/CoreMotion/Metal、私有 CAFilter/系统类、Substrate/Logos 和可选 roothide 属于构建/运行依赖，不在所下载项目源码内。此目录是源码参考集，未做 iOS/Theos 编译验证。

证据文件：tree.json、commit-main.json、commit-legacy.json、legacy-control.json、clock-history.json、tags.json、releases.json、SOURCE_MANIFEST.json。
