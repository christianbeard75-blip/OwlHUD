-- OwlHUD quality of life: sell junk, repair, fast loot, tooltip mover, one-time settings, attack macros, graphics.
local ADDON, O = ...

-- ---------- bags (new and old container API) ----------
local function NumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
  return 0
end
local function SlotInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.quality, info.hyperlink, info.hasNoValue, info.stackCount or 1, info.isLocked end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, locked, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
    return quality, link, noValue, count or 1, locked
  end
  return nil
end
local function UseSlot(bag, slot)
  if C_Container and C_Container.UseContainerItem then C_Container.UseContainerItem(bag, slot)
  elseif UseContainerItem then UseContainerItem(bag, slot) end
end
local function SellPrice(link)
  local price
  if C_Item and C_Item.GetItemInfo then price = select(11, C_Item.GetItemInfo(link))
  elseif GetItemInfo then price = select(11, GetItemInfo(link)) end
  return price or 0
end

-- ---------- merchant: sell grey items, repair ----------
local selling
local function SellJunk()
  if selling then return end
  local queue, total = {}, 0
  for bag = 0, 4 do
    for slot = 1, NumSlots(bag) do
      local quality, link, noValue, count, locked = SlotInfo(bag, slot)
      if link and quality == 0 and not noValue and not locked then
        local price = SellPrice(link) * (count or 1)
        if price > 0 then
          queue[#queue + 1] = { bag, slot }
          total = total + price
        end
      end
    end
  end
  if #queue == 0 then return end
  local sold = #queue
  local function Finish()
    selling = nil
    O.Print("sold " .. sold .. " junk item" .. (sold == 1 and "" or "s") .. " for " .. O.Money(total) .. ".")
  end
  if C_Timer and C_Timer.NewTicker then
    local i, finished = 0, false
    selling = C_Timer.NewTicker(0.15, function(ticker)
      if finished then return end
      i = i + 1
      local item = queue[i]
      if not item or not (MerchantFrame and MerchantFrame:IsShown()) then
        finished = true
        ticker:Cancel()
        if not item then Finish() else selling = nil end
        return
      end
      pcall(UseSlot, item[1], item[2])
    end)
  else
    for i = 1, #queue do pcall(UseSlot, queue[i][1], queue[i][2]) end
    Finish()
  end
end

local function Repair()
  if not (CanMerchantRepair and CanMerchantRepair()) then return end
  local cost, canRepair = GetRepairAllCost()
  if canRepair and cost and cost > 0 then
    if (GetMoney() or 0) >= cost then
      RepairAllItems()
      O.Print("repaired for " .. O.Money(cost) .. ".")
    else
      O.Print("not enough money to repair (" .. O.Money(cost) .. ").")
    end
  end
end

O.On("MERCHANT_SHOW", function()
  if OwlHUDDB.repair then O.Try("repair", Repair) end
  if OwlHUDDB.sell then O.Try("sell junk", SellJunk) end
end)

-- ---------- fast loot ----------
local lastLoot = 0
O.On("LOOT_READY", function()
  if not OwlHUDDB.fastloot then return end
  if GetTime() - lastLoot < 0.3 then return end
  lastLoot = GetTime()
  local toggle = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") or false
  if O.GetCVarBool("autoLootDefault") ~= (toggle and true or false) then
    for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
  end
end)

-- ---------- tooltip mover ----------
local tipAnchor = CreateFrame("Frame", "OwlHUDTooltipAnchor", UIParent)
tipAnchor:SetSize(190, 60)
tipAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -340, 260)
tipAnchor:SetMovable(true)
tipAnchor:SetClampedToScreen(true)
tipAnchor:RegisterForDrag("LeftButton")
tipAnchor.bg = tipAnchor:CreateTexture(nil, "BACKGROUND")
tipAnchor.bg:SetAllPoints()
tipAnchor.bg:SetColorTexture(0, 1, 0, 0.25)
tipAnchor.label = tipAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tipAnchor.label:SetPoint("CENTER")
tipAnchor.label:SetText("Tooltips appear here")
tipAnchor:SetScript("OnDragStart", function(f) f:StartMoving() end)
tipAnchor:SetScript("OnDragStop", function(f)
  f:StopMovingOrSizing()
  local x, y = f:GetLeft(), f:GetBottom()
  if x and y then OwlHUDDB.tooltip = { x = x, y = y } end
end)
tipAnchor:Hide()

