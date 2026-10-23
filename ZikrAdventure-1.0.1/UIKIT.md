# UI kit Zikr Adventure — CSS → SwiftUI

Источник истины для 1.2.0: CSS-переменные `:root` и тёмные переопределения в `ZikrAdventure/Web/index.html`, плюс таблица токенов на странице Confluence [UI kit — правила](https://zikr-app.atlassian.net/wiki/spaces/SD/pages/2850835). Экраны пока не перенесены; этот слой нужен задачам ZKR-50 и далее.

Код: `ZikrAdventure/UI/`. Цвета — Asset Catalog. Версия приложения **1.1.1 / build 3** не менялась.

## Цвета

Существующие наборы **не дублируются**: `--bg` → `LaunchBackground`, `--accent` → `AccentColor`, `--surface` / `--divider` / `--text2` — переименованные наборы `Surface`, `Divider`, `Text2` (раньше `TabBarSurface` / `TabBarDivider` / `TabBarUnselected`).

| CSS | Light | Dark | Asset | SwiftUI |
| --- | --- | --- | --- | --- |
| `--bg` | #E6E0D4 | #0F1522 | `LaunchBackground` | `Theme.Color.bg` |
| `--bg2` | #DCD3C2 | #141C2C | `Bg2` | `Theme.Color.bgSubtle` |
| `--surface` | #F6F2EA | #1A2334 | `Surface` | `Theme.Color.surface` |
| `--surface2` | #FFFFFF | #222C41 | `Surface2` | `Theme.Color.surfaceRaised` |
| `--text` | #1C2333 | #EFE8DA | `Text` | `Theme.Color.text` |
| `--text2` | #5A5F6B | #AFA99D | `Text2` | `Theme.Color.textSecondary` |
| `--disabled` | #A6A298 | #5C5A56 | `Disabled` | `Theme.Color.textDisabled` |
| `--navy` | #1B2A44 | #2C3F63 | `Navy` | `Theme.Color.primary` |
| `--accent` | #8E6E2E | #CBA863 | `AccentColor` | `Theme.Color.accent` |
| `--accentSoft` | #E8DBBE | #3A3322 | `AccentSoft` | `Theme.Color.accentSoft` |
| `--positive` | #2F6B4F | #6FBF94 | `Positive` | `Theme.Color.success` |
| `--warning` | #96550F | #E0A458 | `Warning` | `Theme.Color.warning` |
| `--divider` | #CFC5B1 | #2C3548 | `Divider` | `Theme.Color.divider` |
| `--locked` | #8B8A86 | #6D6C69 | `Locked` | `Theme.Color.locked` |
| `--sea` | #BCD0D3 | #0F2230 | `Sea` | `Theme.Color.mapSea` |
| `--land` | #E5D3AE | #3A3326 | `Land` | `Theme.Color.mapLand` |
| `--country` | #D9BD88 | #4A3F2C | `Country` | `Theme.Color.mapCountry` |
| `--border` | #A88A55 | #A88A55 | `Border` | `Theme.Color.border` / `mapBorder` |
| `--mount` | #9E7F5C | #8E7355 | `Mount` | `Theme.Color.mapMount` |
| `--shadow` | rgba(20,24,36,.10) | rgba(0,0,0,.35) | `Shadow` | `Theme.Color.shadow` / `Theme.Shadow.card` |

Цвета из CSS-классов и Confluence, которых нет в `:root`, но они используются компонентами:

| Источник | Light | Dark | Asset | SwiftUI |
| --- | --- | --- | --- | --- |
| `.btn.danger` / color.danger | #B3261E | #B3261E | `Danger` | `Theme.Color.danger` |
| `.btn.primary` / color.gold | #C2A05A | #C2A05A | `Gold` | `Theme.Color.gold` |
| `.zikr-btn` / color.gold.light | #E3C274 | #E3C274 | `GoldLight` | `Theme.Color.goldLight` |
| текст на primary | #FFFFFF | #FFFFFF | `TextOnPrimary` | `Theme.Color.textOnPrimary` |
| `.scrim` / `.dialog` | #0A0E16 45% | #000 55% | `Scrim` | `Theme.Color.scrim` |
| `.banner` shadow | rgba(0,0,0,.20) | то же | `OverlayShadow` | `Theme.Shadow.overlay` |
| `.ctrls .icon-btn` | rgba(0,0,0,.15) | то же | `FloatingShadow` | `Theme.Shadow.floating` |
| `.zikr-btn` shadow | rgba(15,21,34,.35) | то же | `ZikrButtonShadow` | `Theme.Shadow.zikrButton` |
| `.toggle span::after` | rgba(0,0,0,.30) | то же | `KnobShadow` | `Theme.Shadow.knob` |

`Theme.Opacity.primaryBorder` = `#C2A05A88` у `.btn.primary`.

## Типографика

Шрифты масштабируются через `UIFontMetrics` (Dynamic Type). Serif — системный New York (CSS `ui-serif` / `"New York"`); арабский — Geeza Pro с запасным serif.

| CSS | Размер / начертание | `Theme.Typo` |
| --- | --- | --- |
| `body` 17 / 1.45 | regular | `.body` |
| `.btn` font-weight 700 | 17 bold | `.bodyStrong` |
| `.topbar h1` 20 serif 600 | | `.headingMD` |
| `.group-h` / `.ch-title` 19 serif 600 | | `.headingSM` |
| `.section-title` 15 serif 600 `--text2` | | `.sectionTitle` |
| `.counter .num` clamp(54px, 17vw, 72px) serif 600 | | `.displayCounter` + `Theme.Size.clampedCounter(width:)` |
| `.counter .cap` / `.foot` 14 `--text2` | | `.footnote` |
| `.small` 15 | | `.callout` / `.calloutMedium` |
| `.lang` 17 medium (наследует body) | | `.chip` |
| `.xs` / `.kicker` ~13.5 | | `.kicker` / `.caption` |
| `.tab` 12 | regular / bold selected | `.tab` / `.tabSelected` |
| `.translit` 21 italic serif | | `.translit` |
| `.arabic` clamp 38–50 | | `.arabic` |

Применение: `.themeFont(.body)`.

## Отступы, радиусы, размеры, тени

| CSS / Figma | SwiftUI |
| --- | --- |
| 4 / 8 / 12 / 16 / 20 / 24 / 32 | `Theme.Space.s1…s8` |
| padding 10 / 14 | `Theme.Space.buttonY` / `controlX` |
| `.group-h` margin-top 22 | `Theme.Space.groupHeaderTop` |
| radius 8 / 12 / 14 / 16 / 18 / 22 / 999 | `Theme.Radius.sm…pill` + `list` + `button` + `card` + `sheet` |
| icon 16 / 20 / 22 / 23 / 24 / 28 | `Theme.Size.iconSm…iconXl` + `iconTab` + `iconList` |
| touch 44, button 48, row 48 | `Theme.Size.touch` / `button` / `row` |
| `.toggle` 51×31, knob 27 | `Theme.Size.toggleWidth/Height/Knob` |
| `.bar` height 8 | `Theme.Size.progress` |
| hairline 1 | `Theme.Size.hairline` |
| native tab bar 49 + 4 | `Theme.Size.tabBar` / `tabBarTopPadding` |
| `--shadow` 0 6px 20px | `Theme.Shadow.card` |

## Классы → компоненты

| CSS | Компонент | Заметки |
| --- | --- | --- |
| `.btn.primary` | `AppButton(kind: .primary)` | navy, белый текст, золотая обводка 88 |
| `.btn` | `AppButton(kind: .secondary)` | surface, `--text`, `--divider` |
| `.btn.danger` | `AppButton(kind: .destructive)` | `--danger`, surface |
| `.card` | `AppCard` | radius 18, shadow.card |
| `.list` | `AppList` | radius 16 |
| `.li` | `AppListRow` | icon / link / destructive / value (17 pt, как body) / plain |
| `.switch` + `.toggle` | `AppToggleRow` / `AppToggle` | native `Toggle` + ToggleStyle; вся строка — switch |
| `.lang` / `.lang.on` | `AppChip` / `AppChipGroup` | 17 pt medium, `Layout` flex-wrap |
| `.section-title` / `.group-h` | `AppSectionHeader` | `.sectionTitle` / `.group` |
| `.foot` | `AppFootnote` | |
| `a` / `.link` | `AppLink` | `--accent`, без подчёркивания |
| `.icon-btn` | `AppIconButton` | 44×44, иконка 20 |
| `.bar` | `AppProgressBar` | |
| `.counter` | `AppCounterDisplay` | font-size = clamp(54, 17% ширины, 72) |
| `.tabbar` / `.tab` | `NativeTabBar` | токены; Dynamic Type ограничен `.large` (~12 pt) |

Не вынесены в общий кит (экранно-специфичны, появятся с миграцией экранов): `.zikr-btn`, `.banner`, `.dialog`, `.sheet`, `.timeline`, `.lvl-badge`, `.auth-provider`.

## Preview и DEBUG-галерея

У каждого компонента есть `PreviewProvider` в светлой и тёмной теме (без макроса `#Preview`, iOS 16).

`UIKitGallery` — каталог всех компонентов. Файл обёрнут в `#if DEBUG`. В Debug открывается долгим нажатием (~1.2 с) на вкладку; выбор вкладки при этом не меняется. В Release жест и экран отсутствуют, UI релиза не меняется.

## Ограничения

- Сборка и визуальная сверка — на Mac / iPhone (здесь нет Xcode).
- `index.html` и данные уровней не менялись.
- Экраны Настройки / Инфо / Зикр / Путь Сиры / Карта по-прежнему web view (ZKR-50 и далее).
