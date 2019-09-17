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
local UnitPower, UnitPowerMax, UnitBuff = _G.UnitPower, _G.UnitPowerMax, _G.UnitBuff
local UnitAffectingCombat = _G.UnitAffectingCombat
local GetShapeshiftForm = _G.GetShapeshiftForm
local GetSpellInfo = _G.GetSpellInfo


local BASE_REG_SEC = 2.0
local ENERGY_FORMAT_STRING = "%d / %d"
local ENERGY_FORMAT_STRING_TIMER = "%d / %d (%.1f)"
local ENERGY_FORMAT_STRING_TIMER_NO_MAX = "%d (%.1f)"
local EVENT_UNIT_POWER_FREQUENT, PLAYER_UNIT, POWER_TYPE = "UNIT_POWER_FREQUENT", "player", "ENERGY"
local EVENT_UNIT_MAXPOWER = "UNIT_MAXPOWER"
local EVENT_COMBAT_START, EVENT_COMBAT_END = "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"
local EVENT_SHAPESHIFT, EVENT_STEALTH = "UPDATE_SHAPESHIFT_FORM", "UPDATE_STEALTH"
local ENUM_P_TYPE_ENERGY = Enum.PowerType.Energy
local STEALTH_BUFF_NAME = PlayerClass == "DRUID" and GetSpellInfo(5215) or GetSpellInfo(1784)
local CAT_FORM_BUFF_NAME = GetSpellInfo(768)
local FONT_STRING, FONT_SIZE = _G["SystemFont_Tiny"]:GetFont()

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
            SEB:Print("'width' set: "..SimpleEnergyBarDB.width)
        elseif key == "height" and tonumber(value) then
            SimpleEnergyBarDB.height = tonumber(value) -->= 10 and tonumber(value) or 10
            SEB:UpdateFrameSize()
            SEB:Print("'height' set: "..SimpleEnergyBarDB.height)
        elseif key == "lock" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.locked = enable
            SEB:UpdateFrameSize()
            SEB:Print("'lock' set: "..( enable and "true" or "false" ))
        elseif key == "incombatonly" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.inCombatOnly = enable
            SEB:UpdateFrameSize()
            SEB:Print("'inCombatOnly' set: "..( enable and "true" or "false" ))
        elseif key == "showinstealth" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.showInStealth = enable
            SEB:UpdateFrameSize()
            SEB:Print("'showInStealth' set: "..( enable and "true" or "false" ))
        elseif key == "showonlycurrentenergy" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.showOnlyCurrentEnergy = enable
            SEB:UpdateFrameSize()
            SEB:Print("'showOnlyCurrentEnergy' set: "..( enable and "true" or "false" ))
        elseif key == "showborder" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.showBorder = enable
            SEB:UpdateFrameSize()
            SEB:Print("'showBorder' set: "..( enable and "true" or "false" ))
        elseif key == "textsize" and tonumber(value) then
            local value = tonumber(value)
           --if value >= 3 then
                SimpleEnergyBarDB.textSize = value
                SEB:UpdateFrameSize()
                SEB:Print("'textSize' set: "..value)
            --end
        elseif PlayerClass == "DRUID" and key == "onlyincatform" and tonumber(value) then
            local enable = tonumber(value) == 1 and true or false
            SimpleEnergyBarDB.onlyInCatForm = enable
            SEB:UpdateFrameSize()
            SEB:Print("'onlyInCatForm' set: "..( enable and "true" or "false" ))
        else
            SEB:Print("'"..key.."' UNKNOWN")
        end
    else
        SEB:Print("Slash commands")
        SEB:Print(" - width xxx")
        SEB:Print(" - height xxx")
        SEB:Print(" - lock 0/1")
        SEB:Print(" - inCombatOnly 0/1")
        SEB:Print(" - showInStealth 0/1")
        SEB:Print(" - showOnlyCurrentEnergy 0/1")
        SEB:Print(" - textSize xxx")
        SEB:Print(" - showBorder 0/1")
        if PlayerClass == "DRUID" then
            SEB:Print(" - onlyInCatForm 0/1")
        end
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

