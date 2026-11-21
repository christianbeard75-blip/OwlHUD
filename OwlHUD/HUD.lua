-- OwlHUD combat cues: Judgement ready, cooldown row, seal / blessing / aura / mana warnings.
-- In combat this client hides health, cooldown and aura numbers from addons ("secret values"):
-- they may be handed to the game's own widgets but never compared or calculated with.
-- So cooldowns go through duration objects, and buffs are read out of combat and timed in combat.
local ADDON, O = ...

local JUDGE = "Judgement"
local SMALL = { "Holy Strike", "Consecration", "Hammer of Justice", "Divine Protection", "Lay on Hands" }
local SEAL_TIME = 30
O.defaults.cues = false

-- A value we are allowed to look at, or nil.
local function Plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
O.Plain = Plain

-- ---------- spell helpers ----------
local function SpellTexture(name)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, name)
    if ok and tex then return tex end
  end
  if GetSpellTexture then
    local ok, tex = pcall(GetSpellTexture, name)
    if ok and tex then return tex end
  end
  return nil
end

local function SpellID(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if ok and type(info) == "table" and info.spellID then return Plain(info.spellID) end
  end
  if GetSpellInfo then
    local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
    if ok and id then return Plain(id) end
  end
  return nil
end

-- Puts a spell's cooldown on a Cooldown widget without reading the numbers.
-- Returns the duration object when the secret-safe path was used.
local function ShowCooldown(cd, spellID, name)
  if spellID and C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
    if ok and dur ~= nil then
      pcall(cd.SetCooldownFromDurationObject, cd, dur, true)
      return dur
    end
    return nil
  end
  -- older clients: plain numbers
  local s, d
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, name)
    if ok and type(info) == "table" then s, d = Plain(info.startTime), Plain(info.duration) end
  elseif GetSpellCooldown then
    local ok, a, b = pcall(GetSpellCooldown, name)
    if ok then s, d = Plain(a), Plain(b) end
  end
  if s and d and d > 1.6 then pcall(cd.SetCooldown, cd, s, d) end
  return nil
end

-- ---------- buffs: read out of combat, remembered in combat ----------
local sealExpire, blessingOK, auraOK, buffsKnown = 0, true, true, false
local secretCasts = false

local function ReadBuff(i)
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    local ok, a = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
    if not ok then return nil, nil, true end
    if not a then return nil end
    return Plain(a.name), Plain(a.expirationTime)
  end
  if UnitBuff then
    local ok, name, _, _, _, _, expires = pcall(UnitBuff, "player", i)
    if not ok then return nil, nil, true end
    return Plain(name), Plain(expires)
  end
  return nil, nil, true
end

local function ScanBuffs()
  local seal, blessing, aura, n, sealEnds = false, false, false, 0, nil
  for i = 1, 40 do
    local name, expires, failed = ReadBuff(i)
    if failed then return false end
    if not name then break end
    n = n + 1
    if name:find("Seal") then seal = true; sealEnds = expires
    elseif name:find("Blessing") then blessing = true
    elseif name:find("Aura") then aura = true end
  end
  buffsKnown = true
  blessingOK, auraOK = blessing, aura
  if seal then
    sealExpire = (sealEnds and sealEnds > 0) and sealEnds or (GetTime() + SEAL_TIME)
  else
    sealExpire = 0
  end
  return true, n
end

O.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if Plain(unit) ~= "player" then return end
  local id = Plain(spellID)
  if not id then secretCasts = true; return end
  local name = Plain(O.SpellName(id))
  if name and name:find("^Seal") then sealExpire = GetTime() + SEAL_TIME end
end)

-- ---------- frames ----------
local root = CreateFrame("Frame", "OwlHUDFrame", UIParent)
root:SetSize(56, 56)
root:SetPoint("CENTER", UIParent, "CENTER", 0, -260)
root:SetMovable(true)
root:EnableMouse(false)
root:SetClampedToScreen(true)
root:RegisterForDrag("LeftButton")
root:SetScript("OnDragStart", function(f) if O.unlocked then f:StartMoving() end end)
root:SetScript("OnDragStop", function(f)
  f:StopMovingOrSizing()
  local p, _, rp, x, y = f:GetPoint()
  OwlHUDDB.pos = { p, rp, x, y }
end)
root.bg = root:CreateTexture(nil, "BACKGROUND")
root.bg:SetAllPoints()
root.bg:SetColorTexture(0, 1, 0, 0.25)
root.bg:Hide()

