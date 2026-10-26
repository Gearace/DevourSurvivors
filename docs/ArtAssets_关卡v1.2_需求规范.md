# DevourSurvivors - Level Design v1.2 Art Asset Requirements Spec

> **Version**: v1.0
> **Date**: 2026-10-26
> **Upstream Basis**: docs/关卡设计_灵感归纳_v1.md (Multi-Stage Structure 3.0 / Boss 3-Phase 3.3 / Castlevania Room 3.4 / Alert 3.5 / Soul Death Penalty 3.2 / Golden Sun Elemental Puzzle 3.2 / StS Route Branch 3.2)
> **Companion GDD**: GDD_吞噬幸存者_v1.2.md (v1.2 Multi-Stage Master Outline)
> **Existing Asset Baseline**: ArtAssets_吞噬幸存者_v1.0.md (38 PNGs, already in assets/)
> **Platform**: Mobile Portrait 720x1280, Godot 4.x, 2D Flat Vector Style, AI Image Generation

---

## 0. Code Integration Points (Single Source of Truth)

> This section is the contract between assets and code. New resources must be hookable to the fields/constants listed below, otherwise they are considered un-integrated.

| Code Location | Field/Constant | Asset Requirement | Current Status |
|---|---|---|---|
| enemy_base.gd | textures Dictionary | Enemy textures (basic/swift/heavy/split/decoy/boss exist) | Missing elite_* and boss_ch1/2/3 |
| enemy_base.gd | _apply_elite_default() | 4 elite body_radius/color | Has 4 elites, no dedicated textures |
| enemy_base.gd | _is_boss_type() / _process_boss() | Boss 3-Phase | Has logic, no dedicated boss textures |
| wave_spawner.gd | _enemy_configs | Enemy hp/speed/body_radius/color | Has 6 base types, no elite/boss_ch* |
| wave_spawner.gd | _apply_node_overrides() | Elite body_radius override (tearer 45 / toxin 38 / mirror 30 / fortress 50) | Has logic, no dedicated textures |
| route_generator.gd | _roll_elite_id() | elite_tearer/toxin/mirror/fortress | Has logic, no dedicated textures |
| route_generator.gd | _roll_boss_id() | boss_ch1 / boss_v2_void / boss_v3_abyss | Has logic, no dedicated textures |
| route_ui.gd | NODE_DISPLAY | Node icons (emoji placeholder) | Need to replace with real icons |
| main_game_controller.gd | bg_sprite.texture | Background bg_gameplay.png | Single background, need to switch per chapter |

> **Integration Convention**: New enemy texture naming is enemy_<type>.png, strictly matching the enemy_type string (elite_tearer -> enemy_elite_tearer.png);
> New boss texture is enemy_<boss_id>.png (boss_ch1 -> enemy_boss_ch1.png).

---

## 1. Asset Overview (New This Time)

| Category | Count | Format | Priority | Description |
|---|---|---|---|---|
| Elite Sprite | 4 | PNG Transparent | P0 | Tearer/Toxin/Mirror/Fortress |
| Chapter Boss Sprite | 3 | PNG Transparent | P0 | boss_ch1 / boss_v2_void / boss_v3_abyss |
| Chapter Background | 3 | PNG 720x1280 | P0 | Swamp/Gold Mine/Void Corridor |
| Environment FX | 3 | PNG/Particle | P0 | Poison Fog/Lava/Void Veil |
| Style New Monsters | 4 | PNG Transparent | P1 | Toxin Pod/Split Body/Phase Slash/Feint |
| Exclusive Relic | 3 | PNG 64x64 | P1 | Toxin Core/Gold Shard/Void Shard |
| Node Icon | 6 | PNG 64x64 | P0 | Replace route_ui emoji |
| Card Icon | 55+38 | PNG 64x64 | P1 | Evolution 55 + Relic 38 (procedural combo) |
| Camp/Shop/Event Panel | 11 | PNG | P1 | Camp3+Shop Inventory+Event6 |
| HUD Supplement | 3 | PNG | P1 | Alert Indicator/Chapter Banner/Timer |
| Route Branch Card | 2 | PNG | P2 | Safe Line/Risk Line |

---

## 2. Naming Convention (Aligned with Existing 38)

### 2.1 File Naming
- Enemy: assets/sprites/enemies/enemy_<type>.png, <type> strictly matches the enemy_type string.
- Elite/Chapter Boss follow the same rule, do not create a new directory.
- Background: assets/backgrounds/bg_<chapter>.png (bg_ch1_swamp / bg_ch2_gold / bg_ch3_void).
- Environment FX: assets/sprites/environment/fx_env_<name>.png (new directory environment/).
- Node Icon: assets/ui/nodes/ui_node_<type>.png (new directory nodes/).
- Card Icon: assets/ui/cards/icons/icon_<card_id>.png (card_id uses card_database id).
- Exclusive Relic: assets/ui/relics/relic_<id>.png (new directory relics/).