local function OnUpdate()
    if not SEB.nextTick then return end
    local curTime = GetTime()
    local diff = SEB.nextTick - curTime
    if diff < 0 then
        SEB.nextTick = curTime + BASE_REG_SEC
        diff = 0
    end
    if SEB.barFrame:IsShown() then
        local barFrame = SEB.barFrame
        if barFrame.updateText then
            if SimpleEnergyBarDB.showOnlyCurrentEnergy then
                barFrame.statusbar.text:SetText(format(ENERGY_FORMAT_STRING_TIMER_NO_MAX, barFrame.power, diff))
            else
                barFrame.statusbar.text:SetText(format(ENERGY_FORMAT_STRING_TIMER, barFrame.power, barFrame.statusbar.maxValue, diff))
            end
        end

        local position = barFrame.sparkRange - ( ( barFrame.sparkRange / BASE_REG_SEC ) * ( ( BASE_REG_SEC * 0.5 ) * diff ) )
        barFrame.statusbar.spark:SetPoint("CENTER", barFrame.statusbar, "LEFT", position, 0)
    end
end
local UpdateFrame = CreateFrame("Frame", UIParent)
UpdateFrame:SetScript("OnUpdate", OnUpdate)

local function checkForBuff(buffNameCheck)
    for i = 1, 40 do
        local buffName = UnitBuff(PLAYER_UNIT,i)
        if not buffName then break end
        if buffName == buffNameCheck then
            SEB.barFrame:Show()
            return true
        end
    end
    return false
end

local function HandleDruidShapeShift()
    if SimpleEnergyBarDB.onlyInCatForm then
        if checkForBuff(CAT_FORM_BUFF_NAME) then
            -- pass
        else
            SEB.barFrame:Hide()
            return false
        end
    end

    if SimpleEnergyBarDB.showInStealth and checkForBuff(STEALTH_BUFF_NAME) then
        return true
    elseif not SimpleEnergyBarDB.inCombatOnly or ( SimpleEnergyBarDB.inCombatOnly and UnitAffectingCombat(PLAYER_UNIT) ) then
        SEB.barFrame:Show()
        return true
    else
        SEB.barFrame:Hide()
        return false
    end
end

local function HandleRogueShapeShift()
    if not SimpleEnergyBarDB.inCombatOnly or ( SimpleEnergyBarDB.inCombatOnly and UnitAffectingCombat(PLAYER_UNIT) ) then
        SEB.barFrame:Show()
        return true
    elseif SimpleEnergyBarDB.showInStealth then
        if GetShapeshiftForm() > 0 then
            SEB.barFrame:Show()
            return true
        end
    elseif not SimpleEnergyBarDB.inCombatOnly then
        SEB.barFrame:Show()
        return true
    end
    SEB.barFrame:Hide()
    return false
end

local ShapeShiftOnEvent = PlayerClass == "DRUID" and HandleDruidShapeShift or HandleRogueShapeShift

local lastReg
local function FramOnEvent(self, event, arg1, arg2, ...)
    if event == EVENT_UNIT_POWER_FREQUENT and arg1 == PLAYER_UNIT and arg2 == POWER_TYPE then
        local statusbar = self.statusbar
        local power, powerMax = UnitPower(PLAYER_UNIT, ENUM_P_TYPE_ENERGY), UnitPowerMax(PLAYER_UNIT, ENUM_P_TYPE_ENERGY)
        local lastPowerCheck = ( self.power and self.power < power ) and true or false
        self.power = power
        statusbar:SetValue(power)
        if power >= powerMax then
            self.updateText = false
            if SimpleEnergyBarDB.showOnlyCurrentEnergy then
                statusbar.text:SetText(power)
            else
                statusbar.text:SetText(format(ENERGY_FORMAT_STRING, power, powerMax))
            end
        elseif not SEB.nextTick then
            SEB.nextTick = GetTime() + BASE_REG_SEC
            self.updateText = true
        elseif SEB.nextTick and power < powerMax then
            self.updateText = true
        end

        if SEB.nextTick and lastPowerCheck then
            SEB.nextTick = GetTime() + BASE_REG_SEC
            statusbar.spark:SetPoint("CENTER", statusbar, "LEFT", 0, 0)
        end
    elseif event == EVENT_UNIT_MAXPOWER and arg1 == PLAYER_UNIT and arg2 == POWER_TYPE then
        SEB:UpdateFrameSize()
    elseif event == EVENT_COMBAT_START and SimpleEnergyBarDB.inCombatOnly then
        ShapeShiftOnEvent()
    elseif event == EVENT_COMBAT_END and SimpleEnergyBarDB.inCombatOnly then
        ShapeShiftOnEvent()
    elseif event == EVENT_SHAPESHIFT or event == EVENT_STEALTH then
        ShapeShiftOnEvent()
    end