local judge = CreateFrame("Frame", nil, root)
judge:SetAllPoints(root)
judge.tex = judge:CreateTexture(nil, "ARTWORK")
judge.tex:SetAllPoints()
judge.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
judge.cd = CreateFrame("Cooldown", nil, judge, "CooldownFrameTemplate")
judge.cd:SetAllPoints()
-- "ready" layer: its visibility is set by the game from the cooldown, never by our own comparison
judge.ready = CreateFrame("Frame", nil, judge)
judge.ready:SetAllPoints(judge)
judge.glow = judge.ready:CreateTexture(nil, "OVERLAY")
judge.glow:SetPoint("CENTER")
judge.glow:SetSize(90, 90)
judge.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
judge.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
judge.glow:SetBlendMode("ADD")
judge.glow:SetVertexColor(1, 0.85, 0.3)
judge.label = judge.ready:CreateFontString(nil, "OVERLAY", "GameFontNormal")
judge.label:SetPoint("TOP", judge, "BOTTOM", 0, -2)
judge.label:SetText("JUDGE")
judge.label:SetTextColor(1, 0.85, 0.3)
local glowAG = judge.glow:CreateAnimationGroup()
glowAG:SetLooping("BOUNCE")
local ga = glowAG:CreateAnimation("Alpha")
ga:SetFromAlpha(0.35); ga:SetToAlpha(1); ga:SetDuration(0.45)

local small = {}
for i = 1, #SMALL do
  local f = CreateFrame("Frame", nil, root)
  f:SetSize(30, 30)
  f.spell = SMALL[i]
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cd:SetAllPoints()
  f.known = false
  f:Hide()
  small[i] = f
end

local function LayoutSmall()
  local x = 14
  for i = 1, #small do
    local f = small[i]
    local tex = SpellTexture(f.spell)
    f.known = tex ~= nil
    if f.known then
      f.spellID = SpellID(f.spell) or f.spellID
      f.tex:SetTexture(tex)
      f:ClearAllPoints()
      f:SetPoint("LEFT", root, "RIGHT", x, 0)
      x = x + 36
    else
      f:Hide()
    end
  end
  local jt = SpellTexture(JUDGE)
  if jt then judge.tex:SetTexture(jt) end
  judge.known = jt ~= nil
  judge.spellID = SpellID(JUDGE) or judge.spellID
end

local sealWarn = root:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
sealWarn:SetPoint("BOTTOM", root, "TOP", 0, 30)
sealWarn:SetText("NO SEAL")
sealWarn:SetTextColor(1, 0.25, 0.25)
sealWarn:Hide()
local sealAG = sealWarn:CreateAnimationGroup()
sealAG:SetLooping("BOUNCE")
local sa = sealAG:CreateAnimation("Alpha")
sa:SetFromAlpha(0.4); sa:SetToAlpha(1); sa:SetDuration(0.4)

local infoWarn = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
infoWarn:SetPoint("BOTTOM", root, "TOP", 0, 10)
infoWarn:SetTextColor(1, 0.6, 0.15)
infoWarn:Hide()

local lastSealSound = 0

local function ManaPercent()
  if not (UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100) then return nil end
  local ok, pct = pcall(UnitPowerPercent, "player", 0, false, CurveConstants.ScaleTo100)
  if ok then return Plain(pct) end
  return nil
end

