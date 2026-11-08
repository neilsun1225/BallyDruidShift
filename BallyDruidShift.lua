-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Ballyh (B站八厉害)

local _, class = UnitClass("player")
if class ~= "DRUID" then return end

local MACRO_NAME = "BLHShift"
local BUTTON_NAME = "BallyDruidShiftProxy"

-- A real macro cancels the form; this secure button only casts one spell.
local button = CreateFrame("Button", BUTTON_NAME, UIParent,
    "SecureActionButtonTemplate,SecureHandlerStateTemplate")
button:SetSize(1, 1)
button:SetPoint("CENTER")
button:SetAlpha(0.001)
button:EnableMouse(false)
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "spell")
-- /click defaults to a release event. Match it regardless of the player's
-- ActionButtonUseKeyDown setting, otherwise the secure click can be ignored.
button:SetAttribute("useOnKeyDown", false)
button:SetAttribute("_onstate-form", [[
    local spell = self:GetAttribute("formspell-" .. newstate)
    if spell then self:SetAttribute("spell", spell) end
]])

local function spellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return GetSpellInfo(id) end
end

local function normalize(body)
    return (body or ""):gsub("\r\n", "\n"):gsub("\n+$", "")
end

local function findMacro()
    local accountCount, characterCount = GetNumMacros()
    for i = 1, accountCount do
        local name = GetMacroInfo(i)
        if name == MACRO_NAME then return i, false end
    end
    local base = MAX_ACCOUNT_MACROS or 120
    for i = base + 1, base + characterCount do
        local name = GetMacroInfo(i)
        if name == MACRO_NAME then return i, true end
    end
end

local lastWarning
local function warn(message)
    if message ~= lastWarning then
        print("|cff188383[德鲁伊一键变形]|r " .. message)
        lastWarning = message
    end
end

local function ensureMacro(body)
    local index, characterMacro = findMacro()
    if index then
        local _, _, oldBody = GetMacroInfo(index)
        oldBody = normalize(oldBody)
        if not characterMacro then
            warn("通用宏中已存在 BLHShift，已保留原宏；请换一个名字后重载。")
            return
        end
        if oldBody == normalize(body) then
            BallyDruidShiftDB.managedBody = body
            return
        end
        if not BallyDruidShiftDB.managedBody or
            oldBody ~= normalize(BallyDruidShiftDB.managedBody) then
            warn("角色宏 BLHShift 已存在或已被修改，已保留原内容。")
            return
        end
        local ok, result = pcall(EditMacro, index, nil, nil, body)
        if ok and result then
            BallyDruidShiftDB.managedBody = body
        else
            warn("更新角色宏失败，请检查角色宏列表及插件错误信息。")
        end
        return
    end

    local ok, result = pcall(CreateMacro, MACRO_NAME,
        "Interface\\Icons\\Spell_Nature_Polymorph", body, true)
    if ok and result and result > 0 then
        BallyDruidShiftDB.managedBody = body
        lastWarning = nil
        print("|cff188383[德鲁伊一键变形]|r 已创建角色宏 BLHShift，可从 /macro 拖到技能栏。")
    else
        warn("创建角色宏失败，请检查角色宏是否已满，然后重载界面。")
    end
end

local pendingRebuild = false
local function rebuild()
    if InCombatLockdown() then pendingRebuild = true; return end
    pendingRebuild = false
    UnregisterStateDriver(button, "form")
    button:SetAttribute("spell", nil)

    local conditions, indexes = {}, {}
    for index = 1, GetNumShapeshiftForms() do
        local _, _, _, id = GetShapeshiftFormInfo(index)
        if issecretvalue and issecretvalue(id) then id = nil end
        local name = spellName(id)
        if name and name ~= "" and not name:find("[\r\n]") then
            local state = "f" .. index
            button:SetAttribute("formspell-" .. state, name)
            conditions[#conditions + 1] = "[form:" .. index .. "] " .. state
            indexes[#indexes + 1] = tostring(index)
        end
    end
    conditions[#conditions + 1] = "none"
    RegisterStateDriver(button, "form", table.concat(conditions, "; "))

    local body = "/stopmacro"
    if #indexes > 0 then
        body = "/stopmacro [noform:" .. table.concat(indexes, "/") .. "]\n" ..
            "/cancelform\n/click " .. BUTTON_NAME
    end
    ensureMacro(body)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        BallyDruidShiftDB = BallyDruidShiftDB or {}
        rebuild()
    elseif event == "UPDATE_SHAPESHIFT_FORMS" or event == "SPELLS_CHANGED" then
        if BallyDruidShiftDB then rebuild() end
    elseif event == "PLAYER_REGEN_ENABLED" and pendingRebuild then
        rebuild()
    end
end)
