# Expense Tracker Design System & UI Specifications

> **Default Mode:** Light Mode (Clean Slate & Vibrant Financial)  
> **Toggle Mode:** Dark Mode (Deep Slate & Neon Vault)  
> **Source:** Stitch MCP UI System  
> **Target Platform:** Android (Mobile-First)

---

## 1. Brand & Theme Strategy

The application adopts a **Dual-Theme Design System** where **Light Mode is the default experience**, delivering a crisp, high-clarity financial dashboard, while **Dark Mode** provides an immersive, high-contrast night theme.

Users can toggle seamlessly between Light and Dark modes via a Theme Mode Switcher in the top app bar or settings, with the preference persisted locally via Hive and managed reactively with Riverpod.

- **Light Mode (Default):** Clean paper-white surfaces (`#FFFFFF`), subtle soft grey background (`#F8F9FA`), deep slate typography (`#0F172A`), and vivid emerald (`#059669`) / rose (`#E11D48`) financial indicators.
- **Dark Mode:** Deep slate canvas (`#121826` / `#131314`), elevated glassmorphic containers (`#201F21`), glowing neon accents, and high-contrast pastel emerald/coral data points.
- **Privacy & Local-First:** Privacy badge ("Local Vault • Encrypted") rendered with high visibility in both modes.

---

## 2. Dual-Theme Color Token Matrix

| Token Name | Light Mode (Default) | Dark Mode (Toggleable) | Role / Usage |
| :--- | :--- | :--- | :--- |
| `background` | `#F8F9FA` | `#131314` | Primary scaffold background |
| `surface` | `#FFFFFF` | `#1E222B` | Primary card and sheet surface |
| `surface_container` | `#F1F5F9` | `#201F21` | Recessed containers, inputs, list headers |
| `surface_container_high` | `#FFFFFF` (Shadowed) | `#2A2A2B` | Elevated widgets, modals |
| `surface_glass` | `rgba(255, 255, 255, 0.85)` | `rgba(255, 255, 255, 0.05)` | Translucent blurred cards |
| `primary` | `#0F172A` | `#C1C6D9` | Dominant text, high-emphasis icons |
| `primary_container` | `#E2E8F0` | `#121826` | Subtle primary container |
| `income` (Secondary) | `#059669` | `#10B981` / `#4EDEA3` | Positive cash flow, deposits, growth |
| `income_container` | `#ECFDF5` | `#003824` | Background tint for income chips |
| `expense` (Tertiary) | `#E11D48` | `#F43F5E` / `#FFB2B7` | Expenses, debits, spending alerts |
| `expense_container` | `#FFF1F2` | `#3A000B` | Background tint for expense chips |
| `accent_violet` | `#7C3AED` | `#8B5CF6` | Primary action buttons, FAB gradient |
| `accent_cyan` | `#0284C7` | `#00D2FF` | Chart segments, focus rings, badges |
| `outline` | `#E2E8F0` | `#45464C` | 1px border strokes and dividers |
| `outline_focus` | `#7C3AED` | `#00D2FF` | Input active focus outline |
| `on_background` | `#0F172A` | `#E5E2E3` | Main body & title text |
| `on_surface_variant` | `#64748B` | `#C6C6CC` | Secondary text, timestamps, labels |

---

## 3. Typography Scale

Clean sans-serif **Inter** for readable content and **Geist** for technical/numeric figures.

| Token | Family | Size | Weight | Line Height | Letter Spacing |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `headline-lg` | Inter | 32px | 700 (Bold) | 40px | -0.02em |
| `headline-lg-mobile` | Inter | 28px | 700 (Bold) | 36px | normal |
| `headline-md` | Inter | 24px | 600 (SemiBold) | 32px | -0.01em |
| `headline-sm` | Inter | 20px | 600 (SemiBold) | 28px | normal |
| `body-lg` | Inter | 16px | 400 (Regular) | 24px | normal |
| `body-md` | Inter | 14px | 400 (Regular) | 20px | normal |
| `label-md` | Geist | 12px | 500 (Medium) | 16px | 0.05em |
| `numeric-lg` | Geist | 28px | 700 (Bold) | 32px | normal |
| `numeric-md` | Geist | 18px | 600 (SemiBold) | 24px | normal |

