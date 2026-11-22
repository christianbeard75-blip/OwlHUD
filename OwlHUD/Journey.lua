-- OwlHUD journey layer: owl helper tips, XP bar, elite warning, event cards, day counter, gem tiers.
-- Rides on the classic look (Classic.lua) and switches off with it.
local ADDON, O = ...
local MEDIA = "Interface\\AddOns\\OwlHUD\\Media\\"
local Plain = O.Plain

O.defaults.tips = true

local function Sound(kitName, fallback)
  if not OwlHUDDB.sound then return end
  local id = (SOUNDKIT and SOUNDKIT[kitName]) or fallback
  if id then pcall(PlaySound, id, "Master") end
end

local function HeartCountAt(level)
  return math.max(3, math.min(20, 3 + math.floor((level or 1) / 4)))
end

local anchor = OwlHUDHearts or UIParent

-- ---------- title card queue ----------
local cards, nextCardAt = {}, 0
local function Card(title, sub)
  if #cards < 4 then cards[#cards + 1] = { title, sub } end
end
local function UpdateCards()
  if #cards == 0 or GetTime() < nextCardAt or not O.ShowCard then return end
  local c = table.remove(cards, 1)
  O.ShowCard(c[1], c[2])
  nextCardAt = GetTime() + 5
end

-- ---------- day counter (used by the login card) ----------
O.LoginSubtitle = function()
  local now = time and time() or 0
  if not OwlHUDDB.firstDay then OwlHUDDB.firstDay = now end
  local day = math.floor((now - OwlHUDDB.firstDay) / 86400) + 1
  return "Day " .. day .. " of your journey"
end

-- ---------- XP bar ----------
local xpBar = CreateFrame("StatusBar", nil, anchor)
xpBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
xpBar:SetStatusBarColor(0.95, 0.78, 0.25, 1)
xpBar.bg = xpBar:CreateTexture(nil, "BACKGROUND")
xpBar.bg:SetPoint("TOPLEFT", -1, 1)
xpBar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
xpBar.bg:SetColorTexture(0, 0, 0, 0.85)
xpBar.text = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
xpBar.text:SetPoint("TOPLEFT", xpBar, "BOTTOMLEFT", 0, -2)
xpBar:Hide()

local killXP = {}
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("dies") then return end
  local n = tonumber(msg:match("(%d+) experience"))
  if n and n > 0 then
    killXP[#killXP + 1] = n
    if #killXP > 5 then table.remove(killXP, 1) end
  end
end)

local xpAcc = 10
local function UpdateXP(e)
  xpAcc = xpAcc + e
  if xpAcc < 1 then return end
  xpAcc = 0
  local cur, max = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  local level = Plain(UnitLevel("player")) or 1
  if not cur or not max or max <= 0 then xpBar:Hide(); return end
  local n = HeartCountAt(level)
  local rows = n > 10 and 2 or 1
  xpBar:ClearAllPoints()
  xpBar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -(rows * 22) - 13)
  xpBar:SetSize(math.min(n, 10) * 22 - 2, 4)
  xpBar:SetMinMaxValues(0, max)
  xpBar:SetValue(cur)
  local text = "Lv " .. level .. "  " .. math.floor(cur / max * 100) .. "%"
  if #killXP > 0 then
    local sum = 0
    for i = 1, #killXP do sum = sum + killXP[i] end
    local kills = math.ceil((max - cur) / (sum / #killXP))
    text = text .. "  ~" .. kills .. " kill" .. (kills == 1 and "" or "s")
  end
  xpBar.text:SetText(text)
  xpBar:Show()
end

-- ---------- elite warning on the target arrow ----------
local eliteTarget = false
local ELITE = { elite = true, rareelite = true, rare = true, worldboss = true }
O.On("PLAYER_TARGET_CHANGED", function()
  eliteTarget = false
  if Plain(UnitExists("target")) and Plain(UnitCanAttack("player", "target")) then
    local class = Plain(UnitClassification("target"))
    eliteTarget = class and ELITE[class] or false
  end
  local arrow = O.arrow
  if arrow then
    arrow:SetSize(eliteTarget and 38 or 26, eliteTarget and 38 or 26)
    if eliteTarget then arrow.tex:SetVertexColor(1, 0.35, 0.3) else arrow.tex:SetVertexColor(1, 1, 1) end
  end
end)

-- ---------- owl helper ----------
local owl = CreateFrame("Frame", "OwlHUDOwl", anchor)
owl:SetSize(260, 28)
owl:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
owl.icon = owl:CreateTexture(nil, "ARTWORK")
owl.icon:SetSize(28, 28)
owl.icon:SetPoint("LEFT", owl, "LEFT", 0, 0)
owl.icon:SetTexture(MEDIA .. "owl.tga")
owl.text = owl:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
owl.text:SetPoint("LEFT", owl.icon, "RIGHT", 6, 0)
owl.text:SetJustifyH("LEFT")

local function FreeBagSlots()
  local free = 0
  for bag = 0, 4 do
    local n
    if C_Container and C_Container.GetContainerNumFreeSlots then n = C_Container.GetContainerNumFreeSlots(bag)
    elseif GetContainerNumFreeSlots then n = GetContainerNumFreeSlots(bag) end
    free = free + (Plain(n) or 0)
  end
  return free
end
local function LowestDurability()
  local lowest = 1
  if not GetInventoryItemDurability then return lowest end
  for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    cur, max = Plain(cur), Plain(max)
    if cur and max and max > 0 and cur / max < lowest then lowest = cur / max end
  end
  return lowest
end
local function TalentPoints()
  if UnitCharacterPoints then
    local ok, points = pcall(UnitCharacterPoints, "player")
    if ok then return Plain(points) or 0 end
  end
  -- this game keeps talents the newer way
  if GetNumUnspentTalents then
    local ok, points = pcall(GetNumUnspentTalents)
    if ok and type(Plain(points)) == "number" then return Plain(points) end
  end
  return 0
end
local function ManaPercent()
  if not (UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100) then return nil end
  local ok, pct = pcall(UnitPowerPercent, "player", 0, false, CurveConstants.ScaleTo100)
  if ok then return Plain(pct) end
  return nil
end

O.On("TRAINER_SHOW", function() OwlHUDDB.trainerDue = nil end)

local function PickTip()
  if eliteTarget then return "Careful, that one is elite." end
  if Plain(UnitAffectingCombat("player")) then return nil end
  if LowestDurability() < 0.25 then return "Your gear needs repair." end
  if FreeBagSlots() <= 2 then return "Bags are almost full." end
  if Plain(UnitExists("target")) and Plain(UnitCanAttack("player", "target")) then
    local mana = ManaPercent()
    if mana and mana < 50 then return "Low mana for a fight. Drink first." end
  end
  if OwlHUDDB.trainerDue then return "New level. Visit your trainer." end
  if TalentPoints() > 0 then return "You have a talent point to spend." end
  return nil
end

local owlAcc, owlBob, owlTip = 10, 0, nil
local function UpdateOwl(e)
  if not OwlHUDDB.tips then owl:Hide(); return end
  owl:Show()
  owlAcc = owlAcc + e
  if owlAcc >= 1 then
    owlAcc = 0
    local tip = PickTip()
    if tip ~= owlTip then
      owlTip = tip
      owl.text:SetText(tip or "")
      if tip then Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856) end
    end
    owl.icon:SetAlpha(tip and 1 or 0.4)
  end
  if owlTip then
    owlBob = owlBob + e
    owl.icon:ClearAllPoints()
    owl.icon:SetPoint("LEFT", owl, "LEFT", 0, 2 * math.sin(owlBob * 4))
  end
end

-- ---------- wallet gem colour by wealth ----------
local gemAcc, gemTier = 10, nil
local TIERS = {
  { 1000000, 0.75, 0.35, 1.0 },  -- 100g+: purple
  { 100000, 1.0, 0.3, 0.3 },     -- 10g+: red
  { 10000, 0.35, 0.6, 1.0 },     -- 1g+: blue
  { 0, 0.3, 0.9, 0.4 },          -- green
}
local function UpdateGem(e)
  gemAcc = gemAcc + e
  if gemAcc < 3 then return end
  gemAcc = 0
  local gem = OwlHUDDial and OwlHUDDial.gem
  if not gem then return end
  local money = Plain(GetMoney()) or 0
  for i = 1, #TIERS do
    local t = TIERS[i]
    if money >= t[1] then
      if gemTier ~= i then
        gemTier = i
        gem:SetTexture(MEDIA .. "gem_white.tga")
        gem:SetVertexColor(t[2], t[3], t[4])
      end
      break
    end
  end
end

-- ---------- event cards ----------
O.On("PLAYER_LEVEL_UP", function(level)
  if not OwlHUDDB.classic then return end
  level = Plain(level) or (Plain(UnitLevel("player")) or 1)
  local newHeart = HeartCountAt(level) > HeartCountAt(level - 1)
  Card("Level Up", "Level " .. level .. (newHeart and "   -   a new heart!" or ""))
  if newHeart then Sound("IG_QUEST_LIST_COMPLETE", 878) end
  if level % 2 == 0 then OwlHUDDB.trainerDue = true end
  if C_Timer and C_Timer.After and Screenshot then
    C_Timer.After(1.5, function() pcall(Screenshot) end)
  end
end)

O.On("QUEST_TURNED_IN", function(questID)
  if not OwlHUDDB.classic then return end
  local title
  questID = Plain(questID)
  if questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questID)
    if ok then title = Plain(t) end
  end
  Card("Quest Complete", title)
end)