end

-- Core
function SEB.PLAYER_LOGIN()
    SEB:GetEnergyBar()
    EventFrame:UnregisterEvent("PLAYER_LOGIN")
end
EventFrame:RegisterEvent("PLAYER_LOGIN")

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

    frame.statusbar.text:SetFont(FONT_STRING, SimpleEnergyBarDB.textSize or FONT_SIZE )

    local curEnergy = UnitPower(PLAYER_UNIT, ENUM_P_TYPE_ENERGY)
    frame.statusbar.maxValue = UnitPowerMax(PLAYER_UNIT, ENUM_P_TYPE_ENERGY)
    frame.statusbar:SetMinMaxValues(0, frame.statusbar.maxValue)
    frame.statusbar:SetValue(curEnergy)

    if curEnergy >= frame.statusbar.maxValue then
        self.updateText = false
        if SimpleEnergyBarDB.showOnlyCurrentEnergy then
            frame.statusbar.text:SetText(curEnergy)
        else
            frame.statusbar.text:SetText(format(ENERGY_FORMAT_STRING, curEnergy, frame.statusbar.maxValue))
        end
    end

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
    if db.inCombatOnly then
        if UnitAffectingCombat(PLAYER_UNIT) then
            frame:Show()
        else
            ShapeShiftOnEvent()
        end
        frame:RegisterEvent(EVENT_COMBAT_START)
        frame:RegisterEvent(EVENT_COMBAT_END)
    elseif not db.inCombatOnly then
        ShapeShiftOnEvent()
        frame:UnregisterEvent(EVENT_COMBAT_START)
        frame:UnregisterEvent(EVENT_COMBAT_END)
    end
    if db.showBorder then
        if not frame.border then
            frame.border = CreateFrame("Frame", nil, frame.statusbar)
            frame.border:SetPoint('TOPLEFT', -4, 4)
            frame.border:SetPoint('BOTTOMRIGHT', 4, -4)
        end
        frame.border:SetBackdrop({
            --bgFile = "interface/Addons/"..SEB_Name.."/background",
            edgeFile = "interface/Addons/"..SEB_Name.."/border",
            edgeSize = 6,
            insets = { left = 8, right = 8, top = 8, bottom = 8}})
        frame.border:Show()
    else
        if frame.border then
            frame.border:Hide()
        end
    end
end

function SEB:GetEnergyBar()
    if not self.barFrame then
        local frame = CreateFrame("Frame", UIParent)
        frame:SetWidth(150)
        frame:SetHeight(10)
        frame:SetClampedToScreen(true)
        frame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        frame:SetBackdropColor(0, 0, 0)
        frame:RegisterForDrag("LeftButton", "RightButton")
        frame:RegisterEvent(EVENT_UNIT_POWER_FREQUENT)
        frame:RegisterEvent(EVENT_UNIT_MAXPOWER)
        frame:RegisterEvent(EVENT_SHAPESHIFT)
        if PlayerClass == "DRUID" then
            frame:RegisterEvent(EVENT_STEALTH)
        end
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

        statusbar.text = statusbar:CreateFontString(nil, "ARTWORK")
        statusbar.text:SetTextColor(1,1,1,1)
        statusbar.text:SetAllPoints()
        statusbar.text:SetJustifyH("CENTER")

        frame.statusbar = statusbar

        self.barFrame = frame

        self:UpdateFrameSize()
    end
    return self.barFrame
end