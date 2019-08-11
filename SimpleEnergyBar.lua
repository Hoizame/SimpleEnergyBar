local SEB_Name, SEB = ...

local _, PlayerClass = UnitClass("player")
if PlayerClass ~= "DRUID" and PlayerClass ~= "ROGUE" then return end

SimpleEnergyBarDB = {}

-- lua
local _G = _G
local str_lower, str_split = _G.string.lower, _G.string.split
local unpack, tbl_remove = _G.unpack, _G.table.remove

-- WoW
local GetTime = _G.GetTime
local CreateFrame = _G.CreateFrame
local UnitPower, UnitPowerMax = _G.UnitPower, _G.UnitPowerMax

local BASE_REG_SEC = 2.0
local ENERGY_FORMAT_STRING = "%d / %d"
local ENERGY_FORMAT_STRING_TIMER = "%d / %d (%.1f)"
local EVENT_UNIT_POWER_FREQUENT, PLAYER_UNIT, POWER_TYPE = "UNIT_POWER_FREQUENT", "player", "ENERGY"
local ENUM_P_TYPE_ENERGY = Enum.PowerType.Energy

-- Event handler
local function OnEvent(self, event, ...)
    if SEB[event] then
        SEB[event](...)
    end
end
local EventFrame = CreateFrame("Frame")
EventFrame:SetScript("OnEvent", OnEvent)

-- Slash handler
local function OnSlash(key, value, ...)
    if key and key ~= "" then
        if key == "width" and tonumber(value) then
            SimpleEnergyBarDB.width = tonumber(value) >= 50 and tonumber(value) or 50
            SEB:UpdateFrameSize()
        elseif key == "height" and tonumber(value) then
            SimpleEnergyBarDB.height = tonumber(value) >= 10 and tonumber(value) or 10
            SEB:UpdateFrameSize()
        elseif key == "lock" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.locked = enable
            SEB:UpdateFrameSize()
        end
    else
        SEB:Print("Slash commands")
        SEB:Print(" - lock 0/1")
        SEB:Print(" - width xxx")
        SEB:Print(" - height xxx")
    end
end

SLASH_SIMPLEENERGYBAR1 = "/simpleenerybar"
SLASH_SIMPLEENERGYBAR2 = "/seb"
SlashCmdList["SIMPLEENERGYBAR"] = function(msg)
    msg = str_lower(msg)
    msg = { str_split(" ", msg) }
    if #msg >= 1 then
        local exec = tbl_remove(msg, 1)
        OnSlash(exec, unpack(msg))
    end
end

-- locales
local function FrameOnDragStart(self, arg1)
	if arg1 == "LeftButton" then
		if not SimpleEnergyBarDB.locked then
			self:StartMoving()
		end
	end
end

local function FrameOnDragStop(self)
	self:StopMovingOrSizing()
	local a,b,c,d,e = self:GetPoint()
	SimpleEnergyBarDB.point = { a, nil, c, d, e }
end

local function OnUpdate(self, elapsed)
    if not self.nextTick then return end
    local curTime = GetTime()
    local diff = self.nextTick - curTime
    if diff < 0 then
        self.nextTick = curTime + BASE_REG_SEC
        diff = 0
    end
    if self.updateText then
        self.statusbar.text:SetText(format(ENERGY_FORMAT_STRING_TIMER, self.power, self.powerMax, diff))
    end
    local position = self.sparkRange - ( ( self.sparkRange / BASE_REG_SEC ) * ( ( BASE_REG_SEC * 0.5 ) * diff ) )

    self.statusbar.spark:SetPoint("CENTER", self.statusbar, "LEFT", position, 0)
end