local lastDiscovery, lastDiscoveryAt = nil, 0
local function Discovery(a, b)
  if not OwlHUDDB.classic then return end
  local msg = Plain(b)
  if type(msg) ~= "string" then msg = Plain(a) end
  if type(msg) ~= "string" then return end
  local name = msg:match("^Discovered: (.+)$") or msg:match("^Discovered (.-):")
  if not name then return end
  if name == lastDiscovery and GetTime() - lastDiscoveryAt < 3 then return end
  lastDiscovery, lastDiscoveryAt = name, GetTime()
  Card("Discovered", name)
end
O.On("UI_INFO_MESSAGE", Discovery)
O.On("CHAT_MSG_SYSTEM", Discovery)

O.On("PLAYER_DEAD", function()
  if OwlHUDDB.classic then Card("You Have Fallen", "Rise again, " .. tostring((UnitClass("player")) or "hero"):lower()) end
end)

-- ---------- driver ----------
local features = {
  { name = "cards", fn = UpdateCards },
  { name = "XP bar", fn = UpdateXP },
  { name = "gem", fn = UpdateGem },
}
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, e)
  if not OwlHUDDB.classic then return end
  for i = 1, #features do
    local f = features[i]
    if not f.dead then
      local ok, err = pcall(f.fn, e)
      if not ok then
        f.dead = true
        O.Print("|cffff4040journey " .. f.name .. " turned off:|r " .. tostring(err))
      end
    end
  end
end)