if type(GameTooltip_SetDefaultAnchor) == "function" then
  hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    local p = OwlHUDDB and OwlHUDDB.tooltip
    if not p or not tooltip then return end
    pcall(function()
      tooltip:SetOwner(parent or UIParent, "ANCHOR_NONE")
      tooltip:ClearAllPoints()
      tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    end)
  end)
end

table.insert(O.unlockHooks, function(unlocked)
  tipAnchor:EnableMouse(unlocked)
  if unlocked then
    local p = OwlHUDDB.tooltip
    if p then
      tipAnchor:ClearAllPoints()
      tipAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    end
    tipAnchor:Show()
  else
    tipAnchor:Hide()
  end
end)

O.commands.tooltip = function(arg)
  if arg == "reset" then
    OwlHUDDB.tooltip = nil
    O.Print("tooltips back to the game's default spot.")
  else
    O.Print("/owl unlock and drag the 'Tooltips appear here' box. /owl tooltip reset undoes it.")
  end
end

-- ---------- one-time settings: health bar under the character, stacked nameplates, auto loot ----------
local FIRST_RUN = {
  autoLootDefault = 1,
}
O.On("PLAYER_LOGIN", function()
  if OwlHUDDB.firstRunDone or OwlHUDDB.setup == "new" then return end   -- a new install waits for its owner's choice
  OwlHUDDB.firstRunDone = true
  for k, v in pairs(FIRST_RUN) do O.SetCVar(k, v) end
end)

O.FullSetup = function()
  for k, v in pairs(FIRST_RUN) do O.SetCVar(k, v) end
end

-- ---------- /owl attack: abilities start auto-attack on a new target ----------
local MACROS = {
  { name = "OwlJudge", spell = "Judgement" },
  { name = "OwlStrike", spell = "Holy Strike" },
}
local function EnsureMacro(name, body)
  local index = GetMacroIndexByName(name)
  if index and index > 0 then
    EditMacro(index, name, nil, body)
    return true
  end
  local ok, id = pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body, true)
  return ok and id ~= nil
end

O.commands.attack = function()
  if InCombatLockdown and InCombatLockdown() then
    O.Print("finish the fight first, then run /owl attack again.")
    return
  end
  local swapped, made = 0, 0
  for _, m in ipairs(MACROS) do
    local body = "#showtooltip " .. m.spell .. "\n/startattack\n/cast " .. m.spell
    if EnsureMacro(m.name, body) then
      made = made + 1
      for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and O.SpellName(id) == m.spell then
          PickupMacro(m.name)
          PlaceAction(slot)
          ClearCursor()
          swapped = swapped + 1
        end
      end
    end
  end
  O.SetCVar("SoftTargetEnemy", 3)
  O.SetCVar("SoftTargetIconEnemy", 1)
  if made == 0 then
    O.Print("could not create the macros (macro list may be full).")
  else
    O.Print("done. " .. swapped .. " button" .. (swapped == 1 and "" or "s")
      .. " now start attacking on press. An icon also marks the enemy you are facing.")
    if swapped == 0 then
      O.Print("no Judgement or Holy Strike buttons found to swap. Open Macros and drag OwlJudge and OwlStrike onto your bar.")
    end
  end
end

