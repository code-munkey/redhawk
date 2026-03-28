# LanternUX Developer Guide

LanternUX is a standalone settings panel framework for World of Warcraft addons. It has **no dependencies** -- any addon can use it by adding a single TOC dependency line.

```toc
## Dependencies: LanternUX
```

The panel features a dark monochrome theme (inspired by Linear), sidebar navigation with sections and collapsible groups, 15 built-in widget types, a description panel for contextual help on hover, widget search with jump-to-widget, and smooth scrolling with widget pooling.

---

## Quick Start

```lua
-- Create a panel (lazy -- no WoW frames are created until Show is called)
local panel = LanternUX:CreatePanel({
    name    = "MyAddonSettings",  -- global frame name (required, used for ESC-to-close)
    title   = "My Addon",
    icon    = "Interface\\Icons\\INV_Misc_Gear_01",  -- optional title bar icon
    version = "1.0",              -- optional, shown in title bar
})

-- Add a page with widgets
panel:AddPage("general", {
    label   = "General",
    widgets = function()
        return {
            { type = "header", text = "Basic Settings" },
            { type = "toggle", label = "Enable Feature",
              get = function() return MyDB.enabled end,
              set = function(val) MyDB.enabled = val end,
              desc = "Toggles the main feature on or off.",
            },
            { type = "range", label = "Speed", min = 1, max = 10, step = 1,
              get = function() return MyDB.speed end,
              set = function(val) MyDB.speed = val end,
            },
            { type = "select", label = "Mode",
              values = { fast = "Fast", slow = "Slow" },
              get = function() return MyDB.mode end,
              set = function(val) MyDB.mode = val end,
            },
        }
    end,
})

-- Toggle the panel (show if hidden, hide if shown)
panel:Toggle()
```

---

## Panel API

### CreatePanel

