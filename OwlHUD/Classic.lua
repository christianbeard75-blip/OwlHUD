-- OwlHUD classic look: heart row, magic meter, lock-on bars, item box, day dial, wallet, title cards.
-- Every piece is original art in Media\ and can be switched off with /owl classic.
local ADDON, O = ...
local MEDIA = "Interface\\AddOns\\OwlHUD\\Media\\"

O.defaults.classic = true

local function Sound(kitName, fallback)
  if not OwlHUDDB.sound then return end
  local id = (SOUNDKIT and SOUNDKIT[kitName]) or fallback
  if id then pcall(PlaySound, id, "Master") end
end

-- ---------- movable pieces ----------
local movers = {}
local function Movable(frame, key, label)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame.moverBG = frame:CreateTexture(nil, "BACKGROUND")
  frame.moverBG:SetAllPoints()
  frame.moverBG:SetColorTexture(0, 1, 0, 0.25)
  frame.moverBG:Hide()
  frame.moverLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.moverLabel:SetPoint("BOTTOM", frame, "TOP", 0, 2)
  frame.moverLabel:SetText(label)
  frame.moverLabel:Hide()
  frame:SetScript("OnDragStart", function(f) if O.unlocked then f:StartMoving() end end)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local p, _, rp, x, y = f:GetPoint()
    OwlHUDDB[key] = { p, rp, x, y }
  end)
  movers[#movers + 1] = { frame = frame, key = key }
end

-- ---------- hearts and magic meter ----------
local HEART, GAP, PER_ROW = 20, 2, 10
local hearts = CreateFrame("Frame", "OwlHUDHearts", UIParent)
hearts:SetSize(PER_ROW * (HEART + GAP), HEART * 2 + GAP + 12)
hearts:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
Movable(hearts, "heartsPos", "Hearts")

-- Health and mana are "secret" numbers in combat on this client: they can be handed to a
-- StatusBar but not calculated with. So each heart is its own small bar covering one slice of health.
local heartBars = {}
local function Heart(i)
  local h = heartBars[i]
  if h then return h end
  local row, col = math.floor((i - 1) / PER_ROW), (i - 1) % PER_ROW
  h = CreateFrame("StatusBar", nil, hearts)
  h:SetSize(HEART, HEART)
  h:SetPoint("TOPLEFT", hearts, "TOPLEFT", col * (HEART + GAP), -row * (HEART + GAP))
  h.empty = h:CreateTexture(nil, "BACKGROUND")
  h.empty:SetAllPoints()
  h.empty:SetTexture(MEDIA .. "heart_empty.tga")
  h:SetStatusBarTexture(MEDIA .. "heart_full.tga")
  h:SetMinMaxValues(0, 1)
  h:SetValue(1)
  heartBars[i] = h
  return h
end

local magic = CreateFrame("StatusBar", nil, hearts)
magic:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
magic:SetStatusBarColor(0.18, 0.85, 0.3, 1)
magic.bg = magic:CreateTexture(nil, "BACKGROUND")
magic.bg:SetPoint("TOPLEFT", -1, 1)
magic.bg:SetPoint("BOTTOMRIGHT", 1, -1)
magic.bg:SetColorTexture(0, 0, 0, 0.85)
magic:Hide()

local function HeartCount()
  local level = O.Plain(UnitLevel("player")) or 1
  return math.max(3, math.min(20, 3 + math.floor(level / 4)))
end

-- Health as a plain 0-100 number when the game allows it, otherwise nil.
local function HealthPercent()
  if not (UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100) then return nil end
  local ok, pct = pcall(UnitHealthPercent, "player", true, CurveConstants.ScaleTo100)
  if ok then return O.Plain(pct) end
  return nil
end

local heartAcc, beepAt, pulse = 0, 0, 0
local lastMax, lastN
local function UpdateHearts(e)
  heartAcc = heartAcc + e
  pulse = pulse + e
  local pct = HealthPercent()
  local dead = O.Plain(UnitIsDeadOrGhost("player"))
  local low = pct and pct > 0 and pct < 25 and not dead

  if low then
    hearts:SetAlpha(0.55 + 0.45 * math.abs(math.sin(pulse * 6)))
    if GetTime() - beepAt > 1.3 then
      beepAt = GetTime()
      Sound("MAP_PING", 3175)
    end
  else
    local busy = O.Plain(UnitAffectingCombat("player")) or (pct and pct < 100)
    hearts:SetAlpha(busy and 1 or 0.7)
  end

  if heartAcc < 0.1 then return end
  heartAcc = 0
  local n = HeartCount()
  local maxHP = O.Plain(UnitHealthMax("player"))
  if maxHP and maxHP > 0 and (maxHP ~= lastMax or n ~= lastN) then
    lastMax, lastN = maxHP, n
    for i = 1, 20 do
      if i <= n then
        local h = Heart(i)
        h:SetMinMaxValues((i - 1) * maxHP / n, i * maxHP / n)
        h:Show()
      elseif heartBars[i] then
        heartBars[i]:Hide()
      end
    end
  end
  if lastN then
    local hp = UnitHealth("player")
    for i = 1, lastN do
      pcall(heartBars[i].SetValue, heartBars[i], hp)
    end
  end

  local maxMana = UnitPowerMax("player", 0)
  if O.Plain(maxMana) == 0 then
    magic:Hide()
  else
    local rows = n > PER_ROW and 2 or 1
    magic:ClearAllPoints()
    magic:SetPoint("TOPLEFT", hearts, "TOPLEFT", 0, -(rows * (HEART + GAP)) - 2)
    magic:SetSize(math.min(n, PER_ROW) * (HEART + GAP) - GAP, 7)
    pcall(magic.SetMinMaxValues, magic, 0, maxMana)
    pcall(magic.SetValue, magic, UnitPower("player", 0))
    magic:Show()
  end
end

-- ---------- lock-on: thin bars and a bouncing arrow over the target ----------
local BAR_H = 30
local function MakeBar(top)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  if top then
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
  else
    f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
  end
  f:SetHeight(1)
  f.tex = f:CreateTexture(nil, "BACKGROUND")
  f.tex:SetAllPoints()
  f.tex:SetColorTexture(0, 0, 0, 0.9)
  f:Hide()
  return f
end
local barTop, barBottom = MakeBar(true), MakeBar(false)
local barCur = 0

local arrow = CreateFrame("Frame", nil, UIParent)
arrow:SetSize(26, 26)
arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
arrow.tex:SetAllPoints()
arrow.tex:SetTexture(MEDIA .. "arrow.tga")
arrow:Hide()
O.arrow = arrow
local bounce = 0

local function LockedOn()
  if not O.Plain(UnitExists("target")) then return false end
  return O.Plain(UnitCanAttack("player", "target")) and not O.Plain(UnitIsDeadOrGhost("target")) and true or false
end

local function UpdateLockOn(e)
  local locked = LockedOn()
  local goal = (locked and OwlHUDDB.barsOn) and BAR_H or 0
  barCur = barCur + (goal - barCur) * math.min(1, e * 10)
  if barCur < 0.5 then
    barTop:Hide(); barBottom:Hide()
  else
    barTop:SetHeight(barCur); barBottom:SetHeight(barCur)
    barTop:Show(); barBottom:Show()
  end

  local plate
  if locked and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    plate = C_NamePlate.GetNamePlateForUnit("target")
  end
  if plate then
    bounce = bounce + e
    arrow:ClearAllPoints()
    arrow:SetPoint("BOTTOM", plate, "TOP", 0, 8 + 6 * math.abs(math.sin(bounce * 5)))
    arrow:Show()
  else
    arrow:Hide()
  end
end

-- ---------- target and fight sounds ----------
local lastTargetSound = 0
O.On("PLAYER_TARGET_CHANGED", function()
  if not OwlHUDDB.classic or not LockedOn() then return end
  if GetTime() - lastTargetSound < 0.25 then return end
  lastTargetSound = GetTime()
  Sound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
end)
O.On("PLAYER_REGEN_DISABLED", function()
  if OwlHUDDB.classic then Sound("PVP_ENTER_QUEUE", 8458) end
end)

-- ---------- "You got it" box ----------
local box = CreateFrame("Frame", "OwlHUDItemBox", UIParent)
box:SetSize(380, 58)
box:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 235)
box:SetFrameStrata("HIGH")
box.edge = box:CreateTexture(nil, "BACKGROUND")
box.edge:SetPoint("TOPLEFT", -2, 2)
box.edge:SetPoint("BOTTOMRIGHT", 2, -2)
box.edge:SetColorTexture(0.85, 0.72, 0.35, 1)
box.fill = box:CreateTexture(nil, "BORDER")
box.fill:SetAllPoints()
box.fill:SetColorTexture(0.03, 0.04, 0.12, 0.95)
box.icon = box:CreateTexture(nil, "ARTWORK")
box.icon:SetSize(42, 42)
box.icon:SetPoint("LEFT", box, "LEFT", 8, 0)
box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
box.text:SetPoint("LEFT", box.icon, "RIGHT", 10, 0)
box.text:SetPoint("RIGHT", box, "RIGHT", -10, 0)
box.text:SetJustifyH("LEFT")
box:Hide()
Movable(box, "boxPos", "Item box")