-- ---------- /owl gfx: visuals beyond the menu sliders ----------
local GFX = {
  { "groundEffectDensity", 256 }, { "groundEffectDist", 500 },
  { "lodObjectFadeScale", 200 }, { "doodadLodScale", 200 },
  { "terrainLodDist", 1000 }, { "horizonStart", 4000 },
  { "reflectionMode", 3 }, { "rippleDetail", 3 }, { "reflectionDownscale", 0 },
  { "shadowBlendCascades", 1 }, { "sunshafts", 2 }, { "projectedTextures", 1 },
}
O.commands.gfx = function()
  local applied = 0
  for _, pair in ipairs(GFX) do
    if O.SetCVar(pair[1], pair[2]) then applied = applied + 1 end
  end
  O.Print(applied .. " of " .. #GFX .. " graphics settings applied. The Defaults button in Graphics options undoes them.")
end

-- ---------- side bars: your health and mana left of the character, target health on the right ----------
-- Health is a secret number in combat, so bars and percent text are filled by the game's own widgets.
O.defaults.sides = true

local sides = CreateFrame("Frame", "OwlHUDSides", UIParent)
sides:SetSize(330, 110)
sides:SetPoint("CENTER", UIParent, "CENTER", 0, -20)
sides:SetMovable(true)
sides:SetClampedToScreen(true)
sides:RegisterForDrag("LeftButton")
sides.mover = sides:CreateTexture(nil, "BACKGROUND")
sides.mover:SetAllPoints()
sides.mover:SetColorTexture(0, 1, 0, 0.18)
sides.mover:Hide()
sides:SetScript("OnDragStart", function(f) if O.unlocked then f:StartMoving() end end)
sides:SetScript("OnDragStop", function(f)
  f:StopMovingOrSizing()
  local p, _, rp, x, y = f:GetPoint()
  OwlHUDDB.sidesPos = { p, rp, x, y }
end)

local function VBar(width, r, g, b, font)
  local bar = CreateFrame("StatusBar", nil, sides)
  bar:SetSize(width, 100)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  bar:SetStatusBarColor(r, g, b, 0.9)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetPoint("TOPLEFT", -1, 1)
  bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
  bar.bg:SetColorTexture(0, 0, 0, 0.6)
  bar.text = bar:CreateFontString(nil, "OVERLAY", font)
  return bar
end

local myHP = VBar(12, 0.87, 0.15, 0.18, "GameFontNormalLarge")
myHP:SetPoint("BOTTOMLEFT", sides, "BOTTOMLEFT", 24, 0)
myHP.text:SetPoint("BOTTOM", myHP, "TOP", 0, 4)
local myMana = VBar(6, 0.25, 0.5, 1, "GameFontHighlightSmall")
myMana:SetPoint("BOTTOMLEFT", myHP, "BOTTOMRIGHT", 5, 0)
myMana.text:SetPoint("TOP", myMana, "BOTTOM", 0, -3)
local targetHP = VBar(12, 1, 0.45, 0.2, "GameFontNormalLarge")
targetHP:SetPoint("BOTTOMRIGHT", sides, "BOTTOMRIGHT", -24, 0)
targetHP.text:SetPoint("BOTTOM", targetHP, "TOP", 0, 4)

local function Percent(fn, ...)
  if not (fn and CurveConstants and CurveConstants.ScaleTo100) then return nil end
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

local function Fill(bar, current, maximum, percent)
  pcall(bar.SetMinMaxValues, bar, 0, maximum)
  pcall(bar.SetValue, bar, current)
  if percent ~= nil then
    if not pcall(bar.text.SetFormattedText, bar.text, "%.0f%%", percent) then bar.text:SetText("") end
  else
    local c, m = O.Plain(current), O.Plain(maximum)
    if c and m and m > 0 then bar.text:SetText(math.floor(c / m * 100 + 0.5) .. "%") else bar.text:SetText("") end
  end
end

local sidesAcc, sidesDead = 0, false
local function UpdateSides()
  if not OwlHUDDB.sides then sides:Hide(); return end
  local inCombat = O.Plain(UnitAffectingCombat("player")) and true or false
  local hasTarget = false
  if O.Plain(UnitExists("target")) then
    hasTarget = O.Plain(UnitCanAttack("player", "target")) and not O.Plain(UnitIsDeadOrGhost("target")) and true or false
  end
  if not (inCombat or hasTarget or O.unlocked) then sides:Hide(); return end
  sides:Show()

  Fill(myHP, UnitHealth("player"), UnitHealthMax("player"),
    Percent(UnitHealthPercent, "player", true, CurveConstants and CurveConstants.ScaleTo100))
  local maxMana = UnitPowerMax("player", 0)
  if O.Plain(maxMana) == 0 then
    myMana:Hide()
  else
    myMana:Show()
    Fill(myMana, UnitPower("player", 0), maxMana,
      Percent(UnitPowerPercent, "player", 0, false, CurveConstants and CurveConstants.ScaleTo100))
  end
  if hasTarget then
    targetHP:Show()
    Fill(targetHP, UnitHealth("target"), UnitHealthMax("target"),
      Percent(UnitHealthPercent, "target", true, CurveConstants and CurveConstants.ScaleTo100))
  else
    targetHP:Hide()
  end
end

local sidesDriver = CreateFrame("Frame")
sidesDriver:SetScript("OnUpdate", function(_, e)
  if sidesDead then return end
  sidesAcc = sidesAcc + e
  if sidesAcc < 0.1 then return end
  sidesAcc = 0
  local ok, err = pcall(UpdateSides)
  if not ok then
    sidesDead = true
    sides:Hide()
    O.Print("|cffff4040side bars turned off:|r " .. tostring(err))
  end
end)

O.On("PLAYER_LOGIN", function()
  local p = OwlHUDDB.sidesPos
  if p then
    sides:ClearAllPoints()
    sides:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end)

table.insert(O.unlockHooks, function(unlocked)
  sides:EnableMouse(unlocked)
  if unlocked then sides.mover:Show() else sides.mover:Hide() end
end)

O.commands.sides = function(arg)
  local width = tonumber(arg)
  if width and width >= 160 and width <= 900 then
    OwlHUDDB.sidesWidth = width
    sides:SetWidth(width)
    O.Print("side bars " .. width .. " apart.")
    return
  end
  OwlHUDDB.sides = not OwlHUDDB.sides
  O.Print("side bars" .. (OwlHUDDB.sides and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
O.On("PLAYER_LOGIN", function()
  if OwlHUDDB.sidesWidth then sides:SetWidth(OwlHUDDB.sidesWidth) end
end)

-- ---------- enemy level under the target bar ----------
targetHP.level = targetHP:CreateFontString(nil, "OVERLAY", "GameFontNormal")
targetHP.level:SetPoint("TOP", targetHP, "BOTTOM", 0, -3)

local function UpdateTargetLevel()
  local fs = targetHP.level
  if not O.Plain(UnitExists("target")) then fs:SetText(""); return end
  local raw = UnitLevel("target")
  local level = O.Plain(raw)
  if level == nil then
    -- hidden from addons: let the game print it
    if not pcall(fs.SetFormattedText, fs, "Lv %d", raw) then fs:SetText("") end
    fs:SetTextColor(1, 1, 1)
    return
  end
  local class = O.Plain(UnitClassification("target"))
  local plus = (class == "elite" or class == "rareelite" or class == "worldboss") and "+" or ""
  if level <= 0 then
    fs:SetText("Lv ??" .. plus)
    fs:SetTextColor(1, 0.1, 0.1)
    return
  end
  fs:SetText("Lv " .. level .. plus)
  local r, g, b = 1, 0.82, 0
  if GetCreatureDifficultyColor then
    local ok, c = pcall(GetCreatureDifficultyColor, level)
    if ok and type(c) == "table" and c.r then r, g, b = c.r, c.g, c.b end
  else
    local mine = O.Plain(UnitLevel("player"))
    if mine then
      local diff = level - mine
      if diff >= 5 then r, g, b = 1, 0.1, 0.1
      elseif diff >= 3 then r, g, b = 1, 0.5, 0.25
      elseif diff >= -2 then r, g, b = 1, 0.82, 0
      else r, g, b = 0.25, 0.75, 0.25 end
    end
  end
  fs:SetTextColor(r, g, b)
end

O.On("PLAYER_TARGET_CHANGED", UpdateTargetLevel)
O.On("UNIT_LEVEL", UpdateTargetLevel)
O.On("PLAYER_LEVEL_UP", UpdateTargetLevel)
O.On("PLAYER_ENTERING_WORLD", UpdateTargetLevel)

-- ---------- the game's health bar under the character: shown for fights only ----------
-- This client has one switch for that bar (nameplateShowSelf) and no "only in combat" setting,
-- so OwlHUD flips the switch itself: on as a fight starts or an enemy is targeted, off afterwards.
-- /owl selfbar cycles: fights only, always, off.
O.defaults.selfBar = "leave"   -- new installs: the bar the game draws is left as it is
local SELF_BAR_NEXT = { leave = "combat", combat = "always", always = "off", off = "leave" }
local SELF_BAR_LABEL = { leave = "left alone, the game decides", combat = "only in fights or with an enemy targeted", always = "always shown", off = "hidden" }

local function WantSelfBar(fightStarting)
  local mode = OwlHUDDB.selfBar
  if mode == "always" then return true end
  if mode == "off" then return false end
  if fightStarting or O.Plain(UnitAffectingCombat("player")) then return true end
  if O.Plain(UnitExists("target")) and O.Plain(UnitCanAttack("player", "target"))
    and not O.Plain(UnitIsDeadOrGhost("target")) then return true end
  return false
end

local function ApplySelfBar()
  if OwlHUDDB.selfBar == "leave" then return end
  -- the switch is locked during a fight: it is set as the fight starts and again once it is over
  if InCombatLockdown and InCombatLockdown() then return end
  O.SetCVar("nameplateShowSelf", WantSelfBar() and 1 or 0)
end
O.ApplySelfBar = ApplySelfBar

O.On("PLAYER_REGEN_DISABLED", function()
  if OwlHUDDB.selfBar == "leave" then return end
  if WantSelfBar(true) then O.SetCVar("nameplateShowSelf", 1) end
end)
O.On("PLAYER_REGEN_ENABLED", ApplySelfBar)
O.On("PLAYER_TARGET_CHANGED", ApplySelfBar)
O.On("PLAYER_ENTERING_WORLD", function()
  ApplySelfBar()
  if C_Timer and C_Timer.After then
    C_Timer.After(3, function() O.Try("self bar", ApplySelfBar) end)
  end
end)

O.commands.selfbar = function()
  OwlHUDDB.selfBar = SELF_BAR_NEXT[OwlHUDDB.selfBar] or "combat"
  ApplySelfBar()
  O.Print("health bar under you: " .. SELF_BAR_LABEL[OwlHUDDB.selfBar] .. ".")
end

-- ---------- addons kept switched off ----------
-- The CurseForge app puts removed addons back when it updates. The ones listed here are switched
-- off again at login (the game remembers that), then the interface reloads once so it takes effect.
O.defaults.keepOff = {}

local function AddOnLoaded(name)
  local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not fn then return false end
  local ok, loaded = pcall(fn, name)
  return ok and loaded and true or false
end

local function SwitchOff(name)
  local fn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
  if not fn then return false end
  return (pcall(fn, name))
end

O.On("PLAYER_LOGIN", function()
  if type(OwlHUDDB.keepOff) ~= "table" then return end
  local back
  for name, on in pairs(OwlHUDDB.keepOff) do
    if on and AddOnLoaded(name) and SwitchOff(name) then
      back = (back and (back .. ", ") or "") .. name
    end
  end
  if not back then return end
  local now = time and time() or 0
  local recently = OwlHUDDB.keepOffReload and (now - OwlHUDDB.keepOffReload) < 600
  OwlHUDDB.keepOffReload = now
  if not recently and C_Timer and C_Timer.After and ReloadUI and not (InCombatLockdown and InCombatLockdown()) then
    O.Print(back .. " came back with an addon update. Switched off again.")
    C_Timer.After(6, function() O.Print("|cffffd100type /reload once more|r to finish switching those off (the game would not let me do it for you).") end)
  else
    O.Print(back .. " came back with an addon update. Switched off again: type /reload to finish.")
  end
end)

-- ---------- which addons are kept off: Questie's (MelloUI's quest list is used instead) ----------
O.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  if type(OwlHUDDB.keepOff) ~= "table" then OwlHUDDB.keepOff = {} end
  if not OwlHUDDB.firstRunDone then OwlHUDDB.keepOffVersion = 3 end   -- a fresh install keeps nothing off
  if (OwlHUDDB.keepOffVersion or 0) < 2 then
    OwlHUDDB.keepOffVersion = 2
    OwlHUDDB.keepOffReload = nil
    OwlHUDDB.keepOff.MelloUI_PersonalDisplay = true
    for _, n in ipairs({ "Questie", "QuestieDB", "QuestieForeverGamepad", "QuestieTrace" }) do
      OwlHUDDB.keepOff[n] = true
    end
  end
end)

-- the installed addon whose folder name matches, whatever the letter case
local function FindAddOn(typed)
  local count = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if not (count and info) or typed == "" then return nil end
  local ok, n = pcall(count)
  if not ok or type(n) ~= "number" then return nil end
  for i = 1, n do
    local fine, name = pcall(info, i)
    if fine and type(name) == "string" and name:lower() == typed then return name end
  end
  return nil
end

O.commands.addonoff = function(arg)
  local name = FindAddOn(arg or "")
  if not name then O.Print("no addon with that folder name. Example: /owl addonoff Questie"); return end
  OwlHUDDB.keepOff[name] = true
  SwitchOff(name)
  O.Print(name .. " will stay switched off. Type /reload to finish.")
end

O.commands.addonon = function(arg)
  local name = FindAddOn(arg or "")
  if not name then O.Print("no addon with that folder name. Example: /owl addonon Questie"); return end
  OwlHUDDB.keepOff[name] = nil
  local fn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
  if fn then pcall(fn, name) end
  O.Print(name .. " is switched back on. Type /reload to finish.")
end

-- ---------- quest marker on your target: is this an enemy one of your quests still needs? ----------
-- Read from the game's own tooltip for the unit (no quest database needed). Shown above the
-- target's health percent on the side bar, with a gold word under its level.
O.defaults.questMark = true
local QUEST_LINE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective) or 8
local QUEST_TITLE = (Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestTitle) or 17
local QUEST_ART = {
  kill = { "Interface\\CURSOR\\Attack", "QUEST: KILL" },
  loot = { "Interface\\CURSOR\\Pickup", "QUEST: LOOT" },
  quest = { "Interface\\GossipFrame\\AvailableQuestIcon", "QUEST" },
}