-- ---------- update ----------
local function Update()
  local inCombat = Plain(UnitAffectingCombat("player")) and true or false
  local hasTarget = false
  if Plain(UnitExists("target")) then
    local attackable = Plain(UnitCanAttack("player", "target"))
    local dead = Plain(UnitIsDeadOrGhost("target"))
    hasTarget = attackable and not dead and true or false
  end
  local active = inCombat or hasTarget or O.unlocked

  -- Judgement
  if judge.known and active and OwlHUDDB.cues then
    judge:Show()
    local dur = ShowCooldown(judge.cd, judge.spellID, JUDGE)
    if hasTarget or O.unlocked then
      judge.ready:Show()
      if not glowAG:IsPlaying() then glowAG:Play() end
      local isZero = true
      if dur then
        local ok, z = pcall(dur.IsZero, dur)
        if ok then isZero = z end
      end
      if judge.ready.SetAlphaFromBoolean then
        pcall(judge.ready.SetAlphaFromBoolean, judge.ready, isZero, 1, 0)
      else
        local z = Plain(isZero)
        judge.ready:SetAlpha((z == nil or z) and 1 or 0)
      end
    else
      judge.ready:Hide()
      if glowAG:IsPlaying() then glowAG:Stop() end
    end
  else
    judge:Hide()
  end

  -- small cooldown row
  for i = 1, #small do
    local f = small[i]
    if f.known and active and OwlHUDDB.cues then
      f:Show()
      ShowCooldown(f.cd, f.spellID, f.spell)
    else
      f:Hide()
    end
  end

  -- buffs: only readable out of combat
  if not inCombat then ScanBuffs() end

  local now = GetTime()
  local sealText
  if inCombat or hasTarget then
    if OwlHUDDB.cues and now >= sealExpire then
      if inCombat and secretCasts then
        -- casts cannot be seen in combat on this client: remind for a few seconds, then assume it was recast
        if now < sealExpire + 5 then sealText = "SEAL?" else sealExpire = now + SEAL_TIME - 5 end
      else
        sealText = "NO SEAL"
      end
    end
  end
  if sealText then
    sealWarn:SetText(sealText)
    sealWarn:Show()
    if not sealAG:IsPlaying() then
      sealAG:Play()
      if inCombat and OwlHUDDB.sound and (now - lastSealSound) > 3 then
        lastSealSound = now
        pcall(PlaySound, 8959, "Master")
      end
    end
  else
    sealWarn:Hide()
    if sealAG:IsPlaying() then sealAG:Stop() end
  end

  local lines
  if inCombat or hasTarget then
    if OwlHUDDB.warnBuffs and buffsKnown then
      if not blessingOK then lines = "NO BLESSING" end
      if not auraOK then lines = (lines and (lines .. "   ") or "") .. "NO AURA" end
    end
    if inCombat then
      local mana = ManaPercent()
      if mana and mana < 20 then
        lines = (lines and (lines .. "   ") or "") .. "|cff4da6ffLOW MANA|r"
      end
    end
  end
  if lines then
    infoWarn:SetText(lines)
    infoWarn:Show()
  else
    infoWarn:Hide()
  end
end

local running = false
local acc = 0
local function Start()
  if running then return end
  running = true
  root:SetScript("OnUpdate", function(self, e)
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    local ok, err = pcall(Update)
    if not ok then
      self:SetScript("OnUpdate", nil)
      running = false
      judge:Hide(); sealWarn:Hide(); infoWarn:Hide()
      for i = 1, #small do small[i]:Hide() end
      O.Print("|cffff4040combat cues stopped:|r " .. tostring(err))
    end
  end)
end

O.On("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  if class ~= "PALADIN" then root:Hide(); return end
  if OwlHUDDB.pos then
    root:ClearAllPoints()
    root:SetPoint(OwlHUDDB.pos[1], UIParent, OwlHUDDB.pos[2], OwlHUDDB.pos[3], OwlHUDDB.pos[4])
  end
  if OwlHUDDB.scale then root:SetScale(OwlHUDDB.scale) end
  LayoutSmall()
  Start()
  O.Print("loaded. Type /owl for commands.")
end)

O.On("SPELLS_CHANGED", function() LayoutSmall() end)

table.insert(O.unlockHooks, function(unlocked)
  root:EnableMouse(unlocked)
  if unlocked then root.bg:Show() else root.bg:Hide() end
end)

O.commands.scale = function(arg)
  local v = tonumber(arg)
  if v and v >= 0.4 and v <= 3 then
    OwlHUDDB.scale = v
    root:SetScale(v)
    O.Print("combat cue scale " .. v)
  else
    O.Print("use a number from 0.4 to 3, like /owl scale 1.2")
  end
end

O.commands.reset = function()
  OwlHUDDB.pos, OwlHUDDB.scale = nil, nil
  root:SetScale(1)
  root:ClearAllPoints()
  root:SetPoint("CENTER", UIParent, "CENTER", 0, -260)
  O.Print("combat cues back to the default spot.")
end