local queue, boxT, boxActive = {}, 0, false
local function ItemIcon(link)
  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, link)
    if ok and icon then return icon end
  end
  if GetItemIcon then
    local ok, icon = pcall(GetItemIcon, link)
    if ok and icon then return icon end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function ItemQuality(link)
  local quality
  if C_Item and C_Item.GetItemInfo then quality = select(3, C_Item.GetItemInfo(link))
  elseif GetItemInfo then quality = select(3, GetItemInfo(link)) end
  return quality or 0
end

O.On("CHAT_MSG_LOOT", function(msg)
  if not OwlHUDDB.classic or type(msg) ~= "string" then return end
  if not msg:find("^You ") then return end
  local link = msg:match("(|c.-|Hitem:.-|h%[.-%]|h|r)") or msg:match("(|Hitem:.-|h%[.-%]|h)")
  if not link then return end
  if ItemQuality(link) < 2 then return end
  if #queue < 5 then queue[#queue + 1] = link end
end)

local function UpdateBox(e)
  if O.unlocked then return end
  if not boxActive then
    local link = table.remove(queue, 1)
    if not link then return end
    box.icon:SetTexture(ItemIcon(link))
    box.text:SetText("You got " .. link .. "!")
    boxActive, boxT = true, 0
    box:SetAlpha(0)
    box:Show()
    Sound("IG_QUEST_LIST_COMPLETE", 878)
    return
  end
  boxT = boxT + e
  if boxT < 0.25 then
    box:SetAlpha(boxT / 0.25)
  elseif boxT < 3.25 then
    box:SetAlpha(1)
  elseif boxT < 3.85 then
    box:SetAlpha(1 - (boxT - 3.25) / 0.6)
  else
    box:Hide()
    boxActive = false
  end
