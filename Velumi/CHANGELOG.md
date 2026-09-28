# Changelog

All notable changes to Velumi are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-09-28

First public release.

### Added

- **Windows:** dragging, resizing with a corner grip, minimize (also by double-clicking the title), maximize, restore and close. Also focus with an accent title bar, z-ordering, centering, per-window and global scale, auto-fit on small screens, min/max size, toggle keys, menu bars and status bars.
- **Tabs:** as a sidebar or a top tab bar, with multi-column pages. Tab-less tool windows via `Window:AddGroup`.
- **Containers:** groups (optionally collapsible), collapsing-header and tree sections, scrolling child regions (`BeginChild`/`EndChild`, auto-scroll), `SameLine`, `Indent`, `BeginDisabled`, `AddSpacing`, `Clear` and `Rebuild`.
- **Elements:** Button, Checkbox, Toggle, Slider, Dropdown, MultiDropdown, Input, Keybind, ColorPicker, Label, Paragraph, Separator, ProgressBar and Plot, all sharing one element API.
- **Overlays:** tooltips, context menus with sub menus, notifications (Info/Success/Warning/Error), modal dialogs with container bodies, and `Velumi:Confirm`.
- **Theme engine:** Dark, Light, Midnight, Gray and Classic themes, derived palettes, live switching, custom themes via `RegisterTheme`.
- **Configuration:** automatic and explicit flags, `GetConfig`/`LoadConfig`, JSON export/import, reset, `Bind` tables, a live `Values` table and a `ConfigChanged` signal.
- **Extensibility:** `Velumi.Element.extend` and `Velumi:RegisterElement` for custom elements.
- **Types:** Luau types for every option and object.
- **Showcase:** a demo window with Main, Controls, Layout, Themes, Configuration and Debug tabs.
- **Tests:** a headless test suite (Lune) with a strict engine mock and connection/instance leak checks.
