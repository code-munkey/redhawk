-- MonkeyTracker: MainFrame.lua
-- Thin compatibility shim over WindowManager.
-- All actual window management is handled in WindowManager.lua.

local MT = MonkeyTracker

MT.MainFrame = MT.MainFrame or {}
local F = MT.MainFrame

function F.Build()         MT.WM.Build()         end
function F.Refresh()       MT.WM.RefreshAll()     end
function F.OnDataChanged() MT.WM.RefreshAll()     end

function F.Show()
    if MT.db.windows and MT.db.windows[1] then
        MT.db.windows[1].hidden = false
    end
    MT.WM.ShowWindow(1)
end

function F.Hide()
    if MT.db.windows and MT.db.windows[1] then
        MT.db.windows[1].hidden = true
    end
    MT.WM.HideWindow(1)
end

function F.Toggle()        MT.WM.ToggleWindow(1)   end
function F.ToggleLock()    MT.WM.ToggleLock(1)     end
function F.ApplyLockState() MT.WM.ApplyLockState(1) end
function F.SavePosition()  MT.WM.SavePosition(1)   end
