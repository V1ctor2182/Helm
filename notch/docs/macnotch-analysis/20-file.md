# MacNotch — File Interactions (Drop Actions + Shelf) 模块分析

> 用于 HTML 高保真复刻。素材：`reference/macnotch/file-interactions.mp4`（68.5s, 60fps, 3456×2234，即 Retina @2x，逻辑分辨率约 1728×1117pt）+ 抽帧 `frames/file/`。
> 所有像素估值默认给**逻辑点（pt）= 物理像素 ÷ 2**。标 ⚠️ 的为不确定项，见文末清单。

应用名：**MacNotch**（NotchNook 类刘海工具）。本模块覆盖「把文件拖到刘海 → 弹出 Drop Actions 动作条 → 其中 Shelf 暂存架接住文件 → 再从架子里拖出」全流程，以及 Settings 里的 Drop Actions 配置面板。

---

## 0. 核心交互模型（先读这段）

MacNotch 的文件交互**不是单纯的暂存架**，而是一个**多目标投放条（Drop to Action bar）**：

1. 从 Finder 拖起文件 → 光标接近屏幕顶部刘海。
2. 刘海**向下展开成一条横向动作条**，标题「Drop to Action」，里面是一排可投放动作磁贴：**AirDrop / iCloud / Shelf / Open with / Convert / Zip**（默认 6 个，可在设置里增删，最多 8 个）。
3. 把文件悬停到某个磁贴上 → 该磁贴高亮（图标变白、出现绿色 `+` 角标），松手即执行该动作。
4. 其中 **Shelf（Hold files）** 这个动作 = 暂存架：投进去后刘海变成 **Shelf 视图**，文件以缩略图磁贴横向陈列，可再拖出、删除、批量 Move。
5. 折叠后若架子里有文件，刘海**左侧露出一个迷你缩略图**作为「装着文件」的提示。

所以要复刻两个主界面：**(A) Drop Actions 动作条** 和 **(B) Shelf 暂存架**，外加 **(C) 折叠态持有提示** 与 **(D) Settings 配置面板**。

---

## 1. 折叠态 / 待机（State: idle & holding）

帧：`f_001`、`notch_t1`、`notch_t25`

- 折叠刘海是纯黑（`#000000`，与屏幕黑边无缝融合）圆角胶囊，约 **宽 ~230pt × 高 ~32pt**，**底部两角圆角 ~ 10–12pt**（顶部贴合屏幕顶边，无圆角）。
- **空闲无文件**：刘海就是系统刘海形状，无内容。
- **装着文件（holding）提示**：折叠条**左端露出一个迷你文件缩略图磁贴**（圆角方块，约 22×22pt，圆角 ~5pt，带细白边/浅描边），代表架子里最上面的一项；**右端显示「`· · · · ·`」五个小圆点**（浅灰 `#8E8E93`，约 3pt 直径），是 hover/拖拽提示句柄。
  - ⚠️ 多文件时左侧是否堆叠成多张缩略图（fan/stack）还是只显示 1 张：视频里始终只见 1 张缩略图。
- 拖拽文件经过折叠条时，被拖文件本体（系统拖影）正常显示：**文件图标 + 蓝色胶囊文件名标签**（见下）。

---

## 2. Drop Actions 动作条（State: dragging over notch）

帧：`f_003`、`crop_dropbar.png`、`f_011`、`f_014`、`f_015`、`col_26`、`prefs_62`（Preview 态）

文件拖近顶部，刘海**向下展开**成一条横向条。

### 2.1 容器
- 纯黑底 `#000000`，**整条横跨刘海左右**，向下延伸。整体宽约 **620–680pt**，高约 **95–105pt**（标题行 + 磁贴行）。
- **底部四角大圆角 ~ 22–28pt**；顶部与屏幕顶边对齐（刘海两侧仍是系统刘海内凹）。
- 顶部标题行：
  - 左：图标 + 「**Drop to Action**」（白色，~13pt，半粗）。
  - 右：「**Add actions in Settings → Notch → Drop Actions**」（灰 `#8E8E93`，~12pt）提示文字。
  - Settings 预览态时右上角文字变橙：「**Editing Drop Actions in Settings — no drops accepted**」（`#FF9F0A` 橙）。