targetHP.questIcon = targetHP:CreateTexture(nil, "OVERLAY")
targetHP.questIcon:SetSize(24, 24)
targetHP.questIcon:SetPoint("BOTTOM", targetHP.text, "TOP", 0, 3)
targetHP.questIcon:Hide()
targetHP.questText = targetHP:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
targetHP.questText:SetPoint("TOP", targetHP.level, "BOTTOM", 0, -2)
targetHP.questText:SetTextColor(1, 0.82, 0)

-- "kill", "loot", "quest", or nil when no unfinished objective of yours names this unit
local function QuestKind(unit)
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
  local ok, kind = pcall(function()
    if not O.Plain(UnitExists(unit)) or not O.Plain(UnitCanAttack("player", unit)) then return nil end
    local data = C_TooltipInfo.GetUnit(unit)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local sawTitle, sawObjective = false, false
    for _, line in ipairs(data.lines) do
      local lineType = O.Plain(line.type)
      if lineType == QUEST_TITLE then
        sawTitle = true
      elseif lineType == QUEST_LINE then
        sawObjective = true
        local text = O.Plain(line.leftText)
        if type(text) ~= "string" then return "quest" end
        local cur, total = text:match("(%d+)%s*/%s*(%d+)")
        if cur and total then
          if tonumber(cur) < tonumber(total) then
            return text:find("slain", 1, true) and "kill" or "loot"
          end
        else
          local pct = text:match("(%d+)%%")
          if not pct or tonumber(pct) < 100 then return "quest" end
        end
      end
    end
    if sawTitle and not sawObjective then return "quest" end
    return nil
  end)
  if ok then return kind end
  return nil