```lua
local panel = LanternUX:CreatePanel(config)
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Global frame name. Used for `UISpecialFrames` (ESC to close) and `/fstack` visibility. |
| `title` | string | no | Text shown in the title bar. |
| `icon` | string | no | Texture path for the title bar icon (22x22). |
| `version` | string | no | Version string shown dimmed next to the title. |
| `width` | number | no | Panel width in pixels (default 920). |
| `height` | number | no | Panel height in pixels (default 580). |

The panel frame is created lazily on the first `Show()` call.

### AddSection

```lua
panel:AddSection(key, label)
```

Adds a section header to the sidebar. Sections visually group pages. Pages and sidebar groups with a matching `section` field appear under this header.

- `key` (string) -- unique identifier for the section.
- `label` (string) -- display text (rendered uppercase in the sidebar).

### AddPage

```lua
panel:AddPage(key, opts)
```

Adds a page to the panel.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `label` | string | yes | Sidebar button text. |
| `section` | string | no | Section key this page belongs to. |
| `sidebarGroup` | string | no | Sidebar group key (page appears as a child of the group). |
| `widgets` | function | no* | Returns a table of widget data. |
| `frame` | function | no* | `function(parent) return frame end` -- returns a custom frame. |
| `title` | string | no | Content header title shown above widgets. |
| `description` | string | no | Content header subtitle (below title, dimmed). |
| `onShow` | function | no | Called when the page becomes visible. |
| `onHide` | function | no | Called when the panel is hidden while this page is active. Not called on page navigation. |

*Each page must have either `widgets` or `frame` (not both).

### AddSidebarGroup

```lua
panel:AddSidebarGroup(key, opts)
```

Adds a collapsible group to the sidebar. Pages with `sidebarGroup = key` appear as indented children.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `label` | string | yes | Group header text in the sidebar. |
| `section` | string | no | Section key this group belongs to. |

### Show / Hide / Toggle

```lua
panel:Show()    -- build (if first call) and show the panel
panel:Hide()    -- hide the panel, release widgets
panel:Toggle()  -- show if hidden, hide if shown
```

### SelectPage

```lua
panel:SelectPage(key)
```

Navigates to the page with the given key. If the page is inside a collapsed sidebar group, the group is automatically expanded.

### RefreshCurrentPage

```lua
panel:RefreshCurrentPage()
```

Re-renders the currently active widget page. Preserves the scroll position. Use this after changing data that affects widget state (e.g., adding/removing items from a list).

### GetFrame

```lua
local frame = panel:GetFrame()
```

Returns the underlying WoW Frame, or `nil` if the panel hasn't been built yet.

---

## Widget Types

Every widget is a Lua table with a `type` field and type-specific data fields. Widgets are returned from the `widgets` function of a page.

### Interactive Widgets

#### toggle

A toggle switch with a label.

```lua
{ type = "toggle", label = "Enable Feature",
  get = function() return db.enabled end,
  set = function(val) db.enabled = val end,
  desc = "Turn this feature on or off.",
  disabled = function() return not someCondition end,
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Toggle label text. |
| `get` | function | Returns the current boolean value. |
| `set` | function | Called with the new boolean value on click. |
| `desc` | string | Description shown in the right panel on hover. |
| `disabled` | bool/function | Disables the toggle when true. |

#### range

A slider with label, value display, and optional default marker.

```lua
{ type = "range", label = "Opacity", min = 0, max = 1, step = 0.05,
  get = function() return db.opacity end,
  set = function(val) db.opacity = val end,
  isPercent = true,
  default = 0.8,
  desc = "Adjust the opacity level.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Slider label text (left side). |
| `min` | number | Minimum value. |
| `max` | number | Maximum value. |
| `step` | number | Step increment (default 0.01). |
| `bigStep` | number | Step used for track clicks (optional, defaults to `step`). |
| `get` | function | Returns the current numeric value. |
| `set` | function | Called with the new value on change. |
| `isPercent` | boolean | Displays value as percentage (e.g., `80%` instead of `0.8`). |
| `default` | number | Shows a subtle tick mark at this position on the track. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the slider when true. |

#### select

A dropdown menu with a button showing the current selection.

```lua
{ type = "select", label = "Sound",
  values = { alert = "Alert", chime = "Chime", bell = "Bell" },
  sorting = { "alert", "chime", "bell" },
  get = function() return db.sound end,
  set = function(key) db.sound = key end,
  preview = function(key) PlaySound(sounds[key]) end,
  desc = "Choose which sound to play.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Label text (left side). |
| `values` | table/function | `{ key = "Display Name", ... }` -- the available options. Can be a function returning a table. |
| `sorting` | table/function | Ordered list of keys. If omitted, sorted alphabetically by display name. Can be a function. |
| `get` | function | Returns the currently selected key. |
| `set` | function | Called with the selected key on change. |
| `preview` | function | If provided, each dropdown item shows a preview button. Called with the item key. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the dropdown when true. |

#### execute

A button that performs an action. Supports an optional confirmation step.

```lua
{ type = "execute", label = "Reset All Data",
  func = function() wipe(db); ReloadUI() end,
  confirm = "Are you sure? Click again to confirm.",
  desc = "Deletes all saved data and reloads.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Button text. |
| `func` | function | Called when the button is clicked (after confirm, if set). |
| `confirm` | string | If set, the first click shows this text on the button. A second click executes the action. Moving the mouse away cancels. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the button when true. |

#### input

A text input field with a label above.

```lua
{ type = "input", label = "Custom Message",
  get = function() return db.message end,
  set = function(val) db.message = val end,
  desc = "Enter a custom message to display.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Label text above the input field. |
| `get` | function | Returns the current string value. |
| `set` | function | Called with the new string when focus is lost or Enter is pressed. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the input when true. |

The input field supports item link insertion (Shift-click an item in your bags to insert its link).

#### color

A color picker swatch with a label.

```lua
{ type = "color", label = "Warning Color",
  get = function() return db.r, db.g, db.b end,
  set = function(r, g, b) db.r, db.g, db.b = r, g, b end,
  hasAlpha = false,
  desc = "Color used for warning messages.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Label text (left side). |
| `get` | function | Returns `r, g, b[, a]` (0-1 range). |
| `set` | function | Called with `r, g, b[, a]` on change. |
| `hasAlpha` | boolean | Enables the opacity slider in the color picker (default false). |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the swatch when true. |

### Display Widgets

#### header

A section header with bold text and a divider line underneath.

```lua
{ type = "header", text = "Advanced Settings" }
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Header text (bright white). |

Headers automatically get extra top margin when they aren't the first widget on the page.

#### label

Static text. Supports three font sizes.

```lua
{ type = "label", text = "Some informational text.", fontSize = "small", color = { 0.7, 0.7, 0.7, 1 } }
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | The text to display. Supports word wrap. |
| `fontSize` | string | `"small"`, `"medium"` (default), or `"large"`. |
| `color` | table | `{ r, g, b, a }` override (default: theme text color). |

#### description

Identical to `label`. Provided as a semantic alias for paragraph text.

```lua
{ type = "description", text = "This module does X, Y, and Z.", fontSize = "small" }
```

Same fields as `label`.

#### divider

A horizontal separator line.

```lua
{ type = "divider" }
```

No fields required.

#### callout

A highlighted info/notice/warning box with a colored left border.

```lua
{ type = "callout", text = "This feature requires a /reload to take effect.", severity = "notice" }
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Callout message text. Supports word wrap. |
| `severity` | string | `"info"` (blue, default), `"notice"` (amber), or `"warning"` (red). |

### Composite Widgets

#### group

A collapsible container with a chevron arrow. Children are rendered indented inside a card background when expanded.

```lua
{ type = "group", text = "Sound Settings", desc = "Configure audio alerts.",
  expanded = true,
  stateKey = "soundGroup",
  children = {
      { type = "toggle", label = "Enable Sounds", ... },
      { type = "select", label = "Alert Sound", ... },
      { type = "range", label = "Volume", ... },
  },
}
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Group header text. |
| `desc` | string | Description shown on hover. |
| `expanded` | boolean | Initial state (default: collapsed). Overridden by per-session memory. |
| `stateKey` | string | Stable key for expand/collapse memory within the session. Defaults to `text`. Use this when the group text is dynamic to prevent state loss on re-render. |
| `children` | table | Array of widget data tables. Nested groups are not supported (group-type children are silently skipped). |

#### label_action

A text label with an action button on the right side. Supports confirmation.

```lua
{ type = "label_action", text = "Character: Dede-Silvermoon",
  buttonLabel = "Remove",
  func = function() removeCharacter() end,
  confirm = "Confirm?",
  desc = "Remove this character from the group.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Label text (left side). |
| `buttonLabel` | string | Button text (default: `"Action"`). |
| `func` | function | Called on click (after confirm, if set). |
| `confirm` | string | Confirmation text shown on first click. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the button when true. |

#### item_row

Displays a WoW item with its icon, name, and a remove button. Loads item data asynchronously.

```lua
{ type = "item_row", itemID = 4306,
  func = function() removeItem(4306) end,
  buttonLabel = "Remove",
  confirm = "Remove item?",
  desc = "Remove this item from the sell list.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `itemID` | number | The WoW item ID. Icon and name are loaded automatically. |
| `itemName` | string | Optional override for the item name. |
| `buttonLabel` | string | Button text (default: `"Remove"`). |
| `func` | function | Called on click (after confirm, if set). |
| `confirm` | string | Confirmation text shown on first click. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the button when true. |

Hovering the row shows the item's game tooltip.

#### drop_slot

A drag-and-drop slot for WoW items. Shows a plus icon and accepts cursor items.

```lua
{ type = "drop_slot", label = "Add item:",
  onDrop = function(itemID) addItem(itemID) end,
  desc = "Drag an item here to add it to the list.",
}
```

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | Label text (left of the slot). |
| `onDrop` | function | Called with the `itemID` when an item is dropped. |
| `desc` | string | Description shown on hover. |
| `disabled` | bool/function | Disables the slot when true. |

---

## Common Widget Fields

These fields are supported across most interactive widgets:

### disabled

Controls whether the widget is interactive. Accepts a boolean or a function returning a boolean.

```lua
-- Static
{ type = "toggle", label = "Sub-option", ..., disabled = true }

-- Dynamic (re-evaluated on every refresh)
{ type = "toggle", label = "Sub-option", ...,
  disabled = function() return not db.parentEnabled end,
}
```

When `disabled` is a function, it is re-evaluated whenever any widget's value changes. This allows widgets to react to each other (e.g., a sub-option disabling when its parent toggle is off).

### hidden

Controls whether the widget is rendered at all. Accepts a boolean or a function returning a boolean.

```lua
{ type = "range", label = "Advanced Speed", ...,
  hidden = function() return not db.showAdvanced end,
}
```

Hidden widgets are skipped during layout -- they take up no space. Unlike `disabled`, changing `hidden` state requires a page refresh (`panel:RefreshCurrentPage()`) to re-run the `widgets` function.

### desc

A description string shown in the right-side description panel when the user hovers over the widget.

```lua
{ type = "toggle", label = "Auto Repair",
  desc = "Automatically repair gear when visiting a merchant. Hold Shift to skip.",
  ...
}
```

---

## Theme

Access theme colors and fonts via `LanternUX.Theme`:

```lua
local T = LanternUX.Theme
```

### Colors

All colors are `{ r, g, b, a }` tables (0-1 range). Key colors:

| Key | Description |
|-----|-------------|
| `T.bg` | Panel background |
| `T.sidebar` | Sidebar background |
| `T.titleBar` | Title bar background |
| `T.border` | Panel/widget borders |
| `T.text` | Default text |
| `T.textBright` | Bright/white text (headers, selected items) |
| `T.textDim` | Dimmed text (version, breadcrumbs) |
| `T.accent` | Amber accent color (toggles, sliders, selection bars) |
| `T.accentDim` | Dimmed accent |
| `T.hover` | Hover highlight overlay |
| `T.divider` | Divider/separator lines |
| `T.selected` | Selected sidebar item background |
| `T.accentBar` | Sidebar selection accent bar |
| `T.disabled` | Disabled widget color |
| `T.disabledText` | Disabled label text |
| `T.disabledBg` | Disabled input/button background |
| `T.buttonBg` | Button background |
| `T.buttonBorder` | Button border |
| `T.buttonHover` | Button hover background |
| `T.buttonText` | Button text |
| `T.inputBg` | Input field background |
| `T.inputBorder` | Input field border |
| `T.inputFocus` | Input field focus border |
| `T.dangerBg` | Destructive/confirm button background |
| `T.dangerBorder` | Destructive/confirm button border |
| `T.dangerText` | Destructive/confirm text |
| `T.cardBg` | Group children card background |
| `T.cardBorder` | Group children card border |
| `T.calloutInfo` | Callout info color (blue) |
| `T.calloutNotice` | Callout notice color (amber) |
| `T.calloutWarning` | Callout warning color (red) |

Additional internal keys for individual widget parts (toggle track/thumb colors, slider track/thumb colors, dropdown colors, scrollbar colors, etc.) are defined in `Widgets/Core.lua`.

### Fonts

| Key | Description |
|-----|-------------|
| `T.fontHeading` | Heading font (Roboto Regular, 16pt) |
| `T.fontBody` | Body font (Roboto Regular, 12pt) |
| `T.fontSmall` | Small font (Roboto Regular, 10pt) |
| `T.fontBodyBold` | Bold body font (Roboto Bold, 12pt, outline) |
| `T.fontSmallBold` | Bold small font (Roboto Bold, 10pt, outline) |

Font path strings are also available for direct `SetFont()` calls:

| Key | Path |
|-----|------|
| `T.fontPathThin` | Roboto-Thin.ttf |
| `T.fontPathLight` | Roboto-Light.ttf |
| `T.fontPathRegular` | Roboto-Regular.ttf |
| `T.fontPathBold` | Roboto-Bold.ttf |
| `T.fontPathExtraBold` | Roboto-ExtraBold.ttf |

---

## Draggable Frames

`LanternUX.MakeDraggable` turns any `BackdropTemplate` frame into a lockable, draggable display element with position persistence.

```lua
local frame = CreateFrame("Frame", "MyDisplay", UIParent, "BackdropTemplate")
frame:SetSize(120, 30)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)

LanternUX.MakeDraggable(frame, {
    getPos       = function() return db.pos end,
    setPos       = function(pos) db.pos = pos end,
    getLocked    = function() return db.locked end,
    setLocked    = function(val) db.locked = val end,
    defaultPoint = { "CENTER", UIParent, "CENTER", 0, -100 },
    text         = myFontString,    -- optional
    placeholder  = "Drag to move",  -- optional, shown when unlocked
})
```

### Config Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `getPos` | function | yes | Returns the saved position table or nil. |
| `setPos` | function | yes | Saves a position table `{ point, relPoint, x, y }` (or nil to clear). |
| `getLocked` | function | yes | Returns true if the frame is locked. |
| `setLocked` | function | yes | Sets the locked state. |
| `defaultPoint` | table | yes | Default anchor: `{ point, relativeTo, relPoint, x, y }`. |
| `text` | FontString | no | A FontString to swap with placeholder text when unlocked. |
| `placeholder` | string | no | Text shown on the FontString while unlocked. |

### Methods Added to Frame

| Method | Description |
|--------|-------------|
| `frame:UpdateLock()` | Apply the current lock/unlock state visually. Call after changing `locked`. |
| `frame:RestorePosition()` | Restore the saved position from `getPos()`. |
| `frame:ResetPosition()` | Reset to `defaultPoint` and clear the saved position. |

When unlocked, the frame gets a visible backdrop with an amber border and an "Unlocked - drag to move" label. When the LanternUX panel is closed, all unlocked draggable frames are automatically re-locked.

---

## Custom Frame Pages

For pages that need a fully custom layout (not widget-based), use the `frame` option instead of `widgets`:

```lua
panel:AddPage("home", {
    label = "Home",
    frame = function(parent)
        local f = CreateFrame("Frame", "MyAddon_HomePage", parent)
        f:SetAllPoints()

        local title = f:CreateFontString(nil, "ARTWORK")
        title:SetFontObject(LanternUX.Theme.fontHeading)
        title:SetPoint("CENTER", 0, 20)
        title:SetText("Welcome to My Addon")
        title:SetTextColor(unpack(LanternUX.Theme.textBright))

        return f
    end,
    onShow = function() print("Home page shown") end,
    onHide = function() print("Home page hidden") end,
})
```

The `frame` function receives the content area as its parent. It is called once (lazy) -- the returned frame is cached and reused. Use `onShow`/`onHide` for lifecycle events.

---

## DataTable

A standalone sortable, paginated data table for displaying tabular data (e.g., analytics, order history). This is **not** a widget type -- it's a separate component created via `LanternUX.CreateDataTable()`, typically used inside custom frame pages.

### CreateDataTable

```lua
local dt = LanternUX.CreateDataTable(parent, config)
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `columns` | table | yes | Array of column definitions (see below). |
| `rowHeight` | number | no | Row height in pixels (default 24). |
| `pageSize` | number | no | Rows per page. If set, enables pagination footer. If nil, all rows are shown. |
| `defaultSort` | table | no | `{ key = "columnKey", ascending = true/false }` -- initial sort. |
| `onRowClick` | function | no | `function(entry)` -- called on left-click of a row. |
| `rowTooltip` | function | no | `function(entry, tooltip)` -- populates GameTooltip on row hover. |

#### Column Definition

```lua
{ key = "name", label = "Name", width = 150, align = "LEFT", format = function(val, entry) ... end, isLink = false }
```

| Field | Type | Description |
|-------|------|-------------|
| `key` | string | Data field key used for display and sorting. |
| `label` | string | Column header text. |
| `width` | number | Column width in pixels. |
| `align` | string | Text alignment: `"LEFT"` (default) or `"RIGHT"`. |
| `format` | function | Optional `function(value, entry)` returning display string. |
| `isLink` | boolean | If true, preserves WoW item link coloring in cells. |

### Methods

| Method | Description |
|--------|-------------|
| `dt:SetData(data)` | Sets the data array. Each entry is a table with keys matching column keys. |
| `dt:Refresh()` | Re-sorts and re-renders all visible rows. |
| `dt:SetSortKey(key, ascending)` | Changes the sort column and direction. |
| `dt:SetNoDataText(text)` | Text shown when the data array is empty. |
| `dt:SetPage(n)` | Jump to page n (pagination mode only). |
| `dt:GetPage()` | Returns current page number. |
| `dt:GetTotalPages()` | Returns total page count. |
| `dt:SetPageSize(n)` | Changes rows per page and resets to page 1. |

### Properties

| Property | Description |
|----------|-------------|
| `dt.frame` | The outer container Frame. Anchor and size this in your layout. |

### Example

```lua
panel:AddPage("orders", {
    label = "Orders",
    frame = function(parent)
        local f = CreateFrame("Frame", "MyAddon_OrdersPage", parent)
        f:SetAllPoints()

        local dt = LanternUX.CreateDataTable(f, {
            columns = {
                { key = "item",     label = "Item",     width = 200 },
                { key = "customer", label = "Customer", width = 150 },
                { key = "tip",      label = "Tip",      width = 100, align = "RIGHT",
                  format = function(val) return FormatMoney(val) end },
            },
            pageSize = 20,
            defaultSort = { key = "tip", ascending = false },
            onRowClick = function(entry)
                if IsShiftKeyDown() then removeOrder(entry) end
            end,
            rowTooltip = function(entry, tooltip)
                tooltip:AddLine(entry.item, 1, 1, 1)
                tooltip:AddLine("Shift-click to remove", 0.7, 0.7, 0.7)
            end,
        })

        dt.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        dt.frame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        dt:SetNoDataText("No orders recorded.")
        dt:SetData(myOrdersData)
        dt:Refresh()

        return f
    end,
})
```

Column headers are clickable to sort. Clicking a header toggles between descending and ascending. The active sort column is highlighted with an arrow indicator.

---

## Tips

### Dynamic Widget Lists

Widget functions are called every time a page is selected. Build widget tables dynamically:

```lua
panel:AddPage("items", {
    label = "Items",
    widgets = function()
        local widgets = {
            { type = "drop_slot", label = "Add item:", onDrop = function(id) addItem(id); refreshPage() end },
            { type = "divider" },
        }
        for _, itemID in ipairs(db.items) do
            table.insert(widgets, {
                type = "item_row", itemID = itemID,
                func = function() removeItem(itemID); refreshPage() end,
            })
        end
        return widgets
    end,
})
```

### Page Refresh

After modifying data that the current page displays (adding/removing items, changing a value that affects `hidden` or `disabled` states), call `RefreshCurrentPage()`:

```lua
local function refreshPage()
    panel:RefreshCurrentPage()
end
```

This re-runs the `widgets` function and re-renders the page while preserving scroll position.

### Search

Widget search is built in and indexes all pages automatically. It searches widget labels, descriptions, and page names. Only interactive widget types (toggle, range, select, execute, input, color) are indexed.

Clicking a search result navigates to the widget's page, expands any containing group, and scrolls to the widget.

### Sidebar Organization

Combine sections and sidebar groups for structured navigation:

```lua
-- Sections are visual dividers with uppercase labels
panel:AddSection("modules", "Modules")

-- Sidebar groups are collapsible containers
panel:AddSidebarGroup("combat", { label = "Combat", section = "modules" })

-- Pages inside a group
panel:AddPage("dps", { label = "DPS Tracker", sidebarGroup = "combat" })
panel:AddPage("alerts", { label = "Alerts", sidebarGroup = "combat" })

-- Pages directly in a section (no group)
panel:AddPage("general", { label = "General", section = "modules" })

-- Pages with no section appear first in the sidebar
panel:AddPage("home", { label = "Home" })
```

### Page Headers

Add a title and description to a widget page for context:

```lua
panel:AddPage("autoRepair", {
    label = "Auto Repair",
    title = "Auto Repair",
    description = "Automatically repair gear when visiting a repair-capable merchant.",
    widgets = function() return { ... } end,
})
```

The title is rendered in large bright text at the top of the content area, followed by the description in small dimmed text, with a divider underneath.