### 2.2 动作磁贴（默认 6 个）
横向等分排列，磁贴之间有**细竖分隔线**（白色 ~8% 透明，1px）。每个磁贴垂直堆叠：

| 顺序 | 图标 | 标题（白, ~16pt 半粗） | 副标题（灰, ~12pt） |
|---|---|---|---|
| 1 | 上传箭头方框 | AirDrop | Send nearby |
| 2 | 云朵+上箭头 | iCloud | Save to Drive |
| 3 | 托盘+下箭头 | **Shelf** | **Hold files** |
| 4 | 圆角方框（右上白点徽标） | Open with | Add apps in Settings |
| 5 | 相机+循环箭头 | Convert | Images only |
| 6 | 压缩盒 | Zip | Compress |

- 图标为**线性描边**风格，约 **28–30pt** 高。
- **默认（未悬停）**：图标 + 文字为中灰 `#9A9A9E` 左右；未配置/不可用的磁贴（如示例里 Convert）整体更暗 `#5A5A5E`（disabled 态）。
- **悬停高亮态**：被拖到的磁贴图标与标题变**纯白 `#FFFFFF`**，副标题保持灰；磁贴区域可能有极轻微高亮（⚠️ 未见明显背景块，主要靠图标提亮区分）。
- **Open with** 磁贴图标右上角有一个**白色小圆点徽标**（~6pt），疑似「有可选 App」提示。悬停 Open with 时（`col_26`）磁贴内**横向展开候选 App 图标**（如某 App + Safari 彩色图标，~36pt），可继续投到具体 App。

### 2.3 被拖文件的拖影
- 文件图标（~28pt）+ 紧贴右侧的**蓝色圆角胶囊文件名标签**：背景系统蓝 `#0A84FF`，白字 ~13pt（如「image-sample.png」「sample.pdf」），胶囊圆角 ~9pt。
- 多文件拖拽：胶囊左侧叠一个**绿色圆形 `+` 角标**（`#30D158`，~18pt，白色加号）+ 一个**红色圆形数量角标**（`#FF3B30`，白字，如「6」，~18pt），二者并排在文件图标右下。

---

## 3. Shelf 暂存架（State: stored N items）

帧：`f_005`、`f_006`、`crop_shelf.png`、`settings.png`（空架）

把文件投到 Shelf 磁贴后，刘海切换为 **Shelf 视图**（一个更大的黑色面板）。

### 3.1 容器
- 纯黑 `#000000` 面板，宽约 **620–700pt**，高约 **150–170pt**；**底部四角大圆角 ~ 26–30pt**。
- 展开时面板从刘海向下「长出」（spring 下滑 + 轻微缩放，见 §6）。

### 3.2 头部栏（约 36–40pt 高）
- 左：「**Shelf**」白色粗体 ~17pt + 一个**托盘/信封图标**（线性，~16pt）+ 「**N items**」灰字 ~13pt（如「6 items」）。
- 右侧一排工具按钮（均为深灰圆形底 `#2C2C2E` ~ 28pt 直径的胶囊/圆钮）：
  1. **✓ 圆圈**（全选 / 进入选择模式）
  2. **✕ 圆圈**（取消选择 / 清空选择）
  3. **「Move ⇅」胶囊按钮**（深灰胶囊，白字 + 上下箭头图标；点开是移动目标下拉菜单）
  4. **🗑 垃圾桶**（删除选中 / 清空）
  5. **ⓘ 信息**（圆形）
- ⚠️ 这些按钮的精确分工（选择/删除/清空）靠图标推断，未逐一点击验证。