end

-- ---------- day dial and wallet ----------
local dial = CreateFrame("Frame", "OwlHUDDial", UIParent)
dial:SetSize(150, 70)
dial:SetPoint("TOP", UIParent, "TOP", -230, -6)
Movable(dial, "dialPos", "Clock and wallet")
dial.track = dial:CreateTexture(nil, "ARTWORK")
dial.track:SetColorTexture(1, 1, 1, 0.25)
dial.track:SetSize(120, 2)
dial.track:SetPoint("TOP", dial, "TOP", 0, -30)
dial.orb = dial:CreateTexture(nil, "OVERLAY")
dial.orb:SetSize(22, 22)
dial.time = dial:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dial.time:SetPoint("TOP", dial.track, "BOTTOM", 0, -3)
dial.gem = dial:CreateTexture(nil, "ARTWORK")
dial.gem:SetSize(14, 14)
dial.gem:SetTexture(MEDIA .. "gem.tga")
dial.gem:SetPoint("TOP", dial.time, "BOTTOM", -28, -4)
dial.money = dial:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dial.money:SetPoint("LEFT", dial.gem, "RIGHT", 4, 0)

local dialAcc, shownMoney, orbIsDay = 10, nil, nil
local function Wallet(copper)
  copper = math.floor(copper)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g > 0 then return g .. "g " .. s .. "s" end
  return s .. "s " .. (copper % 100) .. "c"
end
local function UpdateDial(e)
  local money = GetMoney() or 0
  if not shownMoney then shownMoney = money end
  if shownMoney ~= money then
    local step = (money - shownMoney) * math.min(1, e * 4)
    if math.abs(money - shownMoney) < 2 then shownMoney = money else shownMoney = shownMoney + step end
    dial.money:SetText(Wallet(shownMoney))
  end

  dialAcc = dialAcc + e
  if dialAcc < 5 then return end
  dialAcc = 0
  dial.money:SetText(Wallet(shownMoney))
  local hour, minute = GetGameTime()
  hour, minute = math.floor(hour or 12), math.floor(minute or 0)
  local t = hour + minute / 60
  local isDay = t >= 6 and t < 18
  local p = isDay and (t - 6) / 12 or ((t >= 18 and (t - 18) or (t + 6)) / 12)
  if orbIsDay ~= isDay then
    orbIsDay = isDay
    dial.orb:SetTexture(MEDIA .. (isDay and "sun.tga" or "moon.tga"))
  end
  dial.orb:ClearAllPoints()
  dial.orb:SetPoint("CENTER", dial.track, "LEFT", 120 * p, 4 + 14 * math.sin(math.pi * p))
  local h12 = hour % 12
  if h12 == 0 then h12 = 12 end
  dial.time:SetText(string.format("%d:%02d %s", h12, minute, hour < 12 and "AM" or "PM"))
end