end

local function UpdateQuestMark()
  local art = OwlHUDDB.questMark and QUEST_ART[QuestKind("target") or ""]
  if art then
    targetHP.questIcon:SetTexture(art[1])
    targetHP.questIcon:Show()
    targetHP.questText:SetText(art[2])
  else
    targetHP.questIcon:Hide()
    targetHP.questText:SetText("")
  end
end

O.On("PLAYER_TARGET_CHANGED", UpdateQuestMark)
O.On("QUEST_LOG_UPDATE", UpdateQuestMark)
O.On("UNIT_QUEST_LOG_CHANGED", UpdateQuestMark)

O.commands.questmark = function()
  OwlHUDDB.questMark = not OwlHUDDB.questMark
  UpdateQuestMark()
  O.Print("quest marker on your target" .. (OwlHUDDB.questMark and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- gathering marker: a herb or ore vein you can pick is right in front of you ----------
-- The game gives the nearest thing you can interact with the unit name "softinteract" and a cursor
-- picture (the herb sickle, the mining pick). That picture is shown here, with HERB / ORE and the
-- node's name, and a soft ping the moment a new one comes into reach.
O.defaults.gatherMark = true
local SOFT = "softinteract"
local GATHER_WORD = { herb = "HERB", ore = "ORE" }

local gather = CreateFrame("Frame", "OwlHUDGather", UIParent)
gather:SetSize(160, 64)
gather:SetPoint("BOTTOM", targetHP, "TOP", 0, 52)
gather.icon = gather:CreateTexture(nil, "ARTWORK")
gather.icon:SetSize(30, 30)
gather.icon:SetPoint("TOP", gather, "TOP", 0, 0)
gather.title = gather:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gather.title:SetPoint("TOP", gather.icon, "BOTTOM", 0, -2)
gather.name = gather:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gather.name:SetPoint("TOP", gather.title, "BOTTOM", 0, -1)
gather:Hide()

-- cursor pictures the game may hand back as a file number: looked up once
local cursorKinds = {}
do
  local probe = gather:CreateTexture(nil, "BACKGROUND")
  probe:SetSize(1, 1)
  probe:SetAlpha(0)
  local files = {
    GatherHerbs = { "herb", false }, UnableGatherHerbs = { "herb", true },
    Mine = { "ore", false }, UnableMine = { "ore", true },
  }
  for _, folder in ipairs({ "Interface\\Cursor\\", "Interface\\Cursor\\Crosshair\\" }) do
    for file, what in pairs(files) do
      pcall(probe.SetTexture, probe, folder .. file)
      local ok, id = pcall(probe.GetTexture, probe)
      if ok and id ~= nil and O.Plain(id) ~= nil then cursorKinds[id] = what end
    end
  end
  pcall(probe.SetTexture, probe, nil)
end

local function KindFromName(name)
  if type(name) ~= "string" then return nil end
  name = name:lower()
  local blocked = name:find("unable", 1, true) ~= nil
  if name:find("gather", 1, true) or name:find("herb", 1, true) then return "herb", blocked end
  if name:find("mine", 1, true) or name:find("mining", 1, true) then return "ore", blocked end
  return nil
end

-- "herb" or "ore" and whether it is greyed (skill too low), or nil; leaves the picture on gather.icon
local function GatherKind()
  if not SetUnitCursorTexture then return nil end
  if not pcall(SetUnitCursorTexture, gather.icon, SOFT, nil, true) then return nil end
  local okT, texture = pcall(gather.icon.GetTexture, gather.icon)
  texture = okT and O.Plain(texture) or nil
  local known = texture ~= nil and cursorKinds[texture]
  if known then return known[1], known[2] end
  local kind, blocked = KindFromName(texture)
  if kind then return kind, blocked end
  if gather.icon.GetAtlas then
    local okA, atlas = pcall(gather.icon.GetAtlas, gather.icon)
    if okA then return KindFromName(O.Plain(atlas)) end
  end
  return nil
end

local lastGatherName, lastGatherPing = nil, 0
local function UpdateGather()
  if not OwlHUDDB.gatherMark or not O.Plain(UnitExists(SOFT))
    or (UnitIsGameObject and O.Plain(UnitIsGameObject(SOFT)) ~= true) then
    gather:Hide()
    lastGatherName = nil
    return
  end
  local kind, blocked = GatherKind()
  if not GATHER_WORD[kind or ""] then
    gather:Hide()
    lastGatherName = nil
    return
  end
  local name = O.Plain(UnitName(SOFT))
  if type(name) ~= "string" then name = "" end
  gather.title:SetText(GATHER_WORD[kind] .. (blocked and " (skill too low)" or ""))
  if blocked then gather.title:SetTextColor(0.6, 0.6, 0.6) else gather.title:SetTextColor(0.3, 1, 0.3) end
  gather.name:SetText(name)
  gather:Show()
  local key = kind .. name
  if key ~= lastGatherName then
    lastGatherName = key
    local now = GetTime()
    if not blocked and OwlHUDDB.sound and now - lastGatherPing > 4 then
      lastGatherPing = now
      pcall(PlaySound, 3175, "Master")
    end
  end
end

local gatherAcc, gatherDead = 0, false
local gatherDriver = CreateFrame("Frame")
gatherDriver:SetScript("OnUpdate", function(_, e)
  if gatherDead then return end
  gatherAcc = gatherAcc + e
  if gatherAcc < 0.25 then return end
  gatherAcc = 0
  local ok, err = pcall(UpdateGather)
  if not ok then
    gatherDead = true
    gather:Hide()
    O.Print("|cffff4040gathering marker turned off:|r " .. tostring(err))
  end
end)
O.On("PLAYER_SOFT_INTERACT_CHANGED", function() if not gatherDead then UpdateGather() end end)

O.commands.gather = function()
  OwlHUDDB.gatherMark = not OwlHUDDB.gatherMark
  O.Print("gathering marker" .. (OwlHUDDB.gatherMark and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- Questie is in use again (it feeds MelloUI's map circles): no longer kept off ----------
O.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  if type(OwlHUDDB.keepOff) ~= "table" or (OwlHUDDB.keepOffVersion or 0) >= 3 then return end
  OwlHUDDB.keepOffVersion = 3
  for _, n in ipairs({ "Questie", "QuestieDB", "QuestieTrace", "QuestieForeverGamepad" }) do
    OwlHUDDB.keepOff[n] = nil
  end
end)