### 2.2 Size Convention
- Enemy sprite: source 512x512, transparent bg, subject centered, 10% bleed; Godot auto-scales to body_radius (enemy_base._update_visuals already has scaling logic).
- Background: 720x1280 (matches viewport), dark, low-contrast, avoid stealing foreground.
- Environment FX: 256x256 particle texture / full-screen 720x1280 overlay.
- Node Icon / Card Icon: 64x64, transparent bg, thick outline (mobile small size legible).
- Exclusive Relic: 64x64, transparent bg, metal/gem texture.

### 2.3 Style Unity (Continuing v1.0 Flat Vector)
- Flat cartoon, no realistic lighting, clear color blocks; enemy round-blob with face vocabulary continues.
- Three chapters use color palettes to distinguish: Swamp = toxic green/mud brown, Gold Mine = orange-gold/lava red, Void Corridor = purple-black/deep blue.
- When generating, append: flat design, simple cartoon style, game sprite, transparent background, no text, no border, clean edges.

---

## 3. P0 - Elite (4)

| Filename | enemy_type | Radius | Style | AI Prompt |
|---|---|---|---|---|
| enemy_elite_tearer.png | elite_tearer | 45 | Tearer: dark red + tear, muscle fiber feel | dark red elite creature with tattered ragged body, muscle fibers, menacing, flat design, game sprite, 512x512 |
| enemy_elite_toxin.png | elite_toxin | 38 | Toxin: dark green sac + poison droplets | dark green toxin sac creature, dripping poison, bubbles, slimy, flat design, game sprite, 512x512 |
| enemy_elite_mirror.png | elite_mirror | 30 | Mirror: translucent mirror surface + afterimage | translucent mirror-shard creature, fractured glass, ghostly afterimages, flat design, game sprite, 512x512 |
| enemy_elite_fortress.png | elite_fortress | 50 | Fortress: bronze armor + rivets | bronze armored fortress creature, riveted plate armor, slow sturdy, flat design, game sprite, 512x512 |

### 3.1 Elite Exclusive Mechanic Visuals
- Tearer: every 4s tear wave -> companion fx_tear_wave.png (256x64 red fan-shaped shockwave).
- Toxin: poison debuff -> overlay fx_poison_cloud.png (green poison fog 128x128) on player.
- Mirror: summon clones -> use existing enemy_decoy texture (reuse).
- Fortress: gnaw slow -> reuse existing GnawRing (code already implements).

---

## 4. P0 - Chapter Boss (3)

| Filename | boss_id | Chapter | Style | AI Prompt |
|---|---|---|---|---|
| enemy_boss_ch1.png | boss_ch1 | 1 Swamp | Gold Armor Beast / Swamp Devourer: corrupted giant maw | corrupted devourer boss, swamp-moss crust, gaping maw, 3 phases, flat design, game sprite, 512x512 |
| enemy_boss_v2_void.png | boss_v2_void | 2 Void | Void Devourer: geometric black hole | geometric void devourer, black-hole core, purple void, flat design, game sprite, 512x512 |
| enemy_boss_v3_abyss.png | boss_v3_abyss | 3 Abyss | Abyss Maw: tentacles + giant jaws | abyssal maw boss, tentacles, huge jaws, deep-sea, flat design, game sprite, 512x512 |

### 4.1 Boss 3-Phase Visuals (only-wolf style)
- Phase 2 Weakness Exposed: overlay fx_boss_weakpoint.png (glowing weak point ring 128x128, code _process_boss drives when boss_weakness_open).
- Phase 3 Enraged: fx_boss_enraged.png (red aura 256x256).
- Kill Window: fx_kill_window.png (gold ring 64x64, shown when boss_kill_window>0).

---

## 5. P0 - Chapter Backgrounds x3 + Environment FX

| Filename | Chapter | Style | AI Prompt |
|---|---|---|---|
| bg_ch1_swamp.png | 1 Swamp | Dark green toxic swamp + distant fog | dark swamp battlefield, toxic green mist, muck, fog, game background, 720x1280, no text |
| bg_ch2_gold.png | 2 Gold Mine | Orange gold mine + lava cracks | molten gold mine cave, lava cracks, glowing orange, game background, 720x1280, no text |
| bg_ch3_void.png | 3 Void Corridor | Purple black void + floating rocks | void corridor, floating dark rocks, purple void, game background, 720x1280, no text |