-- ---------- title cards: new day on login, area name on entering a zone ----------
local card = CreateFrame("Frame", nil, UIParent)
card:SetSize(900, 110)
card:SetPoint("CENTER", UIParent, "CENTER", 0, 190)
card:SetFrameStrata("HIGH")
card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
card.title:SetPoint("TOP", card, "TOP", 0, 0)
card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
card.sub:SetPoint("TOP", card.title, "BOTTOM", 0, -8)
card:Hide()
local function BigFont(fs, size)
  local src = GameFontNormalHuge
  if src and src.GetFont then
    local path = src:GetFont()
    if path then pcall(fs.SetFont, fs, path, size, "OUTLINE") end
  end
end
BigFont(card.title, 38)

local cardT, cardOn = 0, false
local function ShowCard(title, sub)
  card.title:SetText(title or "")
  card.sub:SetText(sub or "")
  cardT, cardOn = 0, true
  card:SetAlpha(0)
  card:Show()
end
O.ShowCard = ShowCard
local function UpdateCard(e)
  if not cardOn then return end
  cardT = cardT + e
  if cardT < 0.9 then card:SetAlpha(cardT / 0.9)
  elseif cardT < 3.6 then card:SetAlpha(1)
  elseif cardT < 4.8 then card:SetAlpha(1 - (cardT - 3.6) / 1.2)
  else card:Hide(); cardOn = false end
end

local function HideGameZoneText(hide)
  if ZoneTextFrame and ZoneTextFrame.SetAlpha then pcall(ZoneTextFrame.SetAlpha, ZoneTextFrame, hide and 0 or 1) end
end

local lastZone
O.On("ZONE_CHANGED_NEW_AREA", function()
  if not OwlHUDDB.classic then return end
  local zone = GetRealZoneText and GetRealZoneText() or nil
  if zone and zone ~= "" and zone ~= lastZone then
    lastZone = zone
    ShowCard(zone, nil)
  end
end)

-- ---------- driver ----------
local features = {
  { name = "hearts", fn = UpdateHearts },
  { name = "lock-on", fn = UpdateLockOn },
  { name = "item box", fn = UpdateBox },
  { name = "clock", fn = UpdateDial },
  { name = "title card", fn = UpdateCard },
}

local function SetClassic(on)
  OwlHUDDB.classic = on and true or false
  if on then
    hearts:Show(); dial:Show()
  else
    hearts:Hide(); dial:Hide(); box:Hide(); card:Hide(); arrow:Hide()
    barTop:Hide(); barBottom:Hide()
    barCur, boxActive, cardOn = 0, false, false
  end
  HideGameZoneText(on)
  -- keep the game's own combat health bar under the character alongside the hearts
  if O.ApplySelfBar then O.ApplySelfBar() end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, e)
  if not OwlHUDDB.classic then return end
  for i = 1, #features do
    local f = features[i]
    if not f.dead then
      local ok, err = pcall(f.fn, e)
      if not ok then
        f.dead = true
        O.Print("|cffff4040classic " .. f.name .. " turned off:|r " .. tostring(err))
      end
    end
  end
end)

O.On("PLAYER_LOGIN", function()
  for i = 1, #movers do
    local m = movers[i]
    local p = OwlHUDDB[m.key]
    if p then
      m.frame:ClearAllPoints()
      m.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
  end
  SetClassic(OwlHUDDB.classic)
  if OwlHUDDB.classic then
    lastZone = GetRealZoneText and GetRealZoneText() or nil
    local hour = GetGameTime() or 12
    local title = (hour >= 5 and hour < 12) and "Dawn of a New Day"
      or (hour >= 12 and hour < 18) and "The Day Wears On" or "Night Falls"
    ShowCard(title, O.LoginSubtitle and O.LoginSubtitle() or (date and date("%A") or nil))
  end
end)

table.insert(O.unlockHooks, function(unlocked)
  for i = 1, #movers do
    local f = movers[i].frame
    f:EnableMouse(unlocked)
    if unlocked then f.moverBG:Show(); f.moverLabel:Show() else f.moverBG:Hide(); f.moverLabel:Hide() end
  end
  if not OwlHUDDB.classic then return end
  if unlocked then
    box.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    box.text:SetText("You got the item box!")
    box:SetAlpha(1)
    box:Show()
  else
    box:Hide()
    boxActive = false
  end
end)

O.commands.classic = function()
  SetClassic(not OwlHUDDB.classic)
  O.Print("classic look" .. (OwlHUDDB.classic and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
O.commands.bars = function()
  OwlHUDDB.barsOn = not OwlHUDDB.barsOn
  O.Print("lock-on bars" .. (OwlHUDDB.barsOn and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
