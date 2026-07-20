# 吞噬幸存者 - 美术资源需求清单

> **版本**: v1.0
> **日期**: 2026-07-16
> **平台**: 移动端竖屏 720x1280
> **美术风格**: 2D 扁平矢量风（简洁明快，适合移动端）
> **生成方式**: AI 图像生成

---

## 目录

- [一、资源总览](#一资源总览)
- [二、角色与敌人 Sprite](#二角色与敌人-sprite)
- [三、技能效果 Sprite / 粒子](#三技能效果-sprite--粒子)
- [四、UI 界面资源](#四ui-界面资源)
- [五、主菜单与游戏结束界面](#五主菜单与游戏结束界面)
- [六、音效资源](#六音效资源)
- [七、字体](#七字体)
- [八、特效粒子](#八特效粒子)
- [九、AI 生成指南](#九ai-生成指南)
- [十、资源目录结构](#十资源目录结构)
- [十一、优先级与排期](#十一优先级与排期)

---

## 一、资源总览

| 类别 | 数量 | 格式 | 说明 |
|---|---|---|---|
| 角色与敌人 | 7 | PNG 透明背景 | 玩家 + 6种敌人 |
| 技能效果 | 11 | PNG 序列帧 / 粒子贴图 | 11个技能的视觉表现 |
| UI 界面 | 9 | PNG / PNG 切片 | 摇杆、血条、卡牌、弹窗等 |
| 菜单与结束 | 3 | PNG | 标题、背景、结束面板 |
| 音效 | 7 | WAV / OGG | 吞噬、升级、技能、融合等 |
| 字体 | 1 | TTF / OTF | 中文字体 |
| 粒子纹理 | 2 | PNG 图集 | 发光、烟雾、火花等 |

合计约 40 项独立资源
---

## 二、角色与敌人 Sprite

### 2.1 玩家角色

| 字段 | 内容 |
|---|---|
| 资源名 | player.png |
| 用途 | 主角形象，吞噬后体型逐渐变大 |
| 格式 | PNG 透明背景 |
| 尺寸 | 128x128（基础尺寸） |
| 风格 | 卡通风格圆形/椭圆形生物，绿色系，有眼睛，可爱但不幼稚 |
| 变体 | 需支持缩放至 3 倍（体型成长后最大约 384x384） |
| AI 提示词 | cute round green creature, simple cartoon style, flat design, transparent background, facing forward, big eyes, soft shading, game sprite, 128x128 |

### 2.2 敌人 - 普通 (Basic)

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_basic.png |
| 用途 | 基础敌人，被吞噬后玩家获得少量成长 |
| 格式 | PNG 透明背景 |
| 尺寸 | 32x32 |
| 风格 | 小型绿色球状生物，表情呆萌 |
| AI 提示词 | small cute green slime creature, simple cartoon style, flat design, transparent background, side view, game sprite, 32x32 |

### 2.3 敌人 - 迅捷 (Swift)

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_swift.png |
| 用途 | 速度快、体型小，吞噬收益低 |
| 格式 | PNG 透明背景 |
| 尺寸 | 24x24 |
| 风格 | 黄色闪电状生物，有速度线条 |
| AI 提示词 | small yellow lightning creature, fast looking, simple cartoon style, flat design, transparent background, game sprite, 24x24 |

### 2.4 敌人 - 重装 (Heavy)

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_heavy.png |
| 用途 | 体型大、血量高，吞噬收益高 |
| 格式 | PNG 透明背景 |
| 尺寸 | 48x48 |
| 风格 | 红色装甲生物，看起来结实厚重 |
| AI 提示词 | big armored red creature, tough looking, simple cartoon style, flat design, transparent background, game sprite, 48x48 |

### 2.5 敌人 - 分裂 (Split)

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_split.png |
| 用途 | 被吞噬后会分裂成两个小敌人 |
| 格式 | PNG 透明背景 |
| 尺寸 | 36x36 |
| 风格 | 紫色双核生物，看起来像两个球连在一起 |
| AI 提示词 | purple double-ball creature, splitting, simple cartoon style, flat design, transparent background, game sprite, 36x36 |

### 2.6 敌人 - 诱饵 (Decoy)

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_decoy.png |
| 用途 | 体型大但吞噬收益为 0，用来迷惑玩家 |
| 格式 | PNG 透明背景 |
| 尺寸 | 60x60 |
| 风格 | 粉色气球状生物，看起来虚胖 |
| AI 提示词 | pink balloon creature, fake big, simple cartoon style, flat design, transparent background, game sprite, 60x60 |

### 2.7 敌人 - Boss

| 字段 | 内容 |
|---|---|
| 资源名 | enemy_boss.png |
| 用途 | 每 5 波出现的精英 Boss，血量 20 |
| 格式 | PNG 透明背景 |
| 尺寸 | 100x100 |
| 风格 | 金色大型生物，有王冠或光环，威严但不恐怖 |
| AI 提示词 | golden boss creature, crown, majestic, simple cartoon style, flat design, transparent background, game sprite, 100x100 |
---

## 三、技能效果 Sprite / 粒子

> 注意：技能效果可以使用粒子系统（GPUParticles2D）或序列帧动画。以下列出的是粒子贴图/特效帧。

| # | 资源名 | 对应技能 | 尺寸 | 说明 |
|---|---|---|---|---|
| 1 | fx_beam.png | 吞噬波 | 256x64 | 锥形光束，绿色发光 |
| 2 | fx_spiral.png | 螺旋吞噬 | 256x256 | 旋转吞噬漩涡，绿色 |
| 3 | fx_tracking_orb.png | 追踪吞噬 | 32x32 | 追踪弹体，绿色光球 |
| 4 | fx_blackhole.png | 黑洞牵引 | 128x128 | 紫色黑洞吸力效果 |
| 5 | fx_line_cut.png | 相位切割 | 512x16 | 红色切割光线 |
| 6 | fx_shadow_clone.png | 影分身 | 64x64 | 半透明蓝色分身 |
| 7 | fx_shadow_bind.png | 影子束缚 | 256x256 | 紫色束缚光环 |
| 8 | fx_mirror_domain.png | 镜像领域 | 256x256 | 粉色复制光晕 |
| 9 | fx_freeze.png | 时空停滞 | 512x512 | 全屏冰蓝冻结覆盖 |
| 10 | fx_pull.png | 群体拉近 | 256x256 | 橙色吸入漩涡 |
| 11 | fx_aura.png | 吞噬光环 | 128x128 | 金色持续吞噬光环 |

AI 通用提示词模板：

`
glowing [颜色] [效果描述], particle effect, game VFX, transparent background,
simple flat style, [尺寸], no text, no border
`

示例（吞噬波）：
`
glowing green beam effect, particle effect, game VFX, transparent background,
simple flat style, 256x64, no text, no border
`

---

## 四、UI 界面资源

### 4.1 虚拟摇杆

| 字段 | 内容 |
|---|---|
| 资源名 | ui_joystick_outer.png + ui_joystick_inner.png |
| 用途 | 底部虚拟摇杆的外圈和内圈 |
| 格式 | PNG 透明背景 |
| 尺寸 | 外圈 128x128，内圈 50x50 |
| 风格 | 半透明灰色圆形，简约现代 |
| AI 提示词 | simple game joystick, semi-transparent gray circle, outer ring, flat design, transparent background, 128x128 |

### 4.2 HP 血条

| 字段 | 内容 |
|---|---|
| 资源名 | ui_hp_bg.png + ui_hp_bar.png |
| 用途 | 顶部 HP 显示 |
| 格式 | PNG 切片（可拉伸） |
| 尺寸 | 背景 720x20，填充条 720x16 |
| 风格 | 深色背景槽 + 红色填充条 |

### 4.3 能量条

| 字段 | 内容 |
|---|---|
| 资源名 | ui_energy_bg.png + ui_energy_bar.png |
| 用途 | 技能能量显示 |
| 格式 | PNG 切片 |
| 尺寸 | 背景 720x20，填充条 720x16 |
| 风格 | 深色背景槽 + 蓝色/金色填充条 |

### 4.4 卡牌背景

| 字段 | 内容 |
|---|---|
| 资源名 | ui_card_common.png / uncommon.png / legendary.png / relic.png |
| 用途 | 升级弹窗中的卡牌卡片 |
| 格式 | PNG |
| 尺寸 | 180x220 |
| 风格 | 深色圆角卡片，不同稀有度有不同颜色的边框 |
| AI 提示词 | game card background, dark rounded rectangle, [颜色] border, flat design, transparent background, 180x220 |

### 4.5 卡牌图标

| 字段 | 内容 |
|---|---|
| 资源名 | icon_card_*.png x 43 |
| 用途 | 每张卡牌的小图标 |
| 格式 | PNG 透明背景 |
| 尺寸 | 64x64 |
| 说明 | 43 张卡牌各需一个图标，可根据卡牌效果设计（盾牌=防御、闪电=速度等） |

### 4.6 升级弹窗面板

| 字段 | 内容 |
|---|---|
| 资源名 | ui_upgrade_panel.png |
| 用途 | 升级时弹出的半透明深色背景 |
| 格式 | PNG |
| 尺寸 | 720x800 |
| 风格 | 半透明深色渐变背景，圆角 |

### 4.7 确认按钮

| 字段 | 内容 |
|---|---|
| 资源名 | ui_button_confirm.png |
| 用途 | 升级弹窗的确认按钮 |
| 格式 | PNG |
| 尺寸 | 200x50 |
| 风格 | 金色/绿色按钮，圆角 |

### 4.8 HUD 背景

| 字段 | 内容 |
|---|---|
| 资源名 | ui_hud_bg.png |
| 用途 | 顶部状态栏背景 |
| 格式 | PNG |
| 尺寸 | 720x80 |
| 风格 | 半透明深色横条 |

### 4.9 技能冷却指示器

| 字段 | 内容 |
|---|---|
| 资源名 | ui_skill_cd_*.png x 11 |
| 用途 | 每个技能的圆形冷却进度盘 |
| 格式 | PNG 透明背景 |
| 尺寸 | 40x40 |
| 风格 | 半透明圆形，深色填充表示冷却中 |
---

## 五、主菜单与游戏结束界面

### 5.1 游戏标题 Logo

| 字段 | 内容 |
|---|---|
| 资源名 | ui_logo_title.png |
| 用途 | 主菜单标题 |
| 格式 | PNG |
| 尺寸 | 500x120 |
| 风格 | 粗体中文吞噬幸存者，暗色背景，发光效果 |
| AI 提示词 | game title logo, chinese text, glowing effect, dark background, bold font, 500x120, transparent |

### 5.2 开始按钮

| 字段 | 内容 |
|---|---|
| 资源名 | ui_button_start.png |
| 用途 | 主菜单开始游戏按钮 |
| 格式 | PNG |
| 尺寸 | 300x60 |
| 风格 | 大按钮，绿色/金色，圆角 |

### 5.3 背景图

| 字段 | 内容 |
|---|---|
| 资源名 | bg_gameplay.png / bg_menu.png |
| 用途 | 游戏背景 / 主菜单背景 |
| 格式 | PNG |
| 尺寸 | 720x1280 |
| 风格 | 暗色星空/深渊风格，有纵深感 |
| AI 提示词 | dark space background, stars, deep purple and blue gradient, game background, 720x1280, no text |

### 5.4 游戏结束面板

| 字段 | 内容 |
|---|---|
| 资源名 | ui_gameover_panel.png |
| 用途 | 游戏结束时显示的结算面板 |
| 格式 | PNG |
| 尺寸 | 720x600 |
| 风格 | 半透明深色面板，圆角 |

---

## 六、音效资源

> AI 音频生成工具推荐：Suno AI、ElevenLabs、Audo.ai、Freesound.org

| # | 资源名 | 用途 | 格式 | 时长 | 说明 |
|---|---|---|---|---|---|
| 1 | sfx_capture.wav | 吞噬敌人 | WAV | 0.3s | 短促的啵声 |
| 2 | sfx_levelup.wav | 升级弹窗出现 | WAV | 0.5s | 上升感的音效 |
| 3 | sfx_skill_cast.wav | 释放技能 | WAV | 0.4s | 能量释放声 |
| 4 | sfx_fusion.wav | 触发融合 | WAV | 0.8s | 特殊的叮声 |
| 5 | sfx_hit.wav | 玩家受击 | WAV | 0.2s | 短促打击声 |
| 6 | sfx_wave_start.wav | 波次开始 | WAV | 1.0s | 紧张感音效 |
| 7 | bgm_game.ogg | 背景音乐 | OGG | 循环 | 紧张刺激的游戏 BGM |

AI 音频生成提示词参考（吞噬音效）：
`
short pop sound, satisfying, cute, game effect, 0.3 seconds, high quality
`

AI 音频生成提示词参考（背景音乐）：
`
upbeat electronic game music, tense but fun, loopable, 2 minutes,
mobile game background music, no vocals
`

---

## 七、字体

| 字段 | 内容 |
|---|---|
| 资源名 | font_chinese.ttf |
| 用途 | 全部中文文本（标题、卡牌、UI） |
| 格式 | TTF / OTF |
| 推荐 | 思源黑体（免费可商用）、站酷快乐体（活泼风格）、庞门正道标题体（粗体标题） |
| 说明 | 建议使用免费可商用的中文字体，避免版权问题 |

---

## 八、特效粒子

| # | 资源名 | 用途 | 尺寸 | 说明 |
|---|---|---|---|---|
| 1 | tex_particle_glow.png | 发光粒子 | 128x128 | 径向渐变发光球，用于技能光效 |
| 2 | tex_particle_smoke.png | 烟雾粒子 | 64x64 | 半透明烟雾纹理 |
| 3 | tex_particle_spark.png | 火花粒子 | 32x32 | 小星星/火花形状 |
| 4 | tex_particle_ice.png | 冰冻粒子 | 64x64 | 冰晶碎片 |
---

## 九、AI 生成指南

### 9.1 推荐工具

| 类型 | 工具 | 特点 | 费用 |
|---|---|---|---|
| 图像生成 | Midjourney v6 | 质量最高，风格多样 | 订阅制（10美元/月起） |
| 图像生成 | DALL-E 3 | 易用，理解能力强 | 通过 ChatGPT Plus 使用 |
| 图像生成 | Stable Diffusion | 免费开源，可控性强 | 免费（需本地 GPU） |
| 图像生成 | 通义万相 | 国产，中文提示词友好 | 免费额度 |
| 图像生成 | Leonardo AI | 游戏资产专用 | 免费额度 |
| 音频生成 | Suno AI | 生成完整音乐 | 免费额度 |
| 音频生成 | ElevenLabs | 音效生成 | 免费额度 |
| 音效库 | Freesound.org | 免费音效库 | 免费 |

### 9.2 图像生成技巧

通用提示词模板：

`
[主体描述], [风格], [颜色], [视角], [背景], [尺寸], [技术要求]
`

示例：
`
cute round green creature, simple cartoon style, flat design,
transparent background, front view, game sprite, 128x128,
no text, no border, clean edges
`

关键技巧：
1. **透明背景**：加上 transparent background、no background、clean edges
2. **游戏精灵**：加上 game sprite、flat design、simple shapes
3. **一致性**：所有敌人使用相同的风格描述词，确保视觉统一
4. **批量生成**：用同一组提示词模板，只替换主体描述
5. **迭代优化**：先生成 4 张，选最好的，再用相似的提示词生成更多

### 9.3 分批生成建议

**第一批（P0 核心资源，优先生成）**：
- 玩家角色（1 张）
- 6 种敌人（6 张）
- 虚拟摇杆（2 张）
- HP 血条（2 张）
- 游戏背景（1 张）
- 中文字体（下载，无需生成）

**第二批（P1 重要资源）**：
- 43 张卡牌图标（可分批生成，每次 5-10 张）
- 卡牌背景（4 张，不同稀有度）
- 升级弹窗面板（1 张）
- 技能效果（11 张）

**第三批（P2 锦上添花）**：
- 主菜单标题 Logo（1 张）
- 开始按钮（1 张）
- 游戏结束面板（1 张）
- 粒子纹理（4 张）
- 音效（7 个）

### 9.4 风格统一指南

推荐美术风格：**扁平矢量卡通风**（Flat Vector Cartoon）

- 特点：简洁、色彩鲜明、无复杂光影
- 优点：文件小、加载快、适合移动端
- 参考关键词：flat design、minimalist、colorful、cute、simple shapes

颜色规范：
- 玩家：绿色系
- 普通敌人：绿色
- 迅捷敌人：黄色
- 重装敌人：红色
- 分裂敌人：紫色
- 诱饵敌人：粉色
- Boss：金色
- 技能效果：根据技能类型区分颜色
---

## 十、资源目录结构

`
assets/
├── sprites/
│   ├── player/
│   │   └── player.png              # 玩家角色
│   ├── enemies/
│   │   ├── enemy_basic.png         # 普通敌人
│   │   ├── enemy_swift.png         # 迅捷敌人
│   │   ├── enemy_heavy.png         # 重装敌人
│   │   ├── enemy_split.png         # 分裂敌人
│   │   ├── enemy_decoy.png         # 诱饵敌人
│   │   └── enemy_boss.png          # Boss
│   ├── skills/
│   │   ├── fx_beam.png             # 吞噬波
│   │   ├── fx_spiral.png           # 螺旋吞噬
│   │   ├── fx_tracking_orb.png     # 追踪吞噬
│   │   ├── fx_blackhole.png        # 黑洞牵引
│   │   ├── fx_line_cut.png         # 相位切割
│   │   ├── fx_shadow_clone.png     # 影分身
│   │   ├── fx_shadow_bind.png      # 影子束缚
│   │   ├── fx_mirror_domain.png    # 镜像领域
│   │   ├── fx_freeze.png           # 时空停滞
│   │   ├── fx_pull.png             # 群体拉近
│   │   └── fx_aura.png             # 吞噬光环
│   └── particles/
│       ├── tex_particle_glow.png   # 发光粒子
│       ├── tex_particle_smoke.png  # 烟雾粒子
│       ├── tex_particle_spark.png  # 火花粒子
│       └── tex_particle_ice.png    # 冰冻粒子
├── ui/
│   ├── joystick/
│   │   ├── ui_joystick_outer.png   # 摇杆外圈
│   │   └── ui_joystick_inner.png   # 摇杆内圈
│   ├── bars/
│   │   ├── ui_hp_bg.png            # HP 背景槽
│   │   ├── ui_hp_bar.png           # HP 填充条
│   │   ├── ui_energy_bg.png        # 能量背景槽
│   │   └── ui_energy_bar.png       # 能量填充条
│   ├── cards/
│   │   ├── ui_card_common.png      # 普通卡牌背景
│   │   ├── ui_card_uncommon.png    # 稀有卡牌背景
│   │   ├── ui_card_legendary.png   # 传说卡牌背景
│   │   ├── ui_card_relic.png       # 遗物卡牌背景
│   │   └── icons/                  # 卡牌图标目录
│   │       ├── icon_card_001.png
│   │       ├── icon_card_002.png
│   │       └── ... (共43张)
│   ├── panels/
│   │   ├── ui_upgrade_panel.png    # 升级弹窗面板
│   │   ├── ui_gameover_panel.png   # 游戏结束面板
│   │   └── ui_hud_bg.png           # HUD 背景条
│   ├── buttons/
│   │   ├── ui_button_confirm.png   # 确认按钮
│   │   └── ui_button_start.png     # 开始按钮
│   ├── skills/
│   │   └── ui_skill_cd_*.png       # 技能冷却盘 x11
│   └── logo/
│       └── ui_logo_title.png       # 游戏标题 Logo
├── backgrounds/
│   ├── bg_gameplay.png             # 游戏背景
│   └── bg_menu.png                 # 主菜单背景
├── audio/
│   ├── sfx/
│   │   ├── sfx_capture.wav         # 吞噬音效
│   │   ├── sfx_levelup.wav         # 升级音效
│   │   ├── sfx_skill_cast.wav      # 技能音效
│   │   ├── sfx_fusion.wav          # 融合音效
│   │   ├── sfx_hit.wav             # 受击音效
│   │   └── sfx_wave_start.wav      # 波次开始音效
│   ├── music/
│   │   └── bgm_game.ogg            # 背景音乐
│   └── voices/                     # （可选）语音包
└── fonts/
    └── font_chinese.ttf            # 中文字体
`

---

## 十一、优先级与排期

### 第一阶段（核心体验）- 约 1-2 天
- [ ] 玩家角色 Sprite
- [ ] 6 种敌人 Sprite
- [ ] 虚拟摇杆
- [ ] HP 血条
- [ ] 游戏背景
- [ ] 中文字体

### 第二阶段（完整玩法）- 约 2-3 天
- [ ] 43 张卡牌图标（可分批）
- [ ] 卡牌背景（4 种稀有度）
- [ ] 升级弹窗面板
- [ ] 技能效果（11 个）
- [ ] 音效（6 个）

### 第三阶段（polished）- 约 1-2 天
- [ ] 主菜单标题 Logo
- [ ] 开始/确认按钮
- [ ] 游戏结束面板
- [ ] 粒子纹理
- [ ] 背景音乐

### 总计
- 图像资源：约 35-40 张 PNG
- 音频资源：7 个文件
- 字体：1 个 TTF
- 预计 AI 生成时间：3-5 天（每天生成 10-15 张图）

---

*文档结束*