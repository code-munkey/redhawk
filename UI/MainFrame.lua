-- MonkeyTracker: MainFrame.lua
-- Thin compatibility shim over WindowManager.
-- All actual window management is handled in WindowManager.lua.

RAPE.MainFrame = RAPE.MainFrame or {}
local F = RAPE.MainFrame

function F.Build()         RAPE.WM.Build()         end
function F.Refresh()       RAPE.WM.RefreshAll()     end
function F.OnDataChanged() RAPE.WM.RefreshAll()     end

function F.Show()
    if RAPE.db.windows and RAPE.db.windows[1] then
        RAPE.db.windows[1].hidden = false
    end
    RAPE.WM.ShowWindow(1)
end

function F.Hide()
    if RAPE.db.windows and RAPE.db.windows[1] then
        RAPE.db.windows[1].hidden = true
    end
    RAPE.WM.HideWindow(1)
end

function F.Toggle()        RAPE.WM.ToggleWindow(1)   end
function F.ToggleLock()    RAPE.WM.ToggleLock(1)     end
function F.ApplyLockState() RAPE.WM.ApplyLockState(1) end
function F.SavePosition()  RAPE.WM.SavePosition(1)   end