### 3.3 文件陈列区
- 头部下方是一个**虚线圆角矩形拖放区**（dashed border，灰 `#5A5A5E`，圆角 ~16pt，内边距 ~12pt）——既是容器也是「可往里拖」的视觉提示。
- 文件以**横向一排磁贴（grid/row）**陈列，不堆叠、不列表：
  - 每个磁贴 ≈ **宽 56pt**，磁贴间距 ~12pt。
  - **缩略图方块**：圆角方形 ~ 44×44pt，圆角 ~10pt，深灰底 `#1C1C1E`，带细描边。
    - 图片文件 → 真实图片缩略图；
    - 代码/文档 → 系统/类型图标（Swift 红色图标、PDF 文档图标 `sample.pdf`、zip 文档图标、音频波形图标 `audio-sample` 等）。
  - **选择角标**：缩略图右下角一个**灰色圆形勾选徽标**（`#48484A` 底 + 灰勾，~16pt）——多选/管理态。选中时推测变蓝（⚠️ 未捕获到选中蓝态）。
  - **文件名**：缩略图下方，灰白字 ~11pt，居中，**超长截断**为「image-sam…」「Swift-code.…」「audio-sam…」（尾部省略号）。
- 空架占位（`settings.png`）：虚线框内居中两行文字——「**Drop files here**」（白 ~14pt）/「**Stash files here. Drag them out…**」（灰 ~12pt 副提示）。
- 面板右外侧（紧贴刘海展开 UI 右缘）有一条**竖向小图标栏**（音符 ♪ / 托盘 / 闪电 ⚡ / `</>` 代码），是刘海展开后的模块切换 tab，不属于 Shelf 本身但会同框出现。⚠️ 与 Shelf 的从属关系未深究。

---

## 4. 从刘海拖出文件（State: drag-out）

帧：`f_007`、`f_008`

- 在 Shelf 视图里**按住某个文件磁贴往外拖** → 生成系统拖影（文件图标 + 红色数量角标，如「6」），跟随光标移动到 Finder/桌面。
- 拖出过程中 Shelf 面板保持展开；松手后文件落到目标位置（视频里拖回 Finder 窗口）。
- ⚠️ 拖出后该文件是否从架子移除（move 语义）还是保留副本（copy 语义）未确认；存在「Move」按钮暗示默认是**复制出去、保留在架**，需点 Move/删除才清。

---

## 5. Settings — Drop Actions 配置面板（State: settings）

帧：`prefs_62`、`prefs_58/60/64`、`settings.png`（右键菜单）

标准 macOS 设置窗（白底浅色），标题「**MacNotch Settings**」。
- **侧栏**：APP（General / Interaction / Licensing）、NOTCH（Layout / Multiple Screens / **Drop Actions**〔选中，红色高亮〕/ Live Activities）、MODULES（Dashboard / Bluetooth / Calendar / Tasks）。顶部有 MacNotch 图标 + 搜索框。
- **Drop Actions 右侧面板**：
  - 上半部：**已启用动作的可排序列表**（每行左侧拖拽手柄 `≡` + 彩色图标 + 名称）：AirDrop / iCloud / Shelf / Open with / Convert / Zip。
  - 「**Choose Drop Actions**」标题，右侧「**6 selected**」（蓝字）。副说明：「Select up to 8 actions to show when you drop files on the notch.」
  - **3 列动作卡片网格**（每卡：彩色圆角图标 + 标题 + 副标题 + 右侧圆形勾选 toggle）：
    Shelf/Hold files ✓、AirDrop/Send nearby ✓、iCloud/Save to Drive ✓、Zip/Compress ✓、Unzip/Extract ○、Convert/Convert image ✓、Move to/Move files ○、Copy to/Duplicate ○、Open with/Smart App ✓、Music/Play in Music ○。
  - 下方「**Convert**」分区：「Default format when hovering the notch with images.」
- 菜单栏右键菜单（`settings.png`）：**Hide MacNotch / Settings… / Quit MacNotch**。