local lastReg
local function FramOnEvent(self, event, arg1, arg2, ...)
    if event == EVENT_UNIT_POWER_FREQUENT and arg1 == PLAYER_UNIT and arg2 == POWER_TYPE then
        local statusbar = self.statusbar
        local power, powerMax = UnitPower(PLAYER_UNIT, ENUM_P_TYPE_ENERGY), UnitPowerMax(PLAYER_UNIT, ENUM_P_TYPE_ENERGY)
        local lastPowerCheck = ( self.power and self.power < power ) and true or false
        self.power = power
        if self.powerMax ~= powerMax then
            self.powerMax = powerMax
            statusbar:SetMinMaxValues(0, powerMax)
        end
        statusbar:SetValue(power)
        if power >= powerMax then
            self.updateText = false
            statusbar.text:SetText(format(ENERGY_FORMAT_STRING, power, powerMax))
        elseif not self.nextTick then
            self.nextTick = GetTime() + BASE_REG_SEC
            self.updateText = true
        elseif self.nextTick and power < powerMax then
            self.updateText = true
        end

        if self.nextTick and lastPowerCheck then
            self.nextTick = GetTime() + BASE_REG_SEC
            statusbar.spark:SetPoint("CENTER", statusbar, "LEFT", 0, 0)
        end
    end
end

-- Core
function SEB.ADDON_LOADED(addon)
    if addon == SEB_Name then
        SEB:GetEnergyBar()

        EventFrame:UnregisterEvent("ADDON_LOADED")
    end
end
EventFrame:RegisterEvent("ADDON_LOADED")

function SEB:Print(msg)
	print("|cff33ff99SimpleEnergyBar|r: "..(msg or ""))
end

function SEB:UpdateFrameSize()
    if not self.barFrame then return end
    local frame = self.barFrame
    local db = SimpleEnergyBarDB
    local baseHeight = 10

    db.point = db.point or { "CENTER" }
    frame:SetPoint(db.point[1], UIParent, db.point[3], db.point[4], db.point[5])

    frame:SetWidth(db.width or 150)
    frame:SetHeight(db.height or baseHeight)

    frame.statusbar.spark:SetWidth((db.height or baseHeight))
    frame.statusbar.spark:SetHeight((db.height or baseHeight)+4)

    frame.statusbar.maxValue = UnitPowerMax(PLAYER_UNIT, ENUM_P_TYPE_ENERGY)
    frame.statusbar:SetMinMaxValues(0, frame.statusbar.maxValue)
    frame.statusbar:SetValue(UnitPower(PLAYER_UNIT, ENUM_P_TYPE_ENERGY))

    frame.sparkRange = frame:GetWidth()
    frame.sparkMin = 0
    frame.sparkMax = frame.statusbar:GetWidth()

    if db.locked then
        frame:SetMovable(false)
        frame:EnableMouse(false)
        frame:SetScript("OnMouseDown", nil)
        frame:SetScript("OnMouseUp", nil)
    else
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetScript("OnMouseDown", FrameOnDragStart)
        frame:SetScript("OnMouseUp", FrameOnDragStop)
    end
end

function SEB:GetEnergyBar()
    if not self.barFrame then
        local frame = CreateFrame("Frame", UIParent)
        frame:SetWidth(150)
        frame:SetHeight(10)
        frame:SetPoint("CENTER")
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        frame:SetBackdropColor(0, 0, 0)
        frame:RegisterForDrag("LeftButton", "RightButton")
        frame:RegisterEvent(EVENT_UNIT_POWER_FREQUENT)
        frame:SetScript("OnEvent", FramOnEvent)
        frame:SetScript("OnUpdate", OnUpdate)

        local statusbar = CreateFrame("StatusBar", nil, frame)
        statusbar:SetAllPoints()
        statusbar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        statusbar:SetStatusBarColor(1, 1, 0)
        statusbar:SetMinMaxValues(0, 100)
        statusbar:SetValue(75)
        statusbar:GetStatusBarTexture():SetHorizTile(false)
        statusbar:GetStatusBarTexture():SetVertTile(false)

        statusbar.spark = statusbar:CreateTexture(nil, "OVERLAY")
        statusbar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        statusbar.spark:SetPoint("CENTER", statusbar, "LEFT")
        statusbar.spark:SetWidth(10)
        statusbar.spark:SetBlendMode("ADD")

        statusbar.text = statusbar:CreateFontString(nil, "ARTWORK", "GameFontWhiteTiny")
        statusbar.text:SetAllPoints()
        statusbar.text:SetJustifyH("CENTER")

        frame.statusbar = statusbar

        self.barFrame = frame

        self:UpdateFrameSize()
    end
    return self.barFrame
end