O.commands.debug = function()
  if Plain(UnitAffectingCombat("player")) then
    print("  in combat: the game hides buffs from addons, showing remembered state")
  else
    for i = 1, 40 do
      local name, _, failed = ReadBuff(i)
      if failed or not name then break end
      print("  buff " .. i .. ": " .. tostring(name))
    end
    ScanBuffs()
  end
  local left = sealExpire - GetTime()
  print("  seal: " .. (left > 0 and (math.floor(left) .. "s left") or "none")
    .. " | blessing: " .. tostring(blessingOK) .. " | aura: " .. tostring(auraOK))
  print("  secret-safe cooldowns: " .. tostring(C_Spell ~= nil and C_Spell.GetSpellCooldownDuration ~= nil)
    .. " | casts hidden in combat: " .. tostring(secretCasts)
    .. " | Judgement id: " .. tostring(judge.spellID))
end

O.commands.cues = function()
  OwlHUDDB.cues = not OwlHUDDB.cues
  O.Print("Judgement / cooldown icons and seal warning" .. (OwlHUDDB.cues and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- ready ding: a small sound when a tracked ability comes off cooldown ----------
-- isActive / isOnGCD are plain booleans even in combat, so the global cooldown never dings.
O.defaults.ding = true
local DING_SPELLS = { JUDGE, "Holy Strike", "Consecration", "Hammer of Justice", "Divine Protection", "Lay on Hands" }
local DING_SOUNDS = { 3175, 3081, 8960 }
local dingIDs, dingWas, lastDing = {}, {}, 0

local function ResolveDingIDs()
  for i = 1, #DING_SPELLS do
    local name = DING_SPELLS[i]
    dingIDs[name] = SpellID(name) or dingIDs[name]
  end
end

-- true = on its own cooldown, false = ready (or only the global cooldown), nil = cannot tell
local function Cooling(id)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
  local ok, info = pcall(C_Spell.GetSpellCooldown, id)
  if not ok or type(info) ~= "table" then return nil end
  if issecretvalue and (issecretvalue(info.isActive) or issecretvalue(info.isOnGCD)) then return nil end
  if info.isActive ~= nil then
    return (info.isActive and not info.isOnGCD) and true or false
  end
  local d = Plain(info.duration)
  if d == nil then return nil end
  return d > 1.6
end

local function PlayDing(force)
  local now = GetTime()
  if not force and now - lastDing < 0.3 then return end
  lastDing = now
  pcall(PlaySound, DING_SOUNDS[OwlHUDDB.dingSound or 1] or DING_SOUNDS[1], "Master")
end

local function CheckDings()
  local live = Plain(UnitAffectingCombat("player")) and true or false
  if not live and Plain(UnitExists("target")) then
    live = Plain(UnitCanAttack("player", "target")) and true or false
  end
  for i = 1, #DING_SPELLS do
    local name = DING_SPELLS[i]
    local id = dingIDs[name]
    if id then
      local cooling = Cooling(id)
      if cooling ~= nil then
        if dingWas[name] and not cooling and live and OwlHUDDB.ding then PlayDing() end
        dingWas[name] = cooling
      end
    end
  end
end

local dingAcc, dingDead = 0, false
local dingDriver = CreateFrame("Frame")
dingDriver:SetScript("OnUpdate", function(_, e)
  if dingDead then return end
  dingAcc = dingAcc + e
  if dingAcc < 0.1 then return end
  dingAcc = 0
  local ok, err = pcall(CheckDings)
  if not ok then
    dingDead = true
    O.Print("|cffff4040ready ding turned off:|r " .. tostring(err))
  end
end)

O.On("PLAYER_LOGIN", ResolveDingIDs)
O.On("SPELLS_CHANGED", ResolveDingIDs)

O.commands.ding = function(arg)
  local pick = tonumber(arg)
  if pick and DING_SOUNDS[pick] then
    OwlHUDDB.dingSound = pick
    OwlHUDDB.ding = true
    PlayDing(true)
    O.Print("ready ding sound " .. pick .. " of " .. #DING_SOUNDS .. ".")
    return
  end
  OwlHUDDB.ding = not OwlHUDDB.ding
  if OwlHUDDB.ding then PlayDing(true) end
  O.Print("ready ding" .. (OwlHUDDB.ding and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