---

## 6. 动画 / 缓动（估值）

> 60fps 源，但抽帧密度有限，时长为目测区间估值（⚠️）。

- **拖近 → 动作条展开**：刘海从折叠胶囊向下「掉出/展开」成动作条，**spring 下滑 + 轻微高度增长**，约 **0.25–0.35s**，缓动近 `spring(damping≈0.8)` / `easeOut`，带轻微回弹。
- **Shelf 视图切换**：投到 Shelf 后面板继续向下增高到 Shelf 尺寸，crossfade + 高度 spring，约 **0.25–0.3s**。
- **磁贴悬停高亮**：图标提亮/绿+角标出现近乎即时，~0.1s 淡入。
- **文件入架**：缩略图磁贴从投放点缩放/淡入归位（⚠️ 帧未明确捕获，推测 ~0.2s scale+fade）。
- **折叠收起**：反向 spring 收回胶囊，~0.25s；点击外部区域触发收起。

---

## 7. 配色 / 尺寸速查（复刻用）

| 项 | 估值 |
|---|---|
| 面板底色 | `#000000`（纯黑，融入刘海） |
| 工具按钮底 | 深灰 `#2C2C2E` ~ `#3A3A3C` |
| 缩略图底 | `#1C1C1E`，描边 `#3A3A3C` |
| 主文字 | 白 `#FFFFFF` |
| 次文字/disabled | 灰 `#8E8E93` / 更暗 `#5A5A5E` |
| 系统蓝（文件名胶囊 / "selected" 链接） | `#0A84FF` |
| 绿 `+` 角标 | `#30D158` |
| 红数量角标 | `#FF3B30` |
| 橙警示文字 | `#FF9F0A` |
| 选择勾选徽标底 | `#48484A` |
| 折叠刘海 | ~230×32pt，底角 R≈10–12pt |
| Drop Actions 条 | ~620–680 × 95–105pt，底角 R≈22–28pt |
| Shelf 面板 | ~620–700 × 150–170pt，底角 R≈26–30pt，头部 ~38pt |
| 动作磁贴图标 | ~28–30pt 线性描边 |
| Shelf 文件磁贴 | 缩略图 ~44pt（R≈10pt），整磁贴宽 ~56pt，间距 ~12pt，文件名 ~11pt |
| 选择/数量角标 | ~16–18pt |
| 文件名蓝胶囊 | 高 ~20pt，R≈9pt，白字 ~13pt |

---

## 8. 不确定清单（需进一步验证）

1. **多文件折叠提示**：折叠态左侧是 1 张缩略图还是堆叠多张？是否带计数角标？视频始终只见 1 张。
2. **Shelf 选择态颜色**：勾选徽标选中后是否变蓝、是否高亮磁贴边框——未捕获选中瞬间。
3. **拖出语义**：从架子拖出是 move（移除）还是 copy（保留）？「Move」按钮与拖出的关系。
4. **头部工具按钮分工**：✓ / ✕ / Move / 🗑 / ⓘ 各自精确行为（全选？清空？信息面板内容？）未逐一验证。
5. **Move 下拉菜单**：点开「Move ⇅」后的目标列表内容未捕获。
6. **入架/落位动画**：缩略图归位动画的精确曲线与时长（帧不足）。
7. **动作条悬停背景**：高亮磁贴除图标提亮外是否有背景块/分隔线变化——证据弱。
8. **Open with 候选 App 来源**：磁贴内展开的 App 列表如何配置（设置里「Add apps」），白点徽标含义。
9. **超过一屏的文件数**：Shelf 装很多文件时是否横向滚动 / 换行 / 分页——视频最多见 6 个未溢出。
10. **右侧竖向模块 tab**（♪/托盘/⚡/`</>`）与 Shelf 的关系：是否为展开刘海的通用模块切换器。
11. **动画时长**均为目测区间，未逐帧测量帧号差。