O.commands.tips = function()
  OwlHUDDB.tips = not OwlHUDDB.tips
  O.Print("owl tips" .. (OwlHUDDB.tips and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- =====================================================================================
-- The owl, on his own: a pop-up companion who talks.
-- He slides in beside your character, types out a line, and leaves. Lines come from what is
-- happening (levels, targets, gear, quests, places, time played) plus idle chatter.
-- Nothing here does arithmetic on combat-hidden values: checks run on plain values only.
-- =====================================================================================
O.defaults.chatty = "normal"
owl:Hide()

-- a global function called safely: nil when it is missing, fails, or returns a hidden value
local function Q(name, ...)
  local fn = _G[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return Plain(a), Plain(b)
end

-- who is playing: lines differ for a Paladin, and for each side of the war
local CLASS_NAME, CLASS = UnitClass("player")
if type(CLASS) ~= "string" then CLASS = "" end
if type(CLASS_NAME) ~= "string" then CLASS_NAME = "hero" end
local HERO = CLASS_NAME:lower()
local FACTION = Q("UnitFactionGroup", "player")
local ENEMY = FACTION == "Horde" and "Alliance" or "Horde"
local function P(paladin, other)
  if CLASS == "PALADIN" then return paladin end
  return other
end

local pal = CreateFrame("Frame", "OwlHUDPal", UIParent)
pal:SetSize(390, 60)
pal:SetPoint("CENTER", UIParent, "CENTER", -430, -40)
pal:SetFrameStrata("HIGH")
pal:SetMovable(true)
pal:SetClampedToScreen(true)
pal:RegisterForDrag("LeftButton")
pal:SetScript("OnDragStart", function(f) if O.unlocked then f:StartMoving() end end)
pal:SetScript("OnDragStop", function(f)
  f:StopMovingOrSizing()
  local p, _, rp, x, y = f:GetPoint()
  OwlHUDDB.palPos = { p, rp, x, y }
end)
pal.mover = pal:CreateTexture(nil, "BACKGROUND")
pal.mover:SetAllPoints()
pal.mover:SetColorTexture(0, 1, 0, 0.18)
pal.mover:Hide()
pal.icon = pal:CreateTexture(nil, "ARTWORK")
pal.icon:SetSize(80, 80)
pal.icon:SetPoint("CENTER", pal, "LEFT", 28, 0)
pal.icon:SetTexture(MEDIA .. "owl.tga")
pal.bubble = CreateFrame("Frame", nil, pal)
pal.bubble:SetPoint("LEFT", pal, "LEFT", 66, 0)
pal.bubble:SetSize(320, 48)
pal.bubble.bg = pal.bubble:CreateTexture(nil, "BACKGROUND")
pal.bubble.bg:SetAllPoints()
pal.bubble.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9)
for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
  local line = pal.bubble:CreateTexture(nil, "BORDER")
  line:SetColorTexture(0.89, 0.7, 0.29, 0.95)
  pal.bubble.lines = pal.bubble.lines or {}
  pal.bubble.lines[#pal.bubble.lines + 1] = line
  if side == "TOP" or side == "BOTTOM" then
    line:SetPoint(side .. "LEFT", pal.bubble, side .. "LEFT", 0, 0)
    line:SetPoint(side .. "RIGHT", pal.bubble, side .. "RIGHT", 0, 0)
    line:SetHeight(2)
  else
    line:SetPoint("TOP" .. side, pal.bubble, "TOP" .. side, 0, 0)
    line:SetPoint("BOTTOM" .. side, pal.bubble, "BOTTOM" .. side, 0, 0)
    line:SetWidth(2)
  end
end
pal.name = pal.bubble:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pal.name:SetPoint("TOPLEFT", pal.bubble, "TOPLEFT", 10, -6)
pal.name:SetText("Owl")
pal.text = pal.bubble:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pal.text:SetPoint("TOPLEFT", pal.bubble, "TOPLEFT", 10, -21)
pal.text:SetWidth(300)
pal.text:SetJustifyH("LEFT")
if pal.text.SetWordWrap then pal.text:SetWordWrap(true) end
pal:Hide()

-- ---------- saying things ----------
local queue, lastSaid, cur, gapUntil = {}, {}, nil, 0
local TYPE_SPEED = 45

-- flags: "u" urgent (jumps the queue, own sound), "c" may show during a fight
local function Say(key, lines, cooldown, flags)
  if not OwlHUDDB.tips then return false end
  local now = GetTime()
  if lastSaid[key] and now - lastSaid[key] < (cooldown or 120) then return false end
  local text = lines
  if type(lines) == "table" then text = lines[math.random(#lines)] end
  if type(text) ~= "string" or text == "" then return false end
  local urgent = flags and flags:find("u", 1, true) and true or false
  if #queue >= 5 then
    -- full: an urgent line, or a fight line during a fight, takes the place of the newest small talk
    local fightLine = flags and flags:find("c", 1, true) and Plain(UnitAffectingCombat("player"))
    if not urgent and not fightLine then return false end
    table.remove(queue)
  end
  lastSaid[key] = now
  local item = { text = text, urgent = urgent, combat = flags and flags:find("c", 1, true) and true or false, at = now }
  if urgent then table.insert(queue, 1, item) else queue[#queue + 1] = item end
  return true
end
O.OwlSay = Say

local function Step(e)
  if O.unlocked then return end
  local now = GetTime()
  if not cur then
    local item = queue[1]
    if not item or now < gapUntil then return end
    if Plain(UnitAffectingCombat("player")) and not (item.urgent or item.combat) then
      -- in a fight, a line that is allowed in fights goes ahead of the small talk
      for i = 2, #queue do
        if queue[i].urgent or queue[i].combat then
          item = table.remove(queue, i)
          table.insert(queue, 1, item)
          break
        end
      end
      if not (item.urgent or item.combat) then
        if now - item.at > 45 then table.remove(queue, 1) end
        return
      end
    end
    table.remove(queue, 1)
    if now - item.at > 90 then return end
    cur = { text = item.text, t = 0, n = -1, hold = 3.2 + #item.text * 0.045, typing = #item.text / TYPE_SPEED }
    pal.text:SetText(item.text)
    local h = pal.text.GetStringHeight and Plain(pal.text:GetStringHeight())
    if type(h) ~= "number" then h = 14 end
    pal.bubble:SetHeight(math.max(46, h + 31))
    pal.text:SetText("")
    pal:SetAlpha(0)
    pal:Show()
    if item.urgent then
      if OwlHUDDB.sound then pcall(PlaySound, 3081, "Master") end
    else
      Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
    end
    return
  end
  cur.t = cur.t + e
  local t = cur.t
  local leaveAt = 0.2 + cur.typing + cur.hold
  local alpha = 1
  if t < 0.2 then alpha = t / 0.2 elseif t > leaveAt then alpha = 1 - (t - leaveAt) / 0.5 end
  if t > leaveAt and alpha <= 0 then
    pal:Hide()
    cur = nil
    gapUntil = now + 1.2
    return
  end
  pal:SetAlpha(math.max(0, math.min(1, alpha)))
  local n = math.floor((t - 0.1) * TYPE_SPEED)
  if n < 0 then n = 0 elseif n > #cur.text then n = #cur.text end
  if n ~= cur.n then
    cur.n = n
    pal.text:SetText(cur.text:sub(1, n))
  end
  pal.bob = (t < cur.typing + 0.3) and 3 * math.sin(t * 14) or 0
  if not O.OwlPlaces then
    pal.icon:ClearAllPoints()
    pal.icon:SetPoint("CENTER", pal, "LEFT", 28, pal.bob)
  end
end

-- ---------- what he knows ----------
local WARHORSE = FACTION == "Horde" and "ask your Paladin trainer about the warhorse quest" or "see Duthorian Rall in the Stormwind Cathedral"
local LEVEL_LINES_PALADIN = {
  [28] = "Level 28! Last point in Two-Handed Weapon Specialization. Trainer: Holy Strike and Exorcism.",
  [29] = "Level 29! Finish Conviction with this point.",
  [30] = "Level 30! Vengeance opens up. Big trainer visit: Seal of Command rank 2 and more.",
  [31] = "Level 31! Second point in Vengeance.",
  [32] = "Level 32! Finish Vengeance. Trainer has a new Blessing of Might.",
  [33] = "Level 33! Repentance: a new button, and the key to the last talent.",
  [34] = "Level 34! One point in Vindication. Trainer: Divine Shield, the real bubble!",
  [35] = "Level 35! Champion of the Light, first of five.",
  [36] = "Level 36! Champion of the Light again.",
  [37] = "Level 37! Champion of the Light, third point.",
  [38] = "Level 38! Champion of the Light, almost done.",
  [39] = "Level 39! Last point in Champion of the Light. One level to your free warhorse.",
  [40] = "Level 40! Unsealed Wrath, plate armor, and a free warhorse: " .. WARHORSE .. ".",
  [41] = "Level 41! Over to the Holy tree: Divine Strength.",
  [50] = "Level 50! Ten to go.",
  [60] = "Level 60. You did it. I am proud of you.",
}
local LEVEL_LINES = P(LEVEL_LINES_PALADIN, {
  [10] = "Level 10! Talents open up. Pick what makes your main attack stronger.",
  [20] = "Level 20! Lots of new ranks at the trainer.",
  [30] = "Level 30! Halfway, give or take.",
  [40] = "Level 40! Mount time. What a day.",
  [50] = "Level 50! Ten to go.",
  [60] = "Level 60. You did it. I am proud of you.",
})

local ZONE_LINES = {
  ["Duskwood"] = { P("Duskwood. Plenty of undead here: Exorcism likes that.", "Duskwood. Plenty of undead here. Mind the graveyards."), "Dark woods. Stay near the road at night.", "Duskwood. I feel right at home." },
  ["Elwynn Forest"] = { "Elwynn. Peaceful. Almost suspicious.", "Home turf." },
  ["Westfall"] = { "Westfall. Mind the harvest golems.", "Westfall. Dry, dusty, full of bandits." },
  ["Redridge Mountains"] = { "Redridge. The gnolls never learn.", "Redridge. Nice lake, shame about the orcs." },
  ["Stormwind City"] = { "Stormwind! Trainer, bank and auction house are all here.", "The big city. Repair while you are here." },
  ["Ironforge"] = { "Ironforge. Warm in here.", "Ironforge. The auction house is by the gates." },
  ["Darnassus"] = { "Darnassus. So many trees. I approve." },
  ["Wetlands"] = { "Wetlands. Crocolisks bite. Menethil Harbor is the safe spot.", "Wetlands. Watch your step, it is all swamp." },
  ["Loch Modan"] = { "Loch Modan. Good fishing, I hear." },
  ["Stranglethorn Vale"] = { "Stranglethorn. Beautiful, and everything wants to eat you.", "Jungle. " .. ENEMY .. " players hunt here too. Eyes open." },
  ["Darkshore"] = { "Darkshore. Long coast, long walks." },
  ["Ashenvale"] = { (FACTION == "Horde" and "Ashenvale. The west side belongs to the Alliance. Careful." or "Ashenvale. The east side belongs to the Horde. Careful."), "Ashenvale. Old forest. My kind of place." },
  ["Hillsbrad Foothills"] = { "Hillsbrad. The " .. ENEMY .. " likes this place too. Stay sharp." },
  ["Arathi Highlands"] = { "Arathi. Wide open. You can see trouble coming." },
  ["Dun Morogh"] = { "Dun Morogh. Cold feet. Literally." },
  ["Alterac Mountains"] = { "Alterac. Ogres up here hit hard." },
  ["Thousand Needles"] = { "Thousand Needles. Do not look down." },
  ["Desolace"] = { "Desolace. Cheerful name, cheerful place." },
  ["Swamp of Sorrows"] = { "Swamp of Sorrows. They were not joking." },
  ["Badlands"] = { "Badlands. Hot, dry, and full of ogres." },
  ["The Stockade"] = { "The Stockade. Stun the runners!" },
  ["The Deadmines"] = { "The Deadmines. Watch for patrols." },
  ["Gnomeregan"] = { "Gnomeregan. Long dungeon. I hope you have bag space." },
  ["Blackfathom Deeps"] = { "Blackfathom Deeps. Hold your breath." },
  ["Scarlet Monastery"] = { "Scarlet Monastery. They do not like visitors." },
  ["Orgrimmar"] = { "Orgrimmar! Trainer, bank and auction house are all here.", "The big city. Repair while you are here." },
  ["Thunder Bluff"] = { "Thunder Bluff. Mind the edge." },
  ["Undercity"] = { "Undercity. Cozy, in a damp sort of way." },
  ["Durotar"] = { "Durotar. Red rock and scorpids." },
  ["Mulgore"] = { "Mulgore. Open sky. I like it here." },
  ["Tirisfal Glades"] = { "Tirisfal. Gloomy. I feel right at home." },
  ["The Barrens"] = { "The Barrens. It goes on for a while.", "The Barrens. Watch the horizon." },
  ["Silverpine Forest"] = { "Silverpine. Something howls here at night. Not me." },
  ["Stonetalon Mountains"] = { "Stonetalon. Good perches up here." },
  ["Ragefire Chasm"] = { "Ragefire Chasm. Warm. Too warm." },
  ["Wailing Caverns"] = { "Wailing Caverns. Easy to get lost. Stay together." },
  ["Shadowfang Keep"] = { "Shadowfang Keep. Do not split up." },
  ["Razorfen Kraul"] = { "Razorfen Kraul. Thorns everywhere." },
}

local IDLE_COMMON = {
  "Type /owl unlock and you can drag me anywhere.",
  "Too talkative? /owl chatty changes how much I say.",
  "Rest at an inn before you log off. Rested XP is free XP.",
  "Grey junk in your bags gets sold for you at any vendor.",
  "Bandages still work when everything else is on cooldown.",
  "If a fight looks bad, it is fine to walk away.",
  "Check the auction house for a weapon every few levels.",
  "A weapon upgrade beats almost any armor upgrade.",
  "On your target bar, an orange or red level means it is above you.",
  "Click me to skip what I am saying. Right-click and I will hush for a while.",
  "/owl ask, if you ever want my advice.",
  "/owl journal. I have been taking notes.",
  "Hoo.",
  "Hoo hoo.",
  "I counted the stars. Lost track at twelve.",
  "You swing, I supervise. Good system.",
  "I would help carry things, but: wings.",
  "Nice cape, by the way.",
  "Quiet out here. I like it.",
  "Whoo is a good " .. HERO .. "? You are.",
  "I blinked. Did I miss anything?",
  "Do you ever just look at the sky? No? Only me?",
  "That last swing was very heroic. Ten out of ten.",
  "I had a mouse earlier. No reason. Just sharing.",
  "If we get lost, I am blaming the map.",
  "Somewhere, a murloc is planning something. I can feel it.",
}
local CLASS_TIPS = {
  PALADIN = {
    "Stun first, then Judgement. It hits harder on a stunned enemy.",
    "Consecration is for two or more enemies. Save the mana otherwise.",
    "Seal of Command likes slow, heavy weapons.",
    "If something runs away, Hammer of Justice.",
    "Lay on Hands is your full heal, and in Forever it is back every 20 minutes. Use it.",
    "Judgement does not eat your seal any more. One seal, many Judgements.",
    "Your blessings last an hour now. Cast once and forget about it.",
    "Exorcism only works on undead and demons.",
    "Divine Protection first, then heal. In that order.",
    "Purify clears poison and disease.",
    "Blessing of Protection goes on the healer, never the tank.",
    "Spell damage on gear helps you too. Your seal hits with holy damage.",
  },
  WARRIOR = {
    "Rage comes from hitting and being hit. Keep swinging.",
    "Charge to open, then Rend on anything that will live a while.",
    "Battle Shout before the fight, not during.",
    "Hamstring stops runners.",
    "Eat between fights. You have no heals of your own.",
  },
  ROGUE = {
    "Open from stealth whenever you can.",
    "Slice and Dice early, Eviscerate to finish.",
    "Gouge and Kick stop casters.",
    "Vanish is your way out. Do not waste it.",
    "Keep your poisons fresh.",
  },
  HUNTER = {
    "Let your pet get hit first. That is what it is for.",
    "Feed your pet. A happy pet hits harder.",
    "Stay at range. You are weakest up close.",
    "Hunter's Mark on anything that will take a while.",
    "A trap at your feet saves you when something gets close.",
  },
  MAGE = {
    "Frost Nova, step back, then cast.",
    "Polymorph one, fight the other.",
    "Conjure food and water before you need them.",
    "Counterspell stops a heal.",
    "Blink gets you out of a stun.",
  },
  WARLOCK = {
    "Send your pet in first.",
    "Dots on everything, then wand or Shadow Bolt.",
    "Life Tap turns health into mana. Drain Life gets it back.",
    "Keep a Soul Shard or three in your bags.",
    "Fear one, fight the other. Mind where it runs.",
  },
  PRIEST = {
    "Shield first, then fight.",
    "Wands are cheap damage. Use one.",
    "Shadow Word: Pain on everything.",
    "Psychic Scream when too many get close.",
    "In a group, your mana is the group's health bar.",
  },
  DRUID = {
    "Bear form when things hit hard, cat form when they do not.",
    "Rejuvenation before the fight keeps you topped up.",
    "You can heal yourself out of form. Shift out, heal, shift back.",
    "Entangling Roots holds one enemy while you deal with another.",
    "Travel form the moment you get it.",
  },
  SHAMAN = {
    "Drop your totems before a big fight.",
    "Earth Shock interrupts a cast.",
    "Keep your weapon enchant up. It runs out.",
    "Lightning Shield and go.",
    "Ghost Wolf saves a lot of walking.",
  },
}
local IDLE_LINES = {}
for _, line in ipairs(IDLE_COMMON) do IDLE_LINES[#IDLE_LINES + 1] = line end
for _, line in ipairs(CLASS_TIPS[CLASS] or {}) do IDLE_LINES[#IDLE_LINES + 1] = line end

local CHATTY = { quiet = nil, normal = { 540, 840 }, chatty = { 240, 420 } }
local CHATTY_NEXT = { quiet = "normal", normal = "chatty", chatty = "quiet" }
local GOLD_STEPS = { 1, 5, 10, 25, 50, 75, 100, 150, 200, 300, 500, 1000 }
local KILL_STEPS = { [25] = true, [50] = true, [100] = true, [150] = true, [200] = true, [300] = true, [500] = true }

local isPaladin = false
local sessionStart, nextIdle, kills, hoursSaid, lateSaid = 0, 0, 0, 0, false
local wasGrouped, wasAFK, wasResting = false, false, nil

local function ScheduleIdle()
  local range = CHATTY[OwlHUDDB.chatty or "normal"]
  if not range then nextIdle = math.huge; return end
  nextIdle = GetTime() + math.random(range[1], range[2])
end

local function Hour()
  if type(date) ~= "function" then return nil end
  local ok, h = pcall(date, "%H")
  return ok and tonumber(h) or nil
end

local function HealthPercent()
  if not (UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100) then return nil end
  local ok, pct = pcall(UnitHealthPercent, "player", true, CurveConstants.ScaleTo100)
  return ok and Plain(pct) or nil
end

-- seal / blessing / aura on you right now, and seconds left on the blessing; nil when unreadable
local function MyBuffs()
  if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then return nil end
  local seal, blessing, aura, blessingLeft = false, false, false, nil
  for i = 1, 40 do
    local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
    if not ok then return nil end
    if not data then break end
    local name = Plain(data.name)
    if type(name) == "string" then
      if name:find("Seal", 1, true) then seal = true
      elseif name:find("Blessing", 1, true) then
        blessing = true
        local ends = Plain(data.expirationTime)
        if type(ends) == "number" and ends > 0 then blessingLeft = ends - GetTime() end
      elseif name:find("Aura", 1, true) then aura = true end
    end
  end
  return seal, blessing, aura, blessingLeft
end

local function GreyLevel(mine)
  if mine <= 5 then return 0 end
  if mine <= 39 then return mine - math.floor(mine / 10) - 5 end
  if mine <= 59 then return mine - math.floor(mine / 5) - 1 end
  return mine - 9
end

-- ---------- slow checks, every few seconds, out of combat ----------
local checkAcc = 0
local function SlowChecks()
  local now = GetTime()
  if Plain(UnitAffectingCombat("player")) or Plain(UnitIsDeadOrGhost("player")) then return end

  local worn = LowestDurability()
  if worn < 0.1 then Say("dur10", { "Your gear is about to break! Repair now.", "Something you are wearing is nearly broken. Vendor, quickly." }, 300, "u")
  elseif worn < 0.25 then Say("dur25", { "Gear is getting worn. Repair at the next vendor.", "Your armor has seen better days. Repair soon." }, 600) end

  local free = FreeBagSlots()
  if free == 0 then Say("bags0", { "Bags are full! Nothing else will fit.", "No room left in your bags." }, 180, "u")
  elseif free <= 2 then Say("bags2", { "Bags are almost full.", "Two slots left. Time to sell or bank." }, 600) end

  if TalentPoints() > 0 then Say("talent", { "You have a talent point to spend.", "Unspent talent point. Free power, just sitting there." }, 600) end
  if OwlHUDDB.trainerDue then Say("trainer", { "New level: your trainer has something for you.", "Do not forget the trainer. New ranks are waiting." }, 900) end

  if isPaladin then
    local seal, blessing, aura, left = MyBuffs()
    if seal ~= nil then
      if not blessing then Say("noblessing", { "Your blessing is gone. Might, please.", "No blessing on you. Fix that before the next fight." }, 240)
      elseif left and left > 0 and left < 120 then Say("blessinglow", "Your blessing runs out in under two minutes.", 300) end
      if not aura then Say("noaura", { "No aura running. Retribution Aura!", "Your aura is off." }, 240) end
    end
  end

  local played = now - sessionStart
  local hours = math.floor(played / 3600)
  if hours > hoursSaid then
    hoursSaid = hours
    if hours == 1 then Say("played", "One hour in. Going well?", 0)
    elseif hours == 2 then Say("played", "Two hours. Stretch your hands and get some water.", 0)
    elseif hours == 3 then Say("played", "Three hours! Even owls take breaks.", 0)
    else Say("played", "Hour " .. hours .. ". I am impressed and slightly worried.", 0) end
  end
  if not lateSaid and played > 600 then
    local h = Hour()
    if h and h >= 1 and h < 5 then
      lateSaid = true
      Say("late", { "It is past 1 AM out there. Just saying.", "Very late. Even for an owl." }, 0)
    end
  end

  if now >= nextIdle and #queue == 0 and not cur and not Q("UnitIsAFK", "player") then
    -- two times in five he says something about you in particular (Owl.lua gathers it)
    local mine
    if O.OwlPersonal and math.random(5) <= 2 then
      local ok, text = pcall(O.OwlPersonal)
      if ok and type(text) == "string" then mine = text end
    end
    Say("idle", mine or IDLE_LINES, 0)
    ScheduleIdle()
  end
end

local palDriver = CreateFrame("Frame")
local palDead = false
palDriver:SetScript("OnUpdate", function(_, e)
  if palDead then return end
  local ok, err = pcall(function()
    Step(e)
    checkAcc = checkAcc + e
    if checkAcc >= 5 then
      checkAcc = 0
      if OwlHUDDB.tips then SlowChecks() end
    end
  end)
  if not ok then
    palDead = true
    pal:Hide()
    O.Print("|cffff4040owl turned off:|r " .. tostring(err))
  end
end)

-- ---------- things that happen ----------
O.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  isPaladin = class == "PALADIN"
  if OwlHUDDB.palPos then
    local p = OwlHUDDB.palPos
    pal:ClearAllPoints()
    pal:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
  sessionStart = GetTime()
  ScheduleIdle()
  local h = Hour()
  local hello
  if not h then hello = { "There you are. Shall we?", "Back at it. Good." }
  elseif h < 5 then hello = { "Night owl hours. My favorite.", "Still up? So am I." }
  elseif h < 12 then hello = { "Good morning. Shall we?", "Morning! The roads are waiting." }
  elseif h < 18 then hello = { "Good afternoon. Back at it.", "There you are. I kept your spot warm." }
  else hello = { "Good evening. The roads are waiting.", "Evening. Let us see what the night brings." } end
  Say("hello", hello, 0)
  local rested = Q("GetXPExhaustion")
  if type(rested) == "number" and rested > 0 then
    Say("rested", { "You are rested: bonus XP on kills for a while.", "Well rested. Kills are worth double until the blue bar runs out." }, 0)
  end
  if Q("HasNewMail") then Say("mail", "You have mail waiting.", 900) end
  local money = Plain(GetMoney())
  if type(money) == "number" and OwlHUDDB.owlGold == nil then
    local tier = 0
    for i = 1, #GOLD_STEPS do if money >= GOLD_STEPS[i] * 10000 then tier = i end end
    OwlHUDDB.owlGold = tier
  end
end)

O.On("PLAYER_LEVEL_UP", function(level)
  level = Plain(level) or (Plain(UnitLevel("player")) or 1)
  local line = LEVEL_LINES[level]
  if not line then
    if level % 2 == 0 then line = "Level " .. level .. "! A talent point, and the trainer has new ranks."
    else line = "Level " .. level .. "! A talent point to spend." end
  end
  Say("level" .. level, line, 0, "uc")
end)

O.On("PLAYER_XP_UPDATE", function()
  local xp, max, level = Plain(UnitXP("player")), Plain(UnitXPMax("player")), Plain(UnitLevel("player"))
  if xp and max and level and max > 0 and xp / max >= 0.9 then
    Say("almost" .. level, { "Almost level " .. (level + 1) .. ". One good push.", "So close to " .. (level + 1) .. ". Keep going." }, 99999)
  end
end)

O.On("PLAYER_TARGET_CHANGED", function()
  if not Plain(UnitExists("target")) or not Plain(UnitCanAttack("player", "target")) then return end
  if Plain(UnitIsDeadOrGhost("target")) then return end
  local class = Plain(UnitClassification("target"))
  local level, mine = Plain(UnitLevel("target")), Plain(UnitLevel("player"))
  if class == "rareelite" then Say("rareelite", "Rare AND elite. Big prize, big teeth.", 60, "c")
  elseif class == "rare" then Say("rare", { "A rare one! Worth the kill.", "Ooh, a rare. Do not let it get away." }, 60, "c")
  elseif class == "worldboss" then Say("boss", "That is a boss. That is a very large boss.", 60, "c")
  elseif class == "elite" then Say("elite", { "Careful, that one is elite.", "Elite. Bring a friend or bring a plan." }, 90, "c") end
  if type(level) == "number" and type(mine) == "number" then
    if level <= 0 or level - mine >= 5 then
      Say("skull", { "That one is far above you. I would not.", "Way too strong. Walk away slowly." }, 60, "c")
    elseif level - mine >= 3 then
      Say("higher", "That is " .. (level - mine) .. " levels above you. " .. P("Stun early, heal early.", "Be careful."), 120, "c")
    elseif level <= GreyLevel(mine) and not Q("UnitIsPlayer", "target") then
      Say("grey", { "Too weak to give XP. Let it live.", "That one is not worth the swing." }, 300)
    end
  end
  if isPaladin and not Plain(UnitAffectingCombat("player")) then
    local seal = MyBuffs()
    if seal == false then Say("noseal", { "No seal up!", "Seal first, then swing." }, 25, "u") end
  end
end)

local function AfterFight()
  if Plain(UnitAffectingCombat("player")) or Plain(UnitIsDeadOrGhost("player")) then return end
  local hp = HealthPercent()
  local mana = ManaPercent()
  if hp and hp < 35 then
    Say("closecall", { "That was close. Heal up before the next one.", P("Phew. Holy Light, then onward.", "Phew. Catch your breath, then onward."), "Too close. Let us not do that again." }, 45)
  elseif mana and mana < 25 and (Plain(UnitPowerMax("player", 0)) or 0) > 0 then
    Say("lowmana", { "Mana is low. Sit and drink.", "Out of blue. Drink first." }, 90)
  elseif math.random(100) <= 12 then
    Say("praise", { "Clean fight.", "Textbook.", "They never stood a chance.", "Nicely done.", "I would clap, but: wings." }, 420)
  end
end
O.On("PLAYER_REGEN_ENABLED", function()
  if C_Timer and C_Timer.After then C_Timer.After(1.5, function() O.Try("owl after fight", AfterFight) end) end
end)

O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("dies", 1, true) then return end
  kills = kills + 1
  if KILL_STEPS[kills] then
    Say("kills" .. kills, { "That is " .. kills .. " kills this session.", kills .. " down. Who is counting? Me. I am." }, 0)
  end
end)

O.On("PLAYER_DEAD", function()
  Say("dead", { "Ouch. It happens to the best.", "Down, not out. Run back.", "I saw nothing. Nobody saw anything.", "We do not speak of this." }, 20, "uc")
end)
O.On("PLAYER_UNGHOST", function()
  Say("alive", P({ "Back on your feet. Blessing, aura, seal.", "Welcome back. Find Herbs turned off when you died, check it.", "Good as new. Rebuff before you pull." }, { "Back on your feet.", "Welcome back. Any tracking you had on is off now, check it.", "Good as new. Rebuff before you pull." }), 20)
end)

O.On("PLAYER_MONEY", function()
  local money = Plain(GetMoney())
  if type(money) ~= "number" or OwlHUDDB.owlGold == nil then return end
  local tier = 0
  for i = 1, #GOLD_STEPS do if money >= GOLD_STEPS[i] * 10000 then tier = i end end
  if tier > OwlHUDDB.owlGold then
    OwlHUDDB.owlGold = tier
    Say("gold" .. tier, { GOLD_STEPS[tier] .. " gold! Look at you.", "You just passed " .. GOLD_STEPS[tier] .. " gold. Rich " .. HERO .. "." }, 0)
  end
end)

local lastZone
local function ZoneLine()
  local zone = Q("GetRealZoneText")
  if type(zone) ~= "string" or zone == "" or zone == lastZone then return end
  local first = lastZone == nil
  lastZone = zone
  if first then return end
  Say("zone" .. zone, ZONE_LINES[zone] or ("New ground: " .. zone .. ". Keep your eyes open."), 900)
end
O.On("ZONE_CHANGED_NEW_AREA", ZoneLine)

O.On("PLAYER_ENTERING_WORLD", function()
  ZoneLine()
  local inside, kind = Q("IsInInstance")
  if inside and kind == "party" then
    Say("dungeon", P({ "Dungeon time. Let the tank pull, stun the runners.", "In we go. Righteous Fury off unless you are tanking." }, { "Dungeon time. Let the tank pull first.", "In we go. Stay close to the group." }), 600)
  end
end)

O.On("PLAYER_UPDATE_RESTING", function()
  local resting = Q("IsResting") and true or false
  if wasResting ~= nil and resting and not wasResting then
    Say("resting", { "An inn. Good place to log off for rested XP.", "Safe and warm. I approve.", "Town. Repair, sell, restock." }, 900)
  end
  wasResting = resting
end)

O.On("UPDATE_PENDING_MAIL", function()
  if Q("HasNewMail") then Say("mail", { "You have mail.", "Something in the mailbox for you." }, 900) end
end)

-- Under water he used to speak every time you went under. Now he keeps quiet and only warns when about fifteen
-- seconds of air are left, and not at all if you come up before then.
O.breathRun = 0
O.On("MIRROR_TIMER_START", function(timer, value, _, scale)
  if Plain(timer) ~= "BREATH" then return end
  O.breathRun = O.breathRun + 1
  local mine = O.breathRun
  local lines = { "Watch your air!", "You cannot breathe down there. I checked." }
  value, scale = Plain(value), Plain(scale)
  -- the bar also restarts, counting up, when you surface: that is not a dive
  if type(scale) == "number" and scale >= 0 then return end
  if not (C_Timer and C_Timer.After) then Say("breath", lines, 600, "uc") return end
  local left = (type(value) == "number" and value > 0) and value / 1000 or 45
  C_Timer.After(math.max(left - 15, 0), function()
    if mine == O.breathRun then O.Try("owl breath", Say, "breath", lines, 90, "uc") end
  end)
end)
O.On("MIRROR_TIMER_STOP", function(timer) if Plain(timer) == "BREATH" then O.breathRun = O.breathRun + 1 end end)

O.On("PLAYER_FLAGS_CHANGED", function(unit)
  if Plain(unit) ~= "player" then return end
  local afk = Q("UnitIsAFK", "player") and true or false
  if afk and not wasAFK then Say("afk", { "I will keep watch.", "Take your time. I will be here." }, 120)
  elseif wasAFK and not afk then Say("back", { "There you are.", "Welcome back. Nothing ate you. I checked." }, 120) end
  wasAFK = afk
end)

O.On("GROUP_ROSTER_UPDATE", function()
  local grouped = Q("IsInGroup") and true or false
  if grouped and not wasGrouped then
    Say("group", P({ "Group time. Might for melee, Wisdom for casters.", "Friends! Buff everyone, and Righteous Fury off." }, { "Group time. Buff up and say hello.", "Friends! Stick together." }), 600)
  elseif wasGrouped and not grouped then
    Say("solo", { "Just us again.", "Back to the two of us." }, 600)
  end
  wasGrouped = grouped
end)

O.On("READY_CHECK", function()
  Say("ready", P("Ready check! Seal and blessing up?", "Ready check! Buffs up?"), 15, "uc")
end)

O.On("RESURRECT_REQUEST", function()
  Say("rez", "Someone is bringing you back. Say yes!", 15, "uc")
end)

O.On("QUEST_ACCEPTED", function(a, b)
  local title
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    for _, id in ipairs({ Plain(b), Plain(a) }) do
      if type(id) == "number" and not title then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and type(Plain(t)) == "string" then title = Plain(t) end
      end
    end
  end
  if title then Say("questnew", { "New quest: " .. title .. ".", title .. ". Sounds like work. Let us go." }, 25)
  else Say("questnew", { "A new quest. Let us see what they want.", "More work. Good." }, 25) end
end)

O.On("UI_INFO_MESSAGE", function(a, b)
  local msg = Plain(b)
  if type(msg) ~= "string" then msg = Plain(a) end
  if type(msg) ~= "string" then return end
  local what, have, need = msg:match("^(.-):%s*(%d+)%s*/%s*(%d+)")
  have, need = tonumber(have), tonumber(need)
  if not what or what == "" or not have or not need or need <= 0 then return end
  -- Owl.lua reads the quest log for the full picture: counts, what is left, where to hand in
  local function tell()
    if O.OwlObjective then
      local ok, handled = pcall(O.OwlObjective, what, have, need)
      if ok and handled then return end
    end
    if have == need then Say("obj" .. what, { "Done: " .. what .. ", " .. need .. " of " .. need .. ".", what .. ": " .. need .. " of " .. need .. ". Next!" }, 30) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.6, function() O.Try("owl objective", tell) end) else tell() end
end)

O.On("CHAT_MSG_LOOT", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("^You receive") then return end
  if msg:find("|cff0070dd", 1, true) or msg:find("|cffa335ee", 1, true) or msg:find("|cnIQ3", 1, true) or msg:find("|cnIQ4", 1, true) then
    Say("goodloot", { "Ooh. That is a good one.", "Shiny! Check it against what you are wearing.", "Now that is loot." }, 20)
  end
end)

O.On("CHAT_MSG_SKILL", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local skill, value = msg:match("skill in (.-) has increased to (%d+)")
  value = tonumber(value)
  if not skill or not value then return end
  if value == 70 or value == 145 or value == 220 then
    Say("skillcap" .. skill, skill .. " is at " .. value .. ". Train the next rank soon or it stops going up.", 0)
  elseif value % 25 == 0 then
    Say("skill" .. skill .. value, { skill .. " " .. value .. ". Getting good.", skill .. " hit " .. value .. "." }, 0)
  end
end)

-- ---------- moving him, and how much he talks ----------
table.insert(O.unlockHooks, function(unlocked)
  pal:EnableMouse(unlocked)
  if unlocked then
    cur = nil
    pal.mover:Show()
    pal.bubble:SetHeight(46)
    pal.text:SetText("Drag me wherever you like.")
    pal:SetAlpha(1)
    pal:Show()
  else
    pal.mover:Hide()
    pal:Hide()
  end
end)

O.commands.chatty = function()
  OwlHUDDB.chatty = CHATTY_NEXT[OwlHUDDB.chatty or "normal"] or "normal"
  ScheduleIdle()
  local words = { quiet = "quiet: only when something happens", normal = "normal: a remark every 10 minutes or so", chatty = "chatty: a remark every 5 minutes or so" }
  O.Print("owl is " .. words[OwlHUDDB.chatty] .. ".")
end

O.commands.hoot = function()
  if not OwlHUDDB.tips then O.Print("the owl is off. /owl tips turns him on."); return end
  lastSaid.hoot = nil
  Say("hoot", IDLE_LINES, 0, "c")
end

-- =====================================================================================
-- The owl, part two: faces for his moods, clicking him, and "ask the owl".
-- =====================================================================================
local FACES = { happy = "owl_happy.tga", worried = "owl_worried.tga", sleepy = "owl_sleepy.tga", excited = "owl_excited.tga" }
-- the face that goes with a line, by how its key starts (first match wins)
local MOOD_BY_KEY = {
  { "level", "excited" }, { "gold", "excited" }, { "goodloot", "excited" }, { "rare", "excited" }, { "almost", "excited" },
  { "kills", "excited" }, { "skillcap", "worried" }, { "skill", "happy" },
  { "hello", "happy" }, { "praise", "happy" }, { "rested", "happy" }, { "obj", "happy" }, { "questnew", "happy" },
  { "group", "happy" }, { "back", "happy" }, { "alive", "happy" }, { "mail", "happy" }, { "zone", "happy" }, { "ask", "happy" },
  { "dead", "worried" }, { "closecall", "worried" }, { "lowmana", "worried" }, { "dur", "worried" }, { "bags", "worried" },
  { "skull", "worried" }, { "higher", "worried" }, { "elite", "worried" }, { "boss", "worried" }, { "breath", "worried" },
  { "noseal", "worried" }, { "noblessing", "worried" }, { "noaura", "worried" }, { "blessinglow", "worried" }, { "rez", "worried" },
  { "late", "sleepy" }, { "afk", "sleepy" }, { "resting", "sleepy" }, { "played", "sleepy" }, { "grey", "sleepy" },
}

local function MoodFor(key, text)
  if key == "idle" or key == "hoot" then
    if type(text) == "string" and text:find("^Hoo") then return "sleepy" end
    if math.random(3) == 1 then return "happy" end
    return nil
  end
  for i = 1, #MOOD_BY_KEY do
    local m = MOOD_BY_KEY[i]
    if key:sub(1, #m[1]) == m[1] then return m[2] end
  end
  return nil
end

local function SetFace(mood)
  if O.OwlMood then pcall(O.OwlMood, mood) end
  local file = FACES[mood or ""]
  if file then
    pal.icon:SetTexture(MEDIA .. file)
    -- a face picture the game has not loaded yet (no full restart since it was added): the plain owl
    local ok, shown = pcall(pal.icon.GetTexture, pal.icon)
    if ok and shown ~= nil then return end
  end
  pal.icon:SetTexture(MEDIA .. "owl.tga")
end

local hushUntil = 0
local baseSay = Say
Say = function(key, lines, cooldown, flags)
  local urgent = flags and flags:find("u", 1, true) and true or false
  if GetTime() < hushUntil and not urgent and key ~= "hoot" and key:sub(1, 3) ~= "ask" then return false end
  -- on a flight path he keeps quiet about what is on the ground (Owl.lua decides)
  if O.OwlGate then
    local okG, pass = pcall(O.OwlGate, key)
    if okG and pass == false then return false end
  end
  local voiced = false
  if O.OwlLines then
    local mine = O.OwlLines(key, lines)
    if mine then lines, voiced = mine, true end
  end
  -- more ways of saying the everyday things (Owl.lua)
  if O.OwlMore then
    local okM, more = pcall(O.OwlMore, key == "hoot" and "idle" or key, lines, voiced)
    if okM and more then lines = more end
  end
  -- his character (Owl.lua): a fresh choice of wording, and now and then an aside
  if O.OwlFlavor then
    local ok, flavoured = pcall(O.OwlFlavor, key, lines, flags)
    if ok and flavoured then lines = flavoured end
  end
  local said = baseSay(key, lines, cooldown, flags)
  if said then
    local item = urgent and queue[1] or queue[#queue]
    if item then
      item.mood = MoodFor(key, item.text)
      if O.OwlSaid then pcall(O.OwlSaid, item.text) end
    end
  end
  return said
end
O.OwlSay = Say

-- ---------- ask the owl ----------
local TALENT_PLAN = {
  { 28, "Two-Handed Weapon Specialization" }, { 29, "Conviction, the last point" }, { 32, "Vengeance" }, { 33, "Repentance" },
  { 34, "Vindication, one point only" }, { 39, "Champion of the Light" }, { 40, "Unsealed Wrath" },
  { 45, "Divine Strength, over in the Holy tree" }, { 50, "Improved Seals, in the Holy tree" },
}
local TRAINER_PLAN = {
  [28] = "Holy Strike and Exorcism", [30] = "Seal of Command, Consecration, Holy Light and Lay on Hands",
  [32] = "Blessing of Might", [34] = "Divine Shield and Flash of Light",
}
local ZONES_BY_LEVEL = {
  { 24, "Redridge and Duskwood", "The Stockade" },
  { 30, "Duskwood, then Wetlands", "Stockade, Blackfathom Deeps, and Gnomeregan from 29" },
  { 35, "Stranglethorn Vale and Arathi Highlands", "Gnomeregan and Scarlet Monastery" },
  { 40, "southern Stranglethorn, Desolace and Badlands", "Scarlet Monastery and Razorfen Downs" },
  { 45, "Tanaris, Feralas and Swamp of Sorrows", "Uldaman and Zul'Farrak" },
  { 50, "Tanaris, The Hinterlands and Searing Gorge", "Zul'Farrak and Maraudon" },
  { 55, "Un'Goro Crater, Felwood and Western Plaguelands", "Sunken Temple and Blackrock Depths" },
  { 60, "Eastern Plaguelands, Winterspring and Burning Steppes", "Blackrock Depths, Stratholme and Scholomance" },
}

local ANSWERS = {}
ANSWERS.talent = function(level)
  local out = {}
  for i = 1, #TALENT_PLAN do
    if level <= TALENT_PLAN[i][1] then
      out[1] = "At level " .. level .. " your point goes in " .. TALENT_PLAN[i][2] .. "."
      local nxt = TALENT_PLAN[i + 1]
      if nxt then out[2] = "After level " .. TALENT_PLAN[i][1] .. ": " .. nxt[2] .. "." end
      break
    end
  end
  if not out[1] then out[1] = "Past 50 the guides disagree. Time to ask around." end
  if TalentPoints() > 0 then out[#out + 1] = "And you have a point waiting right now." end
  return out
end
ANSWERS.trainer = function(level)
  local now, nxt = level - level % 2, level + 2 - level % 2
  local out = {}
  out[1] = "At " .. now .. ": " .. (TRAINER_PLAN[now] or "new ranks of whatever is on your fight bar") .. "."
  out[2] = "Next visit at " .. nxt .. ": " .. (TRAINER_PLAN[nxt] or "new ranks of your fight buttons") .. "."
  out[3] = "Skip new seals, other auras and Blessing of Wisdom."
  return out
end
ANSWERS.where = function(level)
  for i = 1, #ZONES_BY_LEVEL do
    local z = ZONES_BY_LEVEL[i]
    if level <= z[1] then
      return { "At " .. level .. ", quest in " .. z[2] .. ".", "Dungeons around now: " .. z[3] .. ".", "That is the old-world route. Forever added a few new places too." }
    end
  end
  return { "You are at the top. Dungeons and raids from here." }
end
ANSWERS.rotation = function()
  return { "Seal of Command up, once: Judgement no longer uses it. Judgement and Holy Strike whenever they are ready.", "Consecration only on two or more. Stun, then Judgement, for burst." }
end
ANSWERS.buttons = function()
  return { "Hold RT: A Judgement, X Holy Strike, Y Seal of Command, B Consecration.", "RT D-pad: left stun, up Holy Light, down Lay on Hands.", "Hold LT for blessings, your aura and the bubble." }
end
ANSWERS.group = function()
  return { "Might for melee, Wisdom for casters. Righteous Fury off.", "Let the tank hit first. Stun runners and casters.", "Protection on the healer, never the tank. Lay on Hands saves the tank." }
end
if FACTION == "Horde" then
  ZONES_BY_LEVEL[1] = { 24, "The Barrens and Stonetalon Mountains", "Wailing Caverns and Shadowfang Keep" }
  ZONES_BY_LEVEL[2] = { 30, "Hillsbrad Foothills, Ashenvale and Thousand Needles", "Shadowfang Keep, Blackfathom Deeps and Razorfen Kraul" }
  ZONES_BY_LEVEL[3] = { 35, "Stranglethorn Vale, Arathi Highlands and Desolace", "Razorfen Kraul and Scarlet Monastery" }
end
if CLASS ~= "PALADIN" then
  local ROTATION = {
    WARRIOR = "Charge in, Rend, then your hardest strike whenever you have the rage.",
    ROGUE = "Open from stealth, build combo points, Slice and Dice, then Eviscerate.",
    HUNTER = "Pet in first, Hunter's Mark, then shoot from range. Sting on long fights.",
    MAGE = "Frost Nova, step back, cast. Polymorph the extra one.",
    WARLOCK = "Pet in first, dots on everything, then Shadow Bolt or wand.",
    PRIEST = "Shield, Shadow Word: Pain, then Smite or wand.",
    DRUID = "Pick a form for the fight. Shift out to heal, then back in.",
    SHAMAN = "Totems down, Lightning Shield, shock, then swing.",
  }
  ANSWERS.talent = function()
    local out = { "I only know the Paladin tree by heart.", "A safe rule: first what makes your main attack hit harder, then what keeps you alive." }
    if TalentPoints() > 0 then out[#out + 1] = "And you have a point waiting right now." end
    return out
  end
  ANSWERS.trainer = function(level)
    return { "Your trainer has new ranks every even level. Next visit at " .. (level + 2 - level % 2) .. ".", "Buy the spells you press every fight first. The rest can wait." }
  end
  ANSWERS.rotation = function()
    return { ROTATION[CLASS] or "Use your strongest attack whenever it is ready, and keep your buffs up." }
  end
  ANSWERS.group = function()
    return { "Let the tank hit first.", "Attack what the tank is attacking. Do not pull extra.", "If the healer is in trouble, help the healer." }
  end
end
if Plain(UnitName("player")) ~= "Owlishi" then
  ANSWERS.buttons = function()
    return { "I do not know your button layout yet.", "Put what you press most where your thumb rests." }
  end
end
O.OwlAnswers, O.OwlClassTips = ANSWERS, CLASS_TIPS
local TOPICS = { { "talent", "Talent" }, { "trainer", "Trainer" }, { "where", "Where to go" }, { "rotation", "Rotation" }, { "buttons", "Buttons" }, { "group", "Group tips" } }

local menuOpen, menuAt = false, 0
local function EndLine()
  if cur then cur.t = math.max(cur.t, 0.2 + cur.typing + cur.hold) end
end
local function ShowPrompt()
  pal.bubble:SetHeight(46)
  pal.text:SetText("What do you want to know?")
  SetFace("happy")
  pal:SetAlpha(1)
  pal:Show()
end
local function CloseMenu()
  menuOpen = false
  pal.menu:Hide()
  if not cur and not O.unlocked then pal:Hide() end
end
local function OpenMenu()
  if O.unlocked then return end
  menuOpen, menuAt = true, GetTime()
  pal.menu:Show()
  if not cur then ShowPrompt() end
end

local function Answer(topic)
  local fn = ANSWERS[topic]
  if not fn then return false end
  if not OwlHUDDB.tips then O.Print("the owl is off. /owl tips turns him on."); return true end
  local lines = fn(Plain(UnitLevel("player")) or 1)
  for i = #queue, 1, -1 do queue[i] = nil end
  EndLine()
  gapUntil = 0
  menuAt = GetTime()
  for i = 1, #lines do
    lastSaid["ask" .. i] = nil
    Say("ask" .. i, lines[i], 0, "c")
  end
  return true
end

pal.menu = CreateFrame("Frame", nil, pal)
pal.menu:SetPoint("TOPLEFT", pal.bubble, "BOTTOMLEFT", 0, -4)
pal.menu:SetSize(320, 50)
pal.menu:Hide()
for i = 1, #TOPICS do
  local topic = TOPICS[i]
  local b = CreateFrame("Button", nil, pal.menu)
  b:SetSize(102, 22)
  b:SetPoint("TOPLEFT", pal.menu, "TOPLEFT", ((i - 1) % 3) * 109, -math.floor((i - 1) / 3) * 26)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9)
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
  b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
  b.edge:SetHeight(2)
  b.edge:SetColorTexture(0.89, 0.7, 0.29, 0.95)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
  b.label:SetText(topic[2])
  b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.28, 0.2, 0.06, 0.95) end)
  b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9) end)
  b:SetScript("OnClick", function() O.Try("owl answer", Answer, topic[1]) end)
end

-- ---------- his face follows the line; the menu keeps him on screen ----------
local baseStep = Step
Step = function(e)
  local head, was = queue[1], cur
  baseStep(e)
  if cur and cur ~= was then
    SetFace(head and head.mood)
  elseif was and not cur then
    SetFace(nil)
    menuAt = GetTime()
    if menuOpen and not O.unlocked then ShowPrompt() end
  end
  if menuOpen and not cur and #queue == 0 and GetTime() - menuAt > 45 then CloseMenu() end
end

-- ---------- clicking him: left ends the line, right hushes him for ten minutes ----------
pal:EnableMouse(true)
pal:SetScript("OnMouseUp", function(_, button)
  if O.unlocked then return end
  if button == "RightButton" then
    hushUntil = GetTime() + 600
    for i = #queue, 1, -1 do queue[i] = nil end
    EndLine()
    if menuOpen then CloseMenu() end
    O.Print("owl hushed for 10 minutes. /owl hoot wakes him.")
  elseif cur then
    EndLine()
  elseif menuOpen then
    CloseMenu()
  end
end)
table.insert(O.unlockHooks, function(unlocked)
  pal:EnableMouse(true)
  SetFace(nil)
  menuOpen = false
  pal.menu:Hide()
end)

local baseHoot = O.commands.hoot
O.commands.hoot = function()
  hushUntil = 0
  baseHoot()
end

O.commands.ask = function(arg)
  arg = (arg or ""):match("^(%S*)")
  if arg ~= "" then
    if not Answer(arg) then O.Print("ask about: talent, trainer, where, rotation, buttons, group. Or just /owl ask for the menu.") end
    return
  end
  if not OwlHUDDB.tips then O.Print("the owl is off. /owl tips turns him on."); return end
  if menuOpen then CloseMenu() else OpenMenu() end
end

-- ---------- for the rest of the owl (Owl.lua) ----------
O.Owl = {
  pal = pal, moods = MOOD_BY_KEY, Q = Q, class = CLASS, className = CLASS_NAME, hero = HERO, P = P,
  Say = function(...) return Say(...) end,
  Talking = function() return cur ~= nil end,
  Hush = function(seconds) hushUntil = GetTime() + seconds end,
  EndLine = EndLine,
  Ask = function() O.commands.ask("") end,
  FreeBagSlots = FreeBagSlots,
}
