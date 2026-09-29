# Antigravity 深色图标补丁

给 [Google Antigravity](https://antigravity.google)（macOS 桌面版）换一个深色底的应用图标，解决**深色模式 Dock 里白底图标过于刺眼**的问题。

> **免责声明**：本项目非 Google 官方项目。`icons/` 里的图形是 Antigravity / Gemini 应用图标的衍生作品，商标与原始图形版权归 Google LLC 所有，此处仅用于替换本机已安装应用的图标这一**个人用途**。脚本部分为 MIT（见 [LICENSE](LICENSE)）。

## 快速开始

```bash
git clone https://github.com/TexasLyn/antigravity-dark-icon.git
cd antigravity-dark-icon

# 方式一：系统级深浅双变体图标（macOS 26+，推荐）
./apply-appicon.sh install    # 浅色白底 / 深色系统材质，跟随系统自动切换
./apply-appicon.sh restore    # 还原官方原版

# 方式二：固定深色单 icns（旧方案，任何 macOS 版本）
./apply-icon.sh               # 列出所有变体
./apply-icon.sh G             # 应用「Gemini 同款」
./apply-icon.sh restore       # 还原官方原版
```

往 `/Applications/*.app` 内部写文件属于 macOS **App Management 保护**范围（即使目录 owner 是你也会 `EPERM`），所以必须在**「终端」**里运行，脚本会自动 `exec sudo` 提权（**只需输一次密码**），然后：

1. 首次替换把原图标备份为 `Resources/icon.icns.orig`
2. 替换 `icon.icns`
3. 清除隔离属性（`xattr -cr`）
4. ad-hoc 重签名（`codesign --force --deep --sign -`）—— **必需**，否则 Hardened Runtime 下图标不生效
5. 校验签名 + 刷新 Dock 图标缓存（`killall Dock`）

装好后 Dock 没立刻变？把 Antigravity 从 Dock 移除再拖回来，或注销重登。

## 五个变体

| 文件 | 底色 | 特点 |
|---|---|---|
| **`G-Gemini.icns`** ⭐ | `#212121 → #0F0F0F` 渐变 | **在 Dock 里观感与 Gemini 一致 —— 想要「和 Gemini 一样」就用它** |
| `A-炭黑1C1C1E.icns` | `#1C1C1E` 纯色 | macOS 原生深色 UI 标准色，最「系统感」 |
| `B-深灰2B2B2E.icns` | `#2B2B2E` 纯色 | 方块边界最清晰，不会和 Dock 背景糊在一起 |
| `C-Google202124.icns` | `#202124` 纯色 | Google 自己的深灰品牌色 |
| `D-近黑光晕.icns` | `#101012` + 彩色光晕 | 最有个性，A 字周围有微光扩散 |

彩虹渐变 A 原样保留，只换了底板。圆角/轮廓沿用官方 icns 的 alpha（实测与 Gemini 的圆角差 ≤1px，不需要改）。

## 背景：为什么是自己做的

社区里**没有**现成的 Antigravity 深色图标补丁。搜索结论：

| 类型的第三方项目 | 是否存在 | 说明 |
|---|---|---|
| 界面汉化（改文案） | ✅ 有 | 如 `Silas-02/antigravity-desktop-cn` |
| 界面主题（改配色） | ✅ 有 | VS Code 主题生态 + 第三方换肤 |
| **Dock 图标 / 深色图标** | ❌ **没有** | 本补丁即为此而做 |

顺带排查掉的干扰项：`lbjlaq/Antigravity-Manager` 那个仓库里有个 `tray-icon-fix`，但那是**另一个项目**（Linux 版第三方管理器），跟 Google Antigravity 无关。

## 原图标长什么样

从 `/Applications/Antigravity.app/Contents/Resources/icon.icns` 解出来的原图：

- **纯白圆角方块**（`#FFFFFF`，不是浅灰）+ 彩虹渐变 A
- 最大只有 **512×512** 这一档（官方没给 1024）
- 在深色 Dock 里，周围 VS Code / Xcode / Gemini 全是深色底，只有它是纯白 —— 视觉上就是一颗灯泡

## 关键发现：深色底的「顶亮底暗」渐变是 macOS 系统渲染的

一开始以为 Gemini 的深色底自带一个 `#212121 → #0F0F0F` 的垂直渐变，差点照抄。做了对照实验，结论是**这是系统的统一渲染效果，不是各家图标的设计**：

对 Dock 里 11 个图标逐行采样底板亮度（每行取中性色众数，避开 logo 彩色像素）：

| 图标 | 底板剖面（方块顶部 → 底部） | 落差 |
|---|---|---|
| VS Code | 33 31 30 29 28 27 26 25 24 23 21 19 19 18 16 15 15 | 18 |
| Cherry Studio | 33 31 30 29 28 26 25 23 23 22 21 19 18 17 16 15 15 | 18 |
| Qoder CN | 33 31 30 29 28 · 1 1 1 24 21 21 19 19 17 17 15 15 | 18 |
| Notion | 33 31 30 29 28 27 26 24 23 22 21 20 19 18 17 15 15 | 18 |
| WPS | 33 31 30 29 28 26 25 24 23 22 21 19 18 17 16 15 15 | 18 |
| Excel（微软） | 33 31 30 28 27 26 25 24 23 22 21 19 18 17 16 15 15 | 18 |
| **Gemini** | 33 31 30 29 28 27 25 24 23 22 21 19 19 17 16 15 15 | 18 |
| **Antigravity（官方白底）** | 255 255 255 255 … 255 | **0** |

微软、金山、Notion、VS Code 四家毫无关系的产品，曲线**逐点重合** —— 不可能是巧合。

Apple WWDC25《Say hello to the new look of app icons》也印证：*"The system owns lighting. No baked specular, drop shadows, or gradients-as-lighting — Icon Composer / the system add depth, refraction, and highlights. Keep artwork flat."*（系统负责光照，图稿保持扁平）

**为什么 Antigravity 没有这个效果**：它用的是**老式 `icon.icns`**（无 `Assets.car`，`CFBundleIconName` 未设置），系统走 legacy 渲染路径，不施加 Liquid Glass 效果；而 Gemini / VS Code / Excel 等都有 Icon Composer 的分层 `Assets.car`，走新渲染路径。

**所以**：G 变体把这个观感**烘焙进 icns**。理论上「不真实」（把系统效果画进了图稿），但这正是唯一能让 legacy icns 在 Dock 里跟 Gemini 看起来一致的办法 —— 因为系统不会给这条路径加效果。

> 想真正走系统渲染路径，理论上可以给 Antigravity 补一个 `Assets.car` + `CFBundleIconName`。但那需要 Icon Composer 的分层 `.icon` 格式（纯 GUI、无 CLI），而且 actool 从传统 `.appiconset` 编译时**会静默忽略 dark 变体**（实测两个 Assets.car md5 相同）。风险收益不成比例，没做。

## 实现原理

核心是**把 A 字形从白底板里抠出来**，判据是「与纯白 `(255,255,255)` 的欧氏距离」：

```
d = sqrt((255-r)² + (255-g)² + (255-b)²)
d <= 18   → 底板，判为透明
d >= 95   → 字形，全不透明
18 < d < 95 → 线性过渡（保住抗锯齿边缘）
```

⚠️ **别用饱和度当判据**：彩虹 A 顶部有一圈接近白的浅色，饱和度低，会被误判成底板，导致字形上方出现豁口、深色底上留白边。

抠出字形后，用原图的 alpha 通道当圆角方块遮罩铺新底板，再把字形叠回去，最后用 `iconutil` 打包成各尺寸档位的 `.icns`。

## 自己改颜色 / 重新生成

`scripts/make_icns.py` 是上面这套流程的可复现实现：

```bash
# 依赖 Pillow
python3 -m pip install pillow

python3 scripts/make_icns.py --list          # 看内置变体
python3 scripts/make_icns.py                 # 重新生成全部 5 个到 icons/
python3 scripts/make_icns.py --only G A      # 只生成指定变体
python3 scripts/make_icns.py --out /tmp/gen  # 输出到别处
```

想加自己的颜色，编辑脚本顶部的 `VARIANTS` 字典即可：

```python
VARIANTS = {
    # ...
    "E": dict(kind="solid", name="E-我的深蓝.icns", color=(0x0D, 0x1B, 0x2A),
              desc="深蓝 #0D1B2A"),
}
```

`kind` 支持 `solid`（纯色）、`gradient`（垂直渐变，锚定方块范围 y=47..466）、`glow`（纯色 + 字形彩色光晕）。源图默认读仓库里的 `original-icon.icns`；不存在时会自动回退到 `/Applications/Antigravity.app/Contents/Resources/icon.icns`。

## 仓库结构

```
antigravity-dark-icon/
├── apply-appicon.sh       # v2：装入系统级深浅双变体图标（Assets.car + CFBundleIconName）
├── Antigravity.icon/      # v2 源文件：icon.json + 分层 Assets（可编辑底色/光照）
├── compiled/              # v2 编译产物：Assets.car + Antigravity.icns + partial.plist
├── apply-icon.sh          # v1：应用 / 还原固定深色 icns（自动 sudo + 重签 + 刷 Dock）
├── icons/                 # v1：5 个深色变体 icns
├── scripts/make_icns.py   # v1 生成器：从官方图标重建变体（可自定义颜色）
├── original-icon.icns     # 官方原图备份（240,982 B）
├── preview-dock.png       # 贴进真实 Dock 截图的对比
├── before-dock-detail.png # 替换前后的 Dock 局部放大
├── preview-glyph-detail.png # 原版 vs 变体 A 的 2.4× 细节对比
└── LICENSE
```

## 还原

```bash
./apply-icon.sh restore
```

或手动：

```bash
sudo cp /Applications/Antigravity.app/Contents/Resources/icon.icns.orig \
        /Applications/Antigravity.app/Contents/Resources/icon.icns
sudo codesign --force --deep --sign - /Applications/Antigravity.app
killall Dock
```

---

## v2：系统级深浅自动切换（推翻了 v1 的「不可行」结论）

v1 附录曾断言：自动切换唯一路径是 Icon Composer（纯 GUI、格式未公开），所以没做。**2026-09-29 重新验证后发现结论错了**，而且整个链路可以纯 CLI 完成：

1. **`.icon` 不是封闭格式** —— 它就是一个普通目录：
   ```
   Antigravity.icon/
   ├── icon.json     # 结构描述：分层、填充、光照、平台
   └── Assets/       # 分层图（PNG/SVG 均可）
       └── 1.glyph_unspecified_unspecified_automatic.png
   ```
   Xcode 模板里就有空白样例（`Xcode.app/.../File Templates/macOS/Resource/Icon Composer Icon.xctemplate/`）。

2. **actool 直接吃 `.icon` 目录**，产出 `Assets.car` + 合成 `.icns`：
   ```bash
   actool --compile out/ --platform macosx --minimum-deployment-target 26.0 \
     --app-icon Antigravity --output-partial-info-plist out/partial.plist Antigravity.icon
   ```
   产物结构与 Gemini 真机 `Assets.car` 同构（`Icon Image` 全 System + `Group` 分 Aqua/Dark/Tintable 三外观，运行时系统按外观实时合成）。

3. **外观特化的正确入口是 icon.json，不是文件名**。文件名里 `1.bg_dark_...` 这种槽位**不生效**（实测编译后 dark 合成组照样引用普通层）；要换底色得用 `fill-specializations`：
   ```json
   {
     "fill" : { "automatic-gradient" : "extended-srgb:1,1,1,1" },
     "fill-specializations" : [
       { "appearance" : "dark", "value" : "automatic" }
     ]
   }
   ```
   浅色 = 白底；深色 = `"automatic"` 让系统上深色玻璃材质（和系统其它图标同源）。编译后 `Assets.car` 里会多出一个 `Color-4` 条目 —— 这就是特化生效的标志。

4. 本仓库的 `Antigravity.icon/` 是可编辑源（想改底色/光照直接改 `icon.json`），`compiled/` 是编译产物，`apply-appicon.sh` 负责装入：写 `CFBundleIconName` + `CFBundleIconFile` → `Assets.car` 进 Resources → ad-hoc 重签 → 刷 Dock。

> 深浅切换依旧没有 per-layer 的实测样例可抄（只验证了 fill 层面），所以 A 字形本身在两种模式下是同一张彩虹图层 —— 它本来就该是彩色的，无需特化。

## 附：v1 时代的实测记录（部分结论已被 v2 推翻，留档）

macOS 26+ 确实支持 app 图标的 light/dark/tinted 变体，但**机制有坑**：

1. **传统的 `.appiconset` + `appearances: [{appearance: luminosity, value: dark}]` 写法对 macOS app icon 无效**。
   实测用 `actool` 编译「含 dark 条目」和「仅 light」两个图标集，产出的 `Assets.car` **md5 完全一致**
   （`7f51da3d6400575cb1f4a37020bc37f7`），`assetutil --info` 显示 11 个 rendition 的 `Appearance` 全是 `None`
   —— actool 静默忽略了 dark 条目。
   ✅ 此结论仍成立，但**只对老 `.appiconset` 路径成立**；v2 走的 `.icon` 目录 + `fill-specializations` 不受此限。

2. ~~「唯一可行路径是 Icon Composer 的 `.icon` 格式」「Icon Composer 是纯 GUI、无 CLI、`.icon` 格式未公开」~~
   ❌ **已被 v2 推翻**：`.icon` 是开放的目录格式（`icon.json` + `Assets/`），actool 可直接编译，全程无需 GUI。

3. ~~「收益有限，不做」~~ ❌ 已实现（见 v2 章节）。

### 有用的排查命令

```bash
# 看某个 app 的图标配置
/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" /Applications/X.app/Contents/Info.plist

# 看 Assets.car 里到底有哪些外观变体（assetutil 在 /usr/bin，不在 Xcode 里）
/usr/bin/assetutil --info /Applications/X.app/Contents/Resources/Assets.car

# 从 icns 解出各尺寸 PNG
iconutil -c iconset /Applications/X.app/Contents/Resources/icon.icns -o /tmp/out.iconset

# 重新打包 icns
iconutil -c icns /tmp/out.iconset -o /tmp/new.icns
```