### 5.1 Environment Mechanic Visuals (3.0 Style Difference Table)
| Filename | Purpose | Description |
|---|---|---|
| fx_env_poison_mist.png | Swamp poison fog (every 30s 1 piece -5HP) | Green fog blob 256x256, for GPUParticles2D |
| fx_env_lava_patch.png | Gold Mine lava (ground burn residue) | Orange burn-on-ground 128x128 |
| fx_env_void_veil.png | Void Corridor (vision -30%) | Full-screen purple dark veil 720x1280, alpha 0.4 |

> Switching Rule: main_game_controller loads the corresponding bg_ch*.png and overlays fx_env_*.png when GameManager.chapter changes.

---

## 6. P0 - Routed Level UI (Node Icons + Panels)

### 6.1 Node Icons x6 (replace route_ui.gd NODE_DISPLAY emoji)
| Filename | node_type | Name | Style |
|---|---|---|---|
| ui_node_normal.png | 0 | Normal Wave | Crossed swords, green |
| ui_node_elite.png | 1 | Elite | Skull + crown, red |
| ui_node_camp.png | 2 | Camp | Tent campfire, blue |
| ui_node_shop.png | 3 | Shop | Money bag / stall, gold |
| ui_node_event.png | 4 | Event | Question mark bubble, purple |
| ui_node_boss.png | 5 | Chapter Boss | Crown + fangs, gold |

> 64x64, thick 4px outline, dark rounded square bg; route_ui._build_cards icon Label changed to TextureRect.

### 6.2 Camp Three-One-Choose Cards (3.1 Floor 3/7 Camp Node)
| Filename | Option | Description |
|---|---|---|
| ui_camp_heal.png | Rest | HP +50%, red heart potion |
| ui_camp_evolve.png | Evolve | Free draw 1 evolution card, up arrow + DNA |
| ui_camp_purify.png | Purify | Remove 1 card + 2 energy, broom / purification light |

### 6.3 Shop Panel (3.0 Shop Node)
| Filename | Purpose |
|---|---|
| ui_shop_panel.png | Shop background panel 720x800, dark shelf style |
| ui_shop_item.png | Item slot 120x120 (inventory card) |
| ui_shop_refresh.png | Refresh button 64x64 (loop arrows) |

### 6.4 Event Panel x6 (3.0 Event Node Two-Choose-One)
| Filename | Event | Description |
|---|---|---|
| ui_event_hungry_egg.png | Hungry Egg | Large egg + crack |
| ui_event_ruin.png | Ancient Ruin | Broken stone tablet + runes |
| ui_event_merchant.png | Mystery Merchant | Cloaked merchant + cargo box |
| ui_event_vortex.png | Energy Vortex | Blue energy vortex |
| ui_event_orb.png | Cursed Orb | Purple-black orb + runes |
| ui_event_rift.png | Time Rift | Ice-blue time rift |

> Event panel reuses ui_upgrade_panel structure, each event has 2 option cards (A/B).

---

## 7. P1 - Style New Monsters x4 (3.0 Style Difference Table)

| Filename | Chapter | Style | AI Prompt |
|---|---|---|---|
| enemy_toxin_pod.png | Swamp | Toxin Pod: dark green small sac | small dark-green toxin pod, dripping, flat design, game sprite, 256x256 |
| enemy_split_body.png | Swamp | Split Body: purple double ball (small) | purple double-ball small creature, flat design, game sprite, 256x256 |
| enemy_phase_slash.png | Gold Mine | Phase Slash: orange-gold blade shadow | orange-gold phase slash blade ghost, fast, flat design, game sprite, 256x256 |
| enemy_feint.png | Void | Feint: purple phantom decoy | purple feint phantom, trickster, flat design, game sprite, 256x256 |

> Plan A (P0 landing): same skeleton with color change + modulate; Plan B (P1): independent image. First produce independent 4, integrate into enemy_base textures.

---

## 8. P1 - Cards (v1.1 Card Pool + Exclusive Relic)

### 8.1 Evolution Cards 55 (11 Skills x 5 Materials)
- Plan: procedural combination. Motif 11 (skill) x material color 5 (metal/wood/water/fire/earth) = auto-combine 55, save 90% work.
- Skill motif 11 hand-drawn: icon_skill_<name>.png (devour wave/spiral devour/tracking devour/black hole pull/phase cut/shadow clone/shadow bind/mirror domain/time freeze/group pull/devour aura).
- Material color 5 sets: icon_mat_metal/wood/water/fire/earth.png (small badge 32x32).
- Combination: card rendering overlays badge, filename icon_evo_<skill>_<mat>.png (do not actually generate 55 files, UI composites).

### 8.2 Relic Cards 38 (5 Rarity Tiers)
- Color by rarity: common gray / rare blue / epic purple / legendary gold / artifact rainbow.
- Icon: generic relic rune motif + rarity frame, 5 frames + few exclusive motifs.

