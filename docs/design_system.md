# SmartSwitch Design System

This document specifies the design tokens, component library, motion standards, and accessibility guidelines for the SmartSwitch application (Blueprint §4.1–§4.5).

---

## 1. Design Tokens

### 1.1 Spacing & Grid (8 pt System)
All padding, margins, and layout gaps conform to an 8 pt grid:
- `Spacing.xs`: $4\text{ pt}$ (micro padding, icon spacing)
- `Spacing.sm`: $8\text{ pt}$ (chip padding, compact gaps)
- `Spacing.md`: $16\text{ pt}$ (standard card padding, screen margin)
- `Spacing.lg`: $24\text{ pt}$ (section separation)
- `Spacing.xl`: $32\text{ pt}$ (major screen headers)
- `Spacing.xxl`: $48\text{ pt}$ (touch target minimum dimension)
- `Spacing.screenMargin`: $16\text{ pt}$

### 1.2 Corner Radii
- `Radii.sm`: $8\text{ pt}$ (badges, sub-elements)
- `Radii.button`: $12\text{ pt}$ (action buttons)
- `Radii.card`: $16\text{ pt}$ (standard cards, device cards)
- `Radii.cardLg`: $20\text{ pt}$ (bottom sheets, modals, dialogs)
- `Radii.toggle`: $999\text{ pt}$ (fully rounded pills, toggles, chips)

### 1.3 Color Palette (Light & Dark Mode)
No hard-coded color values are permitted in presentation code; all colors must reference theme tokens:

| Token | Light Theme | Dark Theme | Purpose |
|-------|-------------|------------|---------|
| `primary / accent` | `#FF9F0A` | `#FF9F0A` | Active "ON" state, amber glow |
| `surface` | `#F8F8F8` | `#1C1C1E` | Screen background surfaces |
| `surfaceCard` | `#FFFFFF` | `#2C2C2E` | Device cards, sheets |
| `onSurface` | `#1C1C1E` | `#F2F2F7` | Primary text and icons |
| `onSurfaceVariant` | `#6E6E73` | `#98989F` | Secondary captions, subheadings |
| `border` | `#E5E5EA` | `#38383A` | Subtle card outlines |
| `offline` | `#AEAEB2` | `#8E8E93` | Offline indicator, disabled toggles |
| `error` | `#FF3B30` | `#FF453A` | Errors, critical network health |
| `rssiStrong` | `#34C759` | `#30D158` | Signal $> -60\text{ dBm}$ (Green) |
| `rssiFair` | `#FF9F0A` | `#FF9F0A` | Signal $-60\text{ dBm}$ to $-75\text{ dBm}$ (Amber) |
| `rssiWeak` | `#FF3B30` | `#FF453A` | Signal $< -75\text{ dBm}$ (Red) |

### 1.4 Typography
- Family: `Inter`
- Scales dynamically with system font sizing (`MediaQuery.textScalerOf(context)`).
- Hierarchy:
  - `displayMedium`: 28 pt, Bold (Home screen title)
  - `headlineSmall`: 22 pt, SemiBold (Modal & Sheet headers)
  - `titleLarge`: 20 pt, SemiBold (Card and screen titles)
  - `bodyLarge`: 16 pt, Regular (Primary list items, inputs)
  - `bodyMedium`: 14 pt, Regular (Secondary descriptions)
  - `labelSmall`: 11–12 pt, SemiBold (Status badges, chips, gang tags)

---

## 2. Motion & Feedback

- **Toggle Switch**: 180 ms ease-out animation (`Durations.toggle`).
- **Card Press**: 120 ms scale transition to 0.97 on press down (`Durations.cardPress`).
- **Glow & Shimmer**: Amber soft box-shadow glow when energized; 1200 ms continuous gradient shimmer for skeleton loaders.
- **Haptic Feedback**:
  - `AppHaptics.light()`: Fires instantly on toggle switch taps.
  - `AppHaptics.medium()`: Fires on long-press card quick actions.
  - `AppHaptics.error()`: Fires on network failure / rollback.
- **Reduce Motion**: All animations check `MediaQuery.of(context).disableAnimations` and gracefully degrade to static transitions when enabled.

---

## 3. Core Component Catalog

1. **`DeviceCard`** (`lib/features/home/widgets/device_card.dart`):
   - States: `on` (amber accent glow), `off` (neutral surface), `pending` (same-frame feedback with thin spinner ring), `offline` (greyed, disabled toggle, tap opens help sheet), `error` (shake animation + retry snackbar).
   - Tap toggle = instant optimistic toggle.
   - Tap card body = navigates to Device Control.
   - Long-press = opens Quick Actions modal (Rename, Move Room, Favourite).
   - Running countdown badge when active.

2. **`PowerButton`** (`lib/features/device_control/widgets/power_button.dart`):
   - Large circular toggle button with smooth glow animation, centered in Device Control screen.
   - Touch target $\ge 80\text{ dp}$.

3. **`RssiBar`** (`lib/core/widgets/rssi_bar.dart`):
   - 4-bar signal level indicator with semantic signal descriptions.

4. **`TopologyView`** (`lib/features/mesh_diag/widgets/topology_view.dart`):
   - CustomPainter drawing tree structure: Root node with crown badge at top, sub-nodes partitioned by layer below.
   - Links styled and coloured by parent RSSI. Interactive node tap targets.

5. **`StatusChip`** (`lib/core/widgets/status_chip.dart`):
   - Micro status pills for Wi-Fi, Cloud connection, countdown timers, and "Synced to device" badges.

6. **`SkeletonCard`** (`lib/core/widgets/skeleton_card.dart`):
   - Shimmer placeholder card for smooth loading states.

---

## 4. Accessibility & Semantics

- **Minimum Touch Target**: Every interactive element has an active hit area $\ge 48\times 48\text{ dp}$.
- **Screen Reader Semantics**:
  - State is never conveyed by color alone.
  - Every toggle announces full state: `"Hall light, on, switch"` or `"Balcony light, offline, switch disabled"`.
  - Signal bars announce numeric dBm and category: `"Signal strong, -54 dBm"`.
- **Dynamic Text**: Text components use flexible layouts (`MainAxisSize.min`, `Flexible`, `TextOverflow.ellipsis`) so layout does not break under enlarged system font scales.