---

## 4. Spacing & Shape Tokens

### Spacing & Grid
- **Horizontal Screen Margin:** `20px`
- **Card Padding:** `16px` to `20px`
- **Section / Stack Gap:** `16px`
- **Item / List Gap:** `12px`
- **Base Grid Unit:** `8px`

### Corner Radii
- `rounded-sm`: `6px` (Status badges & chips)
- `rounded-md`: `12px` (Buttons, form input fields, squircle icon containers)
- `rounded-lg`: `16px` (Charts, summary cards)
- `rounded-xl`: `20px` (Main total balance card, modal bottom sheets)
- `rounded-full`: `9999px` (Pill badges, Circular FAB)

---

## 5. Component Styling in Light & Dark Mode

### 1. Top Bar & Theme Toggle
- **Branding:** "Vault" header with shield icon.
- **Theme Toggle Action:** Animated `IconButton` (Sun icon in Dark Mode, Moon icon in Light Mode) at top-right for instant theme switching.
- **Privacy Pill:** "Offline Mode • Encrypted" badge next to title.

### 2. Total Balance Card
- **Light Mode:** Crisp gradient from `#FFFFFF` to `#F1F5F9` with a subtle `1px` border (`#E2E8F0`) and soft diffuse drop shadow (`box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06)`).
- **Dark Mode:** Slate gradient (`#1E2638` to `#131824`) with `1px` border (`#2E3A52`) and glow shadow.
- **Content:** Large balance figure in Geist bold (`$12,450.80`), mini trend indicator (+4.2% this month).

### 3. Income & Expense Split Cards
- **Income Card:**
  - *Light Mode:* White background, Emerald text (`#059669`), light green icon container (`#ECFDF5`).
  - *Dark Mode:* Deep container (`#1A2421`), Emerald text (`#10B981`), dark green icon container (`#003824`).
- **Expense Card:**
  - *Light Mode:* White background, Coral Rose text (`#E11D48`), light red icon container (`#FFF1F2`).
  - *Dark Mode:* Deep container (`#251B20`), Coral text (`#F43F5E`), dark rose icon container (`#3A000B`).

### 4. Category Spending Breakdown Chart
- Interactive visual chart (Donut / Rounded Bar chart) with custom colors:
  - Food & Dining: `#F59E0B` (Amber)
  - Transport: `#0284C7` / `#00D2FF` (Cyan)
  - Entertainment: `#7C3AED` / `#8B5CF6` (Violet)
  - Shopping: `#EC4899` (Pink)
  - Utilities: `#10B981` (Emerald)

### 5. Transaction List & Category Squircles
- Grouped by date (e.g. "Today", "Yesterday").
- Icon housed in a `12px` rounded squircle with category tint.
- Right amount formatted in Geist with dynamic coloring (`+$...` in Green, `-$...` in Red/Dark text).

### 6. Floating Action Button (FAB)
- Vibrant Electric Violet gradient (`#7C3AED` to `#6D28D9` in Light Mode, `#8B5CF6` to `#7C3AED` in Dark Mode).
- Soft drop shadow in Light Mode, vibrant glow in Dark Mode.

### 7. Form Inputs & Modals
- **Light Mode:** Background `#F8F9FA`, border `#E2E8F0`, focus ring `#7C3AED`.
- **Dark Mode:** Background `#1B1B1D`, border `#45464C`, focus ring `#00D2FF`.

---

## 6. Riverpod & Hive State Architecture for Theme Mode

- **Storage Key:** `theme_mode` in the Hive settings box (`Box<dynamic> 'settings'`).
- **State Provider:** `StateNotifierProvider<ThemeNotifier, ThemeMode>`
  - Default value: `ThemeMode.light`
  - Allows user toggle to `ThemeMode.dark` or `ThemeMode.system`.
  - Persists instantly to Hive when changed.