### 8.3 Exclusive Relic 3 (Chapter Artifacts, 3.3 Black Myth)
| Filename | Chapter | Description |
|---|---|---|
| relic_toxin_core.png | Swamp | Toxin Core: dark green gem + poison drop |
| relic_gold_shard.png | Gold Mine | Gold Shard: gold armor piece + molten pattern |
| relic_void_shard.png | Void | Void Shard: purple-black crystal + geometry |

### 8.4 Fusion/Inlay Products 10
- Reuse motif overlay + material highlight, filename icon_fusion_<pair>.png, P2 fill in.

---

## 9. P1 - HUD Supplement

| Filename | Purpose | Description |
|---|---|---|
| ui_alarm.png | Alert indicator (3.5) | 3-level alert lamp (red/yellow/green), x1/x2/x3 |
| ui_chapter_banner.png | Chapter title banner | Flash when entering new chapter (900x200) |
| ui_floor_banner.png | Floor clear banner base | Current floor_banner uses code rendering, companion 720x120 base |
| ui_timer.png | Time limit countdown (3.1) | Top small clock 64x64 + number |

---

## 10. P2 - Polishing

- Route branch card 2 (safe line/risk line, 3.2 floor 11): ui_route_safe.png / ui_route_risk.png.
- Exclusive relic portrait 3 (enlarged 256x256, for settlement display).
- Main menu background bg_menu.png + title Logo (v1.0 list leftover, not in assets).
- Font finalization (Source Han Sans / Zcool KuaiLe, free commercial use).

---

## 11. Priority and Batches (Continuing Previous Conclusion)

### Batch P0 (First make placeholder color blocks disappear + stand up three chapters)
- [ ] 4 elite textures + integrate into enemy_base.textures
- [ ] 3 chapter boss textures + integrate into enemy_base.textures
- [ ] 3 chapter backgrounds + 3 environment FX + main_game_controller switch logic
- [ ] 6 node icons + route_ui change to TextureRect

### Batch P1 (Mechanism complete)
- [ ] Style new monsters 4 + exclusive relics 3
- [ ] Camp/shop/event panels 11
- [ ] Card icons (motif 11 + material 5 combo + relic 38 + exclusive 3)
- [ ] HUD supplement 4 (alert/chapter banner/floor clear/timer)

### Batch P2 (Polish)
- [ ] Route branch card 2 + fusion products 10 + exclusive relic portrait 3
- [ ] bg_menu + Logo + font finalization

---

## 12. Asset Directory Structure (New Part)

assets/
- sprites/
- - enemies/
- - - enemy_elite_tearer.png      # P0
- - - enemy_elite_toxin.png       # P0
- - - enemy_elite_mirror.png      # P0
- - - enemy_elite_fortress.png    # P0
- - - enemy_boss_ch1.png          # P0
- - - enemy_boss_v2_void.png      # P0
- - - enemy_boss_v3_abyss.png     # P0
- - - enemy_toxin_pod.png         # P1
- - - enemy_split_body.png        # P1
- - - enemy_phase_slash.png       # P1
- - - enemy_feint.png             # P1
- - environment/                  # new dir
- - - fx_env_poison_mist.png      # P0
- - - fx_env_lava_patch.png       # P0
- - - fx_env_void_veil.png        # P0
- - skills/
- - - fx_tear_wave.png            # P0 elite tear wave
- - - fx_poison_cloud.png         # P0 poison debuff
- - - fx_boss_weakpoint.png       # P0 boss weakness
- - - fx_boss_enraged.png         # P0 boss enraged
- - - fx_kill_window.png          # P0 kill window
- backgrounds/
- - bg_ch1_swamp.png                # P0
- - bg_ch2_gold.png                 # P0
- - bg_ch3_void.png                 # P0
- ui/
- - nodes/                          # new dir
- - - ui_node_normal.png          # P0
- - - ui_node_elite.png           # P0
- - - ui_node_camp.png            # P0
- - - ui_node_shop.png            # P0
- - - ui_node_event.png           # P0
- - - ui_node_boss.png            # P0
- - camp/                           # new dir
- - - ui_camp_heal.png
- - - ui_camp_evolve.png
- - - ui_camp_purify.png
- - shop/                           # new dir
- - - ui_shop_panel.png
- - - ui_shop_item.png
- - - ui_shop_refresh.png
- - event/                          # new dir
- - - ui_event_hungry_egg.png
- - - ui_event_ruin.png
- - - ui_event_merchant.png
- - - ui_event_vortex.png
- - - ui_event_orb.png
- - - ui_event_rift.png
- - relics/                         # new dir
- - - relic_toxin_core.png
- - - relic_gold_shard.png
- - - relic_void_shard.png
- - cards/icons/                    # P1
- - hud/                            # P1
- - - ui_alarm.png
- - - ui_chapter_banner.png
- - - ui_floor_banner.png
- - - ui_timer.png

---

*Document End*