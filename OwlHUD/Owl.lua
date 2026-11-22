-- OwlHUD owl, the rest of him: a name, voices, a perch where he waits and blinks, hats,
-- supply checks, a savings goal, kill streaks, friends coming online, his journal,
-- and hellos between owls when two players both run OwlHUD.
local ADDON, O = ...
local MEDIA = "Interface\\AddOns\\OwlHUD\\Media\\"
local Plain = O.Plain
local Owl = O.Owl
if not Owl then return end
local pal, Say, Q = Owl.pal, Owl.Say, Owl.Q

O.defaults.owlName = "Owl"
O.defaults.voice = "cheerful"
O.defaults.hats = true
O.defaults.perch = true

for _, mood in ipairs({
  { "streak", "excited" }, { "goal", "excited" }, { "owlmeet", "happy" }, { "owllevel", "excited" }, { "owlhoot", "happy" },
  { "friend", "happy" }, { "supply", "worried" }, { "wake", "sleepy" }, { "named", "happy" }, { "voice", "happy" },
  -- so the little asides fit the news: never "Oh, good!" in front of a friend going down
  { "care", "worried" }, { "dl", "worried" }, { "esee", "worried" }, { "gosfall", "worried" }, { "sawfall", "worried" }, { "sawoops", "worried" },
  { "nobuff", "worried" }, { "stance", "worried" }, { "cheer", "excited" }, { "gift", "happy" }, { "thanks", "happy" }, { "pal", "happy" },
  { "post", "happy" }, { "friendup", "happy" },
}) do table.insert(Owl.moods, 1, mood) end

local function Now() return GetTime() end
local function Clock() return (type(time) == "function" and time()) or 0 end
local function Level() return Plain(UnitLevel("player")) or 1 end
local function Me() return Plain(UnitName("player")) or "" end
local function Zone()
  local z = Q("GetRealZoneText")
  if type(z) == "string" and z ~= "" then return z end
  return "parts unknown"
end
local function Name() return OwlHUDDB.owlName or "Owl" end

-- Names. On this realm the game calls you and your party by first name ("Owlishi", "Paul"), but a message between
-- owls arrives signed with the full name ("Owlishi Owl", "Paul Bunyann"). Left alone, he could not tell that a
-- message was his own echo (and took himself for a friend), nor that the owl writing was the one in his party.
-- So everyone is known by first name, and the full name is kept only as the address to whisper to.
Owl.First = function(name)
  if type(name) ~= "string" then return name end
  return name:match("^(%S+)") or name
end
Owl.Full = function(first, full)
  if type(first) ~= "string" or type(full) ~= "string" or first == full then return end
  if type(OwlHUDDB.fullNames) ~= "table" then OwlHUDDB.fullNames = {} end
  OwlHUDDB.fullNames[first] = full
end
Owl.Addr = function(name)
  local t = OwlHUDDB.fullNames
  return (type(t) == "table" and type(t[name]) == "string" and t[name]) or name
end
-- Friends. He used to look only at the game's own friends list, so a friend added through Battle.net (most are)
-- did not count as a friend at all: no owl beside yours, no letters, no level-up notice. Owl.FL answers the same
-- two questions the game's list does, but from both lists together.
Owl.FL = {}
do
  local list, builtAt = {}, -100
  local function Build()
    local out = {}
    local game = _G.C_FriendList
    if type(game) == "table" and game.GetNumFriends and game.GetFriendInfoByIndex then
      for i = 1, math.min(tonumber(Plain(game.GetNumFriends())) or 0, 100) do
        local ok, info = pcall(game.GetFriendInfoByIndex, i)
        if ok and type(info) == "table" then
          local name = Plain(info.name)
          if type(name) == "string" and name ~= "" then
            out[#out + 1] = { name = name, connected = Plain(info.connected) and true or false, level = tonumber(Plain(info.level)), area = Plain(info.area), class = Plain(info.className), afk = Plain(info.afk) and true or false }
          end
        end
      end
    end
    local bnet = _G.C_BattleNet
    if type(_G.BNGetNumFriends) == "function" and type(bnet) == "table" and bnet.GetFriendNumGameAccounts and bnet.GetFriendGameAccountInfo then
      local okN, total = pcall(_G.BNGetNumFriends)
      total = okN and tonumber(Plain(total)) or 0
      for i = 1, math.min(total, 200) do
        local okC, count = pcall(bnet.GetFriendNumGameAccounts, i)
        for j = 1, math.min(okC and tonumber(Plain(count)) or 0, 6) do
          local ok, g = pcall(bnet.GetFriendGameAccountInfo, i, j)
          if ok and type(g) == "table" then
            local char, client, project = Plain(g.characterName), Plain(g.clientProgram), Plain(g.wowProjectID)
            local same = type(project) ~= "number" or type(_G.WOW_PROJECT_ID) ~= "number" or project == _G.WOW_PROJECT_ID
            if type(char) == "string" and char ~= "" and client == "WoW" and Plain(g.isOnline) and same then
              out[#out + 1] = { name = char, connected = true, level = tonumber(Plain(g.characterLevel)), area = Plain(g.areaName), bnet = true, class = Plain(g.className), afk = Plain(g.isGameAFK) and true or false }
            end
          end
        end
      end
    end
    return out
  end
  Owl.FL.GetNumFriends = function()
    if Now() - builtAt > 3 then
      builtAt = Now()
      local ok, built = pcall(Build)
      list = ok and built or {}
    end
    return #list
  end
  Owl.FL.GetFriendInfoByIndex = function(i) return list[i] end
end
-- once: everything he wrote down under a full name moves to the first name, and what he wrote about "a friend"
-- who was really you is thrown away
O.On("PLAYER_LOGIN", function()
  if OwlHUDDB.namesFixed or Me() == "" then return end
  OwlHUDDB.namesFixed = true
  local me, map = Me(), {}
  local owls = type(OwlHUDDB.journal) == "table" and OwlHUDDB.journal.owls
  if type(owls) ~= "table" then return end
  for full in pairs(owls) do
    local first = type(full) == "string" and full:match("^(%S+)%s")
    if first then map[full] = first end
  end
  if not next(map) then return end
  local function walk(t, depth)
    if depth > 7 then return end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    for _, k in ipairs(keys) do
      local v = t[k]
      local first = type(k) == "string" and map[k]
      if first and t ~= OwlHUDDB.fullNames then
        t[k] = nil
        if first ~= me and t[first] == nil then t[first] = v end
      end
      if type(v) == "table" then walk(v, depth + 1) end
    end
  end
  walk(OwlHUDDB, 1)
  for full, first in pairs(map) do if first ~= me then Owl.Full(first, full) end end
end)

-- Who killed you. He used to blame whatever you had targeted last, so a death to another player went down as a
-- death to the nearest mob. Now he watches who is actually hitting you (the game's combat log) and, when you die,
-- names the last thing that did. If the log tells him nothing, he looks for an enemy player who has you targeted.
-- This sits near the top of the file on purpose: it must run before everything else that reacts to a death.
do
local hit = { name = nil, at = -100, player = false, pet = false }
Owl.clog = { registered = false, events = 0, named = 0 }
local DAMAGE = { SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, DAMAGE_SHIELD = true }
local okFrame, logFrame = pcall(CreateFrame, "Frame")
if okFrame and logFrame then
  Owl.clog.registered = pcall(logFrame.RegisterEvent, logFrame, "COMBAT_LOG_EVENT_UNFILTERED") and true or false
  logFrame:SetScript("OnEvent", function()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local ok, _, sub, _, sGUID, sName, sFlags, _, dGUID, dName = pcall(CombatLogGetCurrentEventInfo)
    if not ok then return end
    sub = Plain(sub)
    if type(sub) ~= "string" then return end
    Owl.clog.events = Owl.clog.events + 1
    local isHit = DAMAGE[sub]
    if not isHit and sub ~= "PARTY_KILL" then return end
    local mine = Plain(UnitGUID("player"))
    sGUID, sName, dGUID, dName, sFlags = Plain(sGUID), Plain(sName), Plain(dGUID), Plain(dName), Plain(sFlags)
    if type(mine) ~= "string" or type(sGUID) ~= "string" or type(dGUID) ~= "string" then return end
    if isHit and dGUID == mine and sGUID ~= mine and type(sName) == "string" and sName ~= "" then
      Owl.clog.named = Owl.clog.named + 1
      local player = sGUID:sub(1, 7) == "Player-"
      local pet = (not player) and type(sFlags) == "number" and type(bit) == "table" and bit.band and bit.band(sFlags, 0x00000100) ~= 0 or false
      hit.name, hit.at, hit.player, hit.pet = sName, Now(), player, pet
    elseif sub == "PARTY_KILL" and sGUID == mine then
      -- a killing blow of yours: counted for the dungeon awards, and remembered by name when it was a player
      if Owl.onBlow then pcall(Owl.onBlow) end
      if dGUID:sub(1, 7) == "Player-" and type(dName) == "string" and Owl.onPvpKill then pcall(Owl.onPvpKill, dName) end
    end
  end)
end
O.On("PLAYER_DEAD", function()
  local killer
  if hit.name and Now() - hit.at < 12 then
    killer = { name = hit.name, player = hit.player, pet = hit.pet, at = Now(), sure = true }
  else
    local name
    local function enemy(unit) return Q("UnitExists", unit) and Q("UnitIsPlayer", unit) and Q("UnitCanAttack", unit, "player") end
    if enemy("target") and Q("UnitIsUnit", "targettarget", "player") then name = Plain(UnitName("target")) end
    if not name then
      for i = 1, 40 do
        local unit = "nameplate" .. i
        if enemy(unit) and Q("UnitIsUnit", unit .. "target", "player") then name = Plain(UnitName(unit)) break end
      end
    end
    if type(name) == "string" and name ~= "" then killer = { name = name, player = true, pet = false, at = Now(), sure = false } end
  end
  Owl.killer = killer
  hit.name = nil
end)
end

-- a picture file, or the plain owl when the game has not loaded that file yet
local function SetArt(texture, file)
  if file then
    texture:SetTexture(MEDIA .. file)
    local ok, shown = pcall(texture.GetTexture, texture)
    if ok and shown ~= nil then return true end
  end
  return false
end

-- =====================================================================================
-- His name
-- =====================================================================================
local function ApplyName() pal.name:SetText(Name()) end
O.On("PLAYER_LOGIN", ApplyName)

O.commands.name = function(arg)
  arg = (arg or ""):gsub("[^%a ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if arg == "" then O.Print("his name is " .. Name() .. ". Change it with /owl name Hooty"); return end
  arg = arg:sub(1, 16):gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end)
  OwlHUDDB.owlName = arg
  ApplyName()
  Say("named", { arg .. ". Yes. I like that.", arg .. "? I can live with " .. arg .. ".", "From now on, call me " .. arg .. "." }, 0, "c")
end

-- =====================================================================================
-- Voices: the same moments, said differently
-- =====================================================================================
local VOICES = {
  sage = {
    hello = { "The road remembers you, traveler.", "You return. Good. There is much still to see.", "Another day, another lesson." },
    idle = { "Patience wins more fights than strength.", "The quiet between battles is also the journey.", "A sharp mind needs rest as much as a sharp blade needs oil.",
      "Those who rush arrive tired.", "Even the tallest tree began by waiting.", "Look twice. Strike once.", "Hoo. That is all the wisdom I have right now." },
    praise = { "Well fought.", "Calm and exact. As it should be.", "You are learning." },
    dead = { "Every fall is a lesson. This one was expensive.", "The path continues. So must you.", "Rest a moment. Then rise." },
    alive = { "You rise again. Wiser, I hope.", "Breathe. Prepare. Then go on." },
    closecall = { "Too near the edge. Remember how that felt.", "Fortune was kind. Do not rely on her." },
    lowmana = { "An empty well gives no water. Rest.", "Sit. Drink. The fight will wait." },
    afk = { "Go. I will mind the fire.", "Stillness is good for you." },
    back = { "You return.", "The world waited." },
    resting = { "A warm hearth. Use it well.", "Rest here. Tomorrow asks more of you." },
    grey = { "That creature has nothing to teach you.", "Leave the small ones be." },
    elite = { "That one is beyond a lone traveler. Choose wisely.", "Strength respects strength. Bring allies." },
    skull = { "Not every battle is yours to fight.", "Walk away. There is no shame in it." },
    bags0 = { "You carry too much. Let something go.", "A full pack makes a slow traveler." },
    bags2 = { "Your pack grows heavy.", "Soon you must choose what to keep." },
    dur25 = { "Your armor tires before you do. Mend it.", "Care for your gear and it will care for you." },
    talent = { "You have grown, and not yet chosen how. A talent waits.", "Knowledge unspent is knowledge wasted." },
    trainer = { "Your teacher has more to show you.", "Seek your trainer. You are ready." },
    mail = { "Word has come for you.", "A letter waits." },
    late = { "The hour is late, even for owls.", "Sleep is also training." },
    goodloot = { "A fine thing. Use it well.", "Fortune favors you today." },
    rare = { "A rare creature. Such chances do not come twice.", "Look closely. Few ever see that one." },
    solo = { "Alone again. That, too, is a kind of peace.", "Just the road and us." },
    wake = { "I was meditating.", "My eyes were closed. My mind was not." },
    rested = { "You are rested. The road pays double for a while.", "Rest has made you quick to learn. Use it." },
    restedout = { "The gift of rest is spent. The road is the road again.", "Rested no longer. Each step earns its own keep now." },
    boss = { "This is the one the others answer to. Be ready.", "A great foe. Breathe, then begin." },
    rareelite = { "Rare, and strong with it. Weigh the prize against the cost.", "Few see that one. Fewer beat it alone." },
    breath = { "You have no gills. Rise.", "The surface. Now." },
    rez = { "A hand is offered. Take it.", "You are being called back. Answer." },
    dur10 = { "Your armor is at its end. Mend it before you fight again.", "One more blow and it fails. Find a smith." },
    adds3 = { "Three at once. Spend everything, or withdraw.", "Too many. There is no shame in running." },
    group = { "Company on the road. See to them before the fight.", "You do not walk alone today. Good." },
    dungeon = { "A deep place. Stay together and let the tank lead.", "Go carefully. Places like this punish haste." },
  },
  sarcastic = {
    hello = { "Oh good, you are back. I was getting so much done.", "Look who remembered they have a game.", "Ah. My favorite walking disaster." },
    idle = { "No no, keep running in circles. It is working great.", "I could fly there faster. Just saying.", "Bold strategy. Let us see how it plays out.",
      "I have seen murlocs with better plans.", "Do not mind me. I am only the brains of the operation.", "Ten out of ten. No notes. Some notes.", "Hoo. That was sarcasm, by the way." },
    praise = { "Wow. You pressed the buttons in the right order.", "Not bad. For you.", "I am almost impressed." },
    dead = { "And down goes the hero. Shocking.", "Have you tried not dying?", "I will add it to the list.", "Excellent plan. Flawless execution." },
    alive = { "Welcome back. Try to keep the insides inside this time.", "Oh good, you are alive. Again." },
    closecall = { "I had already picked out a new hero.", "Cutting it close is a choice, I suppose." },
    lowmana = { "Out of mana. Who could have seen that coming.", "Sit down and drink before you hurt yourself." },
    afk = { "Sure, leave. I will just sit here. Being an owl.", "Take your time. I do not have feelings or anything." },
    back = { "Oh, you are back. I barely noticed.", "Finally." },
    resting = { "An inn. Try not to break anything.", "Civilization. Do wipe your feet." },
    grey = { "Yes, bully the small one. Very brave.", "It gives no XP. But you do you." },
    elite = { "An elite. This should be hilarious.", "Oh, go on. Poke it. I will watch from up here." },
    skull = { "That will kill you. I will wait.", "Sure. Fight the skull. What could go wrong." },
    bags0 = { "Bags full. Of junk, mostly.", "Nothing fits. Maybe stop picking up rocks." },
    bags2 = { "Two slots left. Hoarder.", "Your bags are a cry for help." },
    dur25 = { "Your armor is mostly holes now.", "Repair. Unless the plan is to fight naked." },
    talent = { "A talent point. Unspent. Take your time, it is only free power.", "You do know the points do nothing until you spend them?" },
    trainer = { "Your trainer is waiting. They are probably used to it.", "New ranks exist. You could, you know, learn them." },
    mail = { "You have mail. Somebody likes you. Odd.", "Mail. Probably bills." },
    late = { "It is past 1 AM. But sure, one more quest.", "Sleep is for people with good judgement." },
    goodloot = { "Oh look, something that is not vendor trash.", "A real item. Try not to lose it." },
    rare = { "A rare. Do try not to miss.", "Rare spawn. No pressure." },
    solo = { "Just us. Lucky me.", "They left. I wonder why." },
    wake = { "I was not asleep. I was ignoring you.", "What. I am awake. Go on." },
    rested = { "Rested. Try to spend it on something other than dying.", "Bonus XP. Even you can level with this." },
    restedout = { "The rested bonus is gone. Back to earning it the slow way.", "No more free XP. Tragic." },
    boss = { "A boss. I am sure this will go exactly as planned.", "That is the boss. No, the big one. Yes. That." },
    rareelite = { "Rare and elite. Naturally you want to poke it.", "A rare elite. I will write something nice for the funeral." },
    breath = { "You do know you cannot breathe water?", "Air is up. In case that helps." },
    rez = { "Someone is reviving you. Do try to accept.", "A resurrection. Press yes. It is the big button." },
    dur10 = { "Your gear is about to fall off. Repair, or fight in your socks.", "Everything is red. That is not a fashion choice." },
    adds3 = { "Three on you. Wonderful pull. Truly.", "Three at once. I assume this was the plan." },
    group = { "Oh good, witnesses.", "A group. Try to look like you know what you are doing." },
    dungeon = { "A dungeon. Do not pull the whole room this time.", "In we go. Stand behind the one with the shield." },
  },
}
local VOICE_NEXT = { cheerful = "sage", sage = "sarcastic", sarcastic = "cheerful" }

O.OwlLines = function(key, lines)
  local voice = VOICES[OwlHUDDB.voice or ""]
  if not voice then return nil end
  if key == "hoot" then key = "idle" end
  local mine = voice[key]
  if not mine then return nil end
  -- idle chatter keeps the tips: his own remarks only half the time
  if key == "idle" and math.random(2) == 1 then return nil end
  return mine
end

O.commands.voice = function()
  OwlHUDDB.voice = VOICE_NEXT[OwlHUDDB.voice or "cheerful"] or "cheerful"
  O.Print(Name() .. "'s voice: " .. OwlHUDDB.voice .. ".")
  local hello = { cheerful = "Hoo! Back to my usual self.", sage = "Very well. I shall choose my words with care.", sarcastic = "Oh, you want honesty. This will be fun." }
  Say("voice", hello[OwlHUDDB.voice], 0, "c")
end

-- =====================================================================================
-- Hats
-- =====================================================================================
local partyUntil = 0
local function CurrentHat()
  if not OwlHUDDB.hats then return nil end
  if Now() < partyUntil then return "hat_party.tga" end
  if O.OwlHat then
    local ok, hat = pcall(O.OwlHat)
    if ok and hat then return hat end
  end
  local month
  if type(date) == "function" then
    local ok, m = pcall(date, "%m")
    month = ok and tonumber(m) or nil
  end
  if month == 12 then return "hat_santa.tga" end
  if Level() >= 40 then return "hat_helm.tga" end
  return nil
end

pal.hat = pal:CreateTexture(nil, "OVERLAY")
pal.hat:SetAllPoints(pal.icon)
pal.hat:Hide()

-- =====================================================================================
-- The perch: where he waits between lines. He blinks, looks about, and nods off.
-- =====================================================================================
local perch = CreateFrame("Button", "OwlHUDPerch", UIParent)
perch:SetSize(54, 54)
-- his own spot, away from the hearts; /owl unlock lets you drag him anywhere
perch:SetPoint("CENTER", UIParent, "CENTER", -420, -40)
perch:SetMovable(true)
perch:SetClampedToScreen(true)
perch:RegisterForDrag("LeftButton")
if perch.RegisterForClicks then perch:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
perch.icon = perch:CreateTexture(nil, "ARTWORK")
perch.icon:SetAllPoints()
perch.icon:SetTexture(MEDIA .. "owl.tga")
perch.hat = perch:CreateTexture(nil, "OVERLAY")
perch.hat:SetAllPoints(perch.icon)
perch.hat:Hide()
perch.z = perch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
perch.z:SetPoint("BOTTOMLEFT", perch, "TOPRIGHT", -16, -10)
perch.z:SetText("z z")
perch.z:Hide()
perch.mover = perch:CreateTexture(nil, "BACKGROUND")
perch.mover:SetPoint("TOPLEFT", -4, 4)
perch.mover:SetPoint("BOTTOMRIGHT", 4, -4)
perch.mover:SetColorTexture(0, 1, 0, 0.3)
perch.mover:Hide()
perch.label = perch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
perch.label:SetPoint("TOP", perch, "BOTTOM", 0, -6)
perch.label:SetText("drag the owl")
perch.label:Hide()
perch:SetScript("OnDragStart", function(f) if O.unlocked then f:StartMoving() end end)
perch:SetScript("OnDragStop", function(f)
  f:StopMovingOrSizing()
  local p, _, rp, x, y = f:GetPoint()
  OwlHUDDB.perchPos = { p, rp, x, y }
end)
perch:SetScript("OnClick", function(_, button)
  if O.unlocked then return end
  if button == "RightButton" then
    Owl.Hush(600)
    O.Print(Name() .. " hushed for 10 minutes. /owl hoot wakes him.")
  else
    O.Try("owl options", function() if O.OwlOptions then O.OwlOptions() else Owl.Ask() end end)
  end
end)
perch:Hide()

local lastHat
local function ApplyHat()
  local hat = CurrentHat()
  if hat == lastHat then return end
  lastHat = hat
  for _, tex in ipairs({ pal.hat, perch.hat }) do
    if hat and SetArt(tex, hat) then tex:Show() else tex:Hide() end
  end
end

local nextStretch = 25
local face, faceUntil, nextBlink, nextLook, lastActive, dozing, perchT, slow = "owl.tga", 0, 4, 12, 0, false, 0, 0
local function PerchFace(file)
  if file == face then return end
  face = file
  if not SetArt(perch.icon, file) then perch.icon:SetTexture(MEDIA .. "owl.tga") end
end

local function PerchStep(e)
  local now = Now()
  slow = slow + e
  if slow >= 1 then
    slow = 0
    ApplyHat()
    local speed = Q("GetUnitSpeed", "player")
    if (type(speed) == "number" and speed > 0) or Plain(UnitAffectingCombat("player")) or lastActive == 0 then lastActive = now end
  end
  local want = OwlHUDDB.tips and OwlHUDDB.perch and (O.unlocked or not pal:IsShown())
  if not want then
    if perch:IsShown() then perch:Hide() end
    return
  end
  if not perch:IsShown() then perch:Show() end
  if O.unlocked then return end
  -- you are dead or a ghost: eyes shut, no dozing, no looking about, until you live again
  if Q("UnitIsDeadOrGhost", "player") then
    if dozing then dozing = false perch.z:Hide() end
    lastActive = now
    PerchFace("owl_blink.tga")
    return
  end
  -- on a flight path or a mount he flies alongside
  if O.OwlFlying and O.OwlFlying() then
    if dozing then dozing = false perch.z:Hide() end
    lastActive = now
    PerchFace(math.floor(now / 0.28) % 2 == 0 and "owl_fly1.tga" or "owl_fly2.tga")
    return
  end

  local sleepy = now - lastActive > 75
  if sleepy and not dozing then
    dozing = true
    perch.dozedAt = now
    perch.z:Show()
  elseif dozing and not sleepy then
    dozing = false
    perch.z:Hide()
    if O.OwlWake then pcall(O.OwlWake, now - (perch.dozedAt or now)) end
    if math.random(4) == 1 then Say("wake", { "Hm? I was not sleeping.", "I was resting my eyes.", "Oh! We are moving. Good." }, 600) end
  end
  perchT = perchT + e
  if dozing then
    PerchFace("owl_sleepy.tga")
    perch.z:SetAlpha(0.55 + 0.45 * math.sin(perchT * 2))
    return
  end
  -- a friend in the party is badly hurt or has just gone down: he keeps glancing over at their owl
  if Owl.troubleAt and now - Owl.troubleAt < 1.5 and now % 5 < 3 then
    PerchFace("owl_left.tga")
    return
  end
  if now < faceUntil then return end
  if now >= nextBlink then
    PerchFace("owl_blink.tga")
    faceUntil = now + 0.14
    nextBlink = now + 2.5 + math.random() * 4.5
  elseif now >= nextLook then
    PerchFace(math.random(2) == 1 and "owl_left.tga" or "owl_right.tga")
    faceUntil = now + 1.1 + math.random()
    nextLook = now + 7 + math.random() * 14
  elseif OwlHUDDB.fancy and now >= nextStretch then
    -- a quick stretch of the wings
    PerchFace("owl_stretch.tga")
    faceUntil = now + 0.45
    nextStretch = now + 35 + math.random() * 50
  else
    PerchFace((O.OwlIdleFace and O.OwlIdleFace()) or "owl.tga")
  end
end

local perchDead = false
local perchDriver = CreateFrame("Frame")
perchDriver:SetScript("OnUpdate", function(_, e)
  if perchDead then return end
  local ok, err = pcall(PerchStep, e)
  if not ok then
    perchDead = true
    perch:Hide()
    O.Print("|cffff4040owl perch turned off:|r " .. tostring(err))
  end
end)

-- one owl, one spot: when he talks he does it right where he perches
local function AnchorPal()
  pal:ClearAllPoints()
  pal:SetPoint("LEFT", perch, "CENTER", -28, 0)
end
AnchorPal()

O.On("PLAYER_LOGIN", function()
  local p = OwlHUDDB.perchPos
  if p then
    perch:ClearAllPoints()
    perch:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
  AnchorPal()
end)
table.insert(O.unlockHooks, function(unlocked)
  if unlocked then
    -- only the perch is dragged; the speech box follows it
    pal:Hide()
    perch.mover:Show()
    perch.label:Show()
  else
    perch.mover:Hide()
    perch.label:Hide()
  end
end)
O.commands.owlreset = function()
  OwlHUDDB.perchPos = nil
  perch:ClearAllPoints()
  perch:SetPoint("CENTER", UIParent, "CENTER", -420, -40)
  AnchorPal()
  O.Print(Name() .. " is back at his starting spot, left of your character.")
end
O.commands.perch = function()
  OwlHUDDB.perch = not OwlHUDDB.perch
  O.Print("owl perch" .. (OwlHUDDB.perch and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
O.commands.hats = function()
  OwlHUDDB.hats = not OwlHUDDB.hats
  lastHat = false
  O.Print("owl hats" .. (OwlHUDDB.hats and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- =====================================================================================
-- His journal
-- =====================================================================================
local function Journal()
  local j = OwlHUDDB.journal
  if type(j) ~= "table" then j = {}; OwlHUDDB.journal = j end
  j.entries = type(j.entries) == "table" and j.entries or {}
  j.zones = type(j.zones) == "table" and j.zones or {}
  j.dungeons = type(j.dungeons) == "table" and j.dungeons or {}
  j.owls = type(j.owls) == "table" and j.owls or {}
  j.kills, j.deaths, j.quests, j.best = j.kills or 0, j.deaths or 0, j.quests or 0, j.best or 0
  return j
end

local function Day()
  local first = OwlHUDDB.firstDay
  if type(first) ~= "number" then first = Clock(); OwlHUDDB.firstDay = first end
  return math.floor((Clock() - first) / 86400) + 1
end

local RefreshJournal
local function Note(text)
  local j = Journal()
  table.insert(j.entries, 1, { d = Day(), l = Level(), t = text })
  while #j.entries > 300 do table.remove(j.entries) end
  if RefreshJournal then RefreshJournal() end
end

local book = CreateFrame("Frame", "OwlHUDJournal", UIParent)
book:SetSize(460, 560)
book:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
book:SetFrameStrata("DIALOG")
book:SetMovable(true)
book:EnableMouse(true)
book:SetClampedToScreen(true)
book:RegisterForDrag("LeftButton")
book:SetScript("OnDragStart", function(f) f:StartMoving() end)
book:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
book.edge = book:CreateTexture(nil, "BACKGROUND")
book.edge:SetAllPoints()
book.edge:SetColorTexture(0.24, 0.15, 0.07, 1)
book.page = book:CreateTexture(nil, "BORDER")
book.page:SetPoint("TOPLEFT", 5, -5)
book.page:SetPoint("BOTTOMRIGHT", -5, 5)
book.page:SetColorTexture(0.87, 0.78, 0.58, 1)
book.owl = book:CreateTexture(nil, "ARTWORK")
book.owl:SetSize(44, 44)
book.owl:SetPoint("TOPLEFT", 18, -14)
book.owl:SetTexture(MEDIA .. "owl_happy.tga")
book.title = book:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
book.title:SetPoint("TOPLEFT", 72, -20)
book.title:SetTextColor(0.3, 0.17, 0.05)
book.stats = book:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
book.stats:SetPoint("TOPLEFT", 72, -42)
book.stats:SetWidth(370)
book.stats:SetJustifyH("LEFT")
book.stats:SetTextColor(0.36, 0.24, 0.1)
book.rule = book:CreateTexture(nil, "ARTWORK")
book.rule:SetPoint("TOPLEFT", 18, -80)
book.rule:SetPoint("TOPRIGHT", -18, -80)
book.rule:SetHeight(2)
book.rule:SetColorTexture(0.45, 0.3, 0.12, 0.8)
local ROWS = 11
book.rows = {}
for i = 1, ROWS do
  local day = book:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  day:SetPoint("TOPLEFT", 20, -92 - (i - 1) * 36)
  day:SetWidth(54)
  day:SetJustifyH("LEFT")
  day:SetTextColor(0.5, 0.3, 0.08)
  local text = book:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", 78, -92 - (i - 1) * 36)
  text:SetWidth(360)
  text:SetJustifyH("LEFT")
  text:SetTextColor(0.2, 0.12, 0.05)
  if text.SetMaxLines then text:SetMaxLines(2) end
  book.rows[i] = { day = day, text = text }
end
book.pageText = book:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
book.pageText:SetPoint("BOTTOM", 0, 18)
book.pageText:SetTextColor(0.36, 0.24, 0.1)

-- ink on paper: the game's fonts carry a dark shadow and outline, which smears dark text
local function Ink(fs, size)
  if fs.GetFont and fs.SetFont then
    local ok, file = pcall(fs.GetFont, fs)
    if ok and type(file) == "string" then pcall(fs.SetFont, fs, file, size, "") end
  end
  if fs.SetShadowOffset then pcall(fs.SetShadowOffset, fs, 0, 0) end
  if fs.SetShadowColor then pcall(fs.SetShadowColor, fs, 0, 0, 0, 0) end
end
Ink(book.title, 22)
Ink(book.stats, 13)
Ink(book.pageText, 13)
for i = 1, ROWS do
  Ink(book.rows[i].day, 13)
  Ink(book.rows[i].text, 15)
end

local function BookButton(label, width)
  local b = CreateFrame("Button", nil, book)
  b:SetSize(width, 24)
  b.bg = b:CreateTexture(nil, "ARTWORK")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.3, 0.19, 0.08, 1)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(label)
  b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.45, 0.3, 0.12, 1) end)
  b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.3, 0.19, 0.08, 1) end)
  return b
end
local bookPage = 1
book.newer = BookButton("< Newer", 80)
book.newer:SetPoint("BOTTOMLEFT", 18, 12)
book.older = BookButton("Older >", 80)
book.older:SetPoint("BOTTOMRIGHT", -18, 12)
book.close = BookButton("X", 24)
book.close:SetPoint("TOPRIGHT", -12, -12)
book.close:SetScript("OnClick", function() book:Hide() end)
book:Hide()
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OwlHUDJournal") end

RefreshJournal = function()
  if not book:IsShown() then return end
  local j = Journal()
  local pages = math.max(1, math.ceil(#j.entries / ROWS))
  if bookPage > pages then bookPage = pages end
  if bookPage < 1 then bookPage = 1 end
  book.title:SetText(Name() .. "'s Journal")
  book.stats:SetText("Day " .. Day() .. " with " .. Me() .. "  |  Level " .. Level() .. "  |  " .. j.quests .. " quests  |  " .. j.kills
    .. " kills  |  " .. j.deaths .. " deaths  |  best streak " .. j.best)
  for i = 1, ROWS do
    local entry = j.entries[(bookPage - 1) * ROWS + i]
    local row = book.rows[i]
    if entry then
      row.day:SetText("Day " .. tostring(entry.d or "?"))
      row.text:SetText(tostring(entry.t or ""))
    else
      row.day:SetText("")
      row.text:SetText(i == 1 and "Nothing written yet. Go do something worth writing down." or "")
    end
  end
  book.pageText:SetText("Page " .. bookPage .. " of " .. pages)
end
book.newer:SetScript("OnClick", function() bookPage = bookPage - 1; RefreshJournal() end)
book.older:SetScript("OnClick", function() bookPage = bookPage + 1; RefreshJournal() end)

O.commands.journal = function()
  if book:IsShown() then book:Hide(); return end
  bookPage = 1
  book:Show()
  RefreshJournal()
end

-- what gets written down
-- the first page is written once the game knows where you are (it does not yet at login)
local function StartJournal()
  local zone = Zone()
  if zone == "parts unknown" then return false end
  local j = Journal()
  if not j.started then
    j.started = true
    j.zones[zone] = true
    Note("I started keeping this journal. " .. Me() .. " was level " .. Level() .. ", in " .. zone .. ".")
  end
  for _, entry in ipairs(j.entries) do
    if type(entry.t) == "string" and entry.t:find("parts unknown", 1, true) then entry.t = entry.t:gsub("parts unknown", zone) end
  end
  j.zones["parts unknown"] = nil
  return true
end

O.On("PLAYER_LEVEL_UP", function(level)
  level = Plain(level) or Level()
  partyUntil = Now() + 90
  lastHat = false
  local j = Journal()
  table.insert(j.entries, 1, { d = Day(), l = level, t = "Level " .. level .. ", reached in " .. Zone() .. ". I hooted." })
  if RefreshJournal then RefreshJournal() end
end)

local function NoteZone()
  local zone = Zone()
  if zone == "parts unknown" then return end
  local j = Journal()
  local inside, kind = Q("IsInInstance")
  if inside and (kind == "party" or kind == "raid") then
    if not j.dungeons[zone] then
      j.dungeons[zone] = true
      Note("Went into " .. zone .. " for the first time.")
    end
  elseif not j.zones[zone] then
    j.zones[zone] = true
    Note("First steps into " .. zone .. ".")
  end
end
local function ZoneSeen()
  if StartJournal() then NoteZone() end
end
O.On("ZONE_CHANGED_NEW_AREA", ZoneSeen)
O.On("PLAYER_ENTERING_WORLD", function()
  ZoneSeen()
  if C_Timer and C_Timer.After then C_Timer.After(4, function() O.Try("owl journal", ZoneSeen) end) end
end)

O.On("QUEST_TURNED_IN", function()
  local j = Journal()
  j.quests = j.quests + 1
  if j.quests % 25 == 0 then Note(j.quests .. " quests handed in since I started counting.") end
  if RefreshJournal then RefreshJournal() end
end)

-- =====================================================================================
-- Kill streaks, and rare kills for the journal
-- =====================================================================================
local STREAK_STEPS = { [10] = true, [20] = true, [35] = true, [50] = true, [75] = true, [100] = true, [150] = true, [200] = true }
local streak, rareName = 0, nil

O.On("PLAYER_TARGET_CHANGED", function()
  if not Plain(UnitExists("target")) then return end
  local class = Plain(UnitClassification("target"))
  if class == "rare" or class == "rareelite" then
    local name = Plain(UnitName("target"))
    if type(name) == "string" then rareName = name end
  end
end)

O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("dies", 1, true) then return end
  local j = Journal()
  j.kills = j.kills + 1
  streak = streak + 1
  if streak > j.best then j.best = streak end
  if STREAK_STEPS[streak] then
    Say("streak" .. streak, { streak .. " in a row without dying!", streak .. " straight. Nobody can touch you.", "That is " .. streak .. " kills on one life. Keep it going." }, 0)
    if streak >= 35 then Note(streak .. " kills in a row without dying.") end
  end
  if rareName and msg:sub(1, #rareName) == rareName then
    Note("Brought down " .. rareName .. ", a rare one.")
    rareName = nil
  end
end)

O.On("PLAYER_DEAD", function()
  local j = Journal()
  j.deaths = j.deaths + 1
  if j.deaths == 1 then Note("The first fall I wrote down. In " .. Zone() .. ". We do not talk about it.")
  elseif j.deaths == 10 or j.deaths == 25 or j.deaths == 50 or j.deaths % 100 == 0 then Note("That makes " .. j.deaths .. " falls. Still here.") end
  streak = 0
  if RefreshJournal then RefreshJournal() end
end)

O.On("CHAT_MSG_SKILL", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local skill, value = msg:match("skill in (.-) has increased to (%d+)")
  value = tonumber(value)
  if skill and value and (value == 75 or value == 150 or value == 225 or value == 300) then Note(skill .. " reached " .. value .. ".") end
end)

-- =====================================================================================
-- A savings goal: /owl goal 100 mount
-- =====================================================================================
local function GoalCheck()
  local goal = OwlHUDDB.goal
  local money = Plain(GetMoney())
  if type(goal) ~= "table" or type(goal.gold) ~= "number" or goal.gold <= 0 or type(money) ~= "number" then return nil end
  local pct = math.floor(money / (goal.gold * 10000) * 100)
  local step = (pct >= 100 and 100) or (pct >= 75 and 75) or (pct >= 50 and 50) or (pct >= 25 and 25) or 0
  if step > (goal.said or 0) then
    goal.said = step
    if step == 100 then
      Say("goal100", { "You have enough for your " .. goal.name .. "! " .. goal.gold .. " gold. We did it.", "Goal reached: " .. goal.gold .. " gold for the " .. goal.name .. "!" }, 0)
      Note("Saved " .. goal.gold .. " gold for the " .. goal.name .. ".")
    else
      Say("goal" .. step, { step .. "% of the way to your " .. goal.name .. ".", "Your " .. goal.name .. " fund is at " .. step .. "%. Keep saving." }, 0)
    end
  end
  return pct
end
O.On("PLAYER_MONEY", function() GoalCheck() end)

O.commands.goal = function(arg)
  arg = arg or ""
  if arg == "off" then OwlHUDDB.goal = nil; O.Print("savings goal cleared."); return end
  local gold, what = arg:match("^(%d+)%s*(.-)$")
  gold = tonumber(gold)
  if gold and gold > 0 then
    what = (what or ""):gsub("[^%a ]", "")
    if what == "" then what = "goal" end
    OwlHUDDB.goal = { gold = gold, name = what, said = 0 }
    local money = Plain(GetMoney())
    if type(money) == "number" then
      local pct = math.floor(money / (gold * 10000) * 100)
      OwlHUDDB.goal.said = (pct >= 100 and 75) or (pct >= 75 and 75) or (pct >= 50 and 50) or (pct >= 25 and 25) or 0
    end
    O.Print("saving " .. gold .. " gold for your " .. what .. ". " .. Name() .. " will cheer at each quarter.")
    GoalCheck()
    return
  end
  local goal = OwlHUDDB.goal
  if type(goal) == "table" then
    local pct = GoalCheck() or 0
    O.Print("savings goal: " .. goal.gold .. " gold for your " .. goal.name .. ". You are at " .. pct .. "%.")
  else
    O.Print("no savings goal. Set one like: /owl goal 100 mount")
  end
end

-- =====================================================================================
-- Supplies, checked as you leave a town or inn
-- =====================================================================================
local function Supplies()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Item and C_Item.GetItemInfo) then return nil end
  local food, potions, known = 0, 0, 0
  for bag = 0, 4 do
    local slots = Plain(C_Container.GetContainerNumSlots(bag)) or 0
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local id = type(info) == "table" and (Plain(info.itemID) or Plain(info.hyperlink)) or nil
      if id then
        local classID, subID = select(12, C_Item.GetItemInfo(id))
        classID, subID = Plain(classID), Plain(subID)
        if classID ~= nil then known = known + 1 end
        if classID == 0 then
          local count = Plain(info.stackCount) or 1
          if subID == 5 then food = food + count elseif subID == 1 then potions = potions + count end
        end
      end
    end
  end
  if known == 0 then return nil end
  return food, potions
end

local wasResting
O.On("PLAYER_UPDATE_RESTING", function()
  local resting = Q("IsResting") and true or false
  if wasResting and not resting then
    local ok, food, potions = pcall(Supplies)
    if ok and food then
      if food < 5 then
        -- he keeps count, and after the third time he says so by name
        if type(OwlHUDDB.forgot) ~= "table" then OwlHUDDB.forgot = {} end
        local times = (tonumber(OwlHUDDB.forgot[Me()]) or 0) + 1
        local lines = { "Heading out with almost no food or water. Sure about that?", "Only " .. food .. " food and drink in your bags. Stock up?" }
        if times >= 3 then
          lines = { Me() .. ", do not forget to stock up on water. You always forget.", "Only " .. food .. " food and drink again, " .. Me() .. ". That is " .. times .. " times now. Stock up." }
        end
        if Say("supply", lines, 1200) then OwlHUDDB.forgot[Me()] = times end
      elseif potions == 0 and Level() >= 15 then
        Say("supply", { "No potions on you. A couple would not hurt.", "Leaving town without a single potion. Brave." }, 2400)
      end
    end
  end
  wasResting = resting
end)

-- =====================================================================================
-- Friends coming online
-- =====================================================================================
O.On("CHAT_MSG_SYSTEM", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("has come online", 1, true) then return end
  local who = msg:match("%[([^%]]+)%]") or msg:match("^(%S+) has come online")
  if type(who) ~= "string" or who == "" then return end
  who = who:gsub("%-.*$", "")
  if Owl.Nick then local okN, nick = pcall(Owl.Nick, who) if okN and type(nick) == "string" then who = nick end end
  Say("friend" .. who, { who .. " just came online.", "Look who it is: " .. who .. " is on.", who .. " is here. Say hello." }, 300)
end)

-- =====================================================================================
-- Owls that know each other: a hello between two players who both run OwlHUD
-- =====================================================================================
local PREFIX = "OwlHUD"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end

local function Channel()
  if Q("IsInRaid") then return "RAID" end
  if Q("IsInGroup") then return "PARTY" end
  return nil
end
local function Send(kind, extra)
  local channel = Channel()
  if not (channel and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  return (pcall(C_ChatInfo.SendAddonMessage, PREFIX, kind .. "|" .. Name() .. "|" .. tostring(extra or ""), channel))
end
local function Clean(text, limit)
  if type(text) ~= "string" then return "" end
  return (text:gsub("[|%c]", ""):sub(1, limit or 20))
end

local lastHello, grouped = -100, false
O.On("GROUP_ROSTER_UPDATE", function()
  local now = Channel() ~= nil
  if now and not grouped and Now() - lastHello > 20 then
    lastHello = Now()
    if C_Timer and C_Timer.After then C_Timer.After(2, function() Send("HELLO", Level()) end) else Send("HELLO", Level()) end
  end
  grouped = now
end)
O.On("PLAYER_LEVEL_UP", function(level) Send("LEVEL", Plain(level) or Level()) end)

O.On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
  if Plain(prefix) ~= PREFIX then return end
  text, sender = Plain(text), Plain(sender)
  if type(text) ~= "string" or type(sender) ~= "string" then return end
  local full = Clean(sender:gsub("%-.*$", ""), 24)
  sender = Owl.First(full)
  if sender == "" or sender == Me() then return end
  Owl.Full(sender, full)
  local kind, owl, extra = text:match("^(%u+)|([^|]*)|?(.*)$")
  if not kind then return end
  local long = Clean(extra, 90)
  owl, extra = Clean(owl, 16), Clean(extra, 8)
  if owl == "" then owl = "An owl" end
  if kind == "HELLO" or kind == "HI" then
    Say("owlmeet" .. sender, { owl .. " hoots hello from " .. sender .. "'s shoulder.", "Another owl! That is " .. owl .. ", " .. sender .. "'s owl.",
      "I know that owl. " .. owl .. ", travelling with " .. sender .. "." }, 900)
    local j = Journal()
    if not j.owls[sender] then
      j.owls[sender] = owl
      Note("Met " .. owl .. ", the owl who travels with " .. sender .. ".")
    end
    if kind == "HELLO" then Send("HI", Level()) end
  elseif kind == "LEVEL" then
    local lines = { owl .. " says " .. sender .. " just hit level " .. extra .. ". Show-off.", sender .. " is level " .. extra .. " now. " .. owl .. " will not stop hooting about it.",
      "Level " .. extra .. " for " .. sender .. ". " .. owl .. " is doing a little dance." }
    if Owl.LevelSay then Owl.LevelSay(sender, "owllevel" .. sender, lines, 30) else Say("owllevel" .. sender, lines, 30) end
  elseif kind == "HOOT" then
    Say("owlhoot" .. sender, { owl .. " hoots at you from " .. sender .. "'s shoulder.", owl .. " says hoo." }, 20, "c")
  end
  if Owl.onNet then pcall(Owl.onNet, kind, sender, owl, long) end
end)
Owl.net = { Send = Send }

O.commands.wave = function()
  if Send("HOOT") then Say("owlhoot", { "Hoo! I hooted at the others.", "I said hello to their owls." }, 5, "c")
  else O.Print("nobody in your group to hoot at.") end
end

-- =====================================================================================
-- Ears and eyes: words he listens for in chat, whispers, and enemy players he can see
-- =====================================================================================
O.defaults.sense = true
for _, mood in ipairs({ { "enemy", "worried" }, { "word", "worried" }, { "whisper", "happy" } }) do table.insert(Owl.moods, 1, mood) end

local function MyFaction() return Q("UnitFactionGroup", "player") end
local function EnemyName()
  return MyFaction() == "Horde" and "Alliance" or "Horde"
end

-- the words he listens for; starts with the other faction's name
local function Watch()
  if type(OwlHUDDB.watch) ~= "table" then OwlHUDDB.watch = { [EnemyName():lower()] = true } end
  -- "gank" (ganked, ganking, ganker) is added once; /owl unwatch gank removes it for good
  if not OwlHUDDB.watchGank then OwlHUDDB.watchGank = true OwlHUDDB.watch.gank = true end
  return OwlHUDDB.watch
end

-- chat text without colour codes, links or icons, cut to fit his speech box
local function Snippet(msg)
  msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|", "")
  if #msg > 78 then msg = msg:sub(1, 75) .. "..." end
  return msg
end

local function Listen(place)
  return function(msg, sender, _, channelName)
    if not OwlHUDDB.tips then return end
    msg, sender = Plain(msg), Plain(sender)
    if type(msg) ~= "string" then return end
    sender = type(sender) == "string" and sender:gsub("%-.*$", "") or "Someone"
    if sender == Me() then return end
    local low = msg:lower()
    local watch = Watch()
    local words = {}
    if watch.gank then words[1] = "gank" end
    for word in pairs(watch) do if word ~= "gank" then words[#words + 1] = word end end
    for _, word in ipairs(words) do
      if low:find(word, 1, true) then
        local where = place
        if place == "channel" then
          channelName = Plain(channelName)
          where = type(channelName) == "string" and channelName:gsub("^%d+%.%s*", ""):gsub("%s*%-.*$", "") or "a channel"
        end
        if word == "gank" then
          Say("wordgank", sender .. " mentioned ganking in " .. where .. ". Might want to watch out.", 60, "c")
          return
        end
        Say("word" .. word, sender .. " in " .. where .. ": " .. Snippet(msg), 40, "c")
        return
      end
    end
  end
end
O.On("CHAT_MSG_CHANNEL", Listen("channel"))
O.On("CHAT_MSG_SAY", Listen("say"))
O.On("CHAT_MSG_YELL", Listen("yell"))
O.On("CHAT_MSG_GUILD", Listen("guild"))
O.On("CHAT_MSG_PARTY", Listen("party"))
O.On("CHAT_MSG_PARTY_LEADER", Listen("party"))
O.On("CHAT_MSG_RAID", Listen("raid"))

O.On("CHAT_MSG_WHISPER", function(msg, sender)
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" then return end
  sender = type(sender) == "string" and sender:gsub("%-.*$", "") or "Someone"
  Say("whisper" .. sender, sender .. " whispers: " .. Snippet(msg), 8, "uc")
end)

O.commands.watch = function(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local words = Watch()
  if arg ~= "" then
    if #arg < 2 or #arg > 24 then O.Print("pick a word between 2 and 24 letters."); return end
    words[arg] = true
    O.Print(Name() .. " now listens for \"" .. arg .. "\" in chat.")
  end
  local list = {}
  for word in pairs(words) do list[#list + 1] = word end
  table.sort(list)
  O.Print("listening for: " .. (#list > 0 and table.concat(list, ", ") or "nothing") .. ".  Add: /owl watch word   Remove: /owl unwatch word")
end
O.commands.unwatch = function(arg)
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local words = Watch()
  if words[arg] then words[arg] = nil; O.Print("no longer listening for \"" .. arg .. "\".")
  else O.Print("that word was not on the list. /owl watch shows the list.") end
end

-- enemy players he can actually see: their nameplate appears, or you target or point at them
local spotted, lastSpot = {}, -100
local function Spot(unit)
  if not (OwlHUDDB.sense and OwlHUDDB.tips) then return end
  unit = Plain(unit)
  if type(unit) ~= "string" or not Plain(UnitExists(unit)) then return end
  if not Q("UnitIsPlayer", unit) then return end
  local mine, theirs = MyFaction(), Q("UnitFactionGroup", unit)
  if type(mine) ~= "string" or type(theirs) ~= "string" or theirs == mine then return end
  local inside, kind = Q("IsInInstance")
  if inside and (kind == "pvp" or kind == "arena") then return end
  local name = Plain(UnitName(unit))
  if type(name) ~= "string" then name = "Someone" end
  local now = Now()
  if (spotted[name] and now - spotted[name] < 180) or now - lastSpot < 10 then return end
  spotted[name], lastSpot = now, now
  local level, class = Plain(UnitLevel(unit)), Plain((UnitClass(unit)))
  local what = (type(level) == "number" and level > 0) and ("level " .. level) or "level ??"
  if type(class) == "string" then what = what .. " " .. class end
  local line = theirs .. " nearby: " .. name .. ", " .. what .. "."
  if type(level) == "number" and (level <= 0 or level - Level() >= 5) then line = line .. " Far above you. Careful."
  elseif Q("UnitIsPVP", unit) then line = line .. " Flagged for a fight." end
  if Owl.onEnemy then pcall(Owl.onEnemy, name, what) end
  -- history with this one, if there is any: who has the better of whom
  if Owl.pvpNote then
    local okNote, note = pcall(Owl.pvpNote, name)
    if okNote and type(note) == "string" then line = line .. note end
  end
  Say("enemy" .. name, line, 0, "uc")
end
O.On("NAME_PLATE_UNIT_ADDED", Spot)
O.On("PLAYER_TARGET_CHANGED", function() Spot("target") end)
O.On("UPDATE_MOUSEOVER_UNIT", function() Spot("mouseover") end)

O.commands.sense = function()
  OwlHUDDB.sense = not OwlHUDDB.sense
  O.Print("enemy player lookout" .. (OwlHUDDB.sense and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- =====================================================================================
-- The auction house: sales, expiries, outbids and wins, and what is waiting in the mail
-- =====================================================================================
for _, mood in ipairs({ { "sold", "excited" }, { "won", "excited" }, { "expired", "worried" }, { "outbid", "worried" }, { "auctionmail", "happy" } }) do
  table.insert(Owl.moods, 1, mood)
end

-- the game's own sentence for each event, turned into a pattern that captures the item
local function AuctionPattern(globalName, english)
  local text = _G[globalName]
  if type(text) ~= "string" or not text:find("%%s") then text = english end
  text = text:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)")
  return "^" .. text
end
local AUCTION_EVENTS = {
  { "sold", AuctionPattern("ERR_AUCTION_SOLD_S", "A buyer has been found for your auction of %s.") },
  { "expired", AuctionPattern("ERR_AUCTION_EXPIRED_S", "Your auction of %s has expired.") },
  { "outbid", AuctionPattern("ERR_AUCTION_OUTBID_S", "You have been outbid on %s.") },
  { "won", AuctionPattern("ERR_AUCTION_WON_S", "You won an auction for %s") },
}

local function Auctions()
  local a = OwlHUDDB.auctions
  if type(a) ~= "table" then a = {}; OwlHUDDB.auctions = a end
  a.sold, a.expired, a.won, a.total = a.sold or 0, a.expired or 0, a.won or 0, a.total or 0
  return a
end

local function ListItems(items)
  local text = items[1]
  if #items == 2 then text = items[1] .. " and " .. items[2]
  elseif #items > 2 then text = items[1] .. ", " .. items[2] .. " and " .. (#items - 2) .. " more" end
  return text
end

-- several can arrive in the same second (a stack of auctions ending together): said as one line
local batch, batchWaiting = { sold = {}, expired = {}, outbid = {}, won = {} }, false
local function FlushAuctions()
  batchWaiting = false
  local sold, expired, outbid, won = batch.sold, batch.expired, batch.outbid, batch.won
  batch = { sold = {}, expired = {}, outbid = {}, won = {} }
  if #sold == 1 then
    Say("sold", { "Sold! Your " .. sold[1] .. " found a buyer. The gold is in the mail.", "Someone bought your " .. sold[1] .. ". Go collect." }, 0, "c")
  elseif #sold > 1 then
    Say("sold", #sold .. " auctions sold: " .. ListItems(sold) .. ". The gold is in the mail.", 0, "c")
  end
  if #won == 1 then Say("won", { "You won the auction for " .. won[1] .. "! It is in the mail.", won[1] .. " is yours. Check the mailbox." }, 0, "c")
  elseif #won > 1 then Say("won", "You won " .. #won .. " auctions: " .. ListItems(won) .. ".", 0, "c") end
  if #outbid >= 1 then
    Say("outbid", #outbid == 1 and { "You were outbid on " .. outbid[1] .. ".", "Someone outbid you on " .. outbid[1] .. ". Your gold is back in the mail." }
      or ("Outbid on " .. #outbid .. " auctions: " .. ListItems(outbid) .. "."), 0, "c")
  end
  if #expired == 1 then
    Say("expired", { "Your " .. expired[1] .. " did not sell. It is back in your mail.", "No buyer for your " .. expired[1] .. ". Maybe a lower price." }, 0, "c")
  elseif #expired > 1 then
    Say("expired", #expired .. " auctions expired unsold: " .. ListItems(expired) .. ".", 0, "c")
  end
end

O.On("CHAT_MSG_SYSTEM", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  for i = 1, #AUCTION_EVENTS do
    local kind, pattern = AUCTION_EVENTS[i][1], AUCTION_EVENTS[i][2]
    local item = msg:match(pattern)
    if item then
      item = Snippet(item):gsub("^%[", ""):gsub("%]$", "")
      local a = Auctions()
      if kind == "sold" then
        a.sold, a.total = a.sold + 1, a.total + 1
        if a.total == 1 then Note("Sold something at the auction house for the first time: " .. item .. ".")
        elseif a.total == 25 or a.total == 100 or a.total == 500 then Note(a.total .. " auctions sold. Quite the merchant.") end
      elseif kind == "expired" then a.expired = a.expired + 1
      elseif kind == "won" then a.won = a.won + 1 end
      table.insert(batch[kind], item)
      if not batchWaiting then
        batchWaiting = true
        if C_Timer and C_Timer.After then C_Timer.After(1.5, function() O.Try("owl auctions", FlushAuctions) end) else FlushAuctions() end
      end
      return
    end
  end
end)

local function AuctionMail()
  local a = Auctions()
  local parts = {}
  if a.sold > 0 then parts[#parts + 1] = a.sold .. (a.sold == 1 and " sale" or " sales") end
  if a.won > 0 then parts[#parts + 1] = a.won .. (a.won == 1 and " auction you won" or " auctions you won") end
  if a.expired > 0 then parts[#parts + 1] = a.expired .. (a.expired == 1 and " unsold item" or " unsold items") end
  if #parts == 0 then return nil end
  return table.concat(parts, ", ")
end

-- at the mailbox: what the auction house sent, then the count starts over
O.On("MAIL_SHOW", function()
  local waiting = AuctionMail()
  if waiting then
    Say("auctionmail", "From the auction house: " .. waiting .. ". Empty the mailbox.", 0, "c")
    local a = Auctions()
    a.sold, a.expired, a.won = 0, 0, 0
  end
end)

-- back in town with auction mail still waiting
O.On("PLAYER_UPDATE_RESTING", function()
  if not Q("IsResting") then return end
  local waiting = AuctionMail()
  if waiting then Say("auctionmailwait", "Waiting in your mail from the auction house: " .. waiting .. ".", 900) end
end)

O.commands.auctions = function()
  local waiting = AuctionMail()
  O.Print(waiting and ("waiting in your mail from the auction house: " .. waiting .. ".") or "nothing from the auction house waiting that I know of.")
  O.Print(Auctions().total .. " auctions sold since " .. Name() .. " started counting.")
end

-- =====================================================================================
-- Practical help: new spells missing from your bars, a ready check, quest nudges,
-- session numbers, reminders, quick whisper replies, a gear guard, a herbalism coach
-- =====================================================================================
for _, mood in ipairs({ { "newspell", "excited" }, { "ready", "happy" }, { "notready", "worried" }, { "quests", "happy" }, { "questlog", "worried" },
  { "stats", "happy" }, { "restedout", "sleepy" }, { "remind", "excited" }, { "gear", "worried" }, { "herb", "worried" } }) do
  table.insert(Owl.moods, 1, mood)
end

local function Join(list, limit)
  local shown = {}
  for i = 1, math.min(#list, limit or 3) do shown[i] = list[i] end
  local text = table.concat(shown, ", ")
  if #list > #shown then text = text .. " and " .. (#list - #shown) .. " more" end
  return text
end

-- ---------- spells: what is in your spellbook, and what is on your bars ----------
local function BookSpells()
  local names = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line = 1, Plain(C_SpellBook.GetNumSpellBookSkillLines()) or 0 do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
      if type(info) == "table" and not info.isGuild and not Plain(info.offSpecID) then
        local first = (Plain(info.itemIndexOffset) or 0) + 1
        for slot = first, first + (Plain(info.numSpellBookItems) or 0) - 1 do
          local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
          if type(item) == "table" and Plain(item.itemType) == spellType and not Plain(item.isPassive) and not Plain(item.isOffSpec) then
            local name = Plain(item.name)
            if type(name) == "string" and name ~= "" then
              names[name] = line
              local id = Plain(item.spellID) or Plain(item.actionID)
              if type(id) == "number" then O.OwlBookIds = O.OwlBookIds or {} O.OwlBookIds[name] = id end
            end
          end
        end
      end
    end
    return names, true
  end
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    for tab = 1, Plain(GetNumSpellTabs()) or 0 do
      local _, _, offset, count = GetSpellTabInfo(tab)
      offset, count = Plain(offset) or 0, Plain(count) or 0
      for slot = offset + 1, offset + count do
        local name = Plain((GetSpellBookItemName(slot, "spell")))
        if type(name) == "string" and name ~= "" and not (IsPassiveSpell and Plain(IsPassiveSpell(slot, "spell"))) then names[name] = tab end
      end
    end
    return names, true
  end
  return names, false
end

local function BarSpells()
  local names = {}
  if not GetActionInfo then return names end
  for slot = 1, 180 do
    local kind, id = GetActionInfo(slot)
    kind, id = Plain(kind), Plain(id)
    if kind == "macro" and id and GetMacroSpell then id = Plain(GetMacroSpell(id)); kind = id and "spell" or kind end
    if kind == "spell" and id then
      local name = O.SpellName(id)
      if type(Plain(name)) == "string" then names[name] = true end
    end
  end
  -- some bar setups do not answer the slot-by-slot question: ask the game spell by spell instead
  if not next(names) and C_ActionBar then
    if not O.OwlBookIds then pcall(BookSpells) end
    for name, id in pairs(O.OwlBookIds or {}) do
      local found = false
      if C_ActionBar.FindSpellActionButtons then
        local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, id)
        if ok and type(slots) == "table" and #slots > 0 then found = true end
      end
      if not found and C_ActionBar.IsOnBarOrSpecialBar then
        local ok, on = pcall(C_ActionBar.IsOnBarOrSpecialBar, id)
        if ok and Plain(on) == true then found = true end
      end
      if found then names[name] = true end
    end
  end
  -- (second value: could he read the bars at all?)
  return names, next(names) ~= nil
end

local spellCheckAt
local function CheckNewSpells()
  local book, readable = BookSpells()
  if not readable then return end
  local seen = OwlHUDDB.spellsKnown
  if type(seen) ~= "table" then
    -- the first look only takes stock: nothing is "new" yet
    seen = {}
    for name in pairs(book) do seen[name] = true end
    OwlHUDDB.spellsKnown = seen
    return
  end
  local bars, readable = BarSpells()
  local missing, fresh = {}, {}
  for name in pairs(book) do
    if not seen[name] then
      seen[name] = true
      fresh[#fresh + 1] = name
      if not bars[name] then missing[#missing + 1] = name end
    end
  end
  table.sort(missing)
  table.sort(fresh)
  if not readable then
    -- he cannot see the bars here, so he does not claim anything about them
    if #fresh == 1 then Say("newspell", "You learned " .. fresh[1] .. ". Make sure it has a button.", 0)
    elseif #fresh > 1 then Say("newspell", "New at the trainer: " .. Join(fresh, 3) .. ". Make sure they have buttons.", 0) end
  elseif #missing == 1 then
    Say("newspell", { missing[1] .. " is new, and it is not on your bars yet.", "You learned " .. missing[1] .. ". Find it a button." }, 0)
  elseif #missing > 1 then
    Say("newspell", "New and not on your bars yet: " .. Join(missing, 3) .. ".", 0)
  end
end
local function QueueSpellCheck() spellCheckAt = Now() + 4 end
O.On("SPELLS_CHANGED", QueueSpellCheck)
O.On("LEARNED_SPELL_IN_TAB", QueueSpellCheck)
O.On("TRAINER_CLOSED", QueueSpellCheck)

O.commands.spells = function()
  local book, readable = BookSpells()
  if not readable then O.Print("this version of the game does not let me read your spellbook."); return end
  local bars, canRead = BarSpells()
  if not canRead then O.Print("I cannot see your action bars with this setup, so I cannot tell which spells have no button.") return end
  local missing = {}
  for name, line in pairs(book) do
    if line ~= 1 and not bars[name] then missing[#missing + 1] = name end
  end
  table.sort(missing)
  if #missing == 0 then O.Print("every spell in your spellbook is on a bar.")
  else O.Print("in your spellbook but not on any bar: " .. table.concat(missing, ", ") .. ".") end
end

-- ---------- a ready check ----------
local function Durability()
  local lowest = 1
  if not GetInventoryItemDurability then return nil end
  local any = false
  for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    cur, max = Plain(cur), Plain(max)
    if cur and max and max > 0 then
      any = true
      if cur / max < lowest then lowest = cur / max end
    end
  end
  return any and lowest or nil
end

local function ReadyReport()
  local good, bad = {}, {}
  local dur = Durability()
  if dur then
    local pct = math.floor(dur * 100 + 0.5)
    if pct < 30 then bad[#bad + 1] = "gear at " .. pct .. "%, repair first" else good[#good + 1] = "gear " .. pct .. "%" end
  end
  local free = math.floor(tonumber(Owl.FreeBagSlots()) or 0)
  if free <= 3 then bad[#bad + 1] = "only " .. free .. " bag slots" else good[#good + 1] = free .. " bag slots" end
  local ok, food, potions = pcall(Supplies)
  if ok and food then
    if food < 5 then bad[#bad + 1] = "only " .. food .. " food and drink" else good[#good + 1] = food .. " food and drink" end
    good[#good + 1] = potions .. (potions == 1 and " potion" or " potions")
  end
  if Owl.class == "PALADIN" and C_UnitAuras and C_UnitAuras.GetBuffDataByIndex and not Plain(UnitAffectingCombat("player")) then
    local blessing, aura, readable = false, false, true
    for i = 1, 40 do
      local fine, data = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
      if not fine then readable = false; break end
      if not data then break end
      local name = Plain(data.name)
      if type(name) == "string" then
        if name:find("Blessing", 1, true) then blessing = true elseif name:find("Aura", 1, true) then aura = true end
      end
    end
    if readable then
      if not blessing then bad[#bad + 1] = "no blessing" end
      if not aura then bad[#bad + 1] = "no aura" end
    end
  end
  return good, bad
end

local function SayReady(always)
  local good, bad = ReadyReport()
  if #bad > 0 then
    Say("notready", "Not quite ready: " .. table.concat(bad, ", ") .. ".", always and 0 or 300, "c")
  elseif always then
    Say("ready", "Good to go: " .. table.concat(good, ", ") .. ".", 0, "c")
  end
end
O.commands.ready = function() SayReady(true) end

local wasGroupedForReady = false
O.On("GROUP_ROSTER_UPDATE", function()
  local grouped = Q("IsInGroup") and true or false
  if grouped and not wasGroupedForReady and C_Timer and C_Timer.After then
    C_Timer.After(6, function() O.Try("owl ready check", SayReady, false) end)
  end
  wasGroupedForReady = grouped
end)

-- ---------- quests ready to hand in, and a nearly full log ----------
local function QuestCounts()
  local total, done = 0, 0
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, Plain(C_QuestLog.GetNumQuestLogEntries()) or 0 do
      local info = C_QuestLog.GetInfo(i)
      if type(info) == "table" and not Plain(info.isHeader) and not Plain(info.isHidden) then
        total = total + 1
        local id = Plain(info.questID)
        local complete = id and ((C_QuestLog.ReadyForTurnIn and Plain(C_QuestLog.ReadyForTurnIn(id))) or (C_QuestLog.IsComplete and Plain(C_QuestLog.IsComplete(id))))
        if complete then done = done + 1 end
      end
    end
    return total, done, C_QuestLog.GetMaxNumQuestsCanAccept and Plain(C_QuestLog.GetMaxNumQuestsCanAccept()) or nil
  end
  if GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, Plain(GetNumQuestLogEntries()) or 0 do
      local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
      if Plain(title) and not Plain(isHeader) then
        total = total + 1
        if Plain(isComplete) == 1 or Plain(isComplete) == true then done = done + 1 end
      end
    end
    return total, done, nil
  end
  return nil
end

local wasRestingForQuests
O.On("PLAYER_UPDATE_RESTING", function()
  local resting = Q("IsResting") and true or false
  if resting and wasRestingForQuests == false then
    local ok, total, done = pcall(QuestCounts)
    if ok and done and done > 0 then
      Say("quests", done == 1 and "You have a quest ready to hand in." or ("You have " .. done .. " quests ready to hand in."), 600)
    end
  end
  wasRestingForQuests = resting
end)
O.On("QUEST_ACCEPTED", function()
  local ok, total, _, max = pcall(QuestCounts)
  if ok and total and max and max > 0 and total >= max - 2 then
    Say("questlog", "Your quest log is nearly full: " .. total .. " of " .. max .. ".", 600)
  end
end)

-- ---------- session numbers ----------
local session = { start = nil, xp = 0, lastXP = nil, lastMax = nil, money = nil, kills = 0, deaths = 0, rested = nil }
Owl.session = session
O.On("PLAYER_LOGIN", function()
  session.start = Now()
  session.lastXP, session.lastMax = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  session.money = Plain(GetMoney())
  local rested = Q("GetXPExhaustion")
  session.rested = type(rested) == "number" and rested > 0
end)
O.On("PLAYER_XP_UPDATE", function()
  local xp, max = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  if type(xp) ~= "number" or type(max) ~= "number" then return end
  if type(session.lastXP) == "number" then
    if xp >= session.lastXP then session.xp = session.xp + (xp - session.lastXP)
    else session.xp = session.xp + ((session.lastMax or session.lastXP) - session.lastXP) + xp end
  end
  session.lastXP, session.lastMax = xp, max
  local rested = Q("GetXPExhaustion")
  local now = type(rested) == "number" and rested > 0
  if session.rested and not now then Say("restedout", { "Your rested XP just ran out. Normal XP from here.", "The blue bar is empty. An inn would fix that." }, 600) end
  session.rested = now
end)
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) == "string" and msg:find("dies", 1, true) then session.kills = session.kills + 1 end
end)
O.On("PLAYER_DEAD", function() session.deaths = session.deaths + 1 end)

local function Duration(seconds)
  local minutes = math.floor(seconds / 60 + 0.5)
  if minutes < 60 then return minutes .. " min" end
  return math.floor(minutes / 60) .. " h " .. (minutes % 60) .. " min"
end

O.commands.stats = function()
  if not session.start then O.Print("no session numbers yet."); return end
  local played = math.max(1, Now() - session.start)
  local perHour = math.floor(session.xp / played * 3600)
  local first = "This session: " .. Duration(played) .. ", " .. session.kills .. " kills, " .. session.deaths .. (session.deaths == 1 and " death" or " deaths") .. "."
  local second = perHour .. " XP an hour."
  local xp, max = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  if perHour > 0 and type(xp) == "number" and type(max) == "number" and max > xp then
    second = second .. " Level " .. (Level() + 1) .. " in about " .. Duration((max - xp) / perHour * 3600) .. " at this pace."
  end
  local money = Plain(GetMoney())
  local third
  if type(money) == "number" and type(session.money) == "number" then
    local diff = money - session.money
    third = (diff >= 0 and "Gold earned: " or "Gold spent: ") .. O.Money(math.abs(diff)) .. "."
  end
  O.Print(first) O.Print(second) if third then O.Print(third) end
  Owl.lastStats = { first, second, third }
  for i, line in ipairs(Owl.lastStats) do Say("stats" .. i .. Now(), line, 0, "c") end
end

-- ---------- reminders: /owl remind 20 check the auction house ----------
local function Reminders()
  if type(OwlHUDDB.reminders) ~= "table" then OwlHUDDB.reminders = {} end
  return OwlHUDDB.reminders
end
O.commands.remind = function(arg)
  arg = arg or ""
  local list = Reminders()
  if arg == "clear" then OwlHUDDB.reminders = {}; O.Print("all reminders cleared."); return end
  local minutes, text = arg:match("^(%d+)%s*(.*)$")
  minutes = tonumber(minutes)
  if minutes and minutes > 0 and minutes <= 1440 then
    text = (text or ""):gsub("^%s+", "")
    if text == "" then text = "time is up" end
    text = text:sub(1, 1):upper() .. text:sub(2, 80)
    list[#list + 1] = { at = Clock() + minutes * 60, text = text }
    O.Print(Name() .. " will remind you in " .. minutes .. " min: " .. text)
    return
  end
  if #list == 0 then O.Print("no reminders. Set one like: /owl remind 20 check the auction house") return end
  for _, r in ipairs(list) do O.Print("in " .. Duration(math.max(0, r.at - Clock())) .. ": " .. tostring(r.text)) end
  O.Print("/owl remind clear removes them all.")
end

-- ---------- quick replies to a whisper ----------
local REPLIES = { "On my way.", "One sec.", "Can't right now, sorry.", "Thanks!" }
local replyTo, replyUntil = nil, 0
local replies = CreateFrame("Frame", "OwlHUDReplies", UIParent)
replies:SetSize(330, 46)
replies:SetPoint("TOPLEFT", pal.bubble, "BOTTOMLEFT", 0, -4)
replies:SetFrameStrata("HIGH")
replies.label = replies:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
replies.label:SetPoint("TOPLEFT", 2, 0)
replies:Hide()
for i = 1, #REPLIES do
  local b = CreateFrame("Button", nil, replies)
  b:SetSize(158, 20)
  b:SetPoint("TOPLEFT", replies, "TOPLEFT", ((i - 1) % 2) * 162, -14 - math.floor((i - 1) / 2) * 23)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(REPLIES[i])
  b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.28, 0.2, 0.06, 0.95) end)
  b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9) end)
  b:SetScript("OnClick", function()
    if replyTo and SendChatMessage then
      local sent = pcall(SendChatMessage, REPLIES[i], "WHISPER", nil, replyTo)
      O.Print(sent and ("told " .. replyTo:gsub("%-.*$", "") .. ": " .. REPLIES[i]) or "the game would not send that whisper.")
    end
    replies:Hide()
  end)
end
O.On("CHAT_MSG_WHISPER", function(_, sender)
  sender = Plain(sender)
  if type(sender) ~= "string" or sender == "" or not OwlHUDDB.tips or OwlHUDDB.replies == false then return end
  if pal.menu and pal.menu:IsShown() then return end
  replyTo, replyUntil = sender, Now() + 30
  replies.label:SetText("Reply to " .. sender:gsub("%-.*$", "") .. ":")
  replies:Show()
end)
O.commands.replies = function()
  OwlHUDDB.replies = OwlHUDDB.replies == false
  if not OwlHUDDB.replies then replies:Hide() end
  O.Print("quick whisper replies" .. (OwlHUDDB.replies and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- gear guard, as a fight starts ----------
O.On("PLAYER_REGEN_DISABLED", function()
  if not GetInventoryItemID then return end
  local weapon = Plain(GetInventoryItemID("player", 16))
  if not weapon then Say("gearnone", "You have no weapon equipped!", 60, "uc"); return end
  if C_Item and C_Item.GetItemInfo then
    local classID, subID = select(12, C_Item.GetItemInfo(weapon))
    if Plain(classID) == 2 and Plain(subID) == 20 then Say("gearpole", "You are fighting with a fishing pole!", 60, "uc"); return end
  end
  if GetInventoryItemDurability then
    local cur, max = GetInventoryItemDurability(16)
    if Plain(cur) == 0 and (Plain(max) or 0) > 0 then Say("gearbroken", "Your weapon is broken! Repair it.", 120, "uc") end
  end
end)

-- ---------- herbalism coach: is your skill high enough for this zone? ----------
local HERB_ZONES = {
  ["Westfall"] = 50, ["Loch Modan"] = 50, ["Darkshore"] = 50, ["Silverpine Forest"] = 50, ["The Barrens"] = 50,
  ["Redridge Mountains"] = 50, ["Ashenvale"] = 70, ["Stonetalon Mountains"] = 70, ["Duskwood"] = 70, ["Wetlands"] = 85,
  ["Hillsbrad Foothills"] = 100, ["Thousand Needles"] = 115, ["Arathi Highlands"] = 125, ["Stranglethorn Vale"] = 125,
  ["Alterac Mountains"] = 125, ["Desolace"] = 125, ["Dustwallow Marsh"] = 150, ["Swamp of Sorrows"] = 150, ["Badlands"] = 160,
  ["Tanaris"] = 190, ["Feralas"] = 190, ["The Hinterlands"] = 190, ["Searing Gorge"] = 200, ["Felwood"] = 230, ["Un'Goro Crater"] = 230,
  ["Western Plaguelands"] = 250, ["Eastern Plaguelands"] = 270, ["Winterspring"] = 270,
}
O.On("CHAT_MSG_SKILL", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local skill, value = msg:match("skill in (.-) has increased to (%d+)")
  if skill and tonumber(value) then
    if type(OwlHUDDB.skills) ~= "table" then OwlHUDDB.skills = {} end
    OwlHUDDB.skills[skill] = tonumber(value)
  end
end)
O.On("ZONE_CHANGED_NEW_AREA", function()
  if O.OwlHerbCoach then
    local ok, handled = pcall(O.OwlHerbCoach)
    if ok and handled then return end
  end
  local have = type(OwlHUDDB.skills) == "table" and OwlHUDDB.skills.Herbalism
  local need = HERB_ZONES[Zone()]
  if have and need and have < need then
    Say("herb" .. Zone(), "Most herbs here want about " .. need .. " Herbalism. Yours was " .. have .. " last I saw.", 1800)
  end
end)

-- ---------- one slow tick for the timers above ----------
local extraAcc, extraDead = 0, false
local extraDriver = CreateFrame("Frame")
extraDriver:SetScript("OnUpdate", function(_, e)
  if extraDead then return end
  extraAcc = extraAcc + e
  if extraAcc < 1 then return end
  extraAcc = 0
  local ok, err = pcall(function()
    if spellCheckAt and Now() >= spellCheckAt and not Plain(UnitAffectingCombat("player")) then
      spellCheckAt = nil
      CheckNewSpells()
    end
    if replies:IsShown() and Now() > replyUntil then replies:Hide() end
    local list = OwlHUDDB.reminders
    if type(list) == "table" and #list > 0 then
      local clock = Clock()
      for i = #list, 1, -1 do
        if type(list[i]) ~= "table" or type(list[i].at) ~= "number" then table.remove(list, i)
        elseif clock >= list[i].at then
          Say("remind" .. i .. clock, "Reminder: " .. tostring(list[i].text), 0, "uc")
          table.remove(list, i)
        end
      end
    end
  end)
  if not ok then
    extraDead = true
    O.Print("|cffff4040owl extras turned off:|r " .. tostring(err))
  end
end)

-- =====================================================================================
-- Knowing you: he reads your character sheet (out of combat only) and remembers it
-- =====================================================================================
table.insert(Owl.moods, 1, { "newgear", "excited" })
table.insert(Owl.moods, 1, { "memory", "happy" })

local function Pack(ok, ...)
  if not ok then return { n = 0 } end
  local t = { n = select("#", ...) }
  for i = 1, t.n do t[i] = Plain((select(i, ...))) end
  return t
end
local function Call(name, ...)
  local fn = _G[name]
  if type(fn) ~= "function" then return { n = 0 } end
  return Pack(pcall(fn, ...))
end
local function Str(v) return type(v) == "string" and v ~= "" and v or nil end
local function Num(v) return type(v) == "number" and v or nil end
local moneyKept
Owl.Money = function()
  local m = Plain(GetMoney())
  if type(m) == "number" and m > 0 then moneyKept = m end
  return moneyKept or (type(m) == "number" and m or nil)
end
for _, event in ipairs({ "PLAYER_MONEY", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN", "MERCHANT_CLOSED", "MAIL_CLOSED" }) do O.On(event, function() Owl.Money() end) end

local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
-- slot id, what to call it, the level by which most characters have one
local SLOTS = { { 16, "weapon", 1 }, { 1, "helmet", 26 }, { 3, "shoulders", 22 }, { 15, "cloak", 15 }, { 5, "chest piece", 5 }, { 9, "bracers", 12 },
  { 10, "gloves", 10 }, { 6, "belt", 10 }, { 7, "leggings", 5 }, { 8, "boots", 8 }, { 11, "ring", 32 }, { 12, "second ring", 36 }, { 2, "necklace", 36 },
  { 17, "off hand", 999 }, { 18, "ranged slot", 999 } }

local me = { gear = {}, stats = {}, profs = {}, trees = {} }
Owl.me = me

local function ItemFacts(link)
  local name, quality, ilvl
  if C_Item and C_Item.GetItemInfo then
    local r = Pack(pcall(C_Item.GetItemInfo, link))
    name, quality, ilvl = Str(r[1]), Num(r[3]), Num(r[4])
  end
  if not name then
    local r = Call("GetItemInfo", link)
    name, quality, ilvl = Str(r[1]), Num(r[3]), Num(r[4])
  end
  if not name then name = link:match("%[(.-)%]") end
  if C_Item and C_Item.GetDetailedItemLevelInfo then
    local r = Pack(pcall(C_Item.GetDetailedItemLevelInfo, link))
    if Num(r[1]) and r[1] > 0 then ilvl = r[1] end
  end
  return name, quality, ilvl
end

local function Gather()
  me.name = Me()
  me.realm = Str(Call("GetRealmName")[1])
  local r = Call("UnitRace", "player")
  me.race, me.raceToken = Str(r[1]), Str(r[2])
  r = Call("GetGuildInfo", "player")
  me.guild, me.guildRank = Str(r[1]), Str(r[2])
  me.home = Str(Call("GetBindLocation")[1])
  me.level = Level()

  me.stats = {}
  for i = 1, 5 do
    r = Call("UnitStat", "player", i)
    local v = Num(r[2]) or Num(r[1])
    if v and v > 0 then me.stats[#me.stats + 1] = { STAT_NAMES[i], math.floor(v) } end
  end
  r = Call("UnitArmor", "player")
  me.armor = Num(r[2]) or Num(r[1])
  me.health = Num(Plain(UnitHealthMax("player")))

  me.gear = {}
  local total, count = 0, 0
  for _, s in ipairs(SLOTS) do
    local link = Str(Call("GetInventoryItemLink", "player", s[1])[1])
    if link then
      local name, quality, ilvl = ItemFacts(link)
      if name then
        me.gear[s[1]] = { name = name, quality = quality, ilvl = ilvl, slot = s[2], link = link }
        if ilvl and s[1] ~= 18 then total, count = total + ilvl, count + 1 end
      end
    end
  end
  me.ilvl = count >= 4 and math.floor(total / count + 0.5) or nil

  me.profs = {}
  local seen = {}
  local lines = Num(Call("GetNumSkillLines")[1])
  if lines then
    local wanted = false
    for i = 1, lines do
      r = Call("GetSkillLineInfo", i)
      local name = Str(r[1])
      if name and r[2] then
        local low = name:lower()
        wanted = low:find("profession", 1, true) ~= nil or low:find("secondary", 1, true) ~= nil
      elseif name and wanted and Num(r[4]) and not seen[name] then
        seen[name] = true
        me.profs[#me.profs + 1] = { name, r[4], Num(r[7]) }
      end
    end
  end
  if #me.profs == 0 then
    local p = Call("GetProfessions")
    for i = 1, p.n do
      if Num(p[i]) then
        r = Call("GetProfessionInfo", p[i])
        if Str(r[1]) and Num(r[3]) and not seen[r[1]] then
          seen[r[1]] = true
          me.profs[#me.profs + 1] = { r[1], r[3], Num(r[4]) }
        end
      end
    end
  end
  if #me.profs == 0 and type(OwlHUDDB.skills) == "table" then
    for _, name in ipairs({ "Herbalism", "Mining", "Skinning", "Alchemy", "Blacksmithing", "Engineering", "Leatherworking", "Tailoring", "Enchanting", "Cooking", "Fishing", "First Aid" }) do
      if Num(OwlHUDDB.skills[name]) then me.profs[#me.profs + 1] = { name, OwlHUDDB.skills[name] } end
    end
  end

  me.trees = {}
  for tab = 1, math.min(Num(Call("GetNumTalentTabs")[1]) or 0, 5) do
    r = Call("GetTalentTabInfo", tab)
    local name, points
    if Str(r[1]) then name, points = r[1], Num(r[3]) else name, points = Str(r[2]), Num(r[5]) end
    if name and points and points > 0 then me.trees[#me.trees + 1] = { name, points } end
  end
  table.sort(me.trees, function(a, b) return a[2] > b[2] end)

  me.rep = nil
  local best = 4
  local factions = Num(Call("GetNumFactions")[1])
  if factions then
    for i = 1, math.min(factions, 120) do
      r = Call("GetFactionInfo", i)
      if Str(r[1]) and Num(r[3]) and not r[9] and r[3] > best and r[3] <= 8 then best = r[3]; me.rep = { r[1], STANDING[r[3]] } end
    end
  elseif C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    local n = Num(Plain(C_Reputation.GetNumFactions())) or 0
    for i = 1, math.min(n, 120) do
      local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
      if ok and type(d) == "table" then
        local name, standing = Str(Plain(d.name)), Num(Plain(d.reaction))
        if name and standing and not Plain(d.isHeader) and standing > best and standing <= 8 then best = standing; me.rep = { name, STANDING[standing] } end
      end
    end
  end
  me.kills = Num(Call("GetPVPLifetimeStats")[1])
  me.gathered = true
end

-- ---------- what he remembers between sessions, per character ----------
local function Record()
  if type(OwlHUDDB.chars) ~= "table" then OwlHUDDB.chars = {} end
  -- His memory of you is filed under your name and realm. Some sessions the game does not give the realm's name;
  -- he used to open a blank second book ("Name-") and forget everything. Now he remembers the realm himself, and
  -- failing that picks the fullest book he already keeps under your name.
  local name, realm = Me(), Str(Call("GetRealmName")[1])
  if type(OwlHUDDB.realmOf) ~= "table" then OwlHUDDB.realmOf = {} end
  if realm then OwlHUDDB.realmOf[name] = realm else realm = Str(OwlHUDDB.realmOf[name]) end
  local key = name .. "-" .. (realm or "")
  local blank = name .. "-"
  if not realm and name ~= "" then
    local best, bestN = nil, -1
    for k, v in pairs(OwlHUDDB.chars) do
      if type(k) == "string" and k ~= blank and k:sub(1, #blank) == blank and type(v) == "table" and (Num(v.sessions) or 0) > bestN then best, bestN = k, Num(v.sessions) or 0 end
    end
    if best then key = best end
  end
  -- a blank book left over from such a session is folded back into the real one
  local stray = key ~= blank and name ~= "" and OwlHUDDB.chars[blank]
  if type(stray) == "table" then
    local main = OwlHUDDB.chars[key]
    if type(main) == "table" then
      for _, field in ipairs({ "bond", "playedSecs", "sessions" }) do main[field] = (Num(main[field]) or 0) + (Num(stray[field]) or 0) end
      OwlHUDDB.chars[blank] = nil
    end
  end
  local rec = OwlHUDDB.chars[key]
  if type(rec) ~= "table" then
    rec = { firstSeen = Clock(), sessions = 0 }
    OwlHUDDB.chars[key] = rec
  end
  return rec
end
Owl.Record = Record

local function SlotWord(id) for _, s in ipairs(SLOTS) do if s[1] == id then return s[2] end end return "gear" end

local function Remember(announce)
  local rec = Record()
  local old = rec.gear
  if announce and type(old) == "table" then
    local changed = {}
    for id, item in pairs(me.gear) do
      if old[id] ~= item.name then changed[#changed + 1] = id end
    end
    if #changed == 1 then
      local item = me.gear[changed[1]]
      local was = type(rec.ilvls) == "table" and Num(rec.ilvls[changed[1]])
      local gain = (item.ilvl and was and item.ilvl > was) and (" Up " .. (item.ilvl - was) .. " item levels.") or ""
      if O.OwlRankSuffix then
        local ok, extra = pcall(O.OwlRankSuffix, item.link)
        if ok and type(extra) == "string" then gain = gain .. extra end
      end
      if item.quality and item.quality >= 4 then Say("newgear", "An epic! " .. item.name .. ". Look at you.", 15)
      elseif item.quality == 3 then Say("newgear", "A rare one: " .. item.name .. ". It suits you." .. gain, 15)
      else Say("newgear", "New " .. item.slot .. ": " .. item.name .. "." .. gain, 15) end
    elseif #changed > 1 then
      Say("newgear", { "New gear all round. Looking sharp.", #changed .. " new pieces at once. Somebody went shopping." }, 30)
    end
  end
  rec.gear, rec.ilvls = {}, {}
  for id, item in pairs(me.gear) do rec.gear[id] = item.name; rec.ilvls[id] = item.ilvl end
  rec.lastSeen, rec.lastZone, rec.lastLevel = Clock(), Zone(), Level()
end

-- ---------- things only your owl would say ----------
local RACE_LINES = {
  Human = { "Humans. Short lives, big plans. I respect it." },
  Dwarf = { "A dwarf never loses the way home. Or the way to the tavern." },
  NightElf = { "Your people keep owl hours. We understand each other." },
  Gnome = { "You are closer to my size than most. I appreciate that." },
  Orc = { "Strength and honor. I am told that is the phrase." },
  Troll = { "Your people regenerate. Mine molt. Close enough." },
  Tauren = { "Your stride covers ground. I get to rest my wings." },
  Scourge = { "You have already died once. It did not stick. Good." },
  BloodElf = { "You do look good doing this. I will admit it." },
  Draenei = { "A long way from home. So was I, once." },
}
local saidPersonal = {}
local function Days(seconds) return math.floor(seconds / 86400) end

local function PersonalLines()
  local out, name, level = {}, me.name or Me(), Level()
  local function add(text) if text and not saidPersonal[text] then out[#out + 1] = text end end
  local weapon = me.gear[16]
  if weapon then
    add("That " .. weapon.name .. " suits you.")
    add(weapon.name .. ". Still my favorite thing you own.")
  end
  if me.guild then
    add("<" .. me.guild .. "> is lucky to have you.")
    if me.guildRank then add(me.guildRank .. " of <" .. me.guild .. ">. It has a ring to it.") end
  elseif level >= 15 then
    add("No guild yet. A good one makes dungeon groups easier to find.")
  end
  if me.home then add("Your hearthstone leads to " .. me.home .. ". Good to know the way home.") end
  for _, p in ipairs(me.profs) do
    if p[3] and p[2] >= p[3] and p[3] < 300 then add(p[1] .. " is capped at " .. p[2] .. ". A trainer can raise the limit.")
    else add(p[1] .. " " .. p[2] .. ". You have been busy.") end
  end
  local top
  for _, s in ipairs(me.stats) do if not top or s[2] > top[2] then top = s end end
  if top then add(top[1] .. " " .. top[2] .. ". I can tell.") end
  if me.armor and me.armor > 0 then add(math.floor(me.armor) .. " armor between you and the world.") end
  if me.ilvl then add("Your gear averages item level " .. me.ilvl .. ".") end
  if me.trees[1] then add(me.trees[1][2] .. " points in " .. me.trees[1][1] .. ". You have picked your path.") end
  if me.rep then add(me.rep[2] .. " with " .. me.rep[1] .. ". They like you there.") end
  if me.kills and me.kills >= 10 then add(me.kills .. " honorable kills to your name.") end
  -- useful ones: an empty slot, or the piece that has fallen furthest behind
  if me.gathered then
    for _, s in ipairs(SLOTS) do
      if not me.gear[s[1]] and level >= s[3] then add("You have no " .. s[2] .. " equipped. Anything beats an empty slot.") break end
    end
    if me.ilvl then
      local worst
      for id, item in pairs(me.gear) do
        if id ~= 18 and item.ilvl and (not worst or item.ilvl < worst.ilvl) then worst = item end
      end
      if worst and worst.ilvl <= me.ilvl - 8 then add("Your " .. worst.slot .. ", " .. worst.name .. ", is your oldest piece. Replace it first.") end
    end
  end
  local rec = Record()
  local days = Days(Clock() - (rec.firstSeen or Clock()))
  if days >= 2 then add("We have traveled together for " .. days .. " days now, " .. name .. ".") end
  if (rec.sessions or 0) >= 5 then add((rec.sessions) .. " times you have logged in and found me here. I like the routine.") end
  for _, text in ipairs(RACE_LINES[me.raceToken or ""] or {}) do add(text) end
  if name:lower():find("owl", 1, true) then add("An " .. name .. " and an owl. We were always going to get along.")
  elseif name ~= "" then add(name .. ". Still a good name.") end
  if me.race and Owl.className then add("A " .. me.race .. " " .. Owl.className .. ", level " .. level .. ". I would follow no one else.") end
  return out
end

O.OwlPersonal = function()
  if not me.gathered then return nil end
  local lines = PersonalLines()
  if #lines == 0 then saidPersonal = {} return nil end
  local text = lines[math.random(#lines)]
  saidPersonal[text] = true
  return text
end

-- ---------- keeping the picture fresh ----------
local gatherAt, announceGear, greeted = nil, false, false
local function QueueGather(delay, announce)
  local at = Now() + (delay or 3)
  if not gatherAt or at < gatherAt then gatherAt = at end
  if announce then announceGear = true end
end
O.On("PLAYER_EQUIPMENT_CHANGED", function() QueueGather(2, true) end)
for _, event in ipairs({ "PLAYER_GUILD_UPDATE", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "UPDATE_FACTION", "HEARTHSTONE_BOUND", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA" }) do
  O.On(event, function() QueueGather(6, false) end)
end

O.On("PLAYER_LOGIN", function()
  local rec = Record()
  local prev = { seen = rec.lastSeen, zone = rec.lastZone, level = rec.lastLevel, sessions = rec.sessions or 0 }
  rec.sessions = (rec.sessions or 0) + 1
  QueueGather(8, false)
  if C_Timer and C_Timer.After then
    C_Timer.After(14, function()
      O.Try("owl memory", function()
        if greeted then return end
        greeted = true
        local name = Me()
        if not prev.seen then
          Say("memory", "I will remember this day, " .. name .. ". Our first.", 0)
          return
        end
        local away = Clock() - prev.seen
        local first
        if away < 3600 then first = "Back so soon, " .. name .. "? Good."
        elseif away < 86400 then first = "Welcome back, " .. name .. "."
        elseif Days(away) == 1 then first = "A day away, " .. name .. ". I kept watch."
        else first = Days(away) .. " days away, " .. name .. ". I kept watch." end
        Say("memory", first, 0)
        if prev.zone and prev.level and prev.zone ~= "parts unknown" then
          Say("memory2", "Last time we stopped in " .. prev.zone .. " at level " .. prev.level .. ".", 0)
        end
      end)
    end)
  end
end)
O.On("PLAYER_LOGOUT", function() pcall(Remember, false) end)

local meAcc, meDead = 0, false
local meDriver = CreateFrame("Frame")
meDriver:SetScript("OnUpdate", function(_, e)
  if meDead then return end
  meAcc = meAcc + e
  if meAcc < 1 then return end
  meAcc = 0
  if not gatherAt or Now() < gatherAt or Plain(UnitAffectingCombat("player")) then return end
  gatherAt = nil
  local announce = announceGear
  announceGear = false
  local ok, err = pcall(function() Gather() Remember(announce) end)
  if not ok then
    meDead = true
    O.Print("|cffff4040owl character notes turned off:|r " .. tostring(err))
  end
end)

O.commands.me = function()
  if Plain(UnitAffectingCombat("player")) then O.Print("ask me again after the fight.") return end
  local ok, err = pcall(Gather)
  if not ok then O.Print("could not read your character: " .. tostring(err)) return end
  local rec = Record()
  O.Print("|cffffd100What " .. Name() .. " knows about you|r")
  print("  " .. (me.name or "?") .. ", level " .. Level() .. " " .. (me.race or "") .. " " .. (Owl.className or "") .. (me.guild and (" of <" .. me.guild .. ">") or "") .. (me.realm and (", " .. me.realm) or ""))
  if me.home then print("  Home: " .. me.home) end
  if #me.stats > 0 then
    local parts = {}
    for _, s in ipairs(me.stats) do parts[#parts + 1] = s[1] .. " " .. s[2] end
    print("  " .. table.concat(parts, ", ") .. (me.armor and (", Armor " .. math.floor(me.armor)) or ""))
  end
  if me.gear[16] then print("  Weapon: " .. me.gear[16].name .. (me.ilvl and ("   Average item level: " .. me.ilvl) or "")) end
  if #me.trees > 0 then
    local parts = {}
    for _, t in ipairs(me.trees) do parts[#parts + 1] = t[1] .. " " .. t[2] end
    print("  Talents: " .. table.concat(parts, ", "))
  end
  if #me.profs > 0 then
    local parts = {}
    for _, p in ipairs(me.profs) do parts[#parts + 1] = p[1] .. " " .. p[2] end
    print("  Skills: " .. table.concat(parts, ", "))
  end
  if me.rep then print("  Best standing: " .. me.rep[2] .. " with " .. me.rep[1]) end
  local empty = {}
  for _, s in ipairs(SLOTS) do if not me.gear[s[1]] and Level() >= s[3] then empty[#empty + 1] = s[2] end end
  if #empty > 0 then print("  Empty slots: " .. table.concat(empty, ", ")) end
  print("  Together: " .. Days(Clock() - (rec.firstSeen or Clock())) .. " days, " .. (rec.sessions or 1) .. " sessions")
  local line = O.OwlPersonal()
  if line then Say("ask_me" .. Now(), line, 0, "c") end
end

do -- (its own block: Lua allows 200 local names per file)
-- =====================================================================================
-- Forever Leveling BiS: when that addon is installed he reads its scores through its
-- public API (ForeverLevelingBiS_API) and tells you about upgrades. Without it: silent.
-- =====================================================================================
table.insert(Owl.moods, 1, { "bis", "excited" })
table.insert(Owl.moods, 1, { "bisspec", "worried" })
O.defaults.bis = true

local function BiS()
  local api = _G.ForeverLevelingBiS_API
  if OwlHUDDB.bis and type(api) == "table" and (tonumber(api.version) or 1) >= 2 and type(api.GetGain) == "function" then return api end
  return nil
end
local function Gain(api, link)
  local r = Pack(pcall(api.GetGain, link))
  return Num(r[1]), r[2] == true
end
local function GainText(gain)
  if gain >= 10 then return "+" .. string.format("%d", math.floor(gain + 0.5)) end
  return "+" .. (string.format("%.1f", gain):gsub("%.0$", ""))
end
local function LinkName(link) return link:match("%[(.-)%]") or "that item" end
local SETUP_WORDS = { twohand = "a two-hander", dualwield = "two weapons", shield = "a weapon and shield", held = "a weapon and an off-hand", onehand = "a one-hander" }
local function Pretty(key) return type(key) == "string" and (key:sub(1, 1):upper() .. key:sub(2)) or "?" end

-- ---------- where an item ranks for its slot ----------
-- The addon's API has no rank, but its tooltip shows one ("#4 Shoulders", or "Best in slot").
-- He fills the game tooltip off screen for an instant and reads it: only when no tooltip is
-- showing and you are out of combat, so nothing flickers.
local rankCache = {}
local function Clean(text)
  if type(text) ~= "string" then return "" end
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end
local function BisRank(link)
  if type(link) ~= "string" then return nil end
  if rankCache[link] then return rankCache[link].rank, rankCache[link].label, rankCache[link].best end
  local tip = _G.GameTooltip
  if not BiS() or type(tip) ~= "table" or not tip.SetHyperlink or not tip.NumLines then return nil end
  if Plain(UnitAffectingCombat("player")) then return nil end
  local okShown, shown = pcall(tip.IsShown, tip)
  if not okShown or shown then return nil end
  local rank, label, best
  local ok = pcall(function()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:SetHyperlink(link)
    for i = 2, math.min(Plain(tip:NumLines()) or 0, 60) do
      local left, right = _G["GameTooltipTextLeft" .. i], _G["GameTooltipTextRight" .. i]
      if right and right.GetText and (not right.IsShown or right:IsShown()) then
        local n, what = Clean(Plain(right:GetText())):match("^%s*#(%d+)%s+(.-)%s*$")
        if n and what ~= "" then rank, label = tonumber(n), what end
      end
      if left and left.GetText and Clean(Plain(left:GetText())):find("Best in slot", 1, true) then best = true end
    end
  end)
  pcall(tip.Hide, tip)
  if not ok then return nil end
  if rank or best then rankCache[link] = { rank = rank, label = label, best = best } end
  return rank, label, best
end
local function RankWords(link, lead)
  local rank, label, best = BisRank(link)
  if best then return " Best in slot!" end
  if rank then return (lead or ", ranked") .. " #" .. rank .. (label and (" for " .. label) or "") .. "." end
  return nil
end
O.OwlRankSuffix = function(link) return RankWords(link, " Ranked") end
Owl.probe = Owl.probe or {}
Owl.probe.bis = function()
  local api = BiS()
  local w = me.gear[16]
  local rank, label, best
  if w then rank, label, best = BisRank(w.link) end
  local spec, setup = "?", "?"
  if api and type(api.GetSpec) == "function" then local r = Pack(pcall(api.GetSpec)) spec, setup = tostring(r[1]), tostring(r[2]) end
  return "api=" .. tostring(api and api.version) .. " pawn=" .. tostring(type(_G.PawnIsItemAnUpgrade) == "function") .. " spec=" .. spec .. "/" .. setup .. " weapon=" .. tostring(w and w.name)
    .. " gain=" .. tostring(w and api and (Gain(api, w.link))) .. " rank=" .. tostring(rank) .. " label=" .. tostring(label) .. " best=" .. tostring(best)
end

-- ---------- upgrades sitting in your bags ----------
local bisTold, bisFirst, bisScanAt, bisRetries = {}, true, nil, 0
local function BagLink(bag, slot)
  if not C_Container then return nil end
  if C_Container.GetContainerItemLink then
    local r = Pack(pcall(C_Container.GetContainerItemLink, bag, slot))
    if Str(r[1]) then return r[1] end
  end
  if C_Container.GetContainerItemInfo then
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then return Str(Plain(info.hyperlink)) end
  end
  return nil
end

-- without the BiS addon, Pawn's verdict is used instead (its number is a percentage)
local function PawnGain(link)
  if not OwlHUDDB.bis or type(_G.PawnGetItemData) ~= "function" or type(_G.PawnIsItemAnUpgrade) ~= "function" then return nil end
  local ok, item = pcall(_G.PawnGetItemData, link)
  if not ok or type(item) ~= "table" then return nil end
  local ok2, info = pcall(_G.PawnIsItemAnUpgrade, item, true)
  if not ok2 or type(info) ~= "table" or type(info[1]) ~= "table" then return nil end
  local pct = Num(info[1].PercentUpgrade)
  return pct and pct > 0 and pct * 100 or nil
end
local function ScanBags()
  local api = BiS()
  local pawn = not api and type(_G.PawnIsItemAnUpgrade) == "function"
  if not (api or pawn) or not (C_Container and C_Container.GetContainerNumSlots) then return end
  local found, here, loading = {}, {}, false
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local link = BagLink(bag, slot)
      if link and link:find("item:", 1, true) and not here[link] then
        local gain, wait
        if api then gain, wait = Gain(api, link) else gain = PawnGain(link) end
        if wait then loading = true end
        if gain and gain > 0 then
          here[link] = true
          if not bisTold[link] then found[#found + 1] = { link = link, gain = gain, pawn = pawn } end
        end
      end
    end
  end
  -- forget the ones that are gone or no longer better, so they can be mentioned again later
  for link in pairs(bisTold) do if not here[link] then bisTold[link] = nil end end
  if loading and bisRetries < 4 then bisRetries = bisRetries + 1; bisScanAt = Now() + 3 else bisRetries = 0 end
  if #found == 0 then bisFirst = false return end
  table.sort(found, function(a, b) return a.gain > b.gain end)
  for _, f in ipairs(found) do bisTold[f.link] = true end
  if #found == 1 then
    local f = found[1]
    local rank = RankWords(f.link)
    local tail = rank and (rank:sub(1, 1) == "," and rank or ("." .. rank)) or "."
    Say("bis" .. f.link, (bisFirst and "You are carrying an upgrade: " or "Upgrade in your bags: ") .. LinkName(f.link) .. " (" .. GainText(f.gain) .. (f.pawn and "% by Pawn" or "") .. ")" .. tail .. " Put it on.", 30)
  else
    local names = {}
    for i = 1, math.min(#found, 3) do
      local rank, _, best = BisRank(found[i].link)
      names[i] = LinkName(found[i].link) .. (best and " (best in slot)" or rank and (" (#" .. rank .. ")") or "")
    end
    Say("bisbags", (bisFirst and "You are carrying " or "Now carrying ") .. #found .. " upgrades: " .. table.concat(names, ", ") .. (#found > 3 and " and more." or "."), 30)
  end
  bisFirst = false
end
local function QueueBis(delay)
  local at = Now() + (delay or 2)
  if not bisScanAt or at < bisScanAt then bisScanAt = at end
end
O.On("BAG_UPDATE_DELAYED", function() QueueBis(2) end)
O.On("PLAYER_EQUIPMENT_CHANGED", function() QueueBis(3) end)
O.On("PLAYER_LEVEL_UP", function() rankCache = {} QueueBis(5) end)

-- ---------- quest rewards: which one to take ----------
O.On("QUEST_COMPLETE", function()
  local api = BiS()
  local n = Num(Call("GetNumQuestChoices")[1]) or 0
  if not api or n < 2 then return end
  local best, bestSell, loading
  for i = 1, n do
    local link = Str(Call("GetQuestItemLink", "choice", i)[1])
    if link then
      local gain, wait = Gain(api, link)
      if wait then loading = true end
      if gain and gain > 0 and (not best or gain > best.gain) then best = { link = link, gain = gain } end
      local price
      if C_Item and C_Item.GetItemInfo then price = Num(Pack(pcall(C_Item.GetItemInfo, link))[11]) end
      if price and (not bestSell or price > bestSell.price) then bestSell = { link = link, price = price } end
    end
  end
  if best then
    local rank = RankWords(best.link)
    Say("bisquest" .. best.link, "Take " .. LinkName(best.link) .. ": the best upgrade here (" .. GainText(best.gain) .. ")" .. (rank and (rank:sub(1, 1) == "," and rank or ("." .. rank)) or "."), 0, "c")
  elseif not loading and bestSell and bestSell.price > 0 then
    Say("bisquest" .. bestSell.link, "No upgrades among these. " .. LinkName(bestSell.link) .. " sells for the most.", 0, "c")
  end
end)

-- ---------- is it scoring for the spec you actually play? ----------
local specWarned = false
local function BisSpec()
  local api = BiS()
  if not api or type(api.GetSpec) ~= "function" then return nil end
  local r = Pack(pcall(api.GetSpec))
  return Str(r[1]), Str(r[2]), api
end
local function CheckBisSpec()
  local spec, _, api = BisSpec()
  if not spec or specWarned or not me.trees[1] or me.trees[1][2] < 8 then return end
  local tree = me.trees[1][1]:lower():gsub("%s", "")
  if tree == spec then return end
  local known = false
  if type(api.GetSpecs) == "function" then
    local ok, specs = pcall(api.GetSpecs, Owl.class)
    if ok and type(specs) == "table" then for _, s in pairs(specs) do if s == tree then known = true end end end
  end
  if not known then return end
  specWarned = true
  Say("bisspec", "Forever Leveling BiS is scoring gear for " .. Pretty(spec) .. ", but your points are in " .. me.trees[1][1] .. ". Change the spec in that addon.", 0)
end

-- what matters most for your spec right now, from the addon's own weights
local function BisPriorities()
  local spec, _, api = BisSpec()
  if not spec or type(api.GetWeights) ~= "function" then return nil end
  local ok, weights = pcall(api.GetWeights)
  if not ok or type(weights) ~= "table" then return nil end
  local labels = { str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit", atkpwr = "Attack Power", splpwr = "Spell Power", spldmg = "Spell Damage", splheal = "Healing" }
  local list = {}
  for key, label in pairs(labels) do
    local w = Num(Plain(weights[key]))
    if w and w > 0 then list[#list + 1] = { label, w } end
  end
  if #list < 2 then return nil end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  return Pretty(spec), list[1][1], list[2][1]
end

-- how what you wear ranks: the weakest piece, and anything that is best in slot
local function WornRanks()
  local list = {}
  for _, s in ipairs(SLOTS) do
    local item = me.gear[s[1]]
    if item and item.link then
      local rank, label, best = BisRank(item.link)
      if rank or best then list[#list + 1] = { slot = item.slot, name = item.name, rank = rank, label = label, best = best } end
    end
  end
  return list
end
Owl.WornRanks = WornRanks
local function RankLine()
  local list = WornRanks()
  if #list == 0 then return nil end
  local worst, bests = nil, {}
  for _, e in ipairs(list) do
    if e.best then bests[#bests + 1] = e elseif e.rank and (not worst or e.rank > worst.rank) then worst = e end
  end
  if worst and worst.rank >= 4 and (#bests == 0 or math.random(2) == 1) then
    return "Your " .. worst.slot .. ", " .. worst.name .. ", ranks #" .. worst.rank .. " for its slot. The first thing to replace."
  end
  if #bests > 0 then
    local e = bests[math.random(#bests)]
    return e.name .. " is best in slot at your level. Nothing to improve there."
  end
  return nil
end

local basePersonal = O.OwlPersonal
O.OwlPersonal = function()
  if me.gathered and BiS() and math.random(4) == 1 then
    local ok, line = pcall(RankLine)
    if ok and line then return line end
  end
  if math.random(6) == 1 then
    local ok, spec, first, second = pcall(BisPriorities)
    if ok and spec then return "For " .. spec .. " at your level: " .. first .. " first, then " .. second .. ". So says your BiS addon." end
  end
  return basePersonal()
end

local bisAcc, bisDead, bisSpecAt = 0, false, nil
local bisDriver = CreateFrame("Frame")
bisDriver:SetScript("OnUpdate", function(_, e)
  if bisDead then return end
  bisAcc = bisAcc + e
  if bisAcc < 1 then return end
  bisAcc = 0
  if Plain(UnitAffectingCombat("player")) then return end
  local ok, err = pcall(function()
    if bisScanAt and Now() >= bisScanAt then bisScanAt = nil ScanBags() end
    if bisSpecAt and Now() >= bisSpecAt and me.gathered then bisSpecAt = nil CheckBisSpec() end
  end)
  if not ok then
    bisDead = true
    O.Print("|cffff4040owl gear advice turned off:|r " .. tostring(err))
  end
end)
O.On("PLAYER_LOGIN", function()
  QueueBis(20)
  bisSpecAt = Now() + 40
  local api = _G.ForeverLevelingBiS_API
  if type(api) == "table" and type(api.OnChanged) == "function" then pcall(api.OnChanged, function() rankCache = {} QueueBis(2) end) end
end)

-- ---------- a group roll: is it an upgrade for you? ----------
local function Wearable(link)
  if not (C_Item and C_Item.GetItemInfoInstant) then return false end
  local slot = Str(Pack(pcall(C_Item.GetItemInfoInstant, link))[4])
  return slot ~= nil and slot ~= "INVTYPE_BAG" and slot ~= "INVTYPE_TABARD" and slot ~= "INVTYPE_BODY" and slot ~= "INVTYPE_NON_EQUIP_IGNORE"
end
O.On("START_LOOT_ROLL", function(rollID)
  local api = BiS()
  local pawn = not api and OwlHUDDB.bis and type(_G.PawnIsItemAnUpgrade) == "function"
  if not (api or pawn) then return end
  local link = Str(Call("GetLootRollItemLink", Plain(rollID))[1])
  if not link or not Wearable(link) then return end
  local gain, wait
  if api then gain, wait = Gain(api, link) else gain = PawnGain(link) end
  if gain and gain > 0 then
    Say("roll" .. link, "That roll: " .. LinkName(link) .. " is an upgrade for you (" .. GainText(gain) .. (pawn and "% by Pawn" or "") .. "). Need it.", 0, "uc")
    -- he speaks up for you: the other owls in the group tell their players you could use it
    if Owl.net and OwlHUDDB.speakUp ~= false then pcall(Owl.net.Send, "WANT", LinkName(link):sub(1, 60)) end
  elseif not wait then
    Say("roll" .. link, LinkName(link) .. " is not an upgrade for you. Greed or pass.", 0, "c")
  end
end)

-- ---------- at a vendor: gear that is not an upgrade for your main spec ----------
local sellAt
O.On("MERCHANT_SHOW", function() sellAt = Now() + 2 end)
-- The tools of a trade you practise are never on the sell list: a fishing pole is not meant to be an upgrade.
-- He checks your professions first, so a pole in the bags of someone who does not fish can still be named.
local TOOL_OF = { ["Mining Pick"] = "Mining", ["Skinning Knife"] = "Skinning", ["Blacksmith Hammer"] = "Blacksmithing", ["Arclight Spanner"] = "Engineering",
  ["Gyromatic Micro-Adjustor"] = "Engineering", ["Finkle's Skinner"] = "Skinning", ["Zulian Slicer"] = "Skinning" }
local TOOL_WORDS = { { "Fishing", "Fishing" }, { "Angler", "Fishing" }, { "Herbalist", "Herbalism" }, { "Skinn", "Skinning" } }
local function ToolFor(link, name)
  local prof = TOOL_OF[name]
  if not prof then
    for _, w in ipairs(TOOL_WORDS) do if name:find(w[1], 1, true) then prof = w[2] break end end
  end
  if not prof and C_Item and C_Item.GetItemInfoInstant then
    -- the game files fishing poles as their own kind of weapon
    local info = Pack(pcall(C_Item.GetItemInfoInstant, link))
    if Num(info[6]) == 2 and Num(info[7]) == 20 then prof = "Fishing" end
  end
  if not prof then return nil end
  local profs = type(me) == "table" and type(me.profs) == "table" and me.profs or {}
  if #profs == 0 then return prof end
  for _, p in ipairs(profs) do if p[1] == prof then return prof end end
  return nil
end
local function SellList()
  local api = BiS()
  if not api or not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
  local names, seen = {}, {}
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      local link = ok and type(info) == "table" and Str(Plain(info.hyperlink))
      local quality = link and Num(Plain(info.quality))
      if link and (quality == 1 or quality == 2) and Wearable(link) then
        local gain, wait = Gain(api, link)
        local name = LinkName(link)
        if not wait and (not gain or gain < 0) and not seen[name] and not ToolFor(link, name) then seen[name] = true names[#names + 1] = name end
      end
    end
  end
  if #names > 0 then
    Say("sell", "Not upgrades for your main spec: " .. table.concat(names, ", ", 1, math.min(#names, 3)) .. (#names > 3 and (" and " .. (#names - 3) .. " more") or "") .. ". Safe to sell unless you are saving them.", 300)
  end
end
local sellDriver = CreateFrame("Frame")
sellDriver:SetScript("OnUpdate", function()
  if sellAt and Now() >= sellAt then
    sellAt = nil
    pcall(SellList)
  end
end)

O.commands.bis = function()
  if not _G.ForeverLevelingBiS_API then O.Print("Forever Leveling BiS is not installed (or is switched off), so there is nothing to read.") return end
  OwlHUDDB.bis = not OwlHUDDB.bis
  O.Print("gear advice from Forever Leveling BiS" .. (OwlHUDDB.bis and ": |cff40ff40on|r" or ": |cffff4040off|r"))
  if OwlHUDDB.bis then bisFirst = true bisTold = {} QueueBis(1) end
end

local baseMe = O.commands.me
O.commands.me = function(...)
  baseMe(...)
  local spec, setup = BisSpec()
  if spec then
    print("  Gear scored for: " .. Pretty(spec) .. (SETUP_WORDS[setup or ""] and (", " .. SETUP_WORDS[setup]) or "") .. " (Forever Leveling BiS)")
    local ok, s, first, second = pcall(BisPriorities)
    if ok and s then print("  Stats that matter most now: " .. first .. ", then " .. second) end
    local okR, list = pcall(WornRanks)
    if okR and #list > 0 then
      local parts = {}
      for _, e in ipairs(list) do parts[#parts + 1] = e.slot .. (e.best and " best in slot" or (" #" .. e.rank)) end
      print("  How your gear ranks: " .. table.concat(parts, ", "))
    end
  end
end

end

-- =====================================================================================
-- Deep memory: the fights that hurt, where you died, your quests, your stock, your gold,
-- training costs, the people you group with, your dungeon runs, and what Questie,
-- GatherMate2 and Pawn know. Everything is read out of combat and kept per character.
-- =====================================================================================
do
for _, m in ipairs({ { "foe", "worried" }, { "deathspot", "worried" }, { "habit", "sleepy" }, { "questgrey", "sleepy" }, { "questgroup", "worried" },
  { "questhard", "worried" }, { "questzone", "happy" }, { "questaway", "happy" }, { "hearth", "happy" }, { "places", "excited" }, { "stock", "excited" },
  { "train", "happy" }, { "mate", "excited" }, { "friendlvl", "excited" }, { "run", "excited" }, { "questie", "happy" }, { "gather", "happy" } }) do
  table.insert(Owl.moods, 1, m)
end
O.defaults.deep = true
local function On() return OwlHUDDB.deep ~= false end
local function Sub(rec, key) if type(rec[key]) ~= "table" then rec[key] = {} end return rec[key] end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function When(t)
  local ago = Clock() - (t or 0)
  if ago < 3600 then return "a moment ago" end
  if ago < 64800 then return "earlier today" end
  if ago < 172800 then return "yesterday" end
  if ago < 604800 and type(date) == "function" then
    local ok, day = pcall(date, "%A", t)
    if ok and type(day) == "string" and day ~= "" then return "on " .. day end
  end
  return Days(ago) .. " days ago"
end
local function SubZone() return Str(Call("GetSubZoneText")[1]) end

-- ---------- fights and deaths ----------
local fightFoe, fightStart, lastTarget, lastTargetAt = nil, 0, nil, 0
local function TargetName()
  if not Q("UnitExists", "target") or Q("UnitIsPlayer", "target") or not Q("UnitCanAttack", "player", "target") then return nil end
  return Str(Plain(UnitName("target")))
end
local function Foe(name)
  local foes = Sub(Record(), "foes")
  if type(foes[name]) ~= "table" then
    if Count(foes) > 220 then
      for k, f in pairs(foes) do if (f.deaths or 0) == 0 and (f.close or 0) == 0 then foes[k] = nil end end
    end
    foes[name] = { fights = 0, close = 0, deaths = 0 }
  end
  return foes[name]
end
O.On("PLAYER_TARGET_CHANGED", function()
  if not On() then return end
  local name = TargetName()
  if not name then return end
  lastTarget, lastTargetAt = name, Now()
  if InCombat() then return end
  local f = Sub(Record(), "foes")[name]
  if type(f) ~= "table" then return end
  if (f.deaths or 0) > 0 then
    Say("foe" .. name, "Careful. " .. name .. " killed you " .. When(f.lastDeath) .. (f.deathZone == Zone() and ", near here." or "."), 900)
  elseif (f.close or 0) >= 2 then
    Say("foe" .. name, name .. " has pushed you to the edge " .. f.close .. " times. Be ready to heal.", 900)
  end
end)
O.On("PLAYER_REGEN_DISABLED", function()
  fightFoe = TargetName() or (Now() - lastTargetAt < 20 and lastTarget) or nil
  fightStart = Now()
end)
O.On("PLAYER_REGEN_ENABLED", function()
  local name = fightFoe
  fightFoe = nil
  if not name or not On() then return end
  local f = Foe(name)
  f.fights = (f.fights or 0) + 1
  local function look()
    if InCombat() then return end
    local hp, max = Plain(UnitHealth("player")), Plain(UnitHealthMax("player"))
    if type(hp) == "number" and type(max) == "number" and max > 0 and hp > 0 and hp / max < 0.3 then f.close = (f.close or 0) + 1 end
  end
  if C_Timer and C_Timer.After then C_Timer.After(1.2, function() pcall(look) end) else look() end
end)
O.On("PLAYER_DEAD", function()
  if not On() then return end
  local rec = Record()
  local name = fightFoe or (Now() - lastTargetAt < 30 and lastTarget) or nil
  -- what actually killed you beats what you happened to have targeted: a player (or a player's pet) is never
  -- written down as a creature, and a creature the combat log named is the one that gets the blame
  local killer = Owl.killer
  if type(killer) == "table" then
    if killer.player or killer.pet then name = nil elseif killer.sure then name = killer.name end
  end
  if name then
    local f = Foe(name)
    f.deaths, f.lastDeath, f.deathZone = (f.deaths or 0) + 1, Clock(), Zone()
  end
  local place = SubZone()
  if place then
    local spots = Sub(rec, "deathSpots")
    local key = Zone() .. ": " .. place
    spots[key] = (spots[key] or 0) + 1
  end
  if type(rec.run) == "table" then rec.run.deaths = (rec.run.deaths or 0) + 1 end
end)

-- ---------- places: where you have been, and where it went badly ----------
local zoneNow, zoneSince = nil, 0
local function PlaceChanged()
  if not On() then return end
  local rec, zone, place = Record(), Zone(), SubZone()
  if zone == "parts unknown" then return end
  if zoneNow ~= zone then
    if zoneNow then local zt = Sub(rec, "zoneTime") zt[zoneNow] = (zt[zoneNow] or 0) + (Now() - zoneSince) end
    zoneNow, zoneSince = zone, Now()
  end
  if not place then return end
  local seen = Sub(Sub(rec, "places"), zone)
  if not seen[place] then
    seen[place] = true
    local n = Count(seen)
    if n == 10 or n == 20 or n == 30 then Say("places" .. zone .. n, "That is " .. n .. " places you have set foot in across " .. zone .. ".", 0) end
  end
  local died = Sub(rec, "deathSpots")[zone .. ": " .. place]
  if died and died >= 2 and not InCombat() then
    Say("deathspot" .. place, place .. ". You have died here " .. died .. " times. Eyes open.", 1800)
  end
end
for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do O.On(event, function() O.Try("owl places", PlaceChanged) end) end

-- ---------- quests ----------
local function GreenRange()
  return Num(Call("GetQuestGreenRange")[1]) or Num(Call("UnitQuestTrivialLevelRange", "player")[1])
end
local function ScanQuests()
  local out = { zones = {}, list = {}, total = 0, done = 0 }
  local header = nil
  local function add(title, level, id, group, complete)
    local q = { title = title, level = level, id = id, group = group or 0, zone = header, complete = complete }
    out.list[#out.list + 1] = q
    out.total = out.total + 1
    if complete then out.done = out.done + 1 end
    if header then out.zones[header] = (out.zones[header] or 0) + 1 end
  end
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, Num(Plain(C_QuestLog.GetNumQuestLogEntries())) or 0 do
      local ok, info = pcall(C_QuestLog.GetInfo, i)
      if ok and type(info) == "table" and not Plain(info.isHidden) then
        local title = Str(Plain(info.title))
        if Plain(info.isHeader) then header = title
        elseif title then
          local id = Num(Plain(info.questID))
          local complete = id and ((C_QuestLog.ReadyForTurnIn and Plain(C_QuestLog.ReadyForTurnIn(id))) or (C_QuestLog.IsComplete and Plain(C_QuestLog.IsComplete(id)))) and true or false
          add(title, Num(Plain(info.difficultyLevel)) or Num(Plain(info.level)), id, Num(Plain(info.suggestedGroup)), complete)
        end
      end
    end
    return out
  end
  local n = Num(Call("GetNumQuestLogEntries")[1])
  if not n then return nil end
  for i = 1, n do
    local r = Call("GetQuestLogTitle", i)
    if Str(r[1]) then
      if r[4] then header = r[1] else add(r[1], Num(r[2]), Num(r[8]), Num(r[3]), r[6] == 1 or r[6] == true) end
    end
  end
  return out
end
local function GreyQuests(q)
  local range, grey = GreenRange(), {}
  if not range then return grey end
  for _, quest in ipairs(q.list) do
    if quest.level and quest.level > 0 and quest.level < Level() - range and not quest.complete then grey[#grey + 1] = quest end
  end
  return grey
end

local knownQuests, questNewAt, questZoneAt, questGreyAt = nil, nil, nil, nil
local function CheckNewQuests()
  local q = ScanQuests()
  if not q then return end
  local first = knownQuests == nil
  knownQuests = knownQuests or {}
  for _, quest in ipairs(q.list) do
    local key = quest.id or quest.title
    if not knownQuests[key] then
      knownQuests[key] = true
      if not first then
        if quest.group and quest.group > 1 then
          Say("questgroup" .. key, quest.title .. " is a group quest (" .. quest.group .. " players). Ask around before you try it.", 0)
        elseif quest.level and quest.level >= Level() + 4 then
          Say("questhard" .. key, quest.title .. " is level " .. quest.level .. ". Leave it a few levels.", 0)
        end
      end
    end
  end
end
local function CheckQuestZone()
  if Q("IsResting") or Q("IsInInstance") then return end
  local q = ScanQuests()
  if not q or q.total == 0 then return end
  local zone = Zone()
  local here = q.zones[zone]
  if here then
    Say("questzone" .. zone, here == 1 and "You have a quest here." or ("You have " .. here .. " quests here."), 1800)
    return
  end
  local best, bestN
  for z, n in pairs(q.zones) do if not bestN or n > bestN then best, bestN = z, n end end
  if best and bestN >= 2 then Say("questaway" .. zone, "No quests for you here. Most of yours are in " .. best .. " (" .. bestN .. ").", 1800) end
end
local function CheckGreyQuests()
  local q = ScanQuests()
  if not q then return end
  local told, fresh = Sub(Record(), "greyTold"), {}
  for _, quest in ipairs(GreyQuests(q)) do
    local key = tostring(quest.id or quest.title)
    if not told[key] then told[key] = true fresh[#fresh + 1] = quest.title end
  end
  if #fresh == 1 then Say("questgrey", fresh[1] .. " has gone grey: almost no XP left in it.", 600)
  elseif #fresh > 1 then Say("questgrey", #fresh .. " quests have gone grey: " .. Join(fresh, 2) .. ". Little XP left in them.", 600) end
end
O.On("QUEST_ACCEPTED", function() questNewAt = Now() + 2 end)
O.On("PLAYER_LOGIN", function() questNewAt = Now() + 12 end)
O.On("ZONE_CHANGED_NEW_AREA", function() questZoneAt = Now() + 9 end)
local wasRestingDeep
O.On("PLAYER_UPDATE_RESTING", function()
  local resting = Q("IsResting") and true or false
  if resting and wasRestingDeep == false then questGreyAt = Now() + 6 end
  wasRestingDeep = resting
end)

-- ---------- what Questie knows: quests open to you that you have not picked up ----------
local function QuestieOpen()
  local loader, questie = _G.QuestieLoader, _G.Questie
  if type(loader) ~= "table" or type(questie) ~= "table" or type(questie.API) ~= "table" or not questie.API.isReady then return nil end
  local ok, avail = pcall(loader.ImportModule, loader, "AvailableQuests")
  local ok2, db = pcall(loader.ImportModule, loader, "QuestieDB")
  if not ok or type(avail) ~= "table" or type(avail.__availableQuests) ~= "table" then return nil end
  local level, n, looked = Level(), 0, 0
  for id in pairs(avail.__availableQuests) do
    looked = looked + 1
    if looked > 600 then break end
    local lvl
    if ok2 and type(db) == "table" and type(db.QueryQuestSingle) == "function" then
      local okq, v = pcall(db.QueryQuestSingle, id, "questLevel")
      if okq then lvl = Num(v) end
    end
    if lvl and lvl > 0 and lvl >= level - 4 and lvl <= level + 2 then n = n + 1 end
  end
  return n
end

-- ---------- what GatherMate2 knows about this zone ----------
local gatherTold = {}
local function HasSkill(name)
  for _, p in ipairs(me.profs) do if p[1] == name then return true end end
  return type(OwlHUDDB.skills) == "table" and OwlHUDDB.skills[name] ~= nil
end
local function GatherSpots()
  local stub = _G.LibStub
  if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
  local ok, ace = pcall(stub, "AceAddon-3.0", true)
  if not ok or type(ace) ~= "table" then return nil end
  local ok2, gm = pcall(ace.GetAddon, ace, "GatherMate2", true)
  if not ok2 or type(gm) ~= "table" or type(gm.GetNodesForZone) ~= "function" then return nil end
  local map = C_Map and C_Map.GetBestMapForUnit and Num(Plain(C_Map.GetBestMapForUnit("player")))
  if not map then return nil end
  local kind, word
  if HasSkill("Herbalism") then kind, word = "Herb Gathering", "herb" elseif HasSkill("Mining") then kind, word = "Mining", "ore" else return nil end
  local counts, total = {}, 0
  local ok3 = pcall(function()
    for _, node in gm:GetNodesForZone(map, kind, true) do
      counts[node] = (counts[node] or 0) + 1
      total = total + 1
    end
  end)
  if not ok3 or total == 0 then return nil end
  local list = {}
  for node, n in pairs(counts) do
    local okn, name = pcall(gm.GetNameForNode, gm, kind, node)
    if okn and Str(name) then list[#list + 1] = { name, n } end
  end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  return total, word, list
end
local gatherAt
O.On("ZONE_CHANGED_NEW_AREA", function() gatherAt = Now() + 16 end)
local function CheckGather()
  local zone = Zone()
  if gatherTold[zone] or Q("IsResting") or Q("IsInInstance") then return end
  local total, word, list = GatherSpots()
  if not total or total < 5 or not list[1] then return end
  gatherTold[zone] = true
  local names = list[1][1] .. (list[2] and (" and " .. list[2][1]) or "")
  Say("gather" .. zone, "GatherMate knows " .. total .. " " .. word .. " spots in " .. zone .. ", mostly " .. names .. ".", 0)
end

-- ---------- stock: gathered goods in your bags ----------
local KINDS = { [9] = "herbs", [7] = "ore and stone", [6] = "leather", [5] = "cloth" }
local stockBase, stockAt = nil, nil
local function ScanStock()
  local stock = {}
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Item and C_Item.GetItemInfoInstant) then return nil end
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      local link = ok and type(info) == "table" and Str(Plain(info.hyperlink))
      if link then
        local r = Pack(pcall(C_Item.GetItemInfoInstant, link))
        if r[6] == 7 and KINDS[r[7] or 0] then
          local name = link:match("%[(.-)%]")
          if name then
            local s = stock[name] or { count = 0, kind = KINDS[r[7]] }
            s.count = s.count + (Num(Plain(info.stackCount)) or 1)
            if not s.max and C_Item.GetItemInfo then s.max = Num(Pack(pcall(C_Item.GetItemInfo, link))[8]) end
            stock[name] = s
          end
        end
      end
    end
  end
  return stock
end
local function CheckStock()
  local stock = ScanStock()
  if not stock then return end
  local first = stockBase == nil
  stockBase = stockBase or {}
  for name, s in pairs(stock) do
    local max = (s.max and s.max > 1) and s.max or 20
    local stacks = math.floor(s.count / max)
    if not first and stacks > (stockBase[name] or 0) then
      Say("stock" .. name, (stacks == 1 and "A full stack of " or (stacks .. " full stacks of ")) .. name .. ". Worth a trip to the auction house.", 120)
    end
    stockBase[name] = stacks
  end
  for name in pairs(stockBase) do if not stock[name] then stockBase[name] = 0 end end
end
O.On("BAG_UPDATE_DELAYED", function() stockAt = Now() + 3 end)
O.commands.stock = function()
  local stock = ScanStock()
  if not stock or not next(stock) then O.Print("no herbs, ore, leather or cloth in your bags.") return end
  local names = {}
  for name in pairs(stock) do names[#names + 1] = name end
  table.sort(names, function(a, b) return stock[a].count > stock[b].count end)
  O.Print("|cffffd100Gathered goods in your bags|r")
  for _, name in ipairs(names) do print("  " .. stock[name].count .. " x " .. name .. "  (" .. stock[name].kind .. ")") end
end

-- ---------- gold: where it comes from and where it goes ----------
local at = { merchant = false, trainer = false, mail = false, auction = false }
local taxiUntil, questUntil, lootUntil, lastMoney = 0, 0, 0, nil
local goldSession = { inn = {}, out = {} }
for _, pair in ipairs({ { "MERCHANT_SHOW", "merchant", true }, { "MERCHANT_CLOSED", "merchant", false }, { "TRAINER_SHOW", "trainer", true }, { "TRAINER_CLOSED", "trainer", false },
  { "MAIL_SHOW", "mail", true }, { "MAIL_CLOSED", "mail", false }, { "AUCTION_HOUSE_SHOW", "auction", true }, { "AUCTION_HOUSE_CLOSED", "auction", false } }) do
  O.On(pair[1], function() at[pair[2]] = pair[3] end)
end
O.On("TAXIMAP_OPENED", function() taxiUntil = Now() + 8 end)
O.On("QUEST_TURNED_IN", function() questUntil = Now() + 3 end)
O.On("CHAT_MSG_MONEY", function() lootUntil = Now() + 3 end)
O.On("LOOT_OPENED", function() lootUntil = Now() + 3 end)
O.On("PLAYER_LOGIN", function() lastMoney = Num(Plain(GetMoney())) end)
O.On("PLAYER_MONEY", function()
  local money = Num(Plain(GetMoney()))
  if not money then return end
  local diff = lastMoney and (money - lastMoney) or 0
  lastMoney = money
  if diff == 0 or not On() then return end
  local now, cat = Now(), nil
  if diff > 0 then
    cat = (now < questUntil and "quests") or (now < lootUntil and "loot") or (at.merchant and "selling to vendors") or ((at.mail or at.auction) and "mail and auctions") or "other"
  else
    cat = (at.trainer and "training") or (at.merchant and "vendors and repairs") or (at.auction and "auction fees") or (now < taxiUntil and "flights") or (at.mail and "postage") or "other"
  end
  local side = diff > 0 and "inn" or "out"
  local gold = Sub(Record(), "gold")
  local life = Sub(gold, side)
  life[cat] = (life[cat] or 0) + math.abs(diff)
  goldSession[side][cat] = (goldSession[side][cat] or 0) + math.abs(diff)
end)
local function TopOf(t)
  local best, bestV
  for k, v in pairs(t) do if k ~= "other" and (not bestV or v > bestV) then best, bestV = k, v end end
  return best, bestV
end
local function PrintGold(title, t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  if #keys == 0 then return end
  table.sort(keys, function(a, b) return t[a] > t[b] end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. " " .. O.Money(t[k]) end
  print("  " .. title .. ": " .. table.concat(parts, ", "))
end
O.commands.gold = function()
  local gold = Sub(Record(), "gold")
  O.Print("|cffffd100Where your gold comes from and goes|r")
  PrintGold("Earned this session", goldSession.inn)
  PrintGold("Spent this session", goldSession.out)
  PrintGold("Earned all time", Sub(gold, "inn"))
  PrintGold("Spent all time", Sub(gold, "out"))
  if not next(Sub(gold, "inn")) and not next(Sub(gold, "out")) then print("  Nothing yet. I start counting from today.") end
end

-- ---------- training: what it costs now, and what the next level will cost ----------
local trainerAt
local function ReadTrainer()
  if Call("IsTradeskillTrainer")[1] then return end
  local n = Num(Call("GetNumTrainerServices")[1])
  if not n or n == 0 then return end
  local now, later, level = 0, {}, Level()
  for i = 1, n do
    local r = Call("GetTrainerServiceInfo", i)
    local state
    for j = 2, 4 do if r[j] == "available" or r[j] == "unavailable" or r[j] == "used" then state = r[j] end end
    local cost = Num(Call("GetTrainerServiceCost", i)[1]) or 0
    local req = Num(Call("GetTrainerServiceLevelReq", i)[1])
    if state == "available" then now = now + cost
    elseif state == "unavailable" and req and req > level and cost > 0 then later[req] = (later[req] or 0) + cost end
  end
  local rec = Record()
  local training = Sub(rec, "training")
  for lvl in pairs(training) do if tonumber(lvl) and tonumber(lvl) > level then training[lvl] = nil end end
  for lvl, cost in pairs(later) do training[lvl] = cost end
  if now > 0 then
    local money = Num(Plain(GetMoney())) or 0
    if money >= now then Say("train" .. level, "Everything new here costs " .. O.Money(now) .. ". You can afford all of it.", 600)
    else Say("train" .. level, "Everything new here costs " .. O.Money(now) .. ". You have " .. O.Money(money) .. ": buy the important ones first.", 600) end
  end
end
O.On("TRAINER_SHOW", function() trainerAt = Now() + 1 end)
local function CheckTrainingSoon()
  local rec = Record()
  local next_ = Level() + 1
  local cost = type(rec.training) == "table" and Num(rec.training[next_])
  if not cost or cost <= 0 or rec.trainTold == next_ then return end
  local xp, max = Num(Plain(UnitXP("player"))), Num(Plain(UnitXPMax("player")))
  if not xp or not max or max <= 0 or xp / max < 0.75 then return end
  local money = Num(Plain(GetMoney())) or 0
  if Say("trainsoon" .. next_, "Level " .. next_ .. " training will cost about " .. O.Money(cost) .. ". " .. (money >= cost and "You have it covered." or ("You are " .. O.Money(cost - money) .. " short.")), 0) then
    rec.trainTold = next_
  end
end

-- ---------- the people you group with, and friends who level ----------
local sessionMates, mateAt, friendAt = {}, nil, nil
local function PartyNames()
  local names, mine = {}, Me()
  if Q("IsInRaid") then return names end
  for i = 1, 4 do
    local unit = "party" .. i
    if Q("UnitExists", unit) then
      local name = Str(Plain(UnitName(unit)))
      if name and name ~= mine then names[#names + 1] = name end
    end
  end
  return names
end
local function CheckMates()
  local mates = Sub(Record(), "mates")
  for _, name in ipairs(PartyNames()) do
    if not sessionMates[name] then
      sessionMates[name] = true
      local m = type(mates[name]) == "table" and mates[name] or { groups = 0, dungeons = 0 }
      m.groups, m.last = (m.groups or 0) + 1, Clock()
      mates[name] = m
      if m.groups >= 2 then
        Say("mate" .. name, name .. " again! That makes " .. m.groups .. " times you have grouped" .. ((m.dungeons or 0) > 0 and (", and " .. m.dungeons .. (m.dungeons == 1 and " dungeon" or " dungeons") .. " together.") or "."), 600)
      end
    end
  end
end
O.On("GROUP_ROSTER_UPDATE", function() mateAt = Now() + 4 end)
local function CheckFriends()
  local levels = Sub(Record(), "friendLevels")
  local function see(name, level, online)
    name, level = Str(name), Num(level)
    if not name or not level or level <= 0 then return end
    local old = Num(levels[name])
    if old and level > old and online then Say("friendlvl" .. name, name .. " is level " .. level .. " now.", 60) end
    levels[name] = level
  end
  if Owl.FL then
    for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
      local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
      if ok and type(info) == "table" then see(Plain(info.name), Plain(info.level), Plain(info.connected)) end
    end
  else
    for i = 1, math.min(Num(Call("GetNumFriends")[1]) or 0, 100) do
      local r = Call("GetFriendInfo", i)
      see(r[1], r[2], r[5])
    end
  end
end
O.On("FRIENDLIST_UPDATE", function() if not friendAt then friendAt = Now() + 10 end end)

-- ---------- dungeon runs: time, deaths, and how it compares to last time ----------
local runAt
local function FinishRun()
  local rec = Record()
  local run = rec.run
  rec.run = nil
  if type(run) ~= "table" or not run.name or not run.start then return end
  local dur = (run.leftAt or Clock()) - run.start
  if dur < 480 then return end
  local d = Sub(Sub(rec, "dungeons"), run.name)
  local deaths = run.deaths or 0
  local text = run.name .. " done: " .. Duration(dur) .. ", " .. deaths .. (deaths == 1 and " death." or " deaths.")
  if Num(d.last) then
    local diff = d.last - dur
    if math.abs(diff) >= 60 then text = text .. " " .. Duration(math.abs(diff)) .. (diff > 0 and " faster" or " slower") .. " than last time." end
  end
  if (d.runs or 0) > 0 and Num(d.best) and dur < d.best then text = text .. " A new best." end
  if not Num(d.best) or dur < d.best then d.best = dur end
  d.runs, d.last, d.lastDeaths = (d.runs or 0) + 1, dur, deaths
  d.lastMates = type(run.mates) == "table" and run.mates or nil
  Say("run" .. run.name, text, 0)
  pcall(Note, text .. ((type(run.mates) == "table" and #run.mates > 0) and (" With " .. Join(run.mates, 4) .. ".") or ""))
  rec.bond = (Num(rec.bond) or 0) + 10
  local mates = Sub(rec, "mates")
  for _, mate in ipairs(type(run.mates) == "table" and run.mates or {}) do
    if type(mates[mate]) == "table" then mates[mate].runDeaths = (mates[mate].runDeaths or 0) + deaths end
  end
end
local function CheckInstance()
  local rec = Record()
  local inside, kind = Q("IsInInstance")
  local run = type(rec.run) == "table" and rec.run or nil
  if inside and (kind == "party" or kind == "raid") then
    local name = Str(Call("GetInstanceInfo")[1]) or Zone()
    if run and run.name == name then
      run.leftAt = nil
    else
      if run then FinishRun() end
      rec.run = { name = name, start = Clock(), deaths = 0, mates = PartyNames() }
      -- he remembers the last run here, and says so once on the way in
      local before = type(rec.dungeons) == "table" and rec.dungeons[name]
      if type(before) == "table" and Num(before.last) then
        local now, same = PartyNames(), false
        if type(before.lastMates) == "table" and #before.lastMates == #now and #now > 0 then
          same = true
          local set = {}
          for _, n in ipairs(before.lastMates) do set[n] = true end
          for _, n in ipairs(now) do if not set[n] then same = false end end
        end
        local count = ({ "two", "three", "four", "five" })[#now]
        local text = ((same and count) and ("Last time the " .. count .. " of you were here, it took ") or "Last time here took ") .. Duration(before.last) .. "."
        if Num(before.best) and before.best < before.last - 60 then text = text .. " The best is " .. Duration(before.best) .. "." end
        Say("runmem" .. name, text, 3600)
      end
      local mates = Sub(rec, "mates")
      for _, mate in ipairs(PartyNames()) do
        local m = type(mates[mate]) == "table" and mates[mate] or { groups = 1, dungeons = 0 }
        m.dungeons = (m.dungeons or 0) + 1
        mates[mate] = m
      end
    end
  elseif run and not run.leftAt then
    run.leftAt = Clock()
  end
end
O.On("PLAYER_ENTERING_WORLD", function() runAt = Now() + 3 end)
O.On("ZONE_CHANGED_NEW_AREA", function() runAt = Now() + 3 end)

-- ---------- habits: your usual session, your favorite zone ----------
local longSaid, deepLogin = false, nil
O.On("PLAYER_LOGIN", function()
  deepLogin = Now()
  pcall(function()
    local rec = Record()
    if rec.goldFix then return end
    rec.goldFix = true
    for _, s in ipairs(Sub(rec, "history")) do if type(s) == "table" and Num(s.gold) and s.gold < -10000 then s.gold = nil end end
    if rec.money == 0 then rec.money = nil end
  end)
end)
local function History() return Sub(Record(), "history") end
local function UsualSession()
  local h = History()
  if #h < 3 then return nil end
  local dur, xp = 0, 0
  for _, s in ipairs(h) do dur = dur + (s.dur or 0) xp = xp + (s.xp or 0) end
  return dur / #h, dur > 0 and (xp / dur * 3600) or 0
end
O.On("PLAYER_LOGOUT", function()
  pcall(function()
    local rec = Record()
    if deepLogin and Now() - deepLogin >= 300 then
      local h = History()
      local money = Owl.Money()
      h[#h + 1] = { dur = math.floor(Now() - deepLogin), xp = session.xp or 0, at = Clock(), kills = session.kills or 0, gold = (money and Num(session.money)) and (money - session.money) or nil }
      while #h > 30 do table.remove(h, 1) end
    end
    if zoneNow then local zt = Sub(rec, "zoneTime") zt[zoneNow] = (zt[zoneNow] or 0) + (Now() - zoneSince) end
  end)
end)
local baseStats = O.commands.stats
O.commands.stats = function(...)
  baseStats(...)
  local ok, dur, rate = pcall(UsualSession)
  if ok and dur then O.Print("Your usual session: " .. Duration(dur) .. ", about " .. math.floor(rate) .. " XP an hour.") end
end

-- ---------- lines for his idle chatter ----------
local deeperBase = O.OwlPersonal
O.OwlPersonal = function()
  if On() and math.random(4) == 1 then
    local ok, line = pcall(function()
      local rec, lines = Record(), {}
      local zt, fav, favT = Sub(rec, "zoneTime"), nil, 0
      for z, t in pairs(zt) do if t > favT then fav, favT = z, t end end
      if fav and favT > 7200 then lines[#lines + 1] = "You have spent more time in " .. fav .. " than anywhere else. " .. Duration(favT) .. " of it." end
      local topIn = TopOf(Sub(Sub(rec, "gold"), "inn"))
      if topIn then lines[#lines + 1] = "Most of your gold comes from " .. topIn .. "." end
      local topOut = TopOf(Sub(Sub(rec, "gold"), "out"))
      if topOut then lines[#lines + 1] = "Most of your gold goes to " .. topOut .. "." end
      local worst, worstN
      for name, f in pairs(Sub(rec, "foes")) do if (f.deaths or 0) > 0 and (not worstN or f.deaths > worstN) then worst, worstN = name, f.deaths end end
      if worst then lines[#lines + 1] = worst .. " has killed you " .. (worstN == 1 and "once" or (worstN .. " times")) .. ". I am keeping count." end
      local mate, mateN
      for name, m in pairs(Sub(rec, "mates")) do if (m.groups or 0) >= 3 and (not mateN or m.groups > mateN) then mate, mateN = name, m.groups end end
      if mate then lines[#lines + 1] = "You and " .. mate .. " have grouped " .. mateN .. " times. A good team." end
      local places = Sub(rec, "places")[Zone()]
      if places and Count(places) >= 5 then lines[#lines + 1] = Count(places) .. " places visited in " .. Zone() .. " so far." end
      local dur = UsualSession()
      if dur then lines[#lines + 1] = "Your usual session runs about " .. Duration(dur) .. "." end
      if #lines == 0 then return nil end
      return lines[math.random(#lines)]
    end)
    if ok and line then return line end
  end
  return deeperBase()
end

O.commands.quests = function()
  local q = ScanQuests()
  if not q then O.Print("this version of the game does not let me read your quest log.") return end
  O.Print("|cffffd100Your quest log|r: " .. q.total .. " quests, " .. q.done .. " ready to hand in")
  local zones = {}
  for z in pairs(q.zones) do zones[#zones + 1] = z end
  table.sort(zones, function(a, b) return q.zones[a] > q.zones[b] end)
  for _, z in ipairs(zones) do print("  " .. z .. ": " .. q.zones[z]) end
  local grey, group = {}, {}
  for _, quest in ipairs(GreyQuests(q)) do grey[#grey + 1] = quest.title end
  for _, quest in ipairs(q.list) do if quest.group and quest.group > 1 then group[#group + 1] = quest.title .. " (" .. quest.group .. ")" end end
  if #grey > 0 then print("  Gone grey, little XP left: " .. table.concat(grey, ", ")) end
  if #group > 0 then print("  Group quests: " .. table.concat(group, ", ")) end
  local ok, open = pcall(QuestieOpen)
  if ok and open and open > 0 then print("  Questie shows " .. open .. " more quests open to you around your level.") end
end
O.commands.foes = function()
  local list = {}
  for name, f in pairs(Sub(Record(), "foes")) do if (f.deaths or 0) > 0 or (f.close or 0) > 0 then list[#list + 1] = { name, f } end end
  if #list == 0 then O.Print("nothing has given you real trouble yet.") return end
  table.sort(list, function(a, b) return (a[2].deaths or 0) * 10 + (a[2].close or 0) > (b[2].deaths or 0) * 10 + (b[2].close or 0) end)
  O.Print("|cffffd100What has hurt you most|r")
  for i = 1, math.min(#list, 10) do
    local f = list[i][2]
    print("  " .. list[i][1] .. ": killed you " .. (f.deaths or 0) .. ", close calls " .. (f.close or 0) .. ", fights " .. (f.fights or 0))
  end
end
O.commands.deep = function()
  OwlHUDDB.deep = not On()
  O.Print("owl memory of fights, quests, gold and friends" .. (OwlHUDDB.deep and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

Owl.probe = Owl.probe or {}
Owl.probe.quests = function()
  local q = ScanQuests()
  local zones = {}
  if q then for z, n in pairs(q.zones) do zones[#zones + 1] = z .. "=" .. n end end
  return "total=" .. tostring(q and q.total) .. " done=" .. tostring(q and q.done) .. " greenRange=" .. tostring(GreenRange()) .. " zones: " .. table.concat(zones, ", ")
end
Owl.probe.questie = function() return "open=" .. tostring(QuestieOpen()) .. " loader=" .. type(_G.QuestieLoader) .. " ready=" .. tostring(type(_G.Questie) == "table" and type(_G.Questie.API) == "table" and _G.Questie.API.isReady) end
Owl.probe.gathermate = function() local total, word, list = GatherSpots() return "spots=" .. tostring(total) .. " kind=" .. tostring(word) .. " top=" .. tostring(list and list[1] and list[1][1]) end
Owl.probe.stock = function() local s, n = ScanStock(), 0 if s then for _ in pairs(s) do n = n + 1 end end return (s and n or "nil") .. " kinds of gathered goods" end
Owl.lib = { When = When, Sub = Sub, Count = Count, SubZone = SubZone, PartyNames = PartyNames, TopOf = TopOf, History = History,
  ScanQuests = ScanQuests, GreyQuests = GreyQuests, ScanStock = ScanStock, UsualSession = UsualSession }

-- ---------- one driver for all of it ----------
local deepAcc, deepSlow, deepDead, questieAt = 0, 0, false, 600
local deepDriver = CreateFrame("Frame")
deepDriver:SetScript("OnUpdate", function(_, e)
  if deepDead then return end
  deepAcc = deepAcc + e
  if deepAcc < 1 then return end
  deepSlow = deepSlow + deepAcc
  deepAcc = 0
  if not On() or InCombat() then return end
  local ok, err = pcall(function()
    local now = Now()
    local function due(t) return t and now >= t end
    if due(questNewAt) then questNewAt = nil CheckNewQuests() end
    if due(questZoneAt) then questZoneAt = nil CheckQuestZone() end
    if due(questGreyAt) then questGreyAt = nil CheckGreyQuests() end
    if due(gatherAt) then gatherAt = nil CheckGather() end
    if due(stockAt) then stockAt = nil CheckStock() end
    if due(trainerAt) then trainerAt = nil ReadTrainer() end
    if due(mateAt) then mateAt = nil CheckMates() end
    if due(friendAt) then friendAt = nil CheckFriends() end
    if due(runAt) then runAt = nil CheckInstance() end
    if deepSlow < 20 then return end
    deepSlow = 0
    local rec = Record()
    if type(rec.run) == "table" and rec.run.leftAt and Clock() - rec.run.leftAt > 300 then FinishRun() end
    CheckTrainingSoon()
    -- bags nearly full, hearthstone ready, and not already in town
    if me.home and not Q("IsResting") and Owl.FreeBagSlots() <= 2 then
      local r = (C_Container and C_Container.GetItemCooldown) and Pack(pcall(C_Container.GetItemCooldown, 6948)) or Call("GetItemCooldown", 6948)
      local have = (C_Item and C_Item.GetItemCount) and Num(Pack(pcall(C_Item.GetItemCount, 6948))[1]) or Num(Call("GetItemCount", 6948)[1])
      if have and have > 0 and r[1] == 0 then Say("hearth", "Bags nearly full and your hearthstone is ready. " .. me.home .. " is one cast away.", 1800) end
    end
    if not longSaid and deepLogin then
      local dur = UsualSession()
      local played = now - deepLogin
      if dur and played > 2700 and played > dur * 1.5 then
        longSaid = true
        Say("habit", "You have been at it longer than your usual " .. Duration(dur) .. ".", 0)
      end
    end
    if now >= questieAt then
      questieAt = now + 900
      local q = ScanQuests()
      if q and q.total <= 4 then
        local open = QuestieOpen()
        if open and open >= 3 then Say("questie", "Your quest log is light. Questie shows " .. open .. " quests open to you around your level.", 1800) end
      end
    end
  end)
  if not ok then
    deepDead = true
    O.Print("|cffff4040owl deep memory turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- Deeper still: how you fight, rare sightings, your gathering spots, vendors, flight
-- times, your pace, records, the story of each level, whispers, guild life, and the
-- bond between you two, which grows with time and unlocks lines, colours and tricks.
-- =====================================================================================
do
for _, m in ipairs({ { "neglect", "worried" }, { "judged", "worried" }, { "dry", "worried" }, { "deadcd", "worried" }, { "rarehere", "excited" }, { "spots", "happy" },
  { "vend", "happy" }, { "flight", "happy" }, { "pace", "happy" }, { "record", "excited" }, { "story", "happy" }, { "whisperback", "excited" }, { "guild", "happy" },
  { "bond", "excited" }, { "pat", "happy" }, { "trick", "excited" }, { "with", "happy" } }) do
  table.insert(Owl.moods, 1, m)
end
local L = Owl.lib
local When, Sub, Count, SubZone, PartyNames, TopOf, History = L.When, L.Sub, L.Count, L.SubZone, L.PartyNames, L.TopOf, L.History
local function On() return OwlHUDDB.deep ~= false end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function Today() return math.floor(Clock() / 86400) end
local function Short(name) return (name:gsub("%-.*$", "")) end
local loginAt = nil
local function Played()
  local rec = Record()
  return (Num(rec.playedSecs) or 0) + (loginAt and (Now() - loginAt) or 0)
end
local day = { deaths = 0, levels = 0, quests = 0 }

-- ---------- how you fight: what you press, what you forget ----------
local KEY = { PALADIN = { "Judgement", "Hammer of Justice", "Holy Strike", "Consecration", "Exorcism" }, WARRIOR = { "Thunder Clap", "Execute", "Victory Rush" },
  PRIEST = { "Mind Blast", "Shadow Word: Pain", "Devouring Plague", "Vampiric Embrace" } }
local SAVERS = { PALADIN = { "Lay on Hands", "Divine Shield", "Divine Protection" }, MAGE = { "Ice Block" }, ROGUE = { "Evasion", "Vanish" }, WARRIOR = { "Last Stand", "Shield Wall" },
  HUNTER = { "Feign Death" }, PRIEST = { "Desperate Prayer" }, DRUID = { "Barkskin" } }
local fighting, fightCasts, lastCast, habitAt, judgedSaid, deadAt = false, {}, nil, nil, false, nil
local castSeen = { plain = 0, hidden = 0, named = 0 }
Owl.probe = Owl.probe or {}
Owl.probe.bars = function()
  local seen, has = {}, 0
  for slot = 1, 180 do
    local r = Call("GetActionInfo", slot)
    if r[1] ~= nil and #seen < 10 then seen[#seen + 1] = slot .. ":" .. tostring(r[1]) .. ":" .. tostring(r[2]) .. ":" .. tostring(r[3]) end
    if Call("HasAction", slot)[1] then has = has + 1 end
  end
  local fns = {}
  for name, v in pairs(type(C_ActionBar) == "table" and C_ActionBar or {}) do if type(v) == "function" and #fns < 40 then fns[#fns + 1] = name end end
  table.sort(fns)
  local names, readable = BarSpells()
  -- how many spells each way of asking finds, and which of the spellbook he thinks are on no bar
  local bySlot, onBar, missing = 0, 0, {}
  for slot = 1, 180 do local r = Call("GetActionInfo", slot) if r[1] == "spell" or r[1] == "macro" then bySlot = bySlot + 1 end end
  for _ in pairs(names) do onBar = onBar + 1 end
  if not O.OwlBookIds then pcall(BookSpells) end
  for name in pairs(O.OwlBookIds or {}) do if not names[name] and #missing < 12 then missing[#missing + 1] = name end end
  table.sort(missing)
  local kinds = {}
  for slot = 1, 180 do local k = Call("GetActionInfo", slot)[1] if k ~= nil then kinds[tostring(k)] = (kinds[tostring(k)] or 0) + 1 end end
  local kindText = {}
  for k, n in pairs(kinds) do kindText[#kindText + 1] = k .. "=" .. n end
  table.sort(kindText)
  return "readable=" .. tostring(readable) .. " spellSlots=" .. bySlot .. " onBarNames=" .. onBar .. " kinds[" .. table.concat(kindText, ",") .. "] notOnBar[" .. table.concat(missing, "; ") .. "] hasAction=" .. has .. " sample=" .. table.concat(seen, " ") .. " C_ActionBar: " .. table.concat(fns, ",")
end
Owl.probe.talentApi = function()
  local found = {}
  for name, v in pairs(_G) do
    if type(name) == "string" and #found < 60 then
      if type(v) == "function" and (name:find("Talent", 1, true) or name:find("Legacy", 1, true)) and not name:find("Frame", 1, true) and not name:find("_On", 1, true) then found[#found + 1] = name
      elseif type(v) == "table" and name:sub(1, 2) == "C_" and (name:find("Talent", 1, true) or name:find("Spec", 1, true) or name:find("Legacy", 1, true) or name:find("Trait", 1, true)) then
        local fns = {}
        for k, f in pairs(v) do if type(f) == "function" and #fns < 14 then fns[#fns + 1] = k end end
        found[#found + 1] = name .. "{" .. table.concat(fns, ",") .. "}"
      end
    end
  end
  table.sort(found)
  return table.concat(found, " ")
end
Owl.probe.talentPoints = function()
  local parts = {}
  for _, fn in ipairs({ "GetNumUnspentTalents", "UnitCharacterPoints", "GetMaxTalentTier" }) do
    local r = Call(fn, fn == "UnitCharacterPoints" and "player" or nil)
    parts[#parts + 1] = fn .. "=" .. tostring(r[1])
  end
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then parts[#parts + 1] = "config=" .. tostring(Pack(pcall(C_ClassTalents.GetActiveConfigID))[1]) end
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then parts[#parts + 1] = "spec=" .. tostring(Pack(pcall(C_SpecializationInfo.GetSpecialization))[1]) end
  if C_Traits and C_Traits.GetConfigInfo and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    local id = Pack(pcall(C_ClassTalents.GetActiveConfigID))[1]
    if id then
      local okI, info = pcall(C_Traits.GetConfigInfo, id)
      if not okI then info = nil end
      parts[#parts + 1] = "trees=" .. (type(info) == "table" and type(info.treeIDs) == "table" and table.concat(info.treeIDs, "/") or "?")
    end
  end
  return table.concat(parts, " ")
end
Owl.probe.wardrobe = function()
  local c = Owl.cos and Owl.cos.Cos()
  if not c then return "not set up" end
  local own, rare, goals = 0, 0, {}
  for id in pairs(c.own) do own = own + 1 if Owl.cos.ITEM[id] and Owl.cos.ITEM[id].rare then rare = rare + 1 end end
  for _, g in ipairs(c.goals) do goals[#goals + 1] = g.id .. " " .. Owl.cos.Progress(g) .. "/" .. g.n end
  local inst = Call("IsInInstance")
  local far, pals = 0, 0
  for _ in pairs(Owl.cos.friends or {}) do far = far + 1 end
  if Owl.social then for _ in pairs(Owl.social.Soc().pals) do pals = pals + 1 end end
  return "own=" .. own .. " rare=" .. rare .. " goals[" .. table.concat(goals, ", ") .. "] look=" .. Owl.cos.Look(Owl.cos.Worn()) .. " instance=" .. tostring(inst[1]) .. "/" .. tostring(inst[2]) .. "/" .. tostring(Call("GetInstanceInfo")[1])
    .. " dungeon=" .. tostring(Owl.cos.DungeonHere()) .. " owlsBeside=" .. far .. " pals=" .. pals .. " perch=" .. tostring(_G.OwlHUDPerch and _G.OwlHUDPerch:GetWidth()) .. " wardrobeHeight=" .. tostring(_G.OwlHUDWardrobe and _G.OwlHUDWardrobe:GetHeight()) .. " screen=" .. tostring(UIParent and UIParent.GetHeight and UIParent:GetHeight())
end
Owl.probe.art = function()
  local parts = {}
  for name, icon in pairs({ talking = pal.icon, perch = _G.OwlHUDPerch and _G.OwlHUDPerch.icon }) do
    local okT, got = pcall(icon.GetTexture, icon)
    local okL, layer, sub = pcall(icon.GetDrawLayer, icon)
    parts[#parts + 1] = name .. "[shown=" .. tostring((icon:IsShown())) .. " alpha=" .. tostring((icon:GetAlpha())) .. " size=" .. tostring((icon:GetWidth())) .. "x" .. tostring((icon:GetHeight())) .. " tex=" .. tostring(got) .. " asked=" .. tostring(rawget(icon, "owlShown")):gsub("^.*\\", "")
      .. " layer=" .. tostring(layer) .. "/" .. tostring(sub) .. "]"
  end
  local body = Owl.cos and Owl.cos.Body()
  parts[#parts + 1] = "body=" .. (body and (body.p .. "." .. body.c .. "." .. body.m) or "?")
  parts[#parts + 1] = "log=" .. table.concat(type(OwlHUDDB.artLog) == "table" and OwlHUDDB.artLog or {}, " | ")
  return table.concat(parts, " ")
end
Owl.probe.casts = function() return "plain=" .. castSeen.plain .. " hidden=" .. castSeen.hidden .. " named=" .. castSeen.named end
O.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if Plain(unit) ~= "player" then return end
  local id = Plain(spellID)
  if type(id) ~= "number" then castSeen.hidden = castSeen.hidden + 1 return end
  castSeen.plain = castSeen.plain + 1
  local name = Str(Plain(O.SpellName(id)))
  if not name then return end
  castSeen.named = castSeen.named + 1
  if fighting or InCombat() then fightCasts[name] = (fightCasts[name] or 0) + 1 else lastCast = { name, Now() } end
end)
O.On("PLAYER_REGEN_DISABLED", function()
  fighting, fightCasts = true, {}
  if lastCast and Now() - lastCast[2] < 3 then fightCasts[lastCast[1]] = 1 end
end)
O.On("PLAYER_REGEN_ENABLED", function()
  fighting = false
  if not On() then return end
  local rec = Record()
  local fight = Sub(rec, "fight")
  if next(fightCasts) then
    fight.n = (fight.n or 0) + 1
    local casts = Sub(fight, "casts")
    for name, c in pairs(fightCasts) do
      local e = type(casts[name]) == "table" and casts[name] or { n = 0 }
      e.n, e.last = e.n + c, fight.n
      casts[name] = e
    end
    if Owl.class == "PALADIN" then
      local ring = Sub(fight, "judged")
      ring[#ring + 1] = fightCasts["Judgement"] and 1 or 0
      while #ring > 20 do table.remove(ring, 1) end
    end
  end
  local function mana()
    if InCombat() or Q("UnitPowerType", "player") ~= 0 then return end
    local have, max = Num(Plain(UnitPower("player"))), Num(Plain(UnitPowerMax("player")))
    if have and max and max > 0 then
      local ring = Sub(fight, "mana")
      ring[#ring + 1] = (have / max < 0.15) and 1 or 0
      while #ring > 5 do table.remove(ring, 1) end
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(1.2, function() pcall(mana) end) else mana() end
  fightCasts = {}
  habitAt = Now() + 4
end)
local function CheckHabits()
  local rec = Record()
  local fight = Sub(rec, "fight")
  local casts, told, n = Sub(fight, "casts"), Sub(fight, "told"), fight.n or 0
  local mana = Sub(fight, "mana")
  if #mana >= 5 then
    local dry = 0
    for _, v in ipairs(mana) do dry = dry + v end
    if dry >= 3 and Say("dry", dry .. " of your last five fights left you out of mana. Drink before the next pull.", 900) then fight.mana = {} return end
  end
  if n < 10 then return end   -- (spell casts are sometimes hidden from addons in combat; then there is nothing to go on)
  local bars, readable = BarSpells()
  for name, e in pairs(casts) do
    if (not readable or bars[name]) and e.n >= 8 and n - (e.last or 0) >= 25 and told[name] ~= Today() then
      if Say("neglect" .. name, "You have not used " .. name .. " in " .. (n - e.last) .. " fights." .. (readable and " It is still on your bars." or ""), 600) then told[name] = Today() return end
    end
  end
  if n >= 30 then
    for _, name in ipairs(KEY[Owl.class] or {}) do
      if bars[name] and not casts[name] and told[name] ~= Today() then
        if Say("neglect" .. name, name .. " is on your bars, but I have never seen you press it.", 600) then told[name] = Today() return end
      end
    end
  end
  local ring = Sub(fight, "judged")
  if not judgedSaid and #ring >= 15 then
    local did = 0
    for _, v in ipairs(ring) do did = did + v end
    if did < #ring / 2 then
      judgedSaid = true
      Say("judged", "You judged in only " .. did .. " of your last " .. #ring .. " fights. Judgement is free damage.", 0)
    end
  end
end
local function Ready(name)
  if not (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellCooldown) then return false end
  local ok, info = pcall(C_Spell.GetSpellInfo, name)
  local id = ok and type(info) == "table" and Num(Plain(info.spellID))
  if not id then return false end
  local ok2, cd = pcall(C_Spell.GetSpellCooldown, id)
  if not ok2 or type(cd) ~= "table" then return false end
  local active = Plain(cd.isActive)
  if active ~= nil then return active == false end
  return Plain(cd.startTime) == 0
end
O.On("PLAYER_DEAD", function() day.deaths = day.deaths + 1 deadAt = Now() + 2 end)
Owl.ReadySaver = function()
  for _, name in ipairs(SAVERS[Owl.class] or {}) do if Ready(name) then return name end end
  return nil
end
local function CheckDeath()
  if Owl.deathReviewAt and Now() - Owl.deathReviewAt < 12 then return end
  for _, name in ipairs(SAVERS[Owl.class] or {}) do
    if Ready(name) then Say("deadcd", "You died with " .. name .. " ready. Next time, press it at half health.", 600) return end
  end
end

-- ---------- rare sightings ----------
O.On("PLAYER_TARGET_CHANGED", function()
  if not On() then return end
  local class = Q("UnitClassification", "target")
  if class ~= "rare" and class ~= "rareelite" then return end
  local name, place = Str(Plain(UnitName("target"))), SubZone()
  if not name or not place then return end
  Sub(Record(), "rares")[name] = { zone = Zone(), place = place, seen = Clock() }
end)
O.On("ZONE_CHANGED", function()
  if not On() or InCombat() then return end
  local zone, place = Zone(), SubZone()
  if not place then return end
  for name, r in pairs(Sub(Record(), "rares")) do
    if type(r) == "table" and r.zone == zone and r.place == place and not r.killed and Clock() - (r.seen or 0) > 3600 then
      Say("rarehere" .. name, "You saw " .. name .. " here " .. When(r.seen) .. ". Keep an eye out.", 3600)
      return
    end
  end
end)

-- ---------- your gathering spots ----------
local spotsTold, spotsAt = {}, nil
O.On("CHAT_MSG_LOOT", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:find("^You receive") or not On() then return end
  local link = msg:match("(|Hitem:.-|h%[.-%]|h)")
  if not link or not (C_Item and C_Item.GetItemInfoInstant) then return end
  local r = Pack(pcall(C_Item.GetItemInfoInstant, link))
  if r[6] ~= 7 or (r[7] ~= 9 and r[7] ~= 7) then return end
  local place = SubZone()
  if not place then return end
  local picks = Sub(Sub(Record(), "picks"), Zone())
  picks[place] = (picks[place] or 0) + 1
end)
local function BestSpots(zone)
  local picks = Sub(Record(), "picks")[zone]
  if type(picks) ~= "table" then return nil end
  local list, total = {}, 0
  for place, n in pairs(picks) do list[#list + 1] = { place, n } total = total + n end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  return list, total
end
O.On("ZONE_CHANGED_NEW_AREA", function() spotsAt = Now() + 24 end)
local function CheckSpots()
  local zone = Zone()
  if spotsTold[zone] then return end
  local list, total = BestSpots(zone)
  if not list or total < 15 or #list < 2 then return end
  spotsTold[zone] = true
  local parts = {}
  for i = 1, math.min(3, #list) do parts[i] = list[i][1] .. " (" .. list[i][2] .. ")" end
  Say("spots" .. zone, "Your best gathering spots in " .. zone .. ": " .. table.concat(parts, ", ") .. ".", 0)
end
O.commands.herbs = function()
  local list, total = BestSpots(Zone())
  if not list or total == 0 then O.Print("you have not gathered anything in " .. Zone() .. " since I started counting.") return end
  O.Print("|cffffd100Where you have gathered in " .. Zone() .. "|r (" .. total .. " in all)")
  for i = 1, math.min(10, #list) do print("  " .. list[i][1] .. ": " .. list[i][2]) end
end

-- ---------- vendors he has seen: who repairs, who sells food ----------
local vendorAt, vendorName
O.On("MERCHANT_SHOW", function()
  vendorName = Str(Plain(UnitName("npc"))) or Str(Plain(UnitName("target")))
  vendorAt = Now() + 1
end)
local function ReadVendor()
  if not vendorName or vendorName == Me() then return end
  local vendors = Sub(Record(), "vendors")
  if Count(vendors) > 160 and not vendors[vendorName] then return end
  local v = { zone = Zone(), place = SubZone() or Zone() }
  if Call("CanMerchantRepair")[1] then v.repair = true end
  for i = 1, math.min(Num(Call("GetMerchantNumItems")[1]) or 0, 60) do
    local link = Str(Call("GetMerchantItemLink", i)[1])
    if link and C_Item and C_Item.GetItemInfoInstant then
      local r = Pack(pcall(C_Item.GetItemInfoInstant, link))
      if r[6] == 0 and r[7] == 5 then v.food = true end
    end
  end
  if v.repair or v.food then vendors[vendorName] = v end
end
local function Nearest(kind)
  local zone = Zone()
  for name, v in pairs(Sub(Record(), "vendors")) do
    if type(v) == "table" and v.zone == zone and v[kind] then return name, v.place end
  end
end
O.commands.vendors = function()
  local zone, any = Zone(), false
  O.Print("|cffffd100Vendors I know in " .. zone .. "|r")
  for name, v in pairs(Sub(Record(), "vendors")) do
    if type(v) == "table" and v.zone == zone then
      any = true
      print("  " .. name .. " (" .. tostring(v.place) .. "): " .. (v.repair and "repairs" or "") .. ((v.repair and v.food) and ", " or "") .. (v.food and "food and drink" or ""))
    end
  end
  if not any then print("  None yet. I note them down when you visit one.") end
end

-- ---------- flight times ----------
local flight
if type(hooksecurefunc) == "function" and type(_G.TakeTaxiNode) == "function" then
  pcall(hooksecurefunc, "TakeTaxiNode", function(index)
    pcall(function()
      local to, from = Str(Call("TaxiNodeName", index)[1]), nil
      for i = 1, math.min(Num(Call("NumTaxiNodes")[1]) or 0, 120) do
        if Call("TaxiNodeGetType", i)[1] == "CURRENT" then from = Str(Call("TaxiNodeName", i)[1]) end
      end
      if not to or not from then return end
      flight = { key = from .. " > " .. to, to = to }
      local known = Num(Sub(Record(), "flights")[flight.key])
      if known and On() then Say("flight" .. flight.key, "About " .. Duration(known) .. " to " .. to .. ".", 60, "c") end
    end)
  end)
end
O.On("PLAYER_CONTROL_LOST", function() if flight and not flight.start then flight.start = Now() end end)
O.On("PLAYER_CONTROL_GAINED", function()
  if flight and flight.start then
    local took = Now() - flight.start
    if took > 20 and took < 1800 then Sub(Record(), "flights")[flight.key] = math.floor(took) end
  end
  flight = nil
end)

-- ---------- your pace, your records, and the story of each level ----------
local function LevelStats()
  local rec = Record()
  if type(rec.lvl) ~= "table" then rec.lvl = { kills = 0, quests = 0, deaths = 0, played0 = Played(), zones = {} } end
  return rec.lvl
end
local function PerLevel()
  local at, level = Sub(Record(), "levelAt"), Level()
  local newest, oldest = Num(at[level]), nil
  if not newest then return nil end
  local span = 0
  for back = 1, 3 do
    if Num(at[level - back]) then oldest, span = at[level - back], back end
  end
  if not oldest or span == 0 then return nil end
  return (newest - oldest) / span
end
local function PlayPerDay()
  local total, since = 0, Clock() - 7 * 86400
  for _, s in ipairs(History()) do if Num(s.at) and s.at >= since then total = total + (s.dur or 0) end end
  return total / 7
end
local function GoldRate()
  local gold, dur = 0, 0
  for _, s in ipairs(History()) do if Num(s.gold) then gold, dur = gold + s.gold, dur + (s.dur or 0) end end
  if dur < 3600 then return nil end
  return gold / dur * 3600
end
local function PaceLine()
  local per = PerLevel()
  if not per or per <= 0 then return nil end
  local level, target = Level(), nil
  for _, m in ipairs({ 30, 40, 50, 60 }) do if m > level then target = m break end end
  if not target then return nil end
  local need = (target - level) * per
  local text = "At your pace (" .. Duration(per) .. " a level), level " .. target .. " is about " .. Duration(need) .. " of play away"
  local daily = PlayPerDay()
  if daily > 600 then
    local days = math.ceil(need / daily)
    text = text .. ": " .. (days <= 1 and "a day or so" or ("around " .. days .. " days")) .. " at how much you play"
  end
  return text .. "."
end
O.commands.pace = function()
  O.Print("|cffffd100Your pace|r")
  local per, line = PerLevel(), PaceLine()
  if line then print("  " .. line) print("  (Later levels take longer, so treat that as the early side.)")
  else print("  I need to see you gain a full level before I can judge your pace.") end
  local goal, rate, money = OwlHUDDB.goal, GoldRate(), Num(Plain(GetMoney()))
  if rate then print("  Gold: about " .. O.Money(math.max(0, math.floor(rate))) .. " an hour, over your recent sessions.") end
  if type(goal) == "table" and Num(goal.gold) and money then
    local left = goal.gold * 10000 - money
    if left <= 0 then print("  Your goal (" .. tostring(goal.name or "savings") .. ") is already covered.")
    elseif rate and rate > 0 then print("  Your goal (" .. tostring(goal.name or "savings") .. "): about " .. Duration(left / rate * 3600) .. " of play away.")
    else print("  Your goal (" .. tostring(goal.name or "savings") .. "): " .. O.Money(left) .. " to go.") end
  else
    print("  Set a savings goal with /owl goal 100 mount and I will say how far off it is.")
  end
end
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) == "string" and msg:find("dies", 1, true) then
    local s = LevelStats()
    s.kills = (s.kills or 0) + 1
    local zones = Sub(s, "zones")
    zones[Zone()] = (zones[Zone()] or 0) + 1
  end
end)
O.On("QUEST_TURNED_IN", function() local s = LevelStats() s.quests = (s.quests or 0) + 1 day.quests = day.quests + 1 end)
O.On("PLAYER_DEAD", function() local s = LevelStats() s.deaths = (s.deaths or 0) + 1 end)
local storyAt
O.On("PLAYER_LEVEL_UP", function(newLevel)
  day.levels = day.levels + 1
  local level = Num(Plain(newLevel)) or (Level() + 1)
  local rec = Record()
  local played, s = Played(), LevelStats()
  Sub(rec, "levelAt")[level] = played
  local took = played - (Num(s.played0) or played)
  if took > 120 then
    local zone = TopOf(Sub(s, "zones"))
    local text = "Level " .. (level - 1) .. " took " .. Duration(took) .. ": " .. (s.kills or 0) .. ((s.kills or 0) == 1 and " kill, " or " kills, ") .. (s.quests or 0) .. ((s.quests or 0) == 1 and " quest, " or " quests, ") .. (s.deaths or 0) .. ((s.deaths or 0) == 1 and " death" or " deaths") .. "." .. (zone and (" Mostly in " .. zone .. ".") or "")
    pcall(Note, text)
    storyAt = { at = Now() + 14, text = text, took = took }
  end
  rec.lvl = { kills = 0, quests = 0, deaths = 0, played0 = played, zones = {} }
  rec.bond = (Num(rec.bond) or 0) + 5
end)
local recordSaid = {}
local function CheckRecords()
  local records = Sub(Record(), "records")
  local function beat(key, value, text)
    if Num(records[key]) and records[key] > 0 and value > records[key] and not recordSaid[key] then
      if Say("record" .. key, text, 0) then recordSaid[key] = true end
    end
  end
  beat("xp", session.xp or 0, "A new record: more XP this session than any before it.")
  beat("kills", session.kills or 0, "A new record: " .. (session.kills or 0) .. " kills in one session.")
  local money = Num(Plain(GetMoney()))
  if money and Num(session.money) then beat("gold", money - session.money, "A new record: your richest session yet.") end
end
O.commands.records = function()
  local rec = Record()
  local r = Sub(rec, "records")
  O.Print("|cffffd100Your records|r")
  if Num(r.xp) then print("  Most XP in a session: " .. r.xp) end
  if Num(r.kills) then print("  Most kills in a session: " .. r.kills) end
  if Num(r.gold) and r.gold > 0 then print("  Richest session: " .. O.Money(r.gold)) end
  if Num(r.long) then print("  Longest session: " .. Duration(r.long)) end
  if Num(r.fastLevel) then print("  Fastest level: " .. Duration(r.fastLevel)) end
  if type(OwlHUDDB.journal) == "table" and Num(OwlHUDDB.journal.best) then print("  Longest kill streak: " .. OwlHUDDB.journal.best) end
  for name, d in pairs(Sub(rec, "dungeons")) do if type(d) == "table" and Num(d.best) then print("  Fastest " .. name .. ": " .. Duration(d.best)) end end
  if not next(r) then print("  They are set at the end of each session. Check back tomorrow.") end
end

-- ---------- whispers and guild ----------
O.On("CHAT_MSG_WHISPER", function(_, sender)
  sender = Str(Plain(sender))
  if not sender or not On() then return end
  local name = Short(sender)
  local w = Sub(Record(), "whispers")
  local e = type(w[name]) == "table" and w[name] or { n = 0 }
  if Num(e.last) and Clock() - e.last > 7 * 86400 then Say("whisperback" .. name, name .. " again! Not a word in " .. Days(Clock() - e.last) .. " days.", 0) end
  e.n, e.last = (e.n or 0) + 1, Clock()
  w[name] = e
end)
local guildAt, guildLast, guildGreeted = nil, 0, false
O.On("GUILD_ROSTER_UPDATE", function() if not guildAt and Now() - guildLast > 60 then guildAt = Now() + 5 end end)
local function CheckGuild()
  guildLast = Now()
  local n = Num(Call("GetNumGuildMembers")[1])
  if not n or n == 0 then return end
  local rec = Record()
  local guildName = Str(Call("GetGuildInfo", "player")[1])
  if rec.guildName ~= guildName then rec.guildName, rec.guildies, rec.guildSeen = guildName, {}, nil end
  local roster, online, said, mine = Sub(rec, "guildies"), 0, 0, Me()
  for i = 1, math.min(n, 400) do
    local r = Call("GetGuildRosterInfo", i)
    local name, level = Str(r[1]) and Short(r[1]), Num(r[4])
    if name and level and name ~= mine then
      if r[9] then online = online + 1 end
      local old = Num(roster[name])
      if rec.guildSeen and said < 2 then
        if not old then said = said + 1 Say("guildnew" .. name, name .. " joined the guild.", 0)
        elseif level > old and r[9] then said = said + 1 Say("guildlvl" .. name, "Guildmate " .. name .. " is level " .. level .. " now.", 0) end
      end
      roster[name] = level
    end
  end
  rec.guildSeen = true
  if not guildGreeted and online >= 2 then
    guildGreeted = true
    Say("guildon", online .. " guildmates online.", 0)
  end
end

-- ---------- dungeon company ----------
local withAt
O.On("PLAYER_ENTERING_WORLD", function() withAt = Now() + 9 end)
local function CheckCompany()
  local rec = Record()
  if type(rec.run) ~= "table" or Clock() - (rec.run.start or 0) > 60 then return end
  local mates, best, bestN = Sub(rec, "mates"), nil, 1
  for i = 1, 4 do
    local unit = "party" .. i
    local name = Q("UnitExists", unit) and Str(Plain(UnitName(unit)))
    local m = name and mates[name]
    if type(m) == "table" then
      local role = Str(Call("UnitGroupRolesAssigned", unit)[1])
      if role == "TANK" then m.role = "tanks" elseif role == "HEALER" then m.role = "heals" end
      if (m.dungeons or 0) > bestN then best, bestN = name, m.dungeons end
    end
  end
  if best then
    local m = mates[best]
    Say("with" .. best, "With " .. best .. (m.role and (", who " .. m.role) or "") .. ": run number " .. m.dungeons .. " together, " .. (m.runDeaths or 0) .. " deaths of yours so far.", 600)
  end
end

-- ---------- the bond ----------
local BOND = { { 0, "New friends" }, { 120, "Companions" }, { 400, "Trusted" }, { 1000, "Partners" }, { 2500, "Old friends" }, { 6000, "Inseparable" }, { 12000, "Legends" } }
local BOND_GLOW = { { 1, 0.84, 0.43 }, { 1, 0.84, 0.43 }, { 1, 0.62, 0.3 }, { 0.5, 1, 0.6 }, { 0.5, 0.8, 1 }, { 0.8, 0.6, 1 }, { 1, 1, 0.92 } }
local BOND_LINES = {
  [2] = { "Companions. I like the sound of that.", "I have started saving you the good branch." },
  [3] = { "I trust you with my tail feathers. That is not nothing.", "You have never once left me behind. I noticed." },
  [4] = { "Partners. You handle the sword, I handle the commentary.", "I would not perch on anyone else's shoulder." },
  [5] = { "Old friends do not need to talk. I will anyway.", "After all this time you still surprise me." },
  [6] = { "Where you go, I go. That was settled long ago.", "I have forgotten what the road was like without you." },
  [7] = { "They will tell stories about the two of us.", "A legend and an owl. The owl did most of it." },
}
local function BondLevel(points)
  local level = 1
  for i, b in ipairs(BOND) do if points >= b[1] then level = i end end
  return level
end
local function ApplyBond()
  local level = BondLevel(Num(Record().bond) or 0)
  if O.OwlGlowColor then pcall(O.OwlGlowColor, BOND_GLOW[level][1], BOND_GLOW[level][2], BOND_GLOW[level][3]) end
  return level
end
local function AddBond(points)
  local rec = Record()
  local before = BondLevel(Num(rec.bond) or 0)
  rec.bond = (Num(rec.bond) or 0) + points
  local after = BondLevel(rec.bond)
  if after > before then
    ApplyBond()
    if O.OwlOutfit then pcall(O.OwlOutfit) end
    Say("bond" .. after, "We are " .. BOND[after][2] .. " now, " .. Me() .. ". Bond level " .. after .. ".", 0)
    pcall(Note, "The owl and I became " .. BOND[after][2] .. ".")
    if O.OwlBurst then pcall(O.OwlBurst, true) end
  end
end
O.On("QUEST_TURNED_IN", function() pcall(AddBond, 2) end)
Owl.AddBond = AddBond
Owl.BondLevel = function() return BondLevel(Num(Record().bond) or 0) end
Owl.day = day
O.commands.bond = function()
  local points = Num(Record().bond) or 0
  local level = BondLevel(points)
  O.Print("|cffffd100You and " .. Name() .. "|r: " .. BOND[level][2] .. " (bond level " .. level .. " of " .. #BOND .. ")")
  if BOND[level + 1] then print("  " .. math.floor(points) .. " of " .. BOND[level + 1][1] .. " to become " .. BOND[level + 1][2] .. ". It grows as you play, quest, level and run dungeons together.")
  else print("  As far as a bond can go.") end
  print("  /owl pat any time. /owl trick from Trusted on. His glow changes colour as the bond grows.")
end
O.commands.pat = function()
  local rec = Record()
  local level = BondLevel(Num(rec.bond) or 0)
  if rec.patDay ~= Today() then rec.patDay, rec.pats = Today(), 0 end
  rec.pats = (rec.pats or 0) + 1
  if rec.pats <= 5 then pcall(AddBond, 1) end
  local lines = level >= 5 and { "Right there. You always know.", "Mm. Do not stop on my account." }
    or level >= 3 and { "That is the spot.", "Go on, then. One more." }
    or { "Oh. Hello. That is nice.", "Careful with the feathers." }
  Say("pat" .. Now(), lines, 0, "c")
end
O.commands.trick = function()
  local level = BondLevel(Num(Record().bond) or 0)
  if level < 3 then Say("trick" .. Now(), "Tricks are for friends I trust. Ask me again when we are Trusted.", 0, "c") return end
  Say("trick" .. Now(), level >= 5 and { "Watch closely.", "For you? Always." } or { "Fine. Once.", "Do not tell the other owls." }, 0, "c")
  if O.OwlSpin then pcall(O.OwlSpin) end
  if level >= 5 and O.OwlBurst then pcall(O.OwlBurst, true) end
end

-- ---------- more for his idle chatter: the day you are having, and old stories ----------
local bondBase = O.OwlPersonal
O.OwlPersonal = function()
  if On() and math.random(4) == 1 then
    local ok, line = pcall(function()
      local rec, lines = Record(), {}
      if day.deaths >= 3 and day.levels == 0 then lines[#lines + 1] = "Rough day. We take the next pull slowly, yes?" end
      if day.levels >= 2 or day.quests >= 10 then lines[#lines + 1] = "You are on a roll today. I am proud, for an owl." end
      for name, f in pairs(Sub(rec, "foes")) do
        if (f.deaths or 0) >= 1 and Num(f.lastDeath) and Clock() - f.lastDeath > 86400 then
          lines[#lines + 1] = "Remember when " .. name .. " got you in " .. tostring(f.deathZone or "the wilds") .. "? We do not speak of it."
          break
        end
      end
      for name, d in pairs(Sub(rec, "dungeons")) do
        if type(d) == "table" and Num(d.best) then lines[#lines + 1] = "Still thinking about our best " .. name .. " run. " .. Duration(d.best) .. "." break end
      end
      for name, r in pairs(Sub(rec, "rares")) do
        if type(r) == "table" then lines[#lines + 1] = "I still think about " .. name .. " in " .. tostring(r.place) .. "." break end
      end
      local top, topN
      for name, w in pairs(Sub(rec, "whispers")) do if type(w) == "table" and (w.n or 0) >= 10 and (not topN or w.n > topN) then top, topN = name, w.n end end
      if top then lines[#lines + 1] = top .. " whispers you more than anyone. " .. topN .. " times now." end
      local bond = BOND_LINES[BondLevel(Num(rec.bond) or 0)]
      if bond then for _, text in ipairs(bond) do lines[#lines + 1] = text end end
      local pace = PaceLine()
      if pace then lines[#lines + 1] = pace end
      if #lines == 0 then return nil end
      return lines[math.random(#lines)]
    end)
    if ok and line then return line end
  end
  return bondBase()
end

-- ---------- session bookkeeping ----------
O.On("PLAYER_LOGIN", function()
  loginAt = Now()
  O.Try("owl bond", ApplyBond)
  local rec = Record()
  if not Num(Sub(rec, "levelAt")[Level()]) and type(rec.lvl) ~= "table" then LevelStats() end
end)
O.On("PLAYER_LOGOUT", function()
  pcall(function()
    local rec = Record()
    local played = loginAt and (Now() - loginAt) or 0
    rec.playedSecs = (Num(rec.playedSecs) or 0) + played
    if type(rec.lvl) == "table" and Num(rec.lvl.played0) then rec.lvl.played0 = rec.lvl.played0 end
    loginAt = nil
    if played < 300 then return end
    local records = Sub(rec, "records")
    local function keep(key, value) if Num(value) and value > (Num(records[key]) or 0) then records[key] = math.floor(value) end end
    keep("xp", session.xp) keep("kills", session.kills) keep("long", played)
    local money = Owl.Money()
    if money and Num(session.money) then keep("gold", money - session.money) end
  end)
end)

local bondAcc, bondSlow, bondMinute, bondDead = 0, 0, 0, false
local bondDriver = CreateFrame("Frame")
bondDriver:SetScript("OnUpdate", function(_, e)
  if bondDead then return end
  bondAcc = bondAcc + e
  if bondAcc < 1 then return end
  bondSlow, bondMinute = bondSlow + bondAcc, bondMinute + bondAcc
  bondAcc = 0
  if not On() then return end
  local ok, err = pcall(function()
    if bondMinute >= 60 then bondMinute = 0 AddBond(1) end   -- a minute together
    if InCombat() then return end
    local now = Now()
    local function due(t) return t and now >= t end
    if due(habitAt) then habitAt = nil CheckHabits() end
    if due(deadAt) then deadAt = nil CheckDeath() end
    if due(vendorAt) then vendorAt = nil ReadVendor() end
    if due(spotsAt) then spotsAt = nil CheckSpots() end
    if due(guildAt) then guildAt = nil CheckGuild() end
    if due(withAt) then withAt = nil CheckCompany() end
    if storyAt and now >= storyAt.at then
      local s = storyAt
      storyAt = nil
      Say("story", s.text, 0)
      local records = Sub(Record(), "records")
      if Num(records.fastLevel) and s.took < records.fastLevel then Say("recordlevel", "That was your fastest level yet.", 0) end
      if not Num(records.fastLevel) or s.took < records.fastLevel then records.fastLevel = math.floor(s.took) end
      local pace = PaceLine()
      if pace then Say("pace", pace, 0) end
    end
    if bondSlow < 20 then return end
    bondSlow = 0
    CheckRecords()
    if not Q("IsResting") then
      local dur = Durability()
      if dur and dur < 0.3 then
        local name, place = Nearest("repair")
        if name then Say("vendrepair", "Repairs nearby: " .. name .. " in " .. tostring(place) .. ".", 1800) end
      end
      local okS, food = pcall(Supplies)
      if okS and food and food < 5 then
        local name, place = Nearest("food")
        if name then Say("vendfood", "Low on food and drink. " .. name .. " in " .. tostring(place) .. " sells some.", 1800) end
      end
    end
  end)
  if not ok then
    bondDead = true
    O.Print("|cffff4040owl bond and habits turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- More: pull advice, a plan for the session, zones and dungeons for your level, a weekly
-- recap, his own diary, collections, weather moods, dreams, holidays, letters between
-- owls, a rivalry board, the bank, outfits earned through the bond, and his speech bubble.
-- =====================================================================================
do
for _, m in ipairs({ { "pull", "worried" }, { "plan", "happy" }, { "grad", "happy" }, { "dungeonin", "excited" }, { "dungeonout", "sleepy" }, { "week", "happy" },
  { "collect", "excited" }, { "weather", "worried" }, { "dream", "sleepy" }, { "holiday", "excited" }, { "letter", "happy" }, { "rival", "excited" }, { "bank", "happy" } }) do
  table.insert(Owl.moods, 1, m)
end
local L = Owl.lib
local When, Sub, Count, SubZone = L.When, L.Sub, L.Count, L.SubZone
local function On() return OwlHUDDB.deep ~= false end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function Faction() return Q("UnitFactionGroup", "player") == "Horde" and "H" or "A" end
local function Pct(cur, max) cur, max = Num(Plain(cur)), Num(Plain(max)) if cur and max and max > 0 then return math.floor(cur / max * 100 + 0.5) end end
local function UsesMana() return Q("UnitPowerType", "player") == 0 end
local function DateNum(fmt) if type(date) ~= "function" then return nil end local ok, v = pcall(date, fmt) return ok and tonumber(v) or nil end
local sessionAt = nil
local function PlayedNow() return (Num(Record().playedSecs) or 0) + (sessionAt and (Now() - sessionAt) or 0) end

-- ---------- pull advice ----------
local function Hostile()
  if not Q("UnitExists", "target") or Q("UnitIsPlayer", "target") or Q("UnitIsDead", "target") or not Q("UnitCanAttack", "player", "target") then return nil end
  return Str(Plain(UnitName("target")))
end
O.On("PLAYER_TARGET_CHANGED", function()
  if not On() or InCombat() then return end
  local name = Hostile()
  if not name then return end
  local lvl = Num(Plain(UnitLevel("target")))
  if lvl and lvl > 0 and lvl < Level() - 8 then return end
  local hp = Pct(UnitHealth("player"), UnitHealthMax("player"))
  if hp and hp < 45 then Say("pullrest", "You are at " .. hp .. "% health. Rest before you pull " .. name .. ".", 45) return end
  local mana = UsesMana() and Pct(UnitPower("player"), UnitPowerMax("player"))
  if mana and mana < 25 then Say("pullrest", "Only " .. mana .. "% mana. Drink before you pull " .. name .. ".", 45) end
end)
O.commands.pull = function()
  if InCombat() then O.Print("ask me before the fight, not during.") return end
  local name = Hostile()
  if not name then O.Print("target an enemy first and I will size it up.") return end
  local score, notes = 0, {}
  local lvl, class = Num(Plain(UnitLevel("target"))), Q("UnitClassification", "target")
  if lvl == -1 then score = score + 6 notes[#notes + 1] = "far above your level"
  elseif lvl then
    local gap = lvl - Level()
    if gap >= 5 then score = score + 4 elseif gap >= 3 then score = score + 2 elseif gap >= 1 then score = score + 1 elseif gap <= -3 then score = score - 2 end
    notes[#notes + 1] = gap == 0 and "your level" or (math.abs(gap) .. (math.abs(gap) == 1 and " level " or " levels ") .. (gap > 0 and "above you" or "below you"))
  end
  if class == "worldboss" then score = score + 8 notes[#notes + 1] = "a boss"
  elseif class == "elite" or class == "rareelite" then score = score + 3 notes[#notes + 1] = "elite" end
  local f = Sub(Record(), "foes")[name]
  if type(f) == "table" then
    if (f.deaths or 0) > 0 then score = score + 2 notes[#notes + 1] = "it has killed you " .. f.deaths .. (f.deaths == 1 and " time" or " times")
    elseif (f.close or 0) >= 2 then score = score + 1 notes[#notes + 1] = f.close .. " close calls against it"
    elseif (f.fights or 0) >= 5 then score = score - 1 notes[#notes + 1] = f.fights .. " clean wins against it" end
  end
  local hp = Pct(UnitHealth("player"), UnitHealthMax("player"))
  if hp and hp < 50 then score = score + 2 notes[#notes + 1] = "you are at " .. hp .. "% health" end
  local mana = UsesMana() and Pct(UnitPower("player"), UnitPowerMax("player"))
  if mana and mana < 30 then score = score + 1 notes[#notes + 1] = "you are at " .. mana .. "% mana" end
  local verdict = (score <= 0 and "Easy.") or (score <= 2 and "A fair fight.") or (score <= 4 and "Risky. Go in at full health with your cooldowns ready.") or "Do not pull this alone."
  O.Print(name .. ": " .. table.concat(notes, ", ") .. ". " .. verdict)
  Say("pull" .. Now(), name .. ": " .. verdict, 0, "c")
end

-- ---------- zones and dungeons by level ----------
local ZONES = { { "Elwynn Forest", 1, 10, "A" }, { "Dun Morogh", 1, 10, "A" }, { "Teldrassil", 1, 10, "A" }, { "Durotar", 1, 10, "H" }, { "Mulgore", 1, 10, "H" }, { "Tirisfal Glades", 1, 10, "H" },
  { "Westfall", 10, 20, "A" }, { "Loch Modan", 10, 20, "A" }, { "Darkshore", 10, 20, "A" }, { "Silverpine Forest", 10, 20, "H" }, { "The Barrens", 10, 25, "H" },
  { "Redridge Mountains", 15, 25, "A" }, { "Stonetalon Mountains", 15, 27, "B" }, { "Ashenvale", 18, 30, "B" }, { "Duskwood", 18, 30, "A" }, { "Hillsbrad Foothills", 20, 30, "B" },
  { "Wetlands", 20, 30, "A" }, { "Thousand Needles", 25, 35, "B" }, { "Alterac Mountains", 30, 40, "B" }, { "Arathi Highlands", 30, 40, "B" }, { "Desolace", 30, 40, "B" },
  { "Stranglethorn Vale", 30, 45, "B" }, { "Dustwallow Marsh", 35, 45, "B" }, { "Badlands", 35, 45, "B" }, { "Swamp of Sorrows", 35, 45, "B" }, { "Feralas", 40, 50, "B" },
  { "Tanaris", 40, 50, "B" }, { "The Hinterlands", 40, 50, "B" }, { "Searing Gorge", 43, 50, "B" }, { "Azshara", 45, 55, "B" }, { "Blasted Lands", 45, 55, "B" },
  { "Un'Goro Crater", 48, 55, "B" }, { "Felwood", 48, 55, "B" }, { "Burning Steppes", 50, 58, "B" }, { "Western Plaguelands", 51, 58, "B" }, { "Eastern Plaguelands", 53, 60, "B" },
  { "Winterspring", 53, 60, "B" }, { "Silithus", 55, 60, "B" } }
local DUNGEONS = { { "Ragefire Chasm", 13, 18, "H" }, { "The Deadmines", 17, 24, "A" }, { "Wailing Caverns", 17, 24, "B" }, { "Shadowfang Keep", 22, 30, "B" }, { "The Stockade", 22, 30, "A" },
  { "Blackfathom Deeps", 24, 32, "B" }, { "Gnomeregan", 29, 38, "B" }, { "Razorfen Kraul", 29, 38, "B" }, { "Scarlet Monastery", 34, 45, "B" }, { "Razorfen Downs", 37, 46, "B" },
  { "Uldaman", 41, 51, "B" }, { "Zul'Farrak", 44, 54, "B" }, { "Maraudon", 46, 55, "B" }, { "Sunken Temple", 50, 56, "B" }, { "Blackrock Depths", 52, 60, "B" },
  { "Lower Blackrock Spire", 55, 60, "B" }, { "Dire Maul", 56, 60, "B" }, { "Stratholme", 58, 60, "B" }, { "Scholomance", 58, 60, "B" } }
local function Mine(entry) return entry[4] == "B" or entry[4] == Faction() end
Owl.DUNGEONS, Owl.MineDungeon = DUNGEONS, Mine
local function NextZones(level, skip)
  local list = {}
  for _, z in ipairs(ZONES) do if Mine(z) and z[1] ~= skip and level >= z[2] and level <= z[3] - 2 then list[#list + 1] = z end end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  return list
end
local function DungeonsNow(level)
  local list = {}
  for _, d in ipairs(DUNGEONS) do if Mine(d) and level >= d[2] and level <= d[3] then list[#list + 1] = d end end
  return list
end
local gradAt
local function CheckGraduation()
  local zone, level = Zone(), Level()
  for _, z in ipairs(ZONES) do
    if z[1] == zone and level > z[3] then
      local nxt = NextZones(level, zone)
      if nxt[1] then
        Say("grad" .. zone, "You have outgrown " .. zone .. " (levels " .. z[2] .. " to " .. z[3] .. "). Try " .. nxt[1][1] .. (nxt[2] and (" or " .. nxt[2][1]) or "") .. ".", 3600)
      end
      return
    end
  end
end
O.On("ZONE_CHANGED_NEW_AREA", function() gradAt = Now() + 13 end)
O.On("PLAYER_LEVEL_UP", function(newLevel)
  gradAt = Now() + 40
  local level = Num(Plain(newLevel)) or (Level() + 1)
  if not On() then return end
  for _, d in ipairs(DUNGEONS) do
    if Mine(d) then
      if level == d[2] then Say("dungeonin" .. d[1], "You are now in range for " .. d[1] .. " (levels " .. d[2] .. " to " .. d[3] .. ").", 0)
      elseif level == d[3] then Say("dungeonout" .. d[1], "Last good level for " .. d[1] .. ". Run it now or let it go.", 0) end
    end
  end
end)

-- ---------- a plan for the session ----------
local function Plan()
  local parts, q = {}, L.ScanQuests()
  if q then
    if q.done > 0 then parts[#parts + 1] = "hand in " .. q.done .. (q.done == 1 and " quest" or " quests") end
    local best, bestN
    for z, n in pairs(q.zones) do if not bestN or n > bestN then best, bestN = z, n end end
    if best and bestN >= 2 then parts[#parts + 1] = bestN .. " quests in " .. best end
    local grey = #L.GreyQuests(q)
    if grey > 0 then parts[#parts + 1] = "drop " .. grey .. (grey == 1 and " grey quest" or " grey quests") end
  end
  local dungeons = DungeonsNow(Level())
  local extra = dungeons[1] and (dungeons[#dungeons][1] .. " is in your range.") or nil
  local nxt = NextZones(Level(), nil)
  if #parts == 0 and nxt[1] then parts[#parts + 1] = "quest in " .. nxt[1][1] end
  if #parts == 0 and not extra then return nil end
  local text = #parts > 0 and ("The plan: " .. table.concat(parts, ", then ") .. ".") or "The plan:"
  if extra then text = text .. " " .. extra end
  return text
end
O.commands.plan = function()
  local ok, text = pcall(Plan)
  if not ok or not text then O.Print("nothing pressing. Go where the road takes you.") return end
  O.Print(text)
  local ok2, usual = pcall(L.UsualSession)
  if ok2 and usual then O.Print("Your usual session is about " .. Duration(usual) .. ".") end
  Say("plan" .. Now(), text, 0, "c")
end

-- ---------- the week ----------
local function TotalRuns()
  local n = 0
  for _, d in pairs(Sub(Record(), "dungeons")) do if type(d) == "table" then n = n + (d.runs or 0) end end
  return n
end
local function Week()
  local rec = Record()
  if type(rec.week) ~= "table" then
    rec.week = { start = Clock(), level0 = Level(), money0 = Num(Plain(GetMoney())) or 0, deaths = 0, runs0 = TotalRuns(), played0 = PlayedNow() }
  end
  return rec.week
end
local function WeekText(w, lead)
  local levels, gold = Level() - (w.level0 or Level()), (Num(Plain(GetMoney())) or 0) - (w.money0 or 0)
  local runs = TotalRuns() - (w.runs0 or 0)
  local parts = { levels .. (levels == 1 and " level" or " levels"), (gold >= 0 and "+" or "-") .. O.Money(math.abs(gold)), (w.deaths or 0) .. ((w.deaths or 0) == 1 and " death" or " deaths") }
  if runs > 0 then parts[#parts + 1] = runs .. (runs == 1 and " dungeon" or " dungeons") end
  parts[#parts + 1] = Duration(math.max(0, PlayedNow() - (w.played0 or 0))) .. " played"
  return lead .. table.concat(parts, ", ") .. "."
end
O.On("PLAYER_DEAD", function() local w = Week() w.deaths = (w.deaths or 0) + 1 end)
O.commands.week = function() O.Print(WeekText(Week(), "This week so far: ")) end
local function CheckWeek()
  local w = Week()
  if Clock() - (w.start or Clock()) < 7 * 86400 then return end
  local text = WeekText(w, "Your week: ")
  Say("week", text, 0)
  pcall(Note, text)
  Record().week = nil
  Week()
end

-- ---------- collections ----------
local kindOf, lastKill = {}, nil
O.On("PLAYER_TARGET_CHANGED", function()
  local name = Hostile()
  if not name then return end
  local kind = Str(Call("UnitCreatureType", "target")[1])
  if kind then kindOf[name] = kind end
end)
local STEPS = { [25] = true, [50] = true, [100] = true, [150] = true, [200] = true, [300] = true, [400] = true, [500] = true }
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() then return end
  local name = msg:match("^(.-) dies")
  if not name or name == "" then return end
  lastKill = name
  local rec = Record()
  local beasts = Sub(rec, "beasts")
  if not beasts[name] and Count(beasts) < 900 then
    beasts[name] = true
    local n = Count(beasts)
    if STEPS[n] then Say("collect" .. n, "That is " .. n .. " different kinds of creature you have beaten. I keep the list.", 0) end
  end
  if kindOf[name] then local kinds = Sub(rec, "kinds") kinds[kindOf[name]] = (kinds[kindOf[name]] or 0) + 1 end
end)
O.commands.collection = function()
  local rec = Record()
  O.Print("|cffffd100Your collection|r")
  print("  Different creatures beaten: " .. Count(Sub(rec, "beasts")))
  local kinds, list = Sub(rec, "kinds"), {}
  for k, n in pairs(kinds) do list[#list + 1] = k .. " " .. n end
  table.sort(list, function(a, b) return (tonumber(a:match("(%d+)$")) or 0) > (tonumber(b:match("(%d+)$")) or 0) end)
  if #list > 0 then print("  By kind: " .. table.concat(list, ", ")) end
  local places, zones = 0, 0
  for _, seen in pairs(Sub(rec, "places")) do zones = zones + 1 places = places + Count(seen) end
  print("  Zones walked: " .. zones .. "   Places set foot in: " .. places)
  print("  Rares seen: " .. Count(Sub(rec, "rares")) .. "   Dungeons run: " .. Count(Sub(rec, "dungeons")) .. "   Owls met: " .. Count(type(OwlHUDDB.journal) == "table" and type(OwlHUDDB.journal.owls) == "table" and OwlHUDDB.journal.owls or {}))
end

-- ---------- weather moods, flying, dreams ----------
local COLD = { ["Dun Morogh"] = true, ["Winterspring"] = true, ["Alterac Mountains"] = true }
local SUNNY = { ["The Barrens"] = true, ["Durotar"] = true, ["Tanaris"] = true, ["Badlands"] = true, ["Desolace"] = true, ["Thousand Needles"] = true, ["Silithus"] = true, ["Westfall"] = true }
local SPOOKY = { ["Duskwood"] = true, ["Tirisfal Glades"] = true, ["Western Plaguelands"] = true, ["Eastern Plaguelands"] = true, ["Felwood"] = true, ["Silverpine Forest"] = true }
local weatherSaid, faceAt, faceNow, flyAt, flyNow = {}, 0, nil, 0, false
local function Weather()
  -- real weather first (read further down, from the game itself): it sets his face, and has its own lines
  if Owl.wxFace then return nil, Owl.wxFace end
  local zone = Zone()
  local hour = Q("GetGameTime")
  if COLD[zone] then return "cold", "owl_cold.tga" end
  if SUNNY[zone] and type(hour) == "number" and hour >= 9 and hour < 17 then return "sun", "owl_squint.tga" end
  if SPOOKY[zone] and type(hour) == "number" and (hour >= 19 or hour < 6) then return "spooky", "owl_nervous.tga" end
  return nil
end
O.OwlIdleFace = function()
  if not OwlHUDDB.fancy then return nil end
  if Now() >= faceAt then
    faceAt = Now() + 5
    local ok, kind, file = pcall(Weather)
    faceNow = ok and file or nil
    if ok and kind and not weatherSaid[kind .. Zone()] and On() then
      weatherSaid[kind .. Zone()] = true
      local lines = { cold = { "Brr. I am fluffing up until we leave.", "Cold country. I can see my own breath." }, sun = { "That sun. I am squinting, not sleeping.", "Too bright. Owls were not made for noon." },
        spooky = { "I do not like this place after dark. Stay close.", "Something is watching us. Besides me." } }
      Say("weather" .. kind, lines[kind], 1800)
    end
  end
  return faceNow
end
O.OwlFlying = function()
  if not OwlHUDDB.fancy then return false end
  if Now() >= flyAt then
    flyAt = Now() + 0.5
    flyNow = (Q("UnitOnTaxi", "player") or Q("IsMounted")) and true or false
  end
  return flyNow
end
O.OwlWake = function(dozed)
  if type(dozed) ~= "number" or dozed < 120 or math.random(2) == 1 then return end
  local lines = { "I dreamed of " .. Zone() .. ", but everything was mice.", "I dreamed you finally cleaned out your bags.", "I dreamed I was the " .. tostring(Owl.className or "hero"):lower() .. " and you were the owl." }
  if lastKill then lines[#lines + 1] = "I dreamed we fought " .. lastKill .. " again. You won again." end
  Say("dream", lines, 900)
end

-- ---------- holidays and hats ----------
local function Anniversary()
  local first = Num(Record().firstSeen)
  if not first or type(date) ~= "function" then return nil end
  local ok, d0 = pcall(date, "%d", first)
  local ok2, m0 = pcall(date, "%Y%m", first)
  local d, ym = DateNum("%d"), DateNum("%Y%m")
  d0, m0 = ok and tonumber(d0), ok2 and tonumber(m0)
  if not (d and ym and d0 and m0) or d ~= d0 or ym == m0 then return nil end
  return (math.floor(ym / 100) - math.floor(m0 / 100)) * 12 + (ym % 100 - m0 % 100)
end
O.OwlHat = function()
  local m, d = DateNum("%m"), DateNum("%d")
  if not m or not d then return nil end
  if (m == 10 and d >= 24) or (m == 11 and d == 1) then return "hat_witch.tga" end
  if m == 1 and d == 1 then return "hat_party.tga" end
  local ok, months = pcall(Anniversary)
  if ok and months and months > 0 then return "hat_party.tga" end
  return nil
end
local function Holiday()
  local rec, m, d = Record(), DateNum("%m"), DateNum("%d")
  if not m or not d or rec.holidayDay == m * 100 + d then return end
  local name, text = Me(), nil
  if m == 12 and d >= 24 and d <= 26 then text = "Happy Winter Veil, " .. name .. ". I got you nothing. I am an owl."
  elseif m == 10 and d == 31 then text = "Hallow's End. I am the scariest thing here, obviously."
  elseif m == 1 and d == 1 then text = "A new year. Same owl."
  elseif m == 2 and d == 14 then text = "Love is in the air. I remain devoted, mostly to snacks."
  else
    local ok, months = pcall(Anniversary)
    if ok and months and months > 0 then
      text = (months % 12 == 0) and ((months / 12) .. (months == 12 and " year" or " years") .. " since we met, " .. name .. ". Best decision you ever made.") or (months .. (months == 1 and " month" or " months") .. " since we met, " .. name .. ".")
    end
  end
  if text then rec.holidayDay = m * 100 + d Say("holiday", text, 0) end
end

-- ---------- letters between owls, and the rivalry board ----------
local newsAt = -100
local function OwlFriends()
  local owls = type(OwlHUDDB.journal) == "table" and type(OwlHUDDB.journal.owls) == "table" and OwlHUDDB.journal.owls or {}
  local online = {}
  if Owl.FL then
    for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
      local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
      local name = ok and type(info) == "table" and Plain(info.connected) and Str(Plain(info.name))
      if name then
        local listed = name:gsub("%-.*$", "")
        name = Owl.First(listed)
        Owl.Full(name, listed)
        if owls[name] and name ~= Me() then online[#online + 1] = name end
      end
    end
  end
  return online
end
local function SendNews(text)
  if not On() or Now() - newsAt < 30 or not Owl.net then return end
  newsAt = Now()
  text = tostring(text):gsub("[|%c]", ""):sub(1, 80)
  local grouped = {}
  for _, n in ipairs(L.PartyNames()) do grouped[n] = true end
  pcall(Owl.net.Send, "NEWS", text)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    for _, friend in ipairs(OwlFriends()) do
      if not grouped[friend] then pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "NEWS|" .. Name() .. "|" .. text, "WHISPER", Owl.Addr(friend)) end
    end
  end
end
local function MyStats()
  local j = type(OwlHUDDB.journal) == "table" and OwlHUDDB.journal or {}
  return Level() .. "," .. (Num(j.kills) or 0) .. "," .. (Num(j.deaths) or 0) .. "," .. (Owl.BondLevel and Owl.BondLevel() or 1)
end
-- a friend's death reaches him three ways (a letter, a call for care, a warning about the foe). He says it once.
Owl.deathSaid = {}
Owl.DeathSay = function(who, key, line, cooldown, flags)
  local was = Owl.deathSaid[who]
  if was and Now() - was < 45 then return false end
  if Say(key, line, cooldown, flags) then Owl.deathSaid[who] = Now() return true end
  return false
end
-- a level-up reaches him several ways too (the group, a letter, a whisper, the friends list). Said once, and it
-- goes to the front of the queue so it is not lost behind small talk.
Owl.levelSaid = {}
Owl.LevelSay = function(who, key, line, cooldown)
  local was = Owl.levelSaid[who]
  if was and Now() - was < 45 then return false end
  if Say(key, line, cooldown, "uc") then Owl.levelSaid[who] = Now() return true end
  return false
end
Owl.onNet = function(kind, sender, owl, extra)
  if kind == "NEWS" then
    if extra:find("^died") then Owl.DeathSay(sender, "letter" .. sender .. extra, owl .. " writes: " .. sender .. " " .. extra .. ".", 20)
    elseif extra:find("^reached level") then Owl.LevelSay(sender, "letter" .. sender .. extra, owl .. " writes: " .. sender .. " " .. extra .. ".", 20)
    elseif extra ~= "" then Say("letter" .. sender .. extra, owl .. " writes: " .. sender .. " " .. extra .. ".", 20) end
  elseif kind == "WANT" then
    if extra ~= "" then
      Say("want" .. sender .. extra, { owl .. " says " .. sender .. " could use that: " .. extra .. ".", extra .. " would be an upgrade for " .. sender .. ". " .. owl .. " told me.",
        sender .. " needs " .. extra .. ". " .. owl .. " asked nicely." }, 30, "c")
    end
  elseif kind == "HELLO" or kind == "HI" then
    if Owl.net then pcall(Owl.net.Send, "STAT", MyStats()) end
  elseif kind == "STAT" then
    local lvl, kills, deaths, bond = extra:match("^(%d+),(%d+),(%d+),(%d+)")
    if not lvl then return end
    Sub(Record(), "rivals")[sender] = { level = tonumber(lvl), kills = tonumber(kills), deaths = tonumber(deaths), bond = tonumber(bond), at = Clock() }
    local gap = Level() - tonumber(lvl)
    if gap > 0 then Say("rival" .. sender, "You are " .. gap .. (gap == 1 and " level" or " levels") .. " ahead of " .. sender .. ". Do not let it go to your head.", 1800)
    elseif gap < 0 then Say("rival" .. sender, sender .. " is " .. -gap .. (gap == -1 and " level" or " levels") .. " ahead of you. We have work to do.", 1800)
    else Say("rival" .. sender, { "You and " .. sender .. " are the same level. A fair race.", "Neck and neck with " .. sender .. ". Next level wins." }, 1800) end
  end
end
O.commands.rival = function()
  local rivals = Sub(Record(), "rivals")
  if not next(rivals) then O.Print("no rivals yet. Group with a friend who has an owl and ours will compare notes.") return end
  local j = type(OwlHUDDB.journal) == "table" and OwlHUDDB.journal or {}
  O.Print("|cffffd100The board|r")
  print("  " .. Me() .. ": level " .. Level() .. ", " .. (Num(j.kills) or 0) .. " kills, " .. (Num(j.deaths) or 0) .. " deaths, bond " .. (Owl.BondLevel and Owl.BondLevel() or 1))
  for name, r in pairs(rivals) do
    if type(r) == "table" then print("  " .. name .. ": level " .. tostring(r.level) .. ", " .. tostring(r.kills) .. " kills, " .. tostring(r.deaths) .. " deaths, bond " .. tostring(r.bond) .. "  (" .. When(r.at) .. ")") end
  end
end
O.On("PLAYER_DEAD", function()
  local name = Q("UnitExists", "target") and Str(Plain(UnitName("target")))
  local killer = Owl.killer
  if type(killer) == "table" then
    if killer.pet then name = nil elseif killer.sure or killer.player then name = Str(killer.name) end
  end
  SendNews(name and name ~= Me() and ("died to " .. name) or "died")
end)
O.On("PLAYER_LEVEL_UP", function(newLevel) newsAt = -100 SendNews("reached level " .. (Num(Plain(newLevel)) or Level())) end)

-- ---------- the bank ----------
local bankAt
O.On("BANKFRAME_OPENED", function() bankAt = Now() + 1 end)
local function ScanBank()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
  local bank, any = {}, false
  for _, bag in ipairs({ -1, 5, 6, 7, 8, 9, 10, 11 }) do
    local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
    for slot = 1, (okN and Num(Plain(slots))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      local link = ok and type(info) == "table" and Str(Plain(info.hyperlink))
      local name = link and link:match("%[(.-)%]")
      if name then any = true bank[name] = (bank[name] or 0) + (Num(Plain(info.stackCount)) or 1) end
    end
  end
  if not any then return end
  local rec = Record()
  rec.bank, rec.bankAt = bank, Clock()
  local okS, stock = pcall(L.ScanStock)
  if okS and type(stock) == "table" then
    local both = {}
    for name in pairs(stock) do if bank[name] then both[#both + 1] = name end end
    table.sort(both)
    if #both > 0 then Say("bank", "You keep " .. Join(both, 2) .. " in here already. Drop off what you are carrying?", 600) end
  end
end
O.commands.bank = function(arg)
  local rec = Record()
  if type(rec.bank) ~= "table" then O.Print("open your bank once and I will remember what is in it.") return end
  arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local names = {}
  for name in pairs(rec.bank) do if arg == "" or name:lower():find(arg, 1, true) then names[#names + 1] = name end end
  table.sort(names, function(a, b) return rec.bank[a] > rec.bank[b] end)
  if #names == 0 then O.Print("nothing like '" .. arg .. "' in your bank, as of " .. When(rec.bankAt) .. ".") return end
  O.Print("|cffffd100In your bank|r (as of " .. When(rec.bankAt) .. ")")
  for i = 1, math.min(#names, 15) do print("  " .. rec.bank[names[i]] .. " x " .. names[i]) end
  if #names > 15 then print("  ...and " .. (#names - 15) .. " more. Narrow it down: /owl bank silk") end
end

-- ---------- outfits earned through the bond ----------
O.defaults.outfit = true
local perchFrame = _G.OwlHUDPerch
local outfits = {}
for _, holder in ipairs({ pal, perchFrame }) do
  if holder and holder.icon then
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(holder.icon)
    if tex.SetDrawLayer then pcall(tex.SetDrawLayer, tex, "OVERLAY", 1) end
    if holder.hat and holder.hat.SetDrawLayer then pcall(holder.hat.SetDrawLayer, holder.hat, "OVERLAY", 2) end
    tex:Hide()
    holder.outfit = tex
    outfits[#outfits + 1] = tex
  end
end
local outfitNow
O.OwlOutfit = function()
  local level = (OwlHUDDB.outfit ~= false and Owl.BondLevel) and Owl.BondLevel() or 1
  local file = level >= 2 and ("outfit_" .. math.min(level, 5) .. ".tga") or nil
  if file == outfitNow then return end
  outfitNow = file
  for _, tex in ipairs(outfits) do
    if file then
      tex:SetTexture("Interface\\AddOns\\OwlHUD\\Media\\" .. file)
      local ok, shown = pcall(tex.GetTexture, tex)
      if ok and shown ~= nil then tex:Show() else tex:Hide() end
    else tex:Hide() end
  end
end
O.commands.outfit = function()
  OwlHUDDB.outfit = OwlHUDDB.outfit == false
  O.OwlOutfit()
  O.Print("owl outfit" .. (OwlHUDDB.outfit and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- his speech bubble: parchment, with a tail ----------
O.defaults.bubble = "parchment"
local tail = pal.bubble:CreateTexture(nil, "ARTWORK")
tail:SetTexture("Interface\\AddOns\\OwlHUD\\Media\\bubble_tail.tga")
tail:SetSize(13, 18)
tail:SetPoint("RIGHT", pal.bubble, "LEFT", 2, 0)
local function ApplyBubble()
  local parchment = OwlHUDDB.bubble ~= "dark" and OwlHUDDB.bubble ~= "dusk"
  if parchment then
    pal.bubble.bg:SetColorTexture(0.93, 0.86, 0.70, 0.97)
    pal.text:SetTextColor(0.17, 0.10, 0.04)
    pal.name:SetTextColor(0.52, 0.24, 0.04)
  else
    pal.bubble.bg:SetColorTexture(0.05, 0.04, 0.02, 0.9)
    pal.text:SetTextColor(1, 1, 1)
    pal.name:SetTextColor(1, 0.82, 0)
  end
  for _, fs in ipairs({ pal.text, pal.name }) do
    -- dark ink needs a plain font: an outline or a shadow turns the letters into blots
    if fs.GetFont and fs.SetFont then
      local ok, file, size, flags = pcall(fs.GetFont, fs)
      if ok and type(file) == "string" then
        if not fs.owlFont then fs.owlFont = { file, flags } end
        -- his own text size (/owl text 16), so nothing else can shrink it
        local want = math.max(10, math.min(26, tonumber(OwlHUDDB.textSize) or 16))
        if fs == pal.name then want = math.max(10, want - 3) end
        pcall(fs.SetFont, fs, fs.owlFont[1], want, parchment and "" or (fs.owlFont[2] or ""))
      end
    end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, parchment and 0 or 1) end
    if fs.SetShadowOffset then fs:SetShadowOffset(parchment and 0 or 1, parchment and 0 or -1) end
  end
  local ok, shown = pcall(tail.GetTexture, tail)
  if parchment and ok and shown ~= nil then tail:Show() else tail:Hide() end
  if Owl.stage and Owl.stage.Dusk then pcall(Owl.stage.Dusk, OwlHUDDB.bubble == "dusk") end
end
Owl.ApplyBubble = ApplyBubble
O.defaults.textSize = 16
O.commands.text = function(arg)
  local n = tonumber(arg)
  if not n or n < 10 or n > 26 then O.Print("his text size is " .. tostring(OwlHUDDB.textSize or 16) .. ". Set it with /owl text 10 to 26.") return end
  OwlHUDDB.textSize = math.floor(n)
  ApplyBubble()
  O.Print("owl text size: " .. OwlHUDDB.textSize)
end
O.commands.bubble = function()
  local now = OwlHUDDB.bubble
  OwlHUDDB.bubble = (now == "dusk" and "parchment") or (now == "dark" and "dusk") or "dark"
  ApplyBubble()
  O.Print("speech bubble: " .. OwlHUDDB.bubble)
end

-- ---------- his diary, and the driver ----------
O.On("PLAYER_LOGIN", function()
  sessionAt = Now()
  O.Try("owl bubble", ApplyBubble)
  O.Try("owl outfit", O.OwlOutfit)
end)
O.On("PLAYER_LOGOUT", function()
  pcall(function()
    if not sessionAt or Now() - sessionAt < 1200 or not On() then return end
    local d, name = Owl.day or {}, Me()
    local text
    if (d.deaths or 0) >= 3 then text = "a hard day. " .. d.deaths .. " deaths. I pretended not to look."
    elseif (d.levels or 0) >= 1 then text = name .. " grew today. I take some of the credit."
    elseif (d.quests or 0) >= 8 then text = (d.quests) .. " errands run for strangers. " .. name .. " is too kind."
    elseif (session.kills or 0) >= 60 then text = (session.kills) .. " things fell today. I watched from a safe distance."
    else text = "a quiet day in " .. Zone() .. ". I approve of quiet days." end
    Note(Name() .. "'s note: " .. text)
  end)
end)

local moreAcc, moreSlow, moreDead, planAt, weekAt, holidayAt, runsSeen, planTries = 0, 0, false, nil, nil, nil, nil, 0
O.On("PLAYER_LOGIN", function() planAt, weekAt, holidayAt = Now() + 30, Now() + 48, Now() + 60 end)
local moreDriver = CreateFrame("Frame")
moreDriver:SetScript("OnUpdate", function(_, e)
  if moreDead then return end
  moreAcc = moreAcc + e
  if moreAcc < 1 then return end
  moreSlow = moreSlow + moreAcc
  moreAcc = 0
  if not On() or InCombat() then return end
  local ok, err = pcall(function()
    local now = Now()
    local function due(t) return t and now >= t end
    if due(gradAt) then gradAt = nil CheckGraduation() end
    if due(bankAt) then bankAt = nil ScanBank() end
    if due(planAt) then
      planAt = nil
      local text = Plan()
      -- (he may be mid-greeting: try again shortly, a few times)
      if text and not Say("plan", text, 0) and planTries < 4 then planTries = planTries + 1 planAt = now + 20 end
    end
    if due(weekAt) then weekAt = nil CheckWeek() end
    if due(holidayAt) then holidayAt = nil Holiday() end
    if moreSlow < 30 then return end
    moreSlow = 0
    O.OwlOutfit()
    ApplyBubble()   -- (another addon or the game may have put an outline back on the font)
    local runs = TotalRuns()
    if runsSeen and runs > runsSeen then SendNews("finished a dungeon run") end
    runsSeen = runs
  end)
  if not ok then
    moreDead = true
    O.Print("|cffff4040owl extras (plans, letters, outfits) turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- The uncanny part: he puts things together. Kills left to level, where you go next,
-- when you usually stop, your name in chat, your emotes, people and places he knows,
-- round numbers coming up, and he answers when you talk to him in /say.
-- =====================================================================================
do
for _, m in ipairs({ { "know", "happy" }, { "guess", "excited" }, { "named", "excited" }, { "emote", "happy" }, { "reply", "happy" }, { "struggle", "worried" }, { "hushed", "sleepy" } }) do
  table.insert(Owl.moods, 1, m)
end
local L = Owl.lib
local When, Sub, Count, SubZone = L.When, L.Sub, L.Count, L.SubZone
local function On() return OwlHUDDB.deep ~= false and OwlHUDDB.uncanny ~= false end
O.defaults.uncanny = true
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function DayIndex() return math.floor(Clock() / 86400) end
local function RealDate(fmt) if type(date) ~= "function" then return nil end local ok, v = pcall(date, fmt) return ok and type(v) == "string" and v or nil end
local function Journal() return type(OwlHUDDB.journal) == "table" and OwlHUDDB.journal or {} end
local startedAt = nil

-- ---------- kills left to level ----------
local gains, killsSaid = {}, nil
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() then return end
  local name, xp = msg:match("^(.-) dies, you gain (%d+) experience")
  xp = tonumber(xp)
  if not xp or xp <= 0 then return end
  gains[#gains + 1] = xp
  while #gains > 8 do table.remove(gains, 1) end
  local cur, max = Num(Plain(UnitXP("player"))), Num(Plain(UnitXPMax("player")))
  if not cur or not max or max <= 0 or #gains < 4 then return end
  local level = Level()
  if cur / max >= 0.7 and killsSaid ~= level then
    local avg = 0
    for _, g in ipairs(gains) do avg = avg + g end
    avg = avg / #gains
    local left = math.ceil((max - cur) / avg)
    if left >= 2 and left <= 60 then
      local foe = name ~= "" and name or "that"
      local text = ({ "About " .. left .. " more like " .. foe .. " and you are level " .. (level + 1) .. ".", left .. " more of those and it is level " .. (level + 1) .. ". I did the sums.",
        "Level " .. (level + 1) .. " is about " .. left .. " kills away, at what " .. foe .. " is worth." })[OwlHUDDB.flavor == false and 1 or math.random(3)]
      if session.start and session.xp > 0 then
        local rate = session.xp / math.max(60, Now() - session.start)
        local mins = math.floor((max - cur) / rate / 60 + 0.5)
        if mins >= 1 and mins <= 90 then text = text .. " " .. mins .. " min at this pace." end
      end
      if Say("knowkills", text, 0) then killsSaid = level end
    end
  end
  -- round numbers coming up
  local kills = Num(Journal().kills)
  if kills then
    for _, mark in ipairs({ 100, 250, 500, 1000, 2500, 5000, 10000 }) do
      if mark - kills == 3 then Say("knowround" .. mark, "Three more and you will have beaten " .. mark .. " creatures in all. I have been counting.", 0) end
    end
  end
end)
O.On("QUEST_TURNED_IN", function()
  local quests = Num(Journal().quests)
  if not quests or not On() then return end
  for _, mark in ipairs({ 50, 100, 250, 500, 1000 }) do
    if mark - quests == 1 then Say("knowquest" .. mark, "The next quest you hand in will be your " .. mark .. "th. I kept a tally.", 0) end
  end
end)

-- ---------- where you go next, and the places you keep coming back to ----------
local zoneBefore, guessSaid, visitAt, placeSaid = nil, {}, {}, {}
O.On("ZONE_CHANGED_NEW_AREA", function()
  if not On() then return end
  local zone = Zone()
  if zone == "parts unknown" or zone == zoneBefore then return end
  local rec = Record()
  if zoneBefore then
    local from = Sub(Sub(rec, "trans"), zoneBefore)
    local total, best, bestN = 0, nil, 0
    for z, n in pairs(from) do total = total + n if n > bestN then best, bestN = z, n end end
    if total >= 4 and best == zone and bestN / total >= 0.6 and not guessSaid[zoneBefore .. zone] then
      guessSaid[zoneBefore .. zone] = true
      Say("guesszone", "I knew it. After " .. zoneBefore .. " you nearly always come to " .. zone .. ".", 600)
    end
    from[zone] = (from[zone] or 0) + 1
  end
  zoneBefore = zone
end)
O.On("ZONE_CHANGED", function()
  if not On() or InCombat() then return end
  local zone, place = Zone(), SubZone()
  if not place then return end
  local rec, key = Record(), zone .. ": " .. place
  if Now() - (visitAt[key] or -1000) > 300 then
    visitAt[key] = Now()
    local visits = Sub(rec, "visits")
    visits[key] = (visits[key] or 0) + 1
    local n = visits[key]
    if n == 10 or n == 25 or n == 50 or n == 100 then Say("knowvisit" .. key, "You come to " .. place .. " a lot. This is visit number " .. n .. ".", 0) end
  end
  if not placeSaid[key] then
    for level, where in pairs(Sub(rec, "levelPlace")) do
      if where == key and tonumber(level) and tonumber(level) < Level() then
        placeSaid[key] = true
        Say("knowplace" .. key, "You reached level " .. level .. " right here. I remember the spot.", 0)
        break
      end
    end
  end
end)
O.On("PLAYER_LEVEL_UP", function(newLevel)
  local level, place = Num(Plain(newLevel)) or (Level() + 1), SubZone()
  if place then Sub(Record(), "levelPlace")[level] = Zone() .. ": " .. place placeSaid[Zone() .. ": " .. place] = true end
end)

-- ---------- two deaths close together ----------
local deathTimes = {}
O.On("PLAYER_DEAD", function()
  if not On() then return end
  deathTimes[#deathTimes + 1] = Now()
  while #deathTimes > 3 do table.remove(deathTimes, 1) end
  local n = #deathTimes
  if n >= 3 and deathTimes[n] - deathTimes[n - 2] < 900 then
    Say("struggle3", "Three times in a quarter of an hour. This place is not ready for us yet. /owl plan has somewhere kinder.", 900)
  elseif n >= 2 and deathTimes[n] - deathTimes[n - 1] < 600 then
    Say("struggle2", "Twice in ten minutes. No shame in pulling fewer, or trying somewhere else.", 900)
  end
end)

-- ---------- your name in chat ----------
local function Named(place)
  return function(msg, sender, _, channelName)
    if not On() or not OwlHUDDB.tips then return end
    msg, sender = Plain(msg), Plain(sender)
    local mine = Me()
    if type(msg) ~= "string" or type(sender) ~= "string" or #mine < 4 then return end
    sender = sender:gsub("%-.*$", "")
    if sender == mine or not msg:lower():find(mine:lower(), 1, true) then return end
    local where = place
    if place == "channel" then
      channelName = Plain(channelName)
      where = type(channelName) == "string" and channelName:gsub("^%d+%.%s*", ""):gsub("%s*%-.*$", "") or "a channel"
    end
    Say("named" .. sender, sender .. " just said your name in " .. where .. ": " .. Snippet(msg), 60, "c")
  end
end
O.On("CHAT_MSG_CHANNEL", Named("channel"))
O.On("CHAT_MSG_SAY", Named("say"))
O.On("CHAT_MSG_YELL", Named("yell"))
O.On("CHAT_MSG_GUILD", Named("guild"))

-- ---------- he sees your emotes ----------
local EMOTES = { { "dance", { "Nice moves. I would join in, but talons.", "Dancing. In the middle of all this. I approve." } }, { "wave", { "Who are we waving at? Hello!", "I wave too. With a wing." } },
  { "cry", { "Hey. Come here. It will pass.", "There, there. Want me to find something to hit?" } }, { "laugh", { "What is funny? Tell me.", "Good. You should laugh more." } },
  { "cheer", { "Yes! Whatever it is, yes!", "Hooray! I am cheering too." } }, { "sleep", { "Good idea. I will take first watch.", "Sleep, then. I do not need much." } },
  { "bow", { "Very gracious.", "So polite. I taught you well." } }, { "hug", { "Aw. Who is the lucky one?", "A hug. I could use one too." } }, { "kiss", { "Oh my. I will look away.", "Bold." } },
  { "flex", { "Yes, yes. Very strong.", "Impressive. Do it again when someone is looking." } }, { "sigh", { "That was a big sigh. Long day?", "I heard that. Want to talk about it?" } },
  { "yawn", { "Now I am yawning. Stop it.", "Tired? We can stop whenever you like." } }, { "whistle", { "Was that for me? I am already here.", "I can do that louder." } } }
O.On("CHAT_MSG_TEXT_EMOTE", function(msg, sender)
  if not On() then return end
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" or sender:gsub("%-.*$", "") ~= Me() then return end
  local low = msg:lower()
  if not low:find("^you ") then return end
  for _, e in ipairs(EMOTES) do
    if low:find(e[1], 1, true) or (e[1] == "sleep" and low:find("asleep", 1, true)) then Say("emote" .. e[1], e[2], 45, "c") return end
  end
end)

-- ---------- talk to him: say his name (or "owl") in /say ----------
local JOKES = { "What does an owl need after a bath? A t-owl.", "Why did the owl skip the dungeon? He did not give a hoot.", "I know a joke about murlocs, but it mostly gurgles." }
local function Answer(low)
  local name = Me()
  if low:find("thank", 1, true) or low:find(" ty", 1, true) then return { "Anytime, " .. name .. ".", "That is what I am here for." } end
  if low:find("good night", 1, true) or low:find("goodnight", 1, true) or low:find("night night", 1, true) then return { "Sleep well, " .. name .. ". I will keep watch.", "Good night. Same time tomorrow?" } end
  if low:find("shut up", 1, true) or low:find("be quiet", 1, true) or low:find("hush", 1, true) then Owl.Hush(600) return nil, "Fine. Ten minutes of silence. Starting now." end
  if low:find("love", 1, true) then return { "I am fond of you too. Do not make it strange.", "I know. I am very lovable." } end
  if low:find("good owl", 1, true) or low:find("good bird", 1, true) or low:find("good boy", 1, true) or low:find("good job", 1, true) then return { "I know.", "I do my best. It happens to be very good." } end
  if low:find("how are you", 1, true) or low:find("you ok", 1, true) then
    local d = Owl.day or {}
    if (d.deaths or 0) >= 3 then return { "Worried about you, honestly. That was a lot of dying." } end
    if (d.levels or 0) >= 1 then return { "Proud. You levelled today." } end
    return { "Content. Good perch, good company.", "Well fed and well travelled. You?" }
  end
  if low:find("where are we", 1, true) or low:find("where am i", 1, true) then return { (SubZone() and (SubZone() .. ", in ") or "") .. Zone() .. ". I have been paying attention." } end
  if low:find("what time", 1, true) then
    local t = RealDate("%H:%M")
    return { t and ("It is " .. t .. " where you are.") or "Late enough, I think." }
  end
  if low:find("how long", 1, true) then return { startedAt and ("We have been at it for " .. Duration(Now() - startedAt) .. " today.") or "A while now." } end
  if low:find("joke", 1, true) or low:find("funny", 1, true) then return JOKES end
  if low:find("who are you", 1, true) or low:find("what are you", 1, true) then return { "Your owl. Obviously.", "A great horned owl of uncommon intelligence." } end
  if low:find("what should", 1, true) or low:find("what now", 1, true) or low:find("what next", 1, true) then
    if O.commands.plan then pcall(O.commands.plan, "") end
    return nil
  end
  if O.OwlKnow and (low:find("tell me about", 1, true) or low:find("what is", 1, true) or low:find("what about", 1, true) or low:find("how do", 1, true) or low:find("how does", 1, true) or low:find("explain", 1, true)) then
    local hit = O.OwlKnow(low)
    if hit then return { hit } end
    return { "I do not know that one yet. Try camping, legacy, mounts, judgement or herbs." }
  end
  if low:find(" tip ", 1, true) or low:find(" advice ", 1, true) then if O.commands.tip then pcall(O.commands.tip) end return nil end
  if low:find("sorry", 1, true) then return { "Forgiven. Mostly.", "It is forgotten. I forget nothing, but it is forgotten." } end
  if low:find("hello", 1, true) or low:find("hey", 1, true) or low:find("^hi ") or low:find(" hi$") or low:find(" hi ", 1, true) or low:find("yo ", 1, true) then return { "Hello, " .. name .. ".", "Yes? I am right here." } end
  return { "Hm? I am listening.", "You called?", "Yes, " .. name .. "?" }
end
O.On("CHAT_MSG_SAY", function(msg, sender)
  if not On() or not OwlHUDDB.tips then return end
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" or sender:gsub("%-.*$", "") ~= Me() then return end
  local low = " " .. msg:lower():gsub("[%p]", " ") .. " "
  local owl = Name():lower()
  if not (low:find(" " .. owl .. " ", 1, true) or low:find(" owl ", 1, true)) then return end
  local ok, lines, forced = pcall(Answer, low)
  if not ok then return end
  if forced then O.Print(forced) return end
  if lines then Say("reply" .. Now(), lines, 0, "c") end
end)

-- ---------- people and creatures he recognises when you look at them ----------
local knownSaid = {}
O.On("PLAYER_TARGET_CHANGED", function()
  if not On() or InCombat() or not Q("UnitExists", "target") then return end
  local name = Str(Plain(UnitName("target")))
  if not name or name == Me() or knownSaid[name] then return end
  local rec = Record()
  if Q("UnitIsPlayer", "target") then
    if Q("UnitCanAttack", "player", "target") then return end
    local m, w, g = Sub(rec, "mates")[name], Sub(rec, "whispers")[name], Sub(rec, "guildies")[name]
    local text
    if type(m) == "table" and (m.groups or 0) >= 1 then
      text = "That is " .. name .. ". You have grouped " .. (m.groups == 1 and "once" or (m.groups .. " times")) .. ((m.dungeons or 0) > 0 and (" and run " .. m.dungeons .. (m.dungeons == 1 and " dungeon" or " dungeons") .. " together") or "") .. "."
    elseif type(w) == "table" and Num(w.last) then
      text = "That is " .. name .. ". You last whispered " .. When(w.last) .. "."
    elseif g then
      text = "A guildmate: " .. name .. ". Level " .. tostring(g) .. ", last I looked."
    end
    if text then knownSaid[name] = true Say("knowwho" .. name, text, 1800) end
  elseif Call("UnitCreatureType", "target")[1] == "Critter" then
    knownSaid[name] = true
    Say("knowcritter", { "That is a " .. name .. ". Harmless. Probably.", "A " .. name .. ". I could eat that. I will not. But I could." }, 600)
  else
    local v = Sub(rec, "vendors")[name]
    if type(v) == "table" then
      knownSaid[name] = true
      Say("knowvendor" .. name, "I know " .. name .. ": " .. ((v.repair and v.food) and "repairs, and food and drink" or v.repair and "repairs" or "food and drink") .. ".", 1800)
    end
  end
end)

-- ---------- the map, and being hushed ----------
local mapOpens = {}
local function MapOpened()
  if not On() or InCombat() then return end
  mapOpens[#mapOpens + 1] = Now()
  while #mapOpens > 4 do table.remove(mapOpens, 1) end
  if #mapOpens == 4 and mapOpens[4] - mapOpens[1] < 150 then
    mapOpens = {}
    Say("knowmap", "Fourth look at the map. We are in " .. (SubZone() and (SubZone() .. ", ") or "") .. Zone() .. ". Lost? /owl plan might help.", 900)
  end
end
if type(_G.WorldMapFrame) == "table" and type(_G.WorldMapFrame.HookScript) == "function" then pcall(_G.WorldMapFrame.HookScript, _G.WorldMapFrame, "OnShow", function() pcall(MapOpened) end) end
Owl.MapOpened = MapOpened
local hushes, baseHush = 0, Owl.Hush
Owl.Hush = function(seconds)
  hushes = hushes + 1
  return baseHush(seconds)
end

-- ---------- patterns in when you play ----------
local function LoginInsight()
  local rec = Record()
  local days, today = Sub(rec, "playDays"), DayIndex()
  local firstToday = not days[today]
  days[today] = { zone = Zone(), level = Level() }
  for d in pairs(days) do if tonumber(d) and tonumber(d) < today - 45 then days[d] = nil end end
  local hours = Sub(rec, "hours")
  local hour = tonumber(RealDate("%H") or "")
  local logins = 0
  for _, n in pairs(hours) do logins = logins + n end
  local odd = hour and logins >= 12 and not hours[hour] and not hours[(hour + 1) % 24] and not hours[(hour + 23) % 24]
  if hour then hours[hour] = (hours[hour] or 0) + 1 end
  if not firstToday then return end
  local streak = 1
  while days[today - streak] do streak = streak + 1 end
  local ago = days[today - 7]
  if odd then Say("knowhour", "You are never on at this hour. Everything all right?", 0)
  elseif type(ago) == "table" and ago.level and ago.level < Level() then
    Say("knowweek", "A week ago today you were level " .. ago.level .. " in " .. tostring(ago.zone) .. ". Look at you now.", 0)
  elseif streak == 3 or streak == 5 or streak == 7 or streak == 14 or streak == 30 then
    Say("knowstreak", streak .. " days in a row. I am not complaining.", 0)
  end
end

local basePersonal = O.OwlPersonal
O.OwlPersonal = function()
  if On() and math.random(5) == 1 then
    local ok, line = pcall(function()
      local rec, lines, j = Record(), {}, Journal()
      local fight = type(rec.fight) == "table" and rec.fight or {}
      local top, topN
      for name, e in pairs(type(fight.casts) == "table" and fight.casts or {}) do if type(e) == "table" and (e.n or 0) >= 50 and (not topN or e.n > topN) then top, topN = name, e.n end end
      if top then lines[#lines + 1] = "I counted. You have pressed " .. top .. " " .. topN .. " times." end
      local worst, worstN
      for name, f in pairs(Sub(rec, "foes")) do if (f.deaths or 0) >= 2 and (not worstN or f.deaths > worstN) then worst, worstN = name, f.deaths end end
      if worst and Num(j.deaths) and j.deaths >= 4 then lines[#lines + 1] = "You have died " .. j.deaths .. " times in all. " .. worst .. " is to blame for " .. worstN .. " of them." end
      local visits, fav, favN = Sub(rec, "visits"), nil, 0
      for key, n in pairs(visits) do if n > favN then fav, favN = key, n end end
      if fav and favN >= 8 then lines[#lines + 1] = "Your most visited spot is " .. fav:gsub("^.-: ", "") .. ". " .. favN .. " visits." end
      local hours, bestH, bestHN = Sub(rec, "hours"), nil, 0
      for h, n in pairs(hours) do if n > bestHN then bestH, bestHN = h, n end end
      if bestH and bestHN >= 5 then lines[#lines + 1] = "You log in around " .. bestH .. ":00 more than any other hour. I have started waiting up." end
      if hushes >= 3 then lines[#lines + 1] = "You have hushed me " .. hushes .. " times today. I am trying not to take it personally." end
      if Num(j.kills) and Num(j.deaths) and j.deaths > 0 then lines[#lines + 1] = "By my count that is " .. math.floor(j.kills / j.deaths) .. " kills for every death. Respectable." end
      if #lines == 0 then return nil end
      return lines[math.random(#lines)]
    end)
    if ok and line then return line end
  end
  return basePersonal()
end

-- More he has noticed about you, from what he has been writing down all along. Same moments as before (his idle
-- remarks), so he does not talk more: one time in three the remark is one of these instead.
local earlierPersonal, factSaid = O.OwlPersonal, {}
O.OwlPersonal = function()
  if On() and math.random(3) == 1 then
    local ok, line = pcall(function()
      local rec, lines = Record(), {}
      local function add(text) if text and not factSaid[text] then lines[#lines + 1] = text end end
      local function tbl(t) return type(t) == "table" and t or {} end
      local function count(t) local n = 0 for _ in pairs(tbl(t)) do n = n + 1 end return n end
      -- the biggest number in a table (or in one field of its rows), and who it belongs to
      local function top(t, field, skip)
        local best, bestN
        for k, v in pairs(tbl(t)) do
          local n
          if field then n = type(v) == "table" and Num(v[field]) or nil else n = Num(v) end
          if n and k ~= skip and (not bestN or n > bestN) then best, bestN = k, n end
        end
        return best, bestN or 0
      end
      local function coin(c)
        local g, s = math.floor(c / 10000), math.floor(c % 10000 / 100)
        if g > 0 then return g .. " gold" .. (s > 0 and (" " .. s .. " silver") or "") end
        return s .. " silver"
      end
      -- what you fight
      local kinds = {}
      for kind, n in pairs(tbl(rec.kinds)) do if Num(n) and kind ~= "Not specified" then kinds[#kinds + 1] = { kind, n } end end
      table.sort(kinds, function(a, b) return a[2] > b[2] end)
      if kinds[2] and kinds[1][2] >= 20 then
        add("By my tally: " .. kinds[1][1] .. " " .. kinds[1][2] .. ", " .. kinds[2][1] .. " " .. kinds[2][2] .. (kinds[3] and (", " .. kinds[3][1] .. " " .. kinds[3][2]) or "") .. ".")
      end
      local mob, mobN = top(rec.tally)
      if mob and mobN >= 10 then add(mob .. ": " .. mobN .. " beaten. They must tell stories about you by now.") end
      local fights = Num(tbl(rec.fight).n)
      if fights and fights >= 50 then add("I have watched " .. fights .. " of your fights. I have notes on all of them.") end
      local lvl = tbl(rec.lvl)
      if (Num(lvl.kills) or 0) >= 30 then
        add("This level so far: " .. lvl.kills .. " kills" .. ((Num(lvl.quests) or 0) > 0 and (" and " .. lvl.quests .. (lvl.quests == 1 and " quest" or " quests")) or "") .. ".")
      end
      local records = tbl(rec.records)
      if (Num(records.kills) or 0) >= 20 then add("Your best session is " .. records.kills .. " kills. You were in a mood that day.") end
      if (Num(records.long) or 0) >= 3600 then
        add("Your longest sitting is " .. math.floor(records.long / 3600) .. " h " .. math.floor(records.long % 3600 / 60) .. " min. I did not blink.")
      end
      -- gold and things
      local earned = 0
      for _, n in pairs(tbl(tbl(rec.gold).inn)) do earned = earned + (Num(n) or 0) end
      if earned >= 10000 then add("You have earned " .. coin(earned) .. " since I started counting.") end
      local flown = Num(tbl(tbl(rec.gold).out).flights)
      if flown and flown >= 100 then add("You have spent " .. coin(flown) .. " on flights. I fly for free.") end
      local banked = count(rec.bank)
      if banked >= 20 then add(banked .. " different things in your bank. I have seen dragons hoard less.") end
      local loot = {}
      for _, drops in pairs(tbl(rec.drops)) do
        for item, n in pairs(tbl(drops)) do if Num(n) then loot[item] = (loot[item] or 0) + n end end
      end
      local item, itemN = top(loot)
      if item and itemN >= 8 then add(item .. ": " .. itemN .. " looted so far. I am not sure what you are building.") end
      local mine = count(tbl(rec.cos).own)
      if mine >= 3 then add("I own " .. mine .. " things to wear now. All thanks to you.") end
      -- where you have been, and who with
      local paths = count(rec.flightKnown)
      if paths >= 3 then add("You know " .. paths .. " flight paths. I know all of them. I am a bird.") end
      local spots = count(rec.visits)
      if spots >= 20 then add("You have set foot in " .. spots .. " different places with me. I keep the list.") end
      local known = count(rec.vendors)
      if known >= 4 then add("I know " .. known .. " vendors by name now.") end
      local mate, mateN = top(rec.mates, "groups")
      if mate and mateN >= 2 then add("You have grouped with " .. tostring(mate) .. " more than anyone: " .. mateN .. " times.") end
      -- other players: your nemesis, the one you keep beating, and the running score
      if Owl.pvpFacts then
        local okFacts, facts = pcall(Owl.pvpFacts)
        if okFacts and type(facts) == "table" then for _, text in ipairs(facts) do add(text) end end
      end
      -- your trades: where each one stands against its cap, and which is furthest behind
      local trades, lowest = type(me) == "table" and type(me.profs) == "table" and me.profs or {}, nil
      for _, p in ipairs(trades) do
        local trade, skill, cap = Str(p[1]), Num(p[2]), Num(p[3])
        if trade and skill then
          if cap and cap > skill then
            local left = cap - skill
            if left <= 25 then add(trade .. " is " .. skill .. " of " .. cap .. ". " .. left .. " more and you will need a trainer to go on.")
            else add(trade .. " stands at " .. skill .. " of " .. cap .. ".") end
          end
          if not lowest or skill < lowest[2] then lowest = { trade, skill } end
        end
      end
      if lowest and #trades >= 2 then
        add(lowest[1] .. " is your lowest skill, at " .. lowest[2] .. "." .. (lowest[1] == "Fishing" and " So the pole stays in the bag." or ""))
      end
      -- time
      local played = Num(rec.playedSecs)
      if played and played >= 7200 then add("We have " .. math.floor(played / 3600) .. " hours on this character together. I counted every one.") end
      local week = tbl(rec.week)
      if Num(week.level0) and Level() > week.level0 then
        local up = Level() - week.level0
        add("You began this week at level " .. week.level0 .. ". " .. up .. (up == 1 and " level" or " levels") .. " since.")
      end
      if #lines == 0 then factSaid = {} return nil end
      local text = lines[math.random(#lines)]
      factSaid[text] = true
      return text
    end)
    if ok and line then return line end
  end
  return earlierPersonal()
end

-- ---------- he was watching ----------
local fallT, swimT, stillT, critter, inFight, fightEnded, detailAt, levelledAt, fellAt, groundHP = 0, 0, 0, nil, false, -100, -100, -100, -100, nil
local looks = {}
O.On("PLAYER_REGEN_DISABLED", function() inFight = true end)
O.On("PLAYER_REGEN_ENABLED", function() inFight = false fightEnded = Now() end)
O.On("PLAYER_LEVEL_UP", function() levelledAt = Now() end)
O.On("PLAYER_DEAD", function()
  if not On() or inFight or Now() - fightEnded < 8 then return end
  if Now() - fellAt < 5 then Say("sawoops", { "Gravity. It gets everyone eventually.", "I flew down. You took the fast way.", "Next time, the stairs." }, 600)
  else Say("sawoops", { "Nothing was even attacking you. What happened?", "I saw that. We will tell no one." }, 600) end
end)
O.On("SCREENSHOT_SUCCEEDED", function()
  if On() and Now() - levelledAt > 8 then Say("sawshot", { "Nice shot. Did you get my good side?", "Saving that one? I was not ready." }, 900, "c") end
end)
O.On("INSPECT_READY", function()
  if not On() or not Q("UnitIsPlayer", "target") then return end
  local name = Str(Plain(UnitName("target")))
  if name and name ~= Me() then Say("sawinspect" .. name, { "Admiring " .. name .. "'s gear? I saw.", "Sizing up " .. name .. ". Jealous, or shopping?" }, 900) end
end)
O.On("DUEL_REQUESTED", function(name)
  name = Str(Plain(name))
  if On() and name then Say("sawduel", "A duel with " .. name .. "? I will hold your things.", 120, "c") end
end)
O.On("QUEST_DETAIL", function() detailAt = Now() end)
O.On("QUEST_ACCEPTED", function()
  if On() and Now() - detailAt < 2.5 then
    Say("sawskim", { "You accepted that without reading a word. I read it. It is fine.", "One second. That is how long you looked at that quest." }, 1200)
  end
end)
O.On("PLAYER_TARGET_CHANGED", function()
  critter = nil
  if not On() or not Q("UnitExists", "target") then return end
  local name = Str(Plain(UnitName("target")))
  if not name or name == Me() then return end
  if Call("UnitCreatureType", "target")[1] == "Critter" and not Q("UnitIsDead", "target") then critter = name return end
  if Q("UnitCanAttack", "player", "target") then return end
  -- the same friendly face, again and again
  local list = looks[name] or {}
  list[#list + 1] = Now()
  while #list > 4 do table.remove(list, 1) end
  looks[name] = list
  if #list == 4 and list[4] - list[1] < 300 then
    looks[name] = {}
    Say("sawlook" .. name, "That is the fourth time you have looked at " .. name .. ". Something on your mind?", 1800)
  end
end)
local function Watchful()
  -- a fall only gets a remark if it hurt (dying from one is handled where deaths are)
  local hp = Num(Plain(UnitHealth("player")))
  if Q("IsFalling") then
    fallT = fallT + 1
    fellAt = Now()
  else
    if fallT >= 1 and hp and groundHP and hp > 0 and hp < groundHP and not Q("UnitIsDeadOrGhost", "player") then
      Say("sawfall", { "That one hurt. I flew. You did not.", "Next time, the stairs.", "Ow. I felt that from up here." }, 300)
    end
    fallT = 0
    groundHP = hp
  end
  if Q("IsSwimming") then
    swimT = swimT + 1
    if swimT == 120 then Say("sawswim", "Two minutes of swimming. I am an owl, not a duck.", 1800) end
  else swimT = 0 end
  if Q("GetUnitSpeed", "player") == 0 and not Q("UnitIsAFK", "player") and not Q("IsResting") and not Q("UnitOnTaxi", "player") then
    stillT = stillT + 1
    if stillT == 240 then Say("sawstill", { "We have not moved in four minutes. Reading something?", "Still here. So am I. Just checking." }, 1800) end
  else stillT = 0 end
  if critter and Q("UnitExists", "target") and Q("UnitIsDead", "target") and Str(Plain(UnitName("target"))) == critter then
    Say("sawcritter", { "You killed the " .. critter .. ". I saw that.", "That " .. critter .. " had a family." }, 600)
    critter = nil
  end
end
-- a quest you have carried for a long time
local function OldQuest()
  local rec, today = Record(), DayIndex()
  if rec.oldQuestDay == today then return end
  local q = L.ScanQuests()
  if not q then return end
  rec.oldQuestDay = today
  local seen, live, oldest, oldestDays = Sub(rec, "questSeen"), {}, nil, 0
  for _, quest in ipairs(q.list) do
    local key = tostring(quest.id or quest.title)
    live[key] = true
    if not seen[key] then seen[key] = today end
    local days = today - seen[key]
    if days >= 7 and not quest.complete and days > oldestDays then oldest, oldestDays = quest, days end
  end
  for key in pairs(seen) do if not live[key] then seen[key] = nil end end
  if oldest then Say("knowold", "You have carried \"" .. oldest.title .. "\" for " .. oldestDays .. " days. Do it or drop it.", 0) end
end

O.commands.uncanny = function()
  OwlHUDDB.uncanny = OwlHUDDB.uncanny == false
  O.Print("the owl noticing things about you" .. (OwlHUDDB.uncanny and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

local unAcc, unSlow, unDead, insightAt, stopSaid = 0, 0, false, nil, false
O.On("PLAYER_LOGIN", function() startedAt = Now() insightAt = Now() + 75 zoneBefore = nil end)
local unDriver = CreateFrame("Frame")
unDriver:SetScript("OnUpdate", function(_, e)
  if unDead then return end
  unAcc = unAcc + e
  if unAcc < 1 then return end
  unSlow = unSlow + unAcc
  unAcc = 0
  if not On() or InCombat() then return end
  local ok, err = pcall(function()
    if insightAt and Now() >= insightAt then insightAt = nil LoginInsight() end
    Watchful()
    if unSlow < 30 then return end
    unSlow = 0
    OldQuest()
    -- he knows when you usually stop
    if not stopSaid and startedAt then
      local h = L.History()
      if #h >= 5 then
        local usual = L.UsualSession()
        local played = Now() - startedAt
        if usual and usual >= 1200 and played >= usual * 0.95 and played <= usual * 1.1 then
          stopSaid = true
          Say("knowstop", { "This is about when you usually call it a night. One more quest?", "You normally stop around now. I can tell you are thinking about it." }, 0)
        end
      end
    end
  end)
  if not ok then
    unDead = true
    O.Print("|cffff4040owl noticing things turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- World sense: what creatures drop for you, notes on tooltips, what your bags are worth,
-- enemies piling on, a review after a death, a walking order for quests, what quests
-- still need, a yearbook, his bets, secrets, small requests, your words, your other
-- characters, and quests you share with a friend.
-- =====================================================================================
do
for _, m in ipairs({ { "adds", "worried" }, { "review", "worried" }, { "needvendor", "happy" }, { "bet", "excited" }, { "secret", "excited" }, { "request", "happy" }, { "granted", "excited" },
  { "vocab", "happy" }, { "family", "happy" }, { "shared", "excited" }, { "rareback", "excited" } }) do
  table.insert(Owl.moods, 1, m)
end
local L = Owl.lib
local When, Sub, Count, SubZone = L.When, L.Sub, L.Count, L.SubZone
local function On() return OwlHUDDB.deep ~= false end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function Journal() return type(OwlHUDDB.journal) == "table" and OwlHUDDB.journal or {} end
local function Pct(cur, max) cur, max = Num(Plain(cur)), Num(Plain(max)) if cur and max and max > 0 then return math.floor(cur / max * 100 + 0.5) end end
local worldLogin = nil
local function PlayedNow() return (Num(Record().playedSecs) or 0) + (worldLogin and (Now() - worldLogin) or 0) end
local function Capped(t, key, limit) return t[key] ~= nil or Count(t) < limit end

-- ---------- tallies and drops ----------
local lastKill, lastKillAt, lootFrom, lootAt = nil, -100, nil, -100
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() then return end
  local name = msg:match("^(.-) dies")
  if not name or name == "" then return end
  lastKill, lastKillAt = name, Now()
  local rec = Record()
  local tally = Sub(rec, "tally")
  if Capped(tally, name, 900) then tally[name] = (tally[name] or 0) + 1 end
  local rare = Sub(rec, "rares")[name]
  if type(rare) == "table" then rare.killed = Clock() end
end)
O.On("LOOT_OPENED", function()
  local name = Q("UnitExists", "target") and Q("UnitIsDead", "target") and not Q("UnitIsPlayer", "target") and Str(Plain(UnitName("target")))
  lootFrom = name or (Now() - lastKillAt < 90 and lastKill) or nil
  lootAt = Now()
end)
O.On("CHAT_MSG_LOOT", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() or not lootFrom or Now() - lootAt > 4 or not msg:find("^You receive") then return end
  local item = msg:match("|h%[(.-)%]|h")
  if not item then return end
  local n = tonumber(msg:match("x(%d+)%.?%s*$")) or 1
  local drops = Sub(Record(), "drops")
  if not Capped(drops, lootFrom, 300) then return end
  local d = Sub(drops, lootFrom)
  if Capped(d, item, 10) then d[item] = (d[item] or 0) + n end
end)
local function TopDrops(name, limit)
  local d = Sub(Record(), "drops")[name]
  if type(d) ~= "table" then return nil end
  local list = {}
  for item, n in pairs(d) do list[#list + 1] = { item, n } end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  local parts = {}
  for i = 1, math.min(limit or 2, #list) do parts[i] = list[i][1] .. " x" .. list[i][2] end
  return #parts > 0 and table.concat(parts, ", ") or nil
end

-- ---------- his notes on tooltips ----------
O.defaults.tipnotes = true
local function TipNote(tip)
  if not On() or OwlHUDDB.tipnotes == false or tip ~= _G.GameTooltip or InCombat() then return end
  local name
  if tip.GetUnit then name = Str(Plain((tip:GetUnit()))) end
  if not name then
    local first = _G.GameTooltipTextLeft1
    name = first and first.GetText and Str(Plain(first:GetText()))
  end
  if not name then return end
  local rec, parts = Record(), {}
  local n = Sub(rec, "tally")[name]
  if n then parts[#parts + 1] = "beaten " .. n end
  local f = Sub(rec, "foes")[name]
  if type(f) == "table" and (f.deaths or 0) > 0 then parts[#parts + 1] = "killed you " .. f.deaths end
  local drops = TopDrops(name, 2)
  if drops then parts[#parts + 1] = "gave you " .. drops end
  local m = Sub(rec, "mates")[name]
  if type(m) == "table" and (m.groups or 0) > 0 then parts[#parts + 1] = "grouped " .. m.groups .. (m.groups == 1 and " time" or " times") end
  local v = Sub(rec, "vendors")[name]
  if type(v) == "table" then parts[#parts + 1] = (v.repair and v.food) and "repairs, food" or v.repair and "repairs" or "food" end
  if #parts == 0 then return end
  tip:AddLine("|cffffd100" .. Name() .. ":|r " .. table.concat(parts, "; "), 0.92, 0.86, 0.7, true)
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip) pcall(TipNote, tip) end)
elseif type(_G.GameTooltip) == "table" and _G.GameTooltip.HookScript then
  pcall(_G.GameTooltip.HookScript, _G.GameTooltip, "OnTooltipSetUnit", function(tip) pcall(TipNote, tip) end)
end
Owl.TipNote = TipNote
O.commands.tipnotes = function()
  OwlHUDDB.tipnotes = OwlHUDDB.tipnotes == false
  O.Print("owl notes on tooltips" .. (OwlHUDDB.tipnotes and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- what your bags are worth to a vendor ----------
O.commands.worth = function()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Item and C_Item.GetItemInfo) then O.Print("I cannot price your bags in this version of the game.") return end
  local total, junk, list = 0, 0, {}
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      local link = ok and type(info) == "table" and Str(Plain(info.hyperlink))
      if link then
        local price = Num(Pack(pcall(C_Item.GetItemInfo, link))[11]) or 0
        local value = price * (Num(Plain(info.stackCount)) or 1)
        if value > 0 then
          total = total + value
          if Num(Plain(info.quality)) == 0 then junk = junk + value end
          list[#list + 1] = { link:match("%[(.-)%]") or "?", value }
        end
      end
    end
  end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  O.Print("|cffffd100Your bags at a vendor|r: " .. O.Money(total) .. " in all, " .. O.Money(junk) .. " of it grey junk.")
  for i = 1, math.min(5, #list) do print("  " .. list[i][1] .. ": " .. O.Money(list[i][2])) end
  print("  (Vendor prices only. The auction house usually pays more for herbs and cloth.)")
end

-- ---------- a rare you killed: it may be back ----------
O.On("ZONE_CHANGED", function()
  if not On() or InCombat() then return end
  local zone, place = Zone(), SubZone()
  if not place then return end
  for name, r in pairs(Sub(Record(), "rares")) do
    if type(r) == "table" and r.zone == zone and r.place == place and Num(r.killed) and Clock() - r.killed > 7200 then
      Say("rareback" .. name, "You killed " .. name .. " here " .. When(r.killed) .. ". It may be back by now.", 3600)
      return
    end
  end
end)

-- ---------- enemies piling on, and a review after a death ----------
local plates, fight, lastHP, lastMana, addsAcc = {}, nil, nil, nil, 0
O.On("NAME_PLATE_UNIT_ADDED", function(unit) unit = Plain(unit) if type(unit) == "string" then plates[unit] = true end end)
O.On("NAME_PLATE_UNIT_REMOVED", function(unit) unit = Plain(unit) if type(unit) == "string" then plates[unit] = nil end end)
local function OnMe()
  local n = 0
  for unit in pairs(plates) do
    if Plain(UnitAffectingCombat(unit)) == true and Q("UnitCanAttack", "player", unit) and not Q("UnitIsDead", unit) and not Q("UnitIsPlayer", unit) then
      local mine = Q("UnitIsUnit", unit .. "target", "player")
      if mine ~= false then n = n + 1 end
    end
  end
  return n
end
O.On("PLAYER_REGEN_DISABLED", function()
  fight = { at = Now(), hp = lastHP, mana = lastMana, adds = 0 }
  if Q("UnitExists", "target") and Q("UnitCanAttack", "player", "target") then
    fight.foe = Str(Plain(UnitName("target")))
    local lvl = Num(Plain(UnitLevel("target")))
    fight.gap = lvl == -1 and 99 or (lvl and lvl - Level() or nil)
    local class = Q("UnitClassification", "target")
    fight.elite = class == "elite" or class == "rareelite" or class == "worldboss"
  end
end)
O.On("PLAYER_REGEN_ENABLED", function() if fight then fight.ended = Now() end end)
local reviewAt
O.On("PLAYER_DEAD", function()
  if On() and fight and (not fight.ended or Now() - fight.ended < 6) then
    reviewAt = Now() + 3
    Owl.deathReviewAt = Now()
  end
end)
local function Review()
  local f = fight
  if not f then return end
  local why = {}
  if (f.adds or 0) >= 2 then why[#why + 1] = f.adds .. " enemies were on you at once" end
  if f.hp and f.hp < 60 then why[#why + 1] = "you went in at " .. f.hp .. "% health" end
  if f.mana and f.mana < 30 then why[#why + 1] = "you started with " .. f.mana .. "% mana" end
  if f.gap == 99 then why[#why + 1] = "it was far above your level" elseif f.gap and f.gap >= 3 then why[#why + 1] = "it was " .. f.gap .. " levels above you" end
  if f.elite then why[#why + 1] = "it was elite" end
  local saver = Owl.ReadySaver and Owl.ReadySaver()
  if saver then why[#why + 1] = saver .. " was ready and unused" end
  local foe = f.foe and Sub(Record(), "foes")[f.foe]
  if type(foe) == "table" and (foe.deaths or 0) >= 2 then why[#why + 1] = "that is " .. foe.deaths .. " deaths to " .. f.foe end
  if #why == 0 then Say("review", "I watched that one closely. No obvious mistake. Sometimes they just hit hard.", 120)
  else Say("review", "What went wrong: " .. table.concat(why, "; ") .. ".", 0) end
  fight = nil
end

-- ---------- a walking order for the quests on this map ----------
local function Compass(dx, dy)
  local parts = {}
  if dy < -0.03 then parts[#parts + 1] = "north" elseif dy > 0.03 then parts[#parts + 1] = "south" end
  if dx > 0.03 then parts[#parts + 1] = "east" elseif dx < -0.03 then parts[#parts + 1] = "west" end
  return #parts > 0 and table.concat(parts, "-") or "right here"
end
O.commands.route = function()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_QuestLog and C_QuestLog.GetQuestsOnMap) then O.Print("this version of the game does not tell me where quests are on the map.") return end
  local map = Num(Plain(C_Map.GetBestMapForUnit("player")))
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  local px, py
  if okP and type(pos) == "table" then
    if pos.GetXY then local ok, x, y = pcall(pos.GetXY, pos) if ok then px, py = Num(Plain(x)), Num(Plain(y)) end else px, py = Num(Plain(pos.x)), Num(Plain(pos.y)) end
  end
  local okQ, spots = pcall(C_QuestLog.GetQuestsOnMap, map)
  if not (px and py) or not okQ or type(spots) ~= "table" or #spots == 0 then O.Print("the map shows no quest spots for you here. Try it out in the open, in a zone where you have quests.") return end
  local left = {}
  for _, s in ipairs(spots) do
    local id, x, y = Num(Plain(s.questID)), Num(Plain(s.x)), Num(Plain(s.y))
    if id and x and y then
      local title = C_QuestLog.GetTitleForQuestID and Str(Plain(C_QuestLog.GetTitleForQuestID(id))) or ("Quest " .. id)
      left[#left + 1] = { title = title, x = x, y = y }
    end
  end
  O.Print("|cffffd100A walking order from where you stand|r")
  local cx, cy, step = px, py, 0
  while #left > 0 and step < 12 do
    local best, bestD
    for i, s in ipairs(left) do
      local d = (s.x - cx) ^ 2 + (s.y - cy) ^ 2
      if not bestD or d < bestD then best, bestD = i, d end
    end
    local s = table.remove(left, best)
    step = step + 1
    local dist = math.sqrt(bestD)
    print("  " .. step .. ". " .. s.title .. ": " .. Compass(s.x - cx, s.y - cy) .. ((dist < 0.06 and ", close") or (dist < 0.2 and ", a walk") or ", far"))
    cx, cy = s.x, s.y
  end
end

-- ---------- what your quests still need ----------
local function Needs()
  local out = {}
  local q = L.ScanQuests()
  if not q or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return out end
  for _, quest in ipairs(q.list) do
    if quest.id and not quest.complete then
      local ok, objs = pcall(C_QuestLog.GetQuestObjectives, quest.id)
      if ok and type(objs) == "table" then
        for _, o in ipairs(objs) do
          if type(o) == "table" and not Plain(o.finished) then
            local text = Str(Plain(o.text))
            if text then out[#out + 1] = { quest = quest.title, text = text, kind = Str(Plain(o.type)) } end
          end
        end
      end
    end
  end
  return out
end
-- which quest an objective belongs to, and what that quest still wants (with exact counts)
O.OwlQuestOf = function(what)
  local q = L.ScanQuests()
  if not q or not (C_QuestLog and C_QuestLog.GetQuestObjectives) or type(what) ~= "string" or what == "" then return nil end
  for _, quest in ipairs(q.list) do
    if quest.id then
      local ok, objs = pcall(C_QuestLog.GetQuestObjectives, quest.id)
      if ok and type(objs) == "table" then
        local mine, left = false, {}
        for _, o in ipairs(objs) do
          local text = type(o) == "table" and Str(Plain(o.text))
          if text then
            if text:find(what, 1, true) then mine = true
            elseif not Plain(o.finished) then
              local have, need = Num(Plain(o.numFulfilled)), Num(Plain(o.numRequired))
              -- "Wolf Pelt: 3/8" already carries the count; add it when the text does not
              if have and need and need > 0 and not text:find("%d+%s*/%s*%d+") then text = text .. " " .. have .. "/" .. need end
              left[#left + 1] = text
            end
          end
        end
        if mine then return quest.title, left, quest.id end
      end
    end
  end
  return nil
end
O.commands.needs = function()
  local list = Needs()
  if #list == 0 then O.Print("nothing outstanding that I can read. Either all done or this game hides the objectives.") return end
  O.Print("|cffffd100Still to do|r")
  local last
  for _, n in ipairs(list) do
    if n.quest ~= last then print("  |cffffd100" .. n.quest .. "|r") last = n.quest end
    print("     " .. n.text)
  end
end
local needAt
O.On("MERCHANT_SHOW", function() needAt = Now() + 1.5 end)
local function VendorNeeds()
  local wanted = {}
  for _, n in ipairs(Needs()) do if n.kind == "item" then wanted[#wanted + 1] = n end end
  if #wanted == 0 then return end
  for i = 1, math.min(Num(Call("GetMerchantNumItems")[1]) or 0, 60) do
    local link = Str(Call("GetMerchantItemLink", i)[1])
    local name = (link and link:match("%[(.-)%]")) or Str(Call("GetMerchantItemInfo", i)[1])
    if name and #name >= 4 then
      for _, n in ipairs(wanted) do
        if n.text:find(name, 1, true) then Say("needvendor" .. name, "This vendor sells " .. name .. ". " .. n.quest .. " needs it.", 600) return end
      end
    end
  end
end

-- ---------- quest help: every step counted, drop rates, where to hand in, what a new quest wants ----------
table.insert(Owl.moods, 1, { "objp", "happy" })
table.insert(Owl.moods, 1, { "queststuck", "worried" })
table.insert(Owl.moods, 1, { "starts", "excited" })
local killCount, objTrack, lastProgress, killsAtProgress = 0, {}, nil, 0
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) == "string" and msg:find("dies", 1, true) then killCount = killCount + 1 end
end)
local function TurnInWhere(id)
  if not id or not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_QuestLog and C_QuestLog.GetQuestsOnMap) then return nil end
  local map = Num(Plain(C_Map.GetBestMapForUnit("player")))
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  local okQ, spots = pcall(C_QuestLog.GetQuestsOnMap, map)
  if not okP or type(pos) ~= "table" or not okQ or type(spots) ~= "table" then return nil end
  local px, py
  if pos.GetXY then local ok, x, y = pcall(pos.GetXY, pos) if ok then px, py = Num(Plain(x)), Num(Plain(y)) end else px, py = Num(Plain(pos.x)), Num(Plain(pos.y)) end
  if not px then return nil end
  for _, sp in ipairs(spots) do
    if Num(Plain(sp.questID)) == id then
      local x, y = Num(Plain(sp.x)), Num(Plain(sp.y))
      if x and y then
        local dist = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
        return Compass(x - px, y - py) .. ((dist < 0.06 and ", close by") or (dist < 0.2 and ", a walk") or ", a long way")
      end
    end
  end
  return nil
end
local NUMBER = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" }
O.OwlObjective = function(what, have, need)
  if not OwlHUDDB.tips or OwlHUDDB.questhelp == false then return false end
  lastProgress, killsAtProgress = Now(), killCount
  local track = objTrack[what]
  if not track then track = { have0 = have, kills0 = killCount } objTrack[what] = track end
  if have < need then
    local left = need - have
    local step = need <= 6 or left == 1 or math.floor(have * 4 / need) > math.floor((have - 1) * 4 / need)
    if not step then return true end
    local count = NUMBER[left] or tostring(left)
    local ways = { what .. ": " .. have .. " of " .. need .. ". " .. count .. " to go.", "That is " .. have .. " of " .. need .. " for " .. what .. ". " .. count .. " left.",
      what .. ", " .. have .. " down. " .. count .. " more.", have .. " of " .. need .. " on " .. what .. ". Keep at it: " .. count:lower() .. " to go." }
    if left == 1 then ways = { what .. ": " .. have .. " of " .. need .. ". One to go.", "One more for " .. what .. ". " .. have .. " of " .. need .. ".", "Last one! " .. what .. ": " .. have .. " of " .. need .. "." }
    elseif have * 2 == need then ways[#ways + 1] = "Halfway on " .. what .. ": " .. have .. " of " .. need .. "." end
    local text = OwlHUDDB.flavor == false and ways[1] or ways[math.random(#ways)]
    local gained, kills = have - track.have0, killCount - track.kills0
    if left > 1 and gained >= 2 and kills / gained >= 1.4 then
      text = text .. " About one every " .. (string.format("%.1f", kills / gained):gsub("%.0$", "")) .. " kills, so " .. string.format("%d", math.ceil(left * kills / gained)) .. " more kills."
    end
    Say("objp" .. what, text, 6, "c")
    return true
  end
  objTrack[what] = nil
  local quest, left, id = O.OwlQuestOf(what)
  local done = what .. ": " .. need .. " of " .. need .. "."
  if quest and type(left) == "table" and #left > 0 then
    Say("obj" .. what, done .. " Still to do for " .. quest .. ": " .. table.concat(left, ", ", 1, math.min(2, #left)) .. (#left > 2 and (" and " .. (#left - 2) .. " more") or "") .. ".", 20, "c")
  elseif quest then
    local where = TurnInWhere(id)
    local q = L.ScanQuests()
    local ready = q and q.done or 0
    local finish = ({ " That finishes " .. quest .. ".", " And that is " .. quest .. " done.", " " .. quest .. ": finished." })[OwlHUDDB.flavor == false and 1 or math.random(3)]
    Say("obj" .. what, done .. finish .. (where and (" Hand it in to the " .. where .. ".") or " Hand it in.") .. (ready >= 2 and (" That makes " .. ready .. " ready.") or ""), 20, "c")
  else
    Say("obj" .. what, "Done: " .. what .. ", " .. need .. " of " .. need .. ".", 20, "c")
  end
  return true
end
O.defaults.questhelp = true
O.commands.questhelp = function()
  OwlHUDDB.questhelp = OwlHUDDB.questhelp == false
  O.Print("quest progress call-outs" .. (OwlHUDDB.questhelp and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
-- what a quest you just took wants
local questIds, wantsAt
O.On("QUEST_ACCEPTED", function() wantsAt = Now() + 2.5 end)
O.On("PLAYER_LOGIN", function() wantsAt = Now() + 20 end)
local function NewQuestWants()
  local q = L.ScanQuests()
  if not q or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
  local first = questIds == nil
  questIds = questIds or {}
  for _, quest in ipairs(q.list) do
    if quest.id and not questIds[quest.id] then
      questIds[quest.id] = true
      if not first and OwlHUDDB.questhelp ~= false then
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, quest.id)
        local parts = {}
        if ok and type(objs) == "table" then
          for _, o in ipairs(objs) do
            local text = type(o) == "table" and not Plain(o.finished) and Str(Plain(o.text))
            if text then parts[#parts + 1] = (text:gsub("^(.-):%s*0%s*/%s*(%d+)$", "%2 %1")) end
          end
        end
        if #parts > 0 then Say("questwants" .. quest.id, quest.title .. " wants: " .. table.concat(parts, ", ", 1, math.min(3, #parts)) .. (#parts > 3 and " and more" or "") .. ".", 0) end
      end
    end
  end
end
-- an item in your bags that starts a quest
local startsAt
O.On("BAG_UPDATE_DELAYED", function() startsAt = Now() + 3 end)
local function QuestStarters()
  if not (C_Container and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
      if ok and type(info) == "table" and Num(Plain(info.questID)) and not Plain(info.isActive) then
        local ok2, item = pcall(C_Container.GetContainerItemInfo, bag, slot)
        local link = ok2 and type(item) == "table" and Str(Plain(item.hyperlink))
        local name = link and link:match("%[(.-)%]")
        if name then Say("starts" .. name, name .. " in your bags starts a quest. Use it to begin.", 1800) return end
      end
    end
  end
end
-- lots of kills, no progress
local function QuestStuck()
  if OwlHUDDB.questhelp == false or killCount - killsAtProgress < 25 then return end
  local waiting = false
  for _, n in ipairs(Needs()) do if n.kind == "monster" or n.kind == "item" then waiting = true break end end
  killsAtProgress = killCount
  if waiting then Say("queststuck", "25 kills and nothing has counted for a quest. Wrong creature, or just hunting? /owl needs lists what is left.", 1800) end
end

-- ---------- the yearbook, and his bets ----------
local function Page(level)
  local j = Journal()
  local weapon = me.gear and me.gear[16]
  local top = {}
  for _, s in ipairs(me.stats or {}) do top[#top + 1] = s[1] .. " " .. s[2] end
  return { at = Clock(), zone = Zone(), place = SubZone(), gold = Num(Plain(GetMoney())), weapon = weapon and weapon.name, ilvl = me.ilvl, stats = table.concat(top, ", "),
    with = table.concat(L.PartyNames(), ", "), kills = Num(j.kills), deaths = Num(j.deaths), played = math.floor(PlayedNow()) }
end
local betAt
O.On("PLAYER_LEVEL_UP", function(newLevel)
  if not On() then return end
  local level = Num(Plain(newLevel)) or (Level() + 1)
  local rec = Record()
  pcall(function() Sub(rec, "yearbook")[level] = Page(level) end)
  betAt = { at = Now() + 26, level = level }
end)
local function Bet(level)
  local rec = Record()
  local score = Sub(rec, "betScore")
  local played = PlayedNow()
  local bet = rec.bet
  if type(bet) == "table" and bet.level == level and Num(bet.by) then
    if played <= bet.by then
      score.right = (score.right or 0) + 1
      Say("betwon", "I called it: level " .. level .. " inside my guess. That is " .. score.right .. " right, " .. (score.wrong or 0) .. " wrong.", 0)
    else
      score.wrong = (score.wrong or 0) + 1
      Say("betlost", "You took longer than I bet. " .. (score.right or 0) .. " right, " .. score.wrong .. " wrong. I blame the murlocs.", 0)
    end
  end
  local at = Sub(rec, "levelAt")
  local took = Num(at[level]) and Num(at[level - 1]) and (at[level] - at[level - 1]) or nil
  if took and took > 600 then
    local guess = took * 1.15
    rec.bet = { level = level + 1, by = played + guess, made = Clock() }
    Say("bet", "My bet: level " .. (level + 1) .. " within " .. Duration(guess) .. " of play. I am keeping score.", 0)
  else
    rec.bet = nil
  end
end
O.commands.bets = function()
  local rec = Record()
  local score = Sub(rec, "betScore")
  O.Print("his bets: " .. (score.right or 0) .. " right, " .. (score.wrong or 0) .. " wrong.")
  if type(rec.bet) == "table" and Num(rec.bet.by) then print("  Open bet: level " .. tostring(rec.bet.level) .. " within " .. Duration(math.max(0, rec.bet.by - PlayedNow())) .. " more play.") end
end
O.commands.yearbook = function(arg)
  local book = Sub(Record(), "yearbook")
  local want = tonumber(arg)
  local levels = {}
  for lvl in pairs(book) do if tonumber(lvl) then levels[#levels + 1] = tonumber(lvl) end end
  table.sort(levels, function(a, b) return a > b end)
  if #levels == 0 then O.Print("the yearbook gets its first page when you next level up.") return end
  O.Print("|cffffd100The yearbook|r")
  for i, lvl in ipairs(levels) do
    local p = book[lvl] or book[tostring(lvl)]
    if type(p) == "table" and ((want and lvl == want) or (not want and i <= 8)) then
      print("  |cffffd100Level " .. lvl .. "|r, " .. When(p.at) .. ", in " .. tostring(p.place or p.zone) .. (p.place and (", " .. tostring(p.zone)) or ""))
      if want then
        if p.weapon then print("     Carrying " .. p.weapon .. (p.ilvl and (", gear item level " .. p.ilvl) or "")) end
        if p.stats and p.stats ~= "" then print("     " .. p.stats) end
        print("     " .. (p.kills or 0) .. " kills and " .. (p.deaths or 0) .. " deaths in all by then, " .. Duration(p.played or 0) .. " played, " .. O.Money(p.gold or 0) .. " in the purse")
        if p.with and p.with ~= "" then print("     With " .. p.with) end
      end
    end
  end
  if not want then print("  /owl yearbook 27 opens one page.") end
end

-- ---------- secrets: said once, ever ----------
local function Hour() local h = Q("GetGameTime") return type(h) == "number" and h or nil end
local function Night() local h = Hour() return h and (h >= 21 or h < 5) end
local function PlaceHas(word) local p = SubZone() return p and p:find(word, 1, true) ~= nil end
local SECRETS = {
  { "cathedral", function() return PlaceHas("Cathedral") and Hour() == 0 end, "Midnight in the cathedral. Even I feel something." },
  { "graveyard", function() return (PlaceHas("Cemetery") or PlaceHas("Graveyard")) and Night() end, "A graveyard at night. You take me to the nicest places." },
  { "tram", function() return Zone() == "Deeprun Tram" end, "A train under the sea. Gnomes worry me." },
  { "shirtless", function() return me.gathered and Level() >= 10 and not me.gear[5] end, "Where is your armor? I am covered in feathers and even I am embarrassed." },
  { "fishing", function() local w = me.gear[16] return w and w.name and w.name:find("Fishing", 1, true) ~= nil end, "Fishing! Finally, a sensible activity. I will take the small ones." },
  { "eleven", function() return type(date) == "function" and select(2, pcall(date, "%H:%M")) == "11:11" end, "It is 11:11. Make a wish. I wished for mice." },
  { "roundgold", function() local m = Num(Plain(GetMoney())) return m and m >= 10000 and m % 10000 == 0 end, "Exactly that much gold. Not a copper over. That pleases me more than it should." },
  { "doubles", function() local l = Level() return l == 33 or l == 44 or l == 55 end, "I like the look of your level. Two of the same number. Tidy." },
  { "keep", function() return PlaceHas("Stormwind Keep") end, "The king's keep. Do not touch anything. I will touch everything." },
  { "lionspride", function() return PlaceHas("Lion's Pride") end, "The Lion's Pride. Do not ask what I have seen in here." },
  { "bootybay", function() return PlaceHas("Booty Bay") end, "Pirates and parrots. I am the better bird." },
  { "darkshire", function() return PlaceHas("Darkshire") and Night() end, "Darkshire after dark. The name was a warning." },
  { "moonglade", function() return Zone() == "Moonglade" end, "Moonglade. Owls are respected here. As it should be." },
  { "forge", function() return PlaceHas("Great Forge") end, "It is very warm in here. My feathers are curling." },
  { "hundred", function() return (Num(Journal().deaths) or 0) >= 100 end, "One hundred deaths. And you got up every time. I counted both." },
  { "fullday", function() return PlayedNow() >= 86400 end, "A full day and night of play together, all told. Time well wasted." },
  { "pats", function() return (Num(Record().pats) or 0) >= 5 end, "Five pats in a day. That is the limit. I do not make the rules. I do, actually." },
  { "prison", function() return Zone() == "The Stockade" or PlaceHas("Stockade") end, "A prison. For the record, I have done nothing wrong." },
  { "ghost", function() return Q("UnitIsGhost", "player") end, "You are see-through. I can still see you. Owls can." },
  { "named", function() return type(OwlHUDDB.owlName) == "string" and OwlHUDDB.owlName ~= "Owl" end, "You gave me a name. I had one already, but yours is better." },
}
local function CheckSecrets()
  local found = Sub(Record(), "secrets")
  for _, s in ipairs(SECRETS) do
    if not found[s[1]] then
      local ok, hit = pcall(s[2])
      if ok and hit and Say("secret" .. s[1], s[3], 0) then
        found[s[1]] = Clock()
        return
      end
    end
  end
end
O.commands.secrets = function()
  O.Print("you have found " .. Count(Sub(Record(), "secrets")) .. " of " .. #SECRETS .. " things I only say once. I will not tell you where the rest are.")
end

-- ---------- small requests ----------
local did = {}
local CITIES = { ["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true, ["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true }
local REQUESTS = {
  sea = { "Show me the water. Just a swim.", "The water! Cold. Wonderful. Thank you.", function() return Q("IsSwimming") end, "Took the owl for a swim." },
  fly = { "Take me flying. A flight path will do.", "The wind! That is the stuff. Thank you.", function() return Q("UnitOnTaxi", "player") end, "Took the owl flying." },
  city = { "Take me to a city. I want to see people.", "So many people. So many hats. Thank you.", function() return CITIES[Zone()] end, "Showed the owl the city." },
  critter = { "Find me a critter to look at. Only look.", "Look at it. So small. Thank you. I am not hungry at all.", function() return Q("UnitExists", "target") and Call("UnitCreatureType", "target")[1] == "Critter" end, "Found the owl a critter to watch." },
  dance = { "Dance for me. Nobody is watching. I am watching.", "Ha! Yes. That is what I wanted.", function() return did.dance end, "Danced for the owl." },
  inn = { "Let us sit somewhere warm a while. An inn.", "Warm, dry, and nobody is trying to kill us. Thank you.", function() return Q("IsResting") and (SubZone() or ""):find("Inn", 1, true) ~= nil end, "Sat in an inn with the owl." },
  pat = { "A pat on the head would not go amiss. /owl pat", "There. That was all I wanted.", function() return did.pat end, "Gave the owl a pat when he asked." },
}
local requestKeys = { "sea", "fly", "city", "critter", "dance", "inn", "pat" }
O.On("CHAT_MSG_TEXT_EMOTE", function(msg, sender)
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) == "string" and type(sender) == "string" and sender:gsub("%-.*$", "") == Me() and msg:lower():find("dance", 1, true) then did.dance = Now() end
end)
local basePat = O.commands.pat
if basePat then O.commands.pat = function(...) did.pat = Now() return basePat(...) end end
local function CheckRequest()
  local rec = Record()
  local r = rec.request
  if type(r) == "table" and REQUESTS[r.key] then
    local ok, done = pcall(REQUESTS[r.key][3])
    if ok and done then
      rec.request = nil
      rec.requestsDone = (rec.requestsDone or 0) + 1
      rec.requestPlayed = PlayedNow()
      rec.bond = (Num(rec.bond) or 0) + 3
      Say("granted" .. r.key, REQUESTS[r.key][2], 0)
      pcall(Note, REQUESTS[r.key][4])
    elseif Clock() - (r.at or 0) > 3 * 86400 then
      rec.request, rec.requestPlayed = nil, PlayedNow()
    end
    return
  end
  -- a new one: now and then, when things are calm
  local since = PlayedNow() - (Num(rec.requestPlayed) or 0)
  if since < 5400 or Q("IsResting") or Q("IsInInstance") or math.random(4) ~= 1 then return end
  local key = requestKeys[math.random(#requestKeys)]
  if key == rec.lastRequest then return end
  did = {}
  if Say("request" .. key, REQUESTS[key][1], 0) then rec.request, rec.lastRequest = { key = key, at = Clock() }, key end
end
O.commands.request = function()
  local r = Record().request
  if type(r) == "table" and REQUESTS[r.key] then O.Print("he asked: " .. REQUESTS[r.key][1]) else O.Print("he has not asked for anything. He will, sooner or later.") end
end

-- ---------- your words ----------
local GOOD = { "dope", "nice", "sick", "pog", "gg", "sweet", "awesome", "epic", "fire", "yay", "woo", "noice", "clutch", "ez", "lets go", "goated", "based" }
local BAD = { "oof", "rip", "yikes", "bruh", "ugh", "welp", "rekt", "nooo", "big oof" }
local function Heard(msg, sender)
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" or sender:gsub("%-.*$", "") ~= Me() or not On() then return end
  local low = " " .. msg:lower():gsub("[%p]", " ") .. " "
  local vocab = Sub(Record(), "vocab")
  for _, list in ipairs({ GOOD, BAD }) do
    for _, word in ipairs(list) do if low:find(" " .. word .. " ", 1, true) then vocab[word] = (vocab[word] or 0) + 1 end end
  end
end
for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER_INFORM" }) do
  if event == "CHAT_MSG_WHISPER_INFORM" then O.On(event, function(msg) Heard(msg, Me()) end) else O.On(event, Heard) end
end
local function YourWord(list)
  local vocab, best, bestN = Sub(Record(), "vocab"), nil, 2
  for _, word in ipairs(list) do if (vocab[word] or 0) > bestN then best, bestN = word, vocab[word] end end
  return best
end
local wordAt
O.On("PLAYER_LEVEL_UP", function() wordAt = { at = Now() + 34, good = true } end)
O.On("PLAYER_DEAD", function() if math.random(3) == 1 then wordAt = { at = Now() + 9, good = false } end end)

-- ---------- your other characters ----------
local function Family()
  local list, mine = {}, Record()
  for key, rec in pairs(type(OwlHUDDB.chars) == "table" and OwlHUDDB.chars or {}) do
    if type(rec) == "table" and Num(rec.lastLevel) then list[#list + 1] = { key = key, rec = rec, me = rec == mine } end
  end
  table.sort(list, function(a, b) return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end)
  return list
end
O.commands.family = function()
  local list, total = Family(), 0
  O.Print("|cffffd100Your characters|r")
  for _, c in ipairs(list) do
    local r = c.rec
    local money = c.me and Num(Plain(GetMoney())) or Num(r.money)
    total = total + (money or 0)
    print("  " .. c.key:gsub("%-.*$", "") .. ": level " .. (c.me and Level() or r.lastLevel) .. " " .. tostring(r.className or "") .. ", " .. tostring(c.me and Zone() or r.lastZone)
      .. (money and (", " .. O.Money(money)) or "") .. (c.me and "  (here now)" or ("  (" .. When(r.lastSeen) .. ")")))
  end
  print("  Gold across all of them: " .. O.Money(total))
  if #list <= 1 then print("  Only this one so far. Log in on another and I will get to know them too.") end
end
local function FamilyLine()
  local rec = Record()
  local today = math.floor(Clock() / 86400)
  if rec.familyDay == today then return end
  rec.familyDay = today
  for _, c in ipairs(Family()) do
    if not c.me and Num(c.rec.lastSeen) and Clock() - c.rec.lastSeen > 2 * 86400 then
      Say("family", c.key:gsub("%-.*$", "") .. " is still level " .. c.rec.lastLevel .. " in " .. tostring(c.rec.lastZone) .. ", where you left them " .. When(c.rec.lastSeen) .. ".", 0)
      return
    end
  end
end

-- ---------- quests you share with a friend's owl ----------
local theirs, sharedAt = {}, {}
local function SendQuests()
  local q = L.ScanQuests()
  if not q or not Owl.net then return end
  local ids = {}
  for _, quest in ipairs(q.list) do if quest.id then ids[#ids + 1] = tostring(quest.id) end end
  for first = 1, math.min(#ids, 24), 12 do
    pcall(Owl.net.Send, "QUESTS", table.concat(ids, ",", first, math.min(first + 11, #ids)))
  end
end
local netBase = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBase then pcall(netBase, kind, sender, owl, extra) end
  if kind == "HELLO" or kind == "HI" then
    pcall(SendQuests)
  elseif kind == "QUESTS" then
    local set = theirs[sender] or {}
    for id in extra:gmatch("%d+") do set[tonumber(id)] = true end
    theirs[sender] = set
    sharedAt[sender] = Now() + 4
  end
end
local function SharedWith(sender)
  local q = L.ScanQuests()
  local set = theirs[sender]
  if not q or not set then return end
  local titles = {}
  for _, quest in ipairs(q.list) do if quest.id and set[quest.id] then titles[#titles + 1] = quest.title end end
  theirs[sender] = nil
  if #titles == 1 then Say("shared" .. sender, sender .. " has one of your quests too: " .. titles[1] .. ". Do it together.", 1800)
  elseif #titles > 1 then Say("shared" .. sender, sender .. " has " .. #titles .. " of your quests too: " .. Join(titles, 2) .. ". Do them together.", 1800) end
end

-- ---------- the gear hunt ----------
O.commands.hunt = function()
  local ok, list = pcall(Owl.WornRanks or function() return {} end)
  if not ok or type(list) ~= "table" or #list == 0 then O.Print("I need Forever Leveling BiS (and a moment out of combat) to rank your gear.") return end
  table.sort(list, function(a, b) return (a.best and 0 or (a.rank or 0)) > (b.best and 0 or (b.rank or 0)) end)
  O.Print("|cffffd100Where to hunt next|r (worst-ranked first)")
  for i = 1, math.min(6, #list) do
    local e = list[i]
    print("  " .. e.slot .. ": " .. e.name .. (e.best and " is best in slot" or (" ranks #" .. e.rank)))
  end
  if type(SlashCmdList) == "table" and type(SlashCmdList.FOREVERLEVELINGBIS) == "function" then
    print("  Opening the BiS window: look up your " .. list[1].slot .. " there to see where better ones come from.")
    pcall(SlashCmdList.FOREVERLEVELINGBIS, "")
  end
end

-- ---------- drivers ----------
O.On("PLAYER_LOGIN", function() worldLogin = Now() end)
O.On("PLAYER_LOGOUT", function()
  pcall(function()
    local rec = Record()
    rec.className, rec.money = Owl.className, Owl.Money()
  end)
end)
local wAcc, wSlow, wDead, familyAt = 0, 0, false, nil
O.On("PLAYER_LOGIN", function() familyAt = Now() + 95 end)
local wDriver = CreateFrame("Frame")
wDriver:SetScript("OnUpdate", function(_, e)
  if wDead then return end
  wAcc = wAcc + e
  if wAcc < 1 then return end
  wSlow = wSlow + wAcc
  wAcc = 0
  if not On() then return end
  local ok, err = pcall(function()
    if InCombat() then
      -- how many are on you (solo only: in a group the tank has them)
      if fight and not Q("IsInGroup") then
        local n = OnMe()
        if n > (fight.adds or 0) then fight.adds = n end
        if n >= 3 then Say("adds3", "Three on you! Use everything, or run.", 40, "uc")
        elseif n == 2 then Say("adds2", Owl.P and Owl.P("Two on you. Stun one, finish the other.", "Two on you. Burn one down first.") or "Two on you. Burn one down first.", 40, "c") end
      end
      return
    end
    lastHP = Pct(UnitHealth("player"), UnitHealthMax("player")) or lastHP
    if Q("UnitPowerType", "player") == 0 then lastMana = Pct(UnitPower("player"), UnitPowerMax("player")) or lastMana else lastMana = nil end
    local now = Now()
    if reviewAt and now >= reviewAt then reviewAt = nil Review() end
    if needAt and now >= needAt then needAt = nil VendorNeeds() end
    if wantsAt and now >= wantsAt then wantsAt = nil NewQuestWants() end
    if startsAt and now >= startsAt then startsAt = nil QuestStarters() end
    if betAt and now >= betAt.at then local b = betAt betAt = nil Bet(b.level) end
    if familyAt and now >= familyAt then familyAt = nil FamilyLine() end
    if wordAt and now >= wordAt.at then
      local w = wordAt
      wordAt = nil
      local word = YourWord(w.good and GOOD or BAD)
      if word then Say("vocab", word:sub(1, 1):upper() .. word:sub(2) .. (w.good and ". As you would say." or ". Your word, not mine."), 900) end
    end
    for sender, at in pairs(sharedAt) do if now >= at then sharedAt[sender] = nil SharedWith(sender) end end
    if wSlow < 6 then return end
    wSlow = 0
    CheckSecrets()
    CheckRequest()
    QuestStuck()
  end)
  if not ok then
    wDead = true
    O.Print("|cffff4040owl world sense turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- Deeper reads: groups forming in chat, people buying what you carry, reputation maths,
-- healing and damage per mana, debuffs you are carrying, what kind of enemy that is,
-- the mailbox, the make-up of your group, and gold by the day.
-- =====================================================================================
do
for _, m in ipairs({ { "lfg", "excited" }, { "wtb", "excited" }, { "rep", "happy" }, { "debuff", "worried" }, { "knowtype", "happy" }, { "mailbox", "happy" }, { "groupmake", "happy" } }) do
  table.insert(Owl.moods, 1, m)
end
local L = Owl.lib
local When, Sub, Count = L.When, L.Sub, L.Count
local function On() return OwlHUDDB.deep ~= false end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end
local function Faction() return Q("UnitFactionGroup", "player") == "Horde" and "H" or "A" end
local function Known(spell)
  if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
  local ok, info = pcall(C_Spell.GetSpellInfo, spell)
  return ok and type(info) == "table" and Num(Plain(info.spellID)) or nil
end

-- ---------- groups forming in chat ----------
O.defaults.lfg = true
local RUNS = { { "Ragefire Chasm", 13, 18, "H", { "rfc", "ragefire" } }, { "The Deadmines", 17, 24, "A", { "deadmines", "dm", "vc" } }, { "Wailing Caverns", 17, 24, "B", { "wc", "wailing" } },
  { "Shadowfang Keep", 22, 30, "B", { "sfk", "shadowfang" } }, { "The Stockade", 22, 30, "A", { "stocks", "stockade", "stockades" } }, { "Blackfathom Deeps", 24, 32, "B", { "bfd", "blackfathom" } },
  { "Gnomeregan", 29, 38, "B", { "gnomer", "gnomeregan" } }, { "Razorfen Kraul", 29, 38, "B", { "rfk", "kraul" } }, { "Scarlet Monastery", 34, 45, "B", { "sm", "scarlet", "cath", "armory", "library" } },
  { "Razorfen Downs", 37, 46, "B", { "rfd", "downs" } }, { "Uldaman", 41, 51, "B", { "ulda", "uldaman" } }, { "Zul'Farrak", 44, 54, "B", { "zf", "farrak" } }, { "Maraudon", 46, 55, "B", { "mara", "maraudon" } },
  { "Sunken Temple", 50, 56, "B", { "st", "sunken" } }, { "Blackrock Depths", 52, 60, "B", { "brd" } }, { "Lower Blackrock Spire", 55, 60, "B", { "lbrs" } }, { "Dire Maul", 56, 60, "B", { "dire maul", "dme", "dmw", "dmn" } },
  { "Stratholme", 58, 60, "B", { "strat", "stratholme" } }, { "Scholomance", 58, 60, "B", { "scholo", "scholomance" } } }
local FORMING = { "lfm", "lf1m", "lf2m", "lf3m", "lf4m", "lfg", "looking for more", "looking for group", "forming", "need tank", "need healer", "need heals", "need dps", "need 1", "need 2", "lf tank", "lf healer", "lf heals", "lf dps" }
local recent, lfgSaid = {}, -100
local function Forming(msg, sender)
  if not On() or OwlHUDDB.lfg == false or not OwlHUDDB.tips then return end
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" then return end
  sender = sender:gsub("%-.*$", "")
  if sender == Me() or Q("IsInInstance") then return end
  local low = " " .. msg:lower():gsub("[%p]", " "):gsub("%s+", " ") .. " "
  local forming = false
  for _, f in ipairs(FORMING) do if low:find(" " .. f .. " ", 1, true) then forming = true break end end
  if not forming then return end
  local level, run = Level(), nil
  for _, r in ipairs(RUNS) do
    if (r[4] == "B" or r[4] == Faction()) and level >= r[2] - 1 and level <= r[3] + 1 then
      for _, alias in ipairs(r[5]) do if low:find(" " .. alias .. " ", 1, true) then run = r break end end
    end
    if run then break end
  end
  if not run then return end
  local needs = {}
  if low:find(" tank ", 1, true) then needs[#needs + 1] = "a tank" end
  if low:find(" heal", 1, true) then needs[#needs + 1] = "a healer" end
  if low:find(" dps ", 1, true) then needs[#needs + 1] = "damage" end
  local entry = { who = sender, run = run[1], needs = table.concat(needs, ", "), at = Now(), clock = Clock() }
  table.insert(recent, 1, entry)
  while #recent > 8 do table.remove(recent) end
  if Now() - lfgSaid < 45 then return end
  local text = sender .. " is forming " .. run[1] .. (entry.needs ~= "" and (", needs " .. entry.needs) or "") .. ". You are in range. /owl join asks for a spot."
  if Say("lfg" .. sender, text, 180, "c") then lfgSaid = Now() end
end
O.On("CHAT_MSG_CHANNEL", Forming)
O.On("CHAT_MSG_YELL", Forming)
O.On("CHAT_MSG_SAY", Forming)
O.commands.lfg = function(arg)
  if arg == "off" or arg == "on" then OwlHUDDB.lfg = arg == "on" O.Print("listening for groups: " .. arg) return end
  if #recent == 0 then O.Print("nobody has been forming a dungeon in your range since you logged in. /owl lfg off stops me listening.") return end
  O.Print("|cffffd100Groups forming for your level|r")
  for _, e in ipairs(recent) do print("  " .. e.who .. ": " .. e.run .. (e.needs ~= "" and (" (needs " .. e.needs .. ")") or "") .. ", " .. math.floor((Now() - e.at) / 60) .. " min ago") end
  print("  /owl join whispers the newest one.")
end
O.commands.join = function()
  local e = recent[1]
  if not e or Now() - e.at > 900 then O.Print("no fresh group to ask. /owl lfg lists what I heard.") return end
  if not SendChatMessage then return end
  local ok = pcall(SendChatMessage, "Level " .. Level() .. " " .. tostring(Owl.className or "") .. " here. Room for one more in " .. e.run .. "?", "WHISPER", nil, e.who)
  O.Print(ok and ("asked " .. e.who .. " for a spot in " .. e.run .. ".") or "the game would not send that whisper.")
end

-- ---------- someone is buying what you carry ----------
local carried, carriedAt = {}, -100
local function Carried()
  if Now() - carriedAt < 60 or InCombat() then return carried end
  carriedAt = Now()
  carried = {}
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return carried end
  for bag = 0, 4 do
    for slot = 1, Num(Plain(C_Container.GetContainerNumSlots(bag))) or 0 do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      local link = ok and type(info) == "table" and Str(Plain(info.hyperlink))
      local name = link and link:match("%[(.-)%]")
      if name and #name >= 5 then
        local key = name:lower()
        carried[key] = carried[key] or { name = name, count = 0 }
        carried[key].count = carried[key].count + (Num(Plain(info.stackCount)) or 1)
      end
    end
  end
  return carried
end
O.On("CHAT_MSG_CHANNEL", function(msg, sender)
  if not On() or not OwlHUDDB.tips then return end
  msg, sender = Plain(msg), Plain(sender)
  if type(msg) ~= "string" or type(sender) ~= "string" then return end
  sender = sender:gsub("%-.*$", "")
  if sender == Me() then return end
  local low = msg:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  if not (low:find("wtb", 1, true) or low:find("buying", 1, true) or low:find("looking to buy", 1, true)) then return end
  for key, item in pairs(Carried()) do
    if low:find(key, 1, true) then
      Say("wtb" .. key, sender .. " wants to buy " .. item.name .. ". You are carrying " .. item.count .. ".", 300, "c")
      return
    end
  end
end)

-- ---------- the other side talking: the game scrambles it before it reaches us ----------
local function Foreign(msg, sender, language)
  if not On() or not OwlHUDDB.tips then return end
  msg, sender, language = Plain(msg), Plain(sender), Plain(language)
  if type(msg) ~= "string" or type(sender) ~= "string" or type(language) ~= "string" or language == "" then return end
  local mine = Q("GetDefaultLanguage", "player")
  if type(mine) ~= "string" or language == mine or language == "Common" and Faction() == "A" or language == "Orcish" and Faction() == "H" then return end
  sender = sender:gsub("%-.*$", "")
  local low = " " .. msg:lower():gsub("[%p]", " ") .. " "
  if low:find(" kek ", 1, true) or low:find(" bur ", 1, true) then
    Say("foreignlol", sender .. " is laughing. That word is how \"lol\" comes out in " .. language .. ".", 120, "c")
  else
    Say("foreign", sender .. " is speaking " .. language .. ". The game scrambles it before it reaches us, so even I cannot read it. Numbers and item links come through untouched.", 3600, "c")
  end
end
O.On("CHAT_MSG_SAY", Foreign)
O.On("CHAT_MSG_YELL", Foreign)

-- ---------- reputation maths ----------
local repSession, repTold = {}, {}
local function FactionBar(name)
  local n = Num(Call("GetNumFactions")[1])
  if n then
    for i = 1, math.min(n, 150) do
      local r = Call("GetFactionInfo", i)
      if r[1] == name then return Num(r[3]), Num(r[4]), Num(r[5]), Num(r[6]) end
    end
  elseif C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    for i = 1, math.min(Num(Plain(C_Reputation.GetNumFactions())) or 0, 150) do
      local ok, d = pcall(C_Reputation.GetFactionDataByIndex, i)
      if ok and type(d) == "table" and Plain(d.name) == name then
        return Num(Plain(d.reaction)), Num(Plain(d.currentReactionThreshold)), Num(Plain(d.nextReactionThreshold)), Num(Plain(d.currentStanding))
      end
    end
  end
end
O.On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() then return end
  local name, gain = msg:match("Reputation with (.-) increased by (%d+)")
  gain = tonumber(gain)
  if not name or not gain then return end
  repSession[name] = (repSession[name] or 0) + gain
  local standing, low, high, value = FactionBar(name)
  if not (standing and low and high and value) or high <= low or standing >= 8 then return end
  local left = high - value
  if left > 0 and left <= (high - low) * 0.1 and repTold[name] ~= standing then
    repTold[name] = standing
    Say("rep" .. name, "Only " .. left .. " reputation to " .. tostring(STANDING[standing + 1]) .. " with " .. name .. ". About " .. math.ceil(left / gain) .. " more like that.", 0)
  end
end)
O.commands.rep = function()
  if not next(repSession) then O.Print("no reputation gained this session yet.") return end
  O.Print("|cffffd100Reputation this session|r")
  for name, gain in pairs(repSession) do
    local standing, low, high, value = FactionBar(name)
    local tail = ""
    if standing and low and high and value and high > low then tail = "  (" .. tostring(STANDING[standing]) .. ", " .. (high - value) .. " to " .. tostring(STANDING[standing + 1] or "the top") .. ")" end
    print("  " .. name .. ": +" .. gain .. tail)
  end
end

-- ---------- healing and damage for your mana ----------
local function SpellMaths()
  local out = {}
  if not (C_Spell and C_Spell.GetSpellDescription) then return out end
  local names, readable = BarSpells()
  if not readable then names = BookSpells() end
  for name in pairs(names) do
    local id = Known(name)
    if id then
      local cost
      if C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, id)
        if ok and type(costs) == "table" and type(costs[1]) == "table" then cost = Num(Plain(costs[1].cost)) end
      end
      local ok, desc = pcall(C_Spell.GetSpellDescription, id)
      desc = ok and Str(Plain(desc))
      if desc and cost and cost > 0 then
        local low = desc:lower():gsub(",", "")
        local a, b = low:match("(%d+) to (%d+)")
        local amount = a and (tonumber(a) + tonumber(b)) / 2 or tonumber(low:match("for (%d+)")) or tonumber(low:match("(%d+) %a* ?damage"))
        if amount and amount > 0 then
          out[#out + 1] = { name = name, cost = cost, amount = amount, per = amount / cost, heal = low:find("heal", 1, true) ~= nil }
        end
      end
    end
  end
  table.sort(out, function(x, y) return x.per > y.per end)
  return out
end
O.commands.mana = function()
  local list = SpellMaths()
  if #list == 0 then O.Print("I could not read costs and amounts for the spells on your bars in this version of the game.") return end
  for _, heal in ipairs({ true, false }) do
    local any = false
    for _, s in ipairs(list) do
      if s.heal == heal then
        if not any then O.Print("|cffffd100" .. (heal and "Healing" or "Damage") .. " per point of mana|r") any = true end
        print(string.format("  %s: %.2f  (about %d for %d mana)", s.name, s.per, s.amount, s.cost))
      end
    end
  end
  print("  (Read from the spell tooltips: before talents, gear and crits.)")
end

-- ---------- debuffs you are carrying, and what kind of enemy that is ----------
local CURES = { PALADIN = { Poison = { "Cleanse", "Purify" }, Disease = { "Cleanse", "Purify" }, Magic = { "Cleanse" } }, PRIEST = { Magic = { "Dispel Magic" }, Disease = { "Abolish Disease", "Cure Disease" } },
  DRUID = { Poison = { "Abolish Poison", "Cure Poison" }, Curse = { "Remove Curse" } }, SHAMAN = { Poison = { "Cure Poison" }, Disease = { "Cure Disease" } }, MAGE = { Curse = { "Remove Lesser Curse" } } }
local function CheckDebuffs()
  if not (C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex) then return end
  for i = 1, 12 do
    local ok, d = pcall(C_UnitAuras.GetDebuffDataByIndex, "player", i)
    if not ok or type(d) ~= "table" then return end
    local name, kind = Str(Plain(d.name)), Str(Plain(d.dispelName))
    if name and kind and kind ~= "" then
      local cure
      for _, spell in ipairs((CURES[Owl.class] or {})[kind] or {}) do if Known(spell) then cure = spell break end end
      if cure then Say("debuff" .. name, "You are carrying " .. name .. " (" .. kind:lower() .. "). " .. cure .. " takes it off.", 600) return
      elseif Num(Plain(d.duration)) and d.duration > 45 then Say("debuff" .. name, "You are carrying " .. name .. " (" .. kind:lower() .. "). Nothing of yours removes it, so mind your health.", 900) return end
    end
  end
end
local typeSaid = {}
O.On("PLAYER_TARGET_CHANGED", function()
  if not On() or InCombat() or not Q("UnitExists", "target") or Q("UnitIsDead", "target") or Q("UnitIsPlayer", "target") or not Q("UnitCanAttack", "player", "target") then return end
  local name = Str(Plain(UnitName("target")))
  local kind = Str(Call("UnitCreatureType", "target")[1])
  if not name or typeSaid[name] then return end
  if Owl.class == "PALADIN" and (kind == "Undead" or kind == "Demon") and Known("Exorcism") then
    typeSaid[name] = true
    Say("knowtype" .. kind, kind .. ". Exorcism works on this one.", 1800)
  elseif Q("UnitPowerType", "target") == 0 and (Num(Plain(UnitPowerMax("target"))) or 0) > 0 then
    typeSaid[name] = true
    Say("knowcaster", name .. " has mana: a caster. " .. (Owl.P and Owl.P("Keep Hammer of Justice for its cast.", "Interrupt or stun its casts if you can.") or "Interrupt its casts if you can."), 1800)
  end
end)

-- ---------- the mailbox ----------
local mailAt
O.On("MAIL_INBOX_UPDATE", function() if not mailAt then mailAt = Now() + 1.5 end end)
local function ReadMail()
  local n = Num(Call("GetInboxNumItems")[1])
  if not n or n == 0 then return end
  local money, withItems, cod, soon = 0, 0, 0, nil
  for i = 1, math.min(n, 60) do
    local r = Call("GetInboxHeaderInfo", i)
    money = money + (Num(r[5]) or 0)
    if (Num(r[6]) or 0) > 0 then cod = cod + 1 end
    if (Num(r[8]) or 0) > 0 then withItems = withItems + 1 end
    local days = Num(r[7])
    if days and days < 3 and (not soon or days < soon) then soon = days end
  end
  local parts = {}
  if money > 0 then parts[#parts + 1] = O.Money(money) .. " to collect" end
  if withItems > 0 then parts[#parts + 1] = withItems .. " with items" end
  if cod > 0 then parts[#parts + 1] = cod .. " asking for payment" end
  if soon then parts[#parts + 1] = "one expires in " .. (soon < 1 and "under a day" or (math.ceil(soon) .. " days")) end
  Say("mailbox", n .. (n == 1 and " letter" or " letters") .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or "") .. ".", 300)
end

-- ---------- who is in your group ----------
local TANKS = { WARRIOR = true, PALADIN = true, DRUID = true }
local HEALERS = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }
local groupSize, groupAt = 0, nil
O.On("GROUP_ROSTER_UPDATE", function() groupAt = Now() + 6 end)
local function GroupMake()
  if Q("IsInRaid") then return end
  local list, tank, heal = {}, TANKS[Owl.class], HEALERS[Owl.class]
  for i = 1, 4 do
    local unit = "party" .. i
    if Q("UnitExists", unit) then
      local name = Str(Plain(UnitName(unit)))
      local r = Call("UnitClass", unit)
      local level = Num(Plain(UnitLevel(unit)))
      if name and Str(r[1]) then
        list[#list + 1] = name .. " (" .. (level and level > 0 and (level .. " ") or "") .. r[1] .. ")"
        if TANKS[r[2] or ""] then tank = true end
        if HEALERS[r[2] or ""] then heal = true end
      end
    end
  end
  local was = groupSize
  groupSize = #list
  if #list < 2 or #list <= was then return end
  local notes = (not heal and " Nobody here can heal." or "") .. (not tank and " No natural tank." or "")
  if #list == 4 and heal and tank then notes = " A full group, with a tank and a healer in it." end
  Say("groupmake", "Your group: " .. table.concat(list, ", ") .. "." .. notes, 120)
end

-- ---------- gold by the day ----------
local dayMoney
O.On("PLAYER_LOGIN", function() dayMoney = Num(Plain(GetMoney())) end)
O.On("PLAYER_MONEY", function()
  local money = Num(Plain(GetMoney()))
  if not money then return end
  local diff = dayMoney and (money - dayMoney) or 0
  dayMoney = money
  if diff == 0 or not On() then return end
  local days, today = Sub(Record(), "goldDays"), math.floor(Clock() / 86400)
  local d = Sub(days, today)
  if diff > 0 then d.inn = (d.inn or 0) + diff else d.out = (d.out or 0) - diff end
  for key in pairs(days) do if tonumber(key) and tonumber(key) < today - 14 then days[key] = nil end end
end)
local baseGold = O.commands.gold
O.commands.gold = function(...)
  if baseGold then baseGold(...) end
  local days, today, any = Sub(Record(), "goldDays"), math.floor(Clock() / 86400), false
  for back = 0, 6 do
    local d = days[today - back]
    if type(d) == "table" then
      if not any then print("  By day:") any = true end
      print("    " .. (back == 0 and "today" or back == 1 and "yesterday" or (back .. " days ago")) .. ": +" .. O.Money(d.inn or 0) .. "  -" .. O.Money(d.out or 0))
    end
  end
end

Owl.probe = Owl.probe or {}
Owl.probe.deeper = function()
  local maths = SpellMaths()
  return "spellMaths=" .. #maths .. (maths[1] and (" best=" .. maths[1].name) or "") .. " description=" .. tostring(C_Spell and type(C_Spell.GetSpellDescription)) .. " cost=" .. tostring(C_Spell and type(C_Spell.GetSpellPowerCost))
    .. " debuffApi=" .. tostring(C_UnitAuras and type(C_UnitAuras.GetDebuffDataByIndex)) .. " inbox=" .. type(_G.GetInboxHeaderInfo) .. " factionBar=" .. tostring((FactionBar(me.rep and me.rep[1] or "")))
end

local dAcc, dSlow, dDead = 0, 0, false
local dDriver = CreateFrame("Frame")
dDriver:SetScript("OnUpdate", function(_, e)
  if dDead then return end
  dAcc = dAcc + e
  if dAcc < 1 then return end
  dSlow = dSlow + dAcc
  dAcc = 0
  if not On() or InCombat() then return end
  local ok, err = pcall(function()
    local now = Now()
    if mailAt and now >= mailAt then mailAt = nil ReadMail() end
    if groupAt and now >= groupAt then groupAt = nil GroupMake() end
    if dSlow < 6 then return end
    dSlow = 0
    CheckDebuffs()
  end)
  if not ok then
    dDead = true
    O.Print("|cffff4040owl deeper reads turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- Forever knowledge: what changed from the old game, read up from guides (November 2026).
-- Numbers came from beta-era guides, so he says "check the tooltip" where it matters.
-- =====================================================================================
do
table.insert(Owl.moods, 1, { "master", "happy" })
table.insert(Owl.moods, 1, { "weaponfast", "worried" })
table.insert(Owl.moods, 1, { "herbcoach", "happy" })
local L = Owl.lib
local Sub = L.Sub
local function On() return OwlHUDDB.deep ~= false end
local function InCombat() return Plain(UnitAffectingCombat("player")) and true or false end

-- each tip: the words it answers to, then the tip
local TIPS = {
  { "camp camping campfire fire tent rested", "Camping: a Cooking campfire needs only skill 1 and one Simple Wood. Sit by it a minute and every camp object nearby buffs you for an hour." },
  { "camp camping tent rested xp", "A Leatherworking Camp Tent tops your rested XP up to 5% of a level. Worth a sit before a long session." },
  { "camp camping herbalism candle", "With Herbalism 20 you can place an Incense Candle at a camp: Intellect for everyone sitting there." },
  { "legacy points perks account alt", "Legacy points are shared by your whole account. Level 25 on each class is one point, so a second character to 25 is the easiest one going." },
  { "legacy points perks well rested talented", "For leveling, guides put Legacy points into Well Rested first, then Talented, then Thrill of Adventure for health and mana back after kills." },
  { "legacy points crafting profession dungeon", "Other early Legacy points: 150 skill in a crafting profession, and beating the last boss of every dungeon in a level band." },
  { "hidden items gear bis best slot", "Thousands of items have their stats hidden until someone loots them. Past level 30 or so, nobody's best-in-slot list is complete yet." },
  { "potion potions first aid healing herbs sell", "Healing potions are First Aid recipes now, so early herbs like Peacebloom and Briarthorn have more buyers than they used to." },
  { "herb herbs seeds greenhouse herbalism", "Herbs sometimes drop seeds as you pick them. They feed a Greenhouse camp object later on, so do not vendor them." },
  { "group party quest quests share shared", "In a party, kills and items for a shared quest count for everyone. Group up for the slow collection quests." },
  { "hearth hearthstone home city stormwind", "Set your hearthstone in a capital city: trainers, bank, auction house and flights all in one stop." },
  { "auction house ah sell gold prices", "The economy is young and auction prices are low. Check what a vendor pays before you list something cheap." },
  { "dual spec talents respec 40", "Dual spec unlocks at level 40. Keep one build for questing and a second for dungeons." },
  { "mount riding 40 gold cost", "Riding is 100 gold at level 40 and 1,000 at 60. Paladins and warlocks get their level 40 mount from a class quest." },
  { "vendor buyback sold mistake", "Sold something by mistake? The vendor's Buyback tab still has it." },
  { "death spirit healer die durability", "The Spirit Healer brings you back at the graveyard but damages your gear and makes you weak for a while. Run to your body when you can." },
  { "trainer rank ranks bar bars spells", "New ranks do not replace the old ones on your bars. After the trainer, drag the new rank in or you are still casting the weak one." },
  { "profession professions gathering train cap", "A gathering skill stops rising at its cap until a trainer raises it: train at 50, 125 and 200." },
  { "gloves herbalism skill enchant", "Herbalist's Gloves give +5 Herbalism from level 22. Handy for picking a herb just out of reach." },
  { "dungeon dungeons quest quests", "Pick up every dungeon quest before you go in. The rewards are often better than the boss drops." },
}
local CLASS_FACTS = {
  PALADIN = {
    { "judgement judge seal seals rotation", "Judgement no longer uses up your seal in Forever. Cast the seal once and keep judging." },
    { "lay on hands heal cooldown", "Lay on Hands is on a 20 minute cooldown here, not an hour. Use it. It still empties your mana." },
    { "blessing blessings buff might kings", "Blessings last a full hour now. One cast covers a whole session of questing." },
    { "weapon weapons two-hander slow speed seal command", "Seal of Command hits for a share of weapon damage, so slow is strong: 3.3 speed or slower. Only go faster for 15% more damage per second." },
    { "holy strike sacred arbiter judgement talent", "Sacred Arbiter makes Holy Strike hit 20% harder and refresh your Judgement on the target. Use Holy Strike between swings." },
    { "consecration aoe pack", "Consecration does full damage to the first four enemies only. Past that, it is mostly for show." },
    { "interrupt stun hammer justice caster", "You have no interrupt. Hammer of Justice is your one way to stop a cast, so save it for casters." },
    { "pursuit justice speed mount", "Pursuit of Justice speeds you up on foot and mounted. It is worth both points." },
    { "vengeance crit talent", "Vengeance stacks three times from your crits. Conviction's crit chance feeds it." },
    { "mount warhorse 40 quest tome nobility", "Your level 40 warhorse is a free quest: The Tome of Nobility, from Duthorian Rall in the Stormwind cathedral. Keep 100 gold in case riding still costs." },
    { "charger 60 mount epic", "The level 60 Charger is a long quest chain: about 350 gold in fees, materials, Dire Maul West and Scholomance." },
    { "exorcism holy wrath undead demon", "Exorcism and Holy Wrath only work on undead and demons. Duskwood is full of both." },
  },
}
local LEVEL_FACTS = {
  PALADIN = { [34] = "Divine Shield at the trainer now: the full bubble.", [40] = "Level 40 also brings Hammer of the Righteous and dual spec. A second build for dungeons?",
    [44] = "Hammer of Wrath at the trainer: a finisher for enemies at low health.", [50] = "Holy Wrath at the trainer: area damage against undead and demons." },
  ALL = { [25] = "Level 25 earns a Legacy point for your whole account. Spend it in the Legacy panel.", [40] = "Dual spec is open from 40. Riding is 100 gold unless your class has a mount quest.",
    [45] = "Level 45 is another Legacy point for the account.", [60] = "Level 60 is a third Legacy point from this class." },
}
Owl.CLASS_FACTS, Owl.LEVEL_FACTS = CLASS_FACTS, LEVEL_FACTS
local function Pool()
  local pool = {}
  for _, t in ipairs(TIPS) do pool[#pool + 1] = t end
  for _, t in ipairs(CLASS_FACTS[Owl.class] or {}) do pool[#pool + 1] = t end
  return pool
end
local told = {}
local function RandomTip()
  local pool, fresh = Pool(), {}
  for _, t in ipairs(pool) do if not told[t[2]] then fresh[#fresh + 1] = t end end
  if #fresh == 0 then told = {} fresh = pool end
  local t = fresh[math.random(#fresh)]
  told[t[2]] = true
  return t[2]
end
-- find the tip that best matches what was asked
O.OwlKnow = function(text)
  if type(text) ~= "string" then return nil end
  local low = " " .. text:lower():gsub("[%p]", " ") .. " "
  local best, bestN = nil, 0
  for _, t in ipairs(Pool()) do
    local n, words = 0, 0
    for word in t[1]:gmatch("%S+") do
      words = words + 1
      if low:find(" " .. word .. " ", 1, true) then n = n + 1 end
    end
    -- on a tie, the tip with fewer other subjects is the closer answer
    local score = n > 0 and (n + n / words * 0.5) or 0
    if score > bestN then best, bestN = t[2], score end
  end
  return best
end
O.commands.tip = function() Say("master" .. Now(), RandomTip(), 0, "c") end
O.commands.know = function(arg)
  arg = (arg or ""):gsub("^%s+", "")
  if arg == "" then O.Print("ask me about something: /owl know camping, legacy, mount, judgement, herbs, dual spec, hidden items ...") return end
  local hit = O.OwlKnow(arg)
  if not hit then O.Print("I have nothing on '" .. arg .. "'. Try camping, legacy, mount, weapon, trainer, auction, potions.") return end
  O.Print(hit)
  Say("master" .. Now(), hit, 0, "c")
end
local masterBase = O.OwlPersonal
O.OwlPersonal = function()
  if math.random(4) == 1 then return RandomTip() end
  return masterBase()
end
O.On("PLAYER_LEVEL_UP", function(newLevel)
  local level = Num(Plain(newLevel)) or (Level() + 1)
  local mine, all = (LEVEL_FACTS[Owl.class] or {})[level], LEVEL_FACTS.ALL[level]
  if mine then Say("masterlevel", mine, 0) end
  if all and not (mine and Owl.class == "PALADIN" and level == 40) then Say("masterall", all, 0) end
end)

-- ---------- a fast weapon under Seal of Command ----------
local weaponSaid, weaponAt = {}, nil
O.On("PLAYER_EQUIPMENT_CHANGED", function() weaponAt = Now() + 4 end)
O.On("PLAYER_LOGIN", function() weaponAt = Now() + 70 end)
local function CheckWeapon()
  if Owl.class ~= "PALADIN" or Level() < 22 then return end
  local w = me.gear and me.gear[16]
  local speed = Num(Call("UnitAttackSpeed", "player")[1])
  if not w or not w.name or not speed or weaponSaid[w.name] then return end
  if speed > 0 and speed < 3.0 then
    weaponSaid[w.name] = true
    Say("weaponfast", w.name .. " swings every " .. string.format("%.1f", speed) .. " seconds. Seal of Command wants 3.3 or slower: a slow two-hander hits much harder.", 0)
  end
end

-- ---------- herbalism, by the herb: what you can pick here, and what comes next ----------
local ZONE_HERBS = {
  ["Elwynn Forest"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } }, ["Dun Morogh"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } },
  ["Teldrassil"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } }, ["Durotar"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } },
  ["Mulgore"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } }, ["Tirisfal Glades"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 } },
  ["Westfall"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 } },
  ["Loch Modan"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 } },
  ["Darkshore"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 }, { "Stranglekelp", 85 } },
  ["The Barrens"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 }, { "Stranglekelp", 85 } },
  ["Silverpine Forest"] = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 } },
  ["Redridge Mountains"] = { { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 }, { "Bruiseweed", 100 } },
  ["Duskwood"] = { { "Briarthorn", 70 }, { "Grave Moss", 120 }, { "Kingsblood", 125 } },
  ["Wetlands"] = { { "Stranglekelp", 85 }, { "Bruiseweed", 100 }, { "Kingsblood", 125 }, { "Liferoot", 150 } },
  ["Hillsbrad Foothills"] = { { "Briarthorn", 70 }, { "Stranglekelp", 85 }, { "Bruiseweed", 100 }, { "Kingsblood", 125 }, { "Liferoot", 150 } },
  ["Arathi Highlands"] = { { "Wild Steelbloom", 115 }, { "Kingsblood", 125 }, { "Fadeleaf", 160 }, { "Goldthorn", 170 } },
  ["Stranglethorn Vale"] = { { "Wild Steelbloom", 115 }, { "Kingsblood", 125 }, { "Liferoot", 150 }, { "Fadeleaf", 160 }, { "Goldthorn", 170 }, { "Khadgar's Whisker", 185 } },
}
local EASY = { A = "Elwynn Forest or Westfall", H = "Durotar or the Barrens" }
O.OwlHerbCoach = function()
  local have = type(OwlHUDDB.skills) == "table" and Num(OwlHUDDB.skills.Herbalism)
  for _, p in ipairs(me.profs or {}) do if p[1] == "Herbalism" and Num(p[2]) then have = p[2] end end
  local zone = Zone()
  local herbs = ZONE_HERBS[zone]
  if not have or not herbs then return false end
  local can, nextUp = {}, nil
  for _, h in ipairs(herbs) do
    if h[2] <= have then can[#can + 1] = h[1] elseif not nextUp then nextUp = h end
  end
  if #can == 0 then
    local side = Q("UnitFactionGroup", "player") == "Horde" and "H" or "A"
    Say("herbcoach" .. zone, "Nothing here for Herbalism " .. have .. ": the easiest herb in " .. zone .. ", " .. herbs[1][1] .. ", needs " .. herbs[1][2] .. ". Peacebloom and Silverleaf in " .. EASY[side] .. " will catch you up fast.", 3600)
  elseif nextUp then
    Say("herbcoach" .. zone, "With Herbalism " .. have .. " you can pick " .. table.concat(can, ", ", math.max(1, #can - 1)) .. " here. " .. nextUp[1] .. " needs " .. nextUp[2] .. ".", 3600)
  end
  return true
end
O.On("CHAT_MSG_SKILL", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local skill, value = msg:match("skill in (.-) has increased to (%d+)")
  value = tonumber(value)
  if not skill or not value then return end
  if (skill == "Herbalism" or skill == "Mining" or skill == "Skinning") and (value == 50 or value == 125 or value == 200) then
    Say("mastertrain" .. skill .. value, skill .. " " .. value .. ": a trainer can teach the next rank now. It stops rising at " .. (value + 25) .. " until you do.", 0)
  end
end)

local mAcc, mDead = 0, false
local mDriver = CreateFrame("Frame")
mDriver:SetScript("OnUpdate", function(_, e)
  if mDead then return end
  mAcc = mAcc + e
  if mAcc < 1 then return end
  mAcc = 0
  if not On() or InCombat() then return end
  local ok, err = pcall(function()
    if weaponAt and Now() >= weaponAt and me.gathered then weaponAt = nil CheckWeapon() end
  end)
  if not ok then
    mDead = true
    O.Print("|cffff4040owl Forever knowledge turned off:|r " .. tostring(err))
  end
end)
end

-- =====================================================================================
-- Character: a temperament that changes by the day, little asides before and after his
-- lines, no repeating himself, and a store of things only this owl would say.
-- =====================================================================================
do
O.defaults.flavor = true
local TEMPERS = { "cheerful", "plain", "grumpy", "dramatic", "plain", "thoughtful", "hungry", "smug" }
local function Temper()
  if OwlHUDDB.temperLock then return OwlHUDDB.temperLock end
  if OwlHUDDB.temper and OwlHUDDB.temperDay == math.floor(Clock() / 86400) then return OwlHUDDB.temper end
  local day = math.floor(Clock() / 86400)
  OwlHUDDB.temperDay, OwlHUDDB.temper = day, TEMPERS[(day * 7 + #Me()) % #TEMPERS + 1]
  return OwlHUDDB.temper
end
-- asides by the feeling of the line, then by today's temperament
local BEFORE = {
  worried = { "Careful.", "Hm.", "Heads up.", "Uh oh." },
  happy = { "Oh!", "Good news.", "Well now.", "Look at that." },
  excited = { "Ha!", "Yes!", "Hoo hoo!" },
  sleepy = { "Mm.", "Yawn.", "Where was I. Ah." },
  plain = { "For the record:", "By the way.", "Ahem." },
}
local AFTER = {
  worried = { "I will keep watch.", "Just saying.", "Eyes open." },
  happy = { "Hoo.", "I approve.", "As it should be." },
  excited = { "Magnificent.", "I knew it.", "Hoo!" },
  sleepy = { "Wake me if it matters." },
  plain = { "Hoo.", "I notice these things.", "That is all." },
}
local BY_TEMPER = {
  cheerful = { before = { "Oh, good!", "Lovely!" }, after = { "What a day.", "Hoo!" } },
  grumpy = { before = { "Ugh.", "Fine.", "If I must." }, after = { "Hmph.", "Typical." } },
  dramatic = { before = { "Behold!", "Mark my words!", "Alas," }, after = { "As foretold.", "So it is written." } },
  thoughtful = { before = { "Consider this.", "It occurs to me." }, after = { "Worth a thought." } },
  hungry = { before = { "Between snacks:" }, after = { "I could eat.", "Now, lunch." } },
  smug = { before = { "As I predicted.", "Naturally." }, after = { "I am rarely wrong.", "Thank me later." } },
}
local SKIP = { "ask", "reply", "pat", "trick", "secret", "request", "granted", "holiday", "bond", "letter", "pull", "plan", "review", "whisper", "word", "named", "master", "story", "week", "emote", "dream", "adds",
  "roll", "lfg", "wtb", "foreign", "vocab", "remind", "gear", "character" }
local recent, lastAside = {}, nil
local function Feeling(key)
  for i = 1, #Owl.moods do
    local m = Owl.moods[i]
    if key:sub(1, #m[1]) == m[1] then return m[2] end
  end
  return "plain"
end
local function PickFresh(list)
  local fresh = {}
  -- first choice: something he has not said in a long while, across sessions; then anything not said lately
  local unheard = {}
  for _, text in ipairs(list) do
    if not recent[text] then
      fresh[#fresh + 1] = text
      if Owl.SaidBefore and not Owl.SaidBefore(text) then unheard[#unheard + 1] = text end
    end
  end
  if #unheard > 0 then fresh = unheard end
  local pool = #fresh > 0 and fresh or list
  return pool[math.random(#pool)]
end
O.OwlFlavor = function(key, lines, flags)
  -- several ways to say it: take one he has not used lately
  local text = lines
  if type(lines) == "table" then
    if #lines == 0 then return lines end
    text = PickFresh(lines)
  end
  if type(text) ~= "string" or OwlHUDDB.flavor == false then return text end
  if flags and flags:find("u", 1, true) then return text end
  -- short lines only, so his bubble never grows for the sake of an aside; and on a plain day, none at all
  if #text > 64 or text:find("^%l") or Temper() == "plain" then return text end
  for _, skip in ipairs(SKIP) do if key:sub(1, #skip) == skip then return text end end
  local roll = math.random(100)
  if roll > 22 then return text end
  local feeling, temper = Feeling(key), BY_TEMPER[Temper()] or BY_TEMPER.cheerful
  local before = roll <= 14
  local pool = {}
  for _, a in ipairs((before and BEFORE or AFTER)[feeling] or (before and BEFORE or AFTER).plain) do pool[#pool + 1] = a end
  -- today's temperament colours about half of them (never a cheerful aside on bad news)
  if math.random(2) == 1 and not (feeling == "worried" and (Temper() == "cheerful" or Temper() == "smug")) then
    pool = {}
    for _, a in ipairs(before and temper.before or temper.after) do pool[#pool + 1] = a end
  end
  local aside = pool[math.random(#pool)]
  if aside == lastAside then return text end
  lastAside = aside
  if before then
    if aside:sub(-1) == "," then return aside .. " " .. text:sub(1, 1):lower() .. text:sub(2) end
    return aside .. " " .. text
  end
  return text .. " " .. aside
end
local order = {}
O.OwlSaid = function(text)
  if type(text) ~= "string" then return end
  recent[text] = true
  order[#order + 1] = text
  if #order > 40 then recent[table.remove(order, 1)] = nil end
end
O.commands.mood = function(arg)
  arg = (arg or ""):gsub("%s", "")
  if arg == "auto" then OwlHUDDB.temperLock = nil O.Print(Name() .. "'s temper changes with the day again.") return end
  for _, name in ipairs(TEMPERS) do
    if arg == name then OwlHUDDB.temperLock = name O.Print(Name() .. " will stay " .. name .. ". /owl mood auto lets it change by the day again.") return end
  end
  local words = { plain = "plain. Just the facts today, no asides", cheerful = "cheerful. Everything is wonderful and he will tell you so", grumpy = "grumpy. He will help, but he will sigh about it", dramatic = "dramatic. Everything is a prophecy today",
    thoughtful = "thoughtful. Expect observations", hungry = "hungry. It will come up", smug = "smug. He was right about something and has not let it go" }
  O.Print(Name() .. " is " .. (words[Temper()] or Temper()) .. "." .. (OwlHUDDB.temperLock and " (You set this.)" or " It changes with the day."))
  print("  Set one yourself: /owl mood plain, cheerful, grumpy, dramatic, thoughtful, hungry or smug. /owl mood auto goes back to a new one each day.")
end
O.commands.flavor = function()
  OwlHUDDB.flavor = OwlHUDDB.flavor == false
  O.Print("his asides and temperament" .. (OwlHUDDB.flavor and ": |cff40ff40on|r" or ": |cffff4040off|r (plain lines only)"))
end

-- ---------- things only this owl would say ----------
local CHARACTER = {
  "I preened for an hour this morning. You are welcome.", "Do I look bigger today? I feel bigger.", "A hawk looked at me earlier. I looked back. It left.",
  "Parrots repeat things. I originate them. There is a difference.", "I have never trusted a chicken. They know too much and say too little.",
  "I once stared down a murloc. It blinked first. They have no eyelids, so it was a long night.", "If a gnome offers you a device, say no. I speak from experience.",
  "I am not afraid of the dark. The dark is afraid of me. We have an understanding.", "My left wing is my good side. Remember that for screenshots.",
  "I counted the stars last night. I will not tell you the number. It is mine.", "Somewhere there is a mouse with my name on it. Not literally. Mice cannot write.",
  "People say owls are wise. People are correct.", "I can turn my head most of the way round. I mostly use it to judge things.",
  "You walk very loudly, you know. Every mouse for a mile has gone to ground.", "If you ever need a second opinion, mine is the first one. Ask for a third.",
  "I do not sleep. I rest my eyes with great intensity.", "I have decided we are the heroes of this story. I have not checked with anyone.",
  "There is a feather out of place and it is all I can think about.", "I had a cousin who delivered letters. Terrible job. No dental.",
  "Do you ever wonder what the fish think? No? Only me, then.", "I would have been a great general. I see everything and I do not blink.",
  "I told a joke to a kodo once. It is still thinking about it.", "I am fairly sure that tree back there was watching us.",
  "Every inn smells of stew. I am not complaining. I am noting.", "You fight. I supervise. It is a good system.",
  "If I had hands I would applaud. Imagine a small, dignified applause.", "A bat is just a mouse with ambition. I respect that. I would still eat it.",
  "I have been composing a poem about us. It rhymes hoo with you. It is not finished.", "The moon and I go way back.",
  "Never play cards with a goblin. I do not have pockets and I still lost.", "I keep a list of everyone who has been rude to me. It is mostly geese.",
  "Dwarves sing too loudly, elves sing too long. Owls sing exactly right.", "I like it when you say my name. Do it more.",
  "That cloud looks like a mouse. That one also looks like a mouse. I may be hungry.", "I have opinions about your boots but I am keeping them to myself. For now.",
  "One day they will build a statue of you. I will be on the shoulder. Insist on it.",
}
local charBase, charSaid = O.OwlPersonal, {}
O.OwlPersonal = function()
  if OwlHUDDB.flavor ~= false and Temper() ~= "plain" and math.random(4) == 1 then
    local fresh = {}
    for _, text in ipairs(CHARACTER) do if not charSaid[text] then fresh[#fresh + 1] = text end end
    if #fresh == 0 then charSaid = {} fresh = CHARACTER end
    local text = fresh[math.random(#fresh)]
    charSaid[text] = true
    return text
  end
  return charBase()
end
end

-- =====================================================================================
-- Flight paths: he learns which ones you have each time you open a flight map, and
-- reminds you when you are in a zone whose flight master you have not met.
-- =====================================================================================
do
table.insert(Owl.moods, 1, { "flightmiss", "worried" })
local L = Owl.lib
local Sub, SubZone = L.Sub, L.SubZone
local TOWNS = {
  A = { ["Elwynn Forest"] = "Stormwind", ["Stormwind City"] = "Stormwind", ["Dun Morogh"] = "Ironforge", ["Ironforge"] = "Ironforge", ["Westfall"] = "Sentinel Hill", ["Redridge Mountains"] = "Lakeshire",
    ["Duskwood"] = "Darkshire", ["Loch Modan"] = "Thelsamar", ["Wetlands"] = "Menethil Harbor", ["Hillsbrad Foothills"] = "Southshore", ["Arathi Highlands"] = "Refuge Pointe",
    ["Stranglethorn Vale"] = "Booty Bay", ["Blasted Lands"] = "Nethergarde Keep", ["The Hinterlands"] = "Aerie Peak", ["Burning Steppes"] = "Morgan's Vigil", ["Searing Gorge"] = "Thorium Point",
    ["Western Plaguelands"] = "Chillwind Camp", ["Eastern Plaguelands"] = "Light's Hope Chapel", ["Darkshore"] = "Auberdine", ["Ashenvale"] = "Astranaar", ["Stonetalon Mountains"] = "Stonetalon Peak",
    ["Desolace"] = "Nijel's Point", ["Dustwallow Marsh"] = "Theramore", ["The Barrens"] = "Ratchet", ["Feralas"] = "Feathermoon", ["Tanaris"] = "Gadgetzan", ["Un'Goro Crater"] = "Marshal's Refuge",
    ["Felwood"] = "Talonbranch Glade", ["Winterspring"] = "Everlook", ["Silithus"] = "Cenarion Hold", ["Azshara"] = "Talrendis Point", ["Teldrassil"] = "Rut'theran Village" },
  H = { ["Durotar"] = "Orgrimmar", ["Orgrimmar"] = "Orgrimmar", ["Mulgore"] = "Thunder Bluff", ["Thunder Bluff"] = "Thunder Bluff", ["Tirisfal Glades"] = "Undercity", ["Undercity"] = "Undercity",
    ["The Barrens"] = "Crossroads", ["Stonetalon Mountains"] = "Sun Rock Retreat", ["Ashenvale"] = "Splintertree Post", ["Thousand Needles"] = "Freewind Post", ["Dustwallow Marsh"] = "Brackenwall Village",
    ["Desolace"] = "Shadowprey Village", ["Feralas"] = "Camp Mojache", ["Tanaris"] = "Gadgetzan", ["Hillsbrad Foothills"] = "Tarren Mill", ["Arathi Highlands"] = "Hammerfall", ["Badlands"] = "Kargath",
    ["Stranglethorn Vale"] = "Grom'gol", ["Swamp of Sorrows"] = "Stonard", ["Burning Steppes"] = "Flame Crest", ["Searing Gorge"] = "Thorium Point", ["The Hinterlands"] = "Revantusk Village",
    ["Silverpine Forest"] = "The Sepulcher", ["Felwood"] = "Bloodvenom Post", ["Winterspring"] = "Everlook", ["Azshara"] = "Valormok", ["Silithus"] = "Cenarion Hold",
    ["Eastern Plaguelands"] = "Light's Hope Chapel", ["Un'Goro Crater"] = "Marshal's Refuge" },
}
local function Side() return Q("UnitFactionGroup", "player") == "Horde" and "H" or "A" end
local function Have(town)
  local known = Sub(Record(), "flightKnown")
  for name in pairs(known) do if name:find(town, 1, true) then return true end end
  return false
end
O.On("TAXIMAP_OPENED", function()
  local known, read = Sub(Record(), "flightKnown"), 0
  for i = 1, math.min(Num(Call("NumTaxiNodes")[1]) or 0, 150) do
    local name = Str(Call("TaxiNodeName", i)[1])
    if name then known[name] = true read = read + 1 end
  end
  -- the newer way the game lists them, where unreachable ones are the paths you have not found
  if read == 0 and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_Map and C_Map.GetBestMapForUnit then
    local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, Plain(C_Map.GetBestMapForUnit("player")))
    local blocked = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable
    if ok and type(nodes) == "table" then
      for _, node in ipairs(nodes) do
        local name = type(node) == "table" and Str(Plain(node.name))
        if name and (blocked == nil or Plain(node.state) ~= blocked) then known[name] = true read = read + 1 end
      end
    end
  end
  -- only trust the list once it has something in it
  if read > 0 then Record().flightSeen = true end
end)
O.On("UI_INFO_MESSAGE", function(a, b)
  local msg = Plain(b)
  if type(msg) ~= "string" then msg = Plain(a) end
  if type(msg) == "string" and msg:lower():find("flight path", 1, true) then
    local town = TOWNS[Side()][Zone()]
    if town then Sub(Record(), "flightKnown")[town] = true end
  end
end)
local flightAt
local function CheckFlight()
  local rec = Record()
  if OwlHUDDB.deep == false or not rec.flightSeen or Q("IsInInstance") or Q("UnitOnTaxi", "player") then return end
  local zone = Zone()
  local town = TOWNS[Side()][zone]
  if not town or Have(town) then return end
  local place = SubZone() or ""
  if place:find(town, 1, true) then
    Say("flightmiss" .. zone, "The flight master is right here in " .. town .. " and you have not met them. Go and say hello.", 600)
  else
    Say("flightmiss" .. zone, "You do not have the flight path for " .. zone .. " yet. It is in " .. town .. ". Pick it up while we are here.", 2700)
  end
end
O.On("ZONE_CHANGED_NEW_AREA", function() flightAt = Now() + 20 end)
O.On("ZONE_CHANGED", function() if not flightAt then flightAt = Now() + 6 end end)
O.commands.flights = function()
  local rec = Record()
  if not rec.flightSeen then O.Print("open a flight map once and I will know which paths you have.") return end
  local missing = {}
  for zone, town in pairs(TOWNS[Side()]) do if not Have(town) and not missing[town] then missing[town] = zone end end
  local list = {}
  for town, zone in pairs(missing) do list[#list + 1] = town .. " (" .. zone .. ")" end
  table.sort(list)
  if #list == 0 then O.Print("you have every flight path I know of.") return end
  O.Print("|cffffd100Flight paths you do not have yet|r")
  for _, line in ipairs(list) do print("  " .. line) end
end
local fAcc = 0
local fDriver = CreateFrame("Frame")
fDriver:SetScript("OnUpdate", function(_, e)
  fAcc = fAcc + e
  if fAcc < 1 then return end
  fAcc = 0
  if flightAt and Now() >= flightAt and not Plain(UnitAffectingCombat("player")) then
    flightAt = nil
    O.Try("owl flight paths", CheckFlight)
  end
end)
end

-- =====================================================================================
-- The options window (click the owl), notes for later, and a report of what works
-- =====================================================================================
do
local OPTIONS = {
  { head = "The owl" },
  { "He talks", "tips", function() return OwlHUDDB.tips end },
  { "How much he says", "chatty", function() return OwlHUDDB.chatty or "normal" end },
  { "His voice", "voice", function() return OwlHUDDB.voice or "cheerful" end },
  { "Sits on screen", "perch", function() return OwlHUDDB.perch end },
  { "Hats", "hats", function() return OwlHUDDB.hats end },
  { "Glow and movement", "fancy", function() return OwlHUDDB.fancy end },
  { "Talks with friends' owls", "social", function() return OwlHUDDB.social ~= false end },
  { "Extra wordings and small talk", "variety", function() return OwlHUDDB.variety ~= false end },
  { "Talks about places in flight", "flytalk", function() return OwlHUDDB.flytalk ~= false end },
  { "Owls trade notes", "notestoggle", function() return OwlHUDDB.notes ~= false end },
  { "Their owls when not grouped", "farowls", function() return OwlHUDDB.farOwls ~= false end },
  { "Friends' owls beside him", "friendowl", function() return OwlHUDDB.friendOwls ~= false end },
  { "Talks about his goals", "goalstoggle", function() return OwlHUDDB.goals ~= false end },
  { "Things he wears", "outfit", function() return OwlHUDDB.outfit ~= false end },
  { "Speech bubble", "bubble", function() return OwlHUDDB.bubble or "parchment" end },
  { "Smaller text", "text", function() return OwlHUDDB.textSize or 16 end, textStep = -1 },
  { "Bigger text", "text", function() return OwlHUDDB.textSize or 16 end, textStep = 1 },
  { "Smaller owl", "size", function() return (OwlHUDDB.owlSize or 160) .. "%" end, step = -20 },
  { "Bigger owl", "size", function() return (OwlHUDDB.owlSize or 160) .. "%" end, step = 20 },
  { head = "What he tells you" },
  { "Gear advice (BiS addon)", "bis", function() return OwlHUDDB.bis end },
  { "Memory of fights, quests, gold", "deep", function() return OwlHUDDB.deep ~= false end },
  { "Enemy player lookout", "sense", function() return OwlHUDDB.sense end },
  { "Whisper reply buttons", "replies", function() return OwlHUDDB.replies ~= false end },
  { "Asides and varied wording", "flavor", function() return OwlHUDDB.flavor ~= false end },
  { "His temper", "tempercycle", function() return OwlHUDDB.temperLock or "by the day" end },
  { "Notices things about you", "uncanny", function() return OwlHUDDB.uncanny ~= false end },
  { "His notes on tooltips", "tipnotes", function() return OwlHUDDB.tipnotes ~= false end },
  { "Quest progress call-outs", "questhelp", function() return OwlHUDDB.questhelp ~= false end },
  { "Listens for groups forming", "lfgtoggle", function() return OwlHUDDB.lfg ~= false end },
  { "Sounds", "sound", function() return OwlHUDDB.sound end },
  { head = "Your screen" },
  { "Hearts and classic look", "classic", function() return OwlHUDDB.classic end },
  { "Side bars", "sides", function() return OwlHUDDB.sides end },
  { "Paladin cues", "cues", function() return OwlHUDDB.cues end },
  { "Ability ready ding", "ding", function() return OwlHUDDB.ding end },
  { "Quest marker on target", "questmark", function() return OwlHUDDB.questMark end },
  { "Gathering marker", "gather", function() return OwlHUDDB.gatherMark end },
  { "The game's own self bar", "selfbar", function() return OwlHUDDB.selfBar or "leave" end },
  { head = "Done for you" },
  { "Sell junk at vendors", "sell", function() return OwlHUDDB.sell end },
  { "Repair at vendors", "repair", function() return OwlHUDDB.repair end },
  { "Fast looting", "loot", function() return OwlHUDDB.loot end },
}
local ACTIONS = { { "Wardrobe", "wardrobe" }, { "His goals", "goals" }, { "Rare lanterns", "lanterns" }, { "Rare torches", "torches" }, { "Owl friends", "pals" }, { "Party board", "party" }, { "Ready check, all", "readyall" }, { "Hoot-off", "hootoff" },
  { "Send a gift", "gift" }, { "Dance", "dance" }, { "High five", "five" }, { "Where is everyone", "where" }, { "About this owl", "quirks" }, { "Owl notes", "notes" }, { "Owl post", "post" }, { "Ask him something", "ask" }, { "Journal", "journal" }, { "My character", "me" }, { "The plan", "plan" }, { "Session stats", "stats" }, { "My pace", "pace" },
  { "Quest log", "quests" }, { "Gold in and out", "gold" }, { "Collection", "collection" }, { "Records", "records" }, { "Our bond", "bond" }, { "Rivals", "rival" },
  { "Pat him", "pat" }, { "Size up target", "pull" }, { "Quest route", "route" }, { "Still to do", "needs" }, { "Bag value", "worth" }, { "Gear hunt", "hunt" }, { "Yearbook", "yearbook" },
  { "My characters", "family" }, { "A Forever tip", "tip" }, { "Missing flights", "flights" }, { "Groups forming", "lfg" }, { "Reputation", "rep" }, { "Spell value", "mana" }, { "Move things", "unlock" }, { "All commands", "owl" }, { "Report for Claude", "report" } }

-- these answer with a list in the chat window, which is easy to miss
local IN_CHAT, chatHintSaid = {}, false
for _, name in ipairs({ "goals", "pals", "party", "notes", "quirks", "where", "post", "journal", "me", "plan", "stats", "pace", "quests", "gold", "collection", "records", "bond", "rival", "route",
  "needs", "worth", "hunt", "yearbook", "family", "flights", "lfg", "rep", "mana", "owl" }) do IN_CHAT[name] = true end
local W, ROW, COLW = 560, 24, 268
local panel = CreateFrame("Frame", "OwlHUDOptions", UIParent)
panel:SetSize(W, 100)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
panel:SetFrameStrata("DIALOG")
panel:EnableMouse(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(f) f:StartMoving() end)
panel:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
panel.bg = panel:CreateTexture(nil, "BACKGROUND")
panel.bg:SetAllPoints()
panel.bg:SetColorTexture(0.06, 0.05, 0.03, 0.96)
for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
  local line = panel:CreateTexture(nil, "BORDER")
  line:SetColorTexture(0.89, 0.7, 0.29, 0.95)
  if side == "TOP" or side == "BOTTOM" then
    line:SetPoint(side .. "LEFT", panel, side .. "LEFT", 0, 0) line:SetPoint(side .. "RIGHT", panel, side .. "RIGHT", 0, 0) line:SetHeight(2)
  else
    line:SetPoint("TOP" .. side, panel, "TOP" .. side, 0, 0) line:SetPoint("BOTTOM" .. side, panel, "BOTTOM" .. side, 0, 0) line:SetWidth(2)
  end
end
panel.owl = panel:CreateTexture(nil, "ARTWORK")
panel.owl:SetSize(44, 44)
panel.owl:SetPoint("TOPLEFT", 8, -4)
panel.owl:SetTexture(MEDIA .. "owl.tga")
panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panel.title:SetPoint("TOPLEFT", 54, -12)
panel.sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.sub:SetPoint("TOPLEFT", 55, -31)
panel:Hide()
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OwlHUDOptions") end   -- Escape closes it

local function MakeButton(width)
  local b = CreateFrame("Button", nil, panel)
  b:SetSize(width, ROW - 3)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("LEFT", 8, 0)
  b.value = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.value:SetPoint("RIGHT", -8, 0)
  b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.34, 0.25, 0.08, 0.98) end)
  b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95) end)
  return b
end

local rows = {}
local function Refresh()
  panel.title:SetText(Name() .. "'s options")
  panel.sub:SetText("Click a line to change it. Escape closes this. Right-click the owl to hush him.")
  for _, row in ipairs(rows) do
    local ok, v = pcall(row.opt[3])
    if not ok then v = nil end
    if type(v) == "boolean" or v == nil then
      row.value:SetText(v and "|cff40ff40On|r" or "|cff909090Off|r")
    else
      v = tostring(v)
      row.value:SetText("|cffffd100" .. v:sub(1, 1):upper() .. v:sub(2) .. "|r")
    end
  end
end

local y, col = -54, 0
for _, opt in ipairs(OPTIONS) do
  if opt.head then
    if col == 1 then y, col = y - ROW, 0 end
    local h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 12, y - 4)
    h:SetText(opt.head)
    y = y - ROW
  else
    local b = MakeButton(COLW)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + col * (COLW + 4), y)
    b.label:SetText(opt[1])
    b.opt = opt
    b:SetScript("OnClick", function()
      local fn = O.commands[opt[2]]
      if type(fn) == "function" then
        if opt.textStep then O.Try("owl option text", fn, tostring(math.max(10, math.min(26, (tonumber(OwlHUDDB.textSize) or 16) + opt.textStep))))
        elseif opt.step then O.Try("owl option " .. opt[2], fn, tostring(math.max(50, math.min(300, (tonumber(OwlHUDDB.owlSize) or 160) + opt.step))))
        else O.Try("owl option " .. opt[2], fn, "") end
      end
      Refresh()
    end)
    rows[#rows + 1] = b
    if col == 1 then y, col = y - ROW, 0 else col = 1 end
  end
end
if col == 1 then y = y - ROW end
local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
head:SetPoint("TOPLEFT", 12, y - 4)
head:SetText("Ask him for")
y = y - ROW
local AW = 133
for i, act in ipairs(ACTIONS) do
  local b = MakeButton(AW)
  b:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + ((i - 1) % 4) * (AW + 3), y - math.floor((i - 1) / 4) * ROW)
  b.label:SetText(act[1])
  b:SetScript("OnClick", function()
    local fn = O.commands[act[2]]
    if act[2] == "unlock" and O.unlocked then fn = O.commands.lock end
    if act[2] ~= "pat" and act[2] ~= "report" then panel:Hide() end
    if IN_CHAT[act[2]] and not chatHintSaid then
      chatHintSaid = true
      Say("inchat", "When you ask me for a list, I write it in your chat window. Look there.", 0, "c")
    end
    if type(fn) == "function" then O.Try("owl " .. act[2], fn, "") end
  end)
end
y = y - math.ceil(#ACTIONS / 4) * ROW
local close = MakeButton(70)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
close.label:SetText("Close")
close:SetScript("OnClick", function() panel:Hide() end)
panel:SetHeight(-y + 12)

O.commands.tempercycle = function()
  local order = { "plain", "cheerful", "grumpy", "dramatic", "thoughtful", "hungry", "smug" }
  local now = OwlHUDDB.temperLock
  if not now then O.commands.mood(order[1]) return end
  for i, name in ipairs(order) do if name == now then if order[i + 1] then O.commands.mood(order[i + 1]) else O.commands.mood("auto") end return end end
  O.commands.mood("auto")
end
O.commands.goalstoggle = function() O.commands.goals(OwlHUDDB.goals == false and "on" or "off") end
O.commands.notestoggle = function() O.commands.notes(OwlHUDDB.notes == false and "on" or "off") end
O.commands.lfgtoggle = function() O.commands.lfg(OwlHUDDB.lfg == false and "on" or "off") end
O.OwlOptions = function()
  if panel:IsShown() then panel:Hide() return end
  Refresh()
  panel:Show()
end
O.commands.options = function() O.OwlOptions() end
O.commands.menu = O.commands.options

-- ---------- notes to pass on: /owl note the bubble covers my bars ----------
O.commands.note = function(arg)
  arg = (arg or ""):gsub("^%s+", "")
  if type(OwlHUDDB.notes) ~= "table" then OwlHUDDB.notes = {} end
  if arg == "" then
    if #OwlHUDDB.notes == 0 then O.Print("no notes yet. Write one like: /owl note the owl is too big in dungeons") return end
    O.Print("|cffffd100Your notes|r (saved for Claude to read)")
    for i, n in ipairs(OwlHUDDB.notes) do print("  " .. i .. ". " .. tostring(n.text)) end
    return
  end
  if arg == "clear" then OwlHUDDB.notes = {} O.Print("notes cleared.") return end
  local notes = OwlHUDDB.notes
  notes[#notes + 1] = { text = arg:sub(1, 200), at = Clock(), zone = Zone(), level = Level() }
  while #notes > 40 do table.remove(notes, 1) end
  O.Print("noted. (" .. #notes .. " saved)")
end

-- ---------- a log of anything that switched itself off ----------
local basePrint = O.Print
O.Print = function(msg)
  if type(msg) == "string" and (msg:find("turned off", 1, true) or msg:find("problem:", 1, true)) then
    if type(OwlHUDDB) == "table" then
      if type(OwlHUDDB.errlog) ~= "table" then OwlHUDDB.errlog = {} end
      local log = OwlHUDDB.errlog
      log[#log + 1] = (msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")):sub(1, 300)
      while #log > 30 do table.remove(log, 1) end
    end
  end
  return basePrint(msg)
end

-- ---------- the report: what the game let him read, saved where Claude can look ----------
local API = { "UnitStat", "UnitArmor", "GetInventoryItemLink", "GetBindLocation", "GetGuildInfo", "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetNumTalentTabs", "GetTalentTabInfo",
  "GetNumFactions", "GetFactionInfo", "GetQuestGreenRange", "UnitQuestTrivialLevelRange", "GetNumQuestLogEntries", "GetQuestLogTitle", "GetSubZoneText", "IsInInstance", "GetInstanceInfo",
  "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "IsTradeskillTrainer", "GetMerchantNumItems", "GetMerchantItemLink", "TakeTaxiNode",
  "TaxiNodeName", "NumTaxiNodes", "UnitOnTaxi", "IsMounted", "GetLootRollItemLink", "GetNumGuildMembers", "GetGuildRosterInfo", "UnitCreatureType", "UnitGroupRolesAssigned", "GetItemCooldown",
  "GetItemCount", "GetNumQuestChoices", "GetQuestItemLink", "GetActionInfo", "GetMacroSpell", "UnitPowerType", "GetXPExhaustion", "GetPVPLifetimeStats", "hooksecurefunc", "issecretvalue" }
local TABLES = { C_SpellBook = { "GetNumSpellBookSkillLines", "GetSpellBookSkillLineInfo", "GetSpellBookItemInfo" }, C_Spell = { "GetSpellInfo", "GetSpellCooldown", "GetSpellName" },
  C_Item = { "GetItemInfo", "GetItemInfoInstant", "GetDetailedItemLevelInfo", "GetItemCount" }, C_Container = { "GetContainerNumSlots", "GetContainerItemInfo", "GetContainerItemLink", "GetItemCooldown" },
  C_QuestLog = { "GetNumQuestLogEntries", "GetInfo", "IsComplete", "ReadyForTurnIn", "GetMaxNumQuestsCanAccept" }, C_FriendList = { "GetNumFriends", "GetFriendInfoByIndex" },
  C_Reputation = { "GetNumFactions", "GetFactionDataByIndex" }, C_Map = { "GetBestMapForUnit" }, C_ChatInfo = { "SendAddonMessage" }, C_UnitAuras = { "GetBuffDataByIndex" },
  C_TooltipInfo = { "GetUnit" }, C_Timer = { "After" } }
O.commands.report = function()
  local r = { at = Clock(), level = Level(), class = Owl.class, zone = Zone(), missing = {}, probes = {}, read = {} }
  local build = Call("GetBuildInfo")
  r.build = tostring(build[1]) .. " / " .. tostring(build[4])
  for _, name in ipairs(API) do if type(_G[name]) ~= "function" then r.missing[#r.missing + 1] = name end end
  for tname, fns in pairs(TABLES) do
    local t = _G[tname]
    for _, fn in ipairs(fns) do if type(t) ~= "table" or type(t[fn]) ~= "function" then r.missing[#r.missing + 1] = tname .. "." .. fn end end
  end
  table.sort(r.missing)
  if not Plain(UnitAffectingCombat("player")) then
    local function try(label, fn)
      local ok, v = pcall(fn)
      r.read[label] = ok and tostring(v) or ("ERROR " .. tostring(v))
    end
    try("spellbook", function() local n = 0 for _ in pairs((BookSpells())) do n = n + 1 end return n .. " spells" end)
    try("bars", function() local n = 0 for _ in pairs(BarSpells()) do n = n + 1 end return n .. " spells on bars" end)
    try("durability", function() return Durability() end)
    try("supplies", function() local f, p = Supplies() return tostring(f) .. " food, " .. tostring(p) .. " potions" end)
    try("questcounts", function() local t, d, m = QuestCounts() return tostring(t) .. " quests, " .. tostring(d) .. " done, max " .. tostring(m) end)
    try("character", function()
      local gear = 0 for _ in pairs(me.gear) do gear = gear + 1 end
      return "race=" .. tostring(me.race) .. " guild=" .. tostring(me.guild) .. " home=" .. tostring(me.home) .. " stats=" .. #me.stats .. " armor=" .. tostring(me.armor) .. " gear=" .. gear
        .. " ilvl=" .. tostring(me.ilvl) .. " profs=" .. #me.profs .. " trees=" .. #me.trees .. " rep=" .. tostring(me.rep and me.rep[1]) .. " gathered=" .. tostring(me.gathered)
    end)
    try("professions", function() local parts = {} for _, p in ipairs(me.profs) do parts[#parts + 1] = p[1] .. " " .. tostring(p[2]) .. "/" .. tostring(p[3]) end return table.concat(parts, ", ") end)
    try("talents", function() local parts = {} for _, t in ipairs(me.trees) do parts[#parts + 1] = t[1] .. " " .. t[2] end return table.concat(parts, ", ") end)
    for name, fn in pairs(Owl.probe or {}) do try(name, fn) end
  else
    r.read.note = "made in combat: only the lists of missing functions are filled in"
  end
  local rec = Record()
  local counts = {}
  for _, key in ipairs({ "foes", "mates", "vendors", "rares", "picks", "flights", "dungeons", "beasts", "history", "whispers", "guildies", "rivals", "training", "places" }) do
    local n = 0
    if type(rec[key]) == "table" then for _ in pairs(rec[key]) do n = n + 1 end end
    counts[#counts + 1] = key .. "=" .. n
  end
  r.memory = table.concat(counts, " ") .. " bond=" .. tostring(rec.bond) .. " sessions=" .. tostring(rec.sessions) .. " fights=" .. tostring(type(rec.fight) == "table" and rec.fight.n)
  r.errors = OwlHUDDB.errlog
  r.settings = "tips=" .. tostring(OwlHUDDB.tips) .. " chatty=" .. tostring(OwlHUDDB.chatty) .. " fancy=" .. tostring(OwlHUDDB.fancy) .. " size=" .. tostring(OwlHUDDB.owlSize) .. " bubble=" .. tostring(OwlHUDDB.bubble) .. " deep=" .. tostring(OwlHUDDB.deep) .. " bis=" .. tostring(OwlHUDDB.bis)
  OwlHUDDB.report = r
  O.Print("|cffffd100Report made.|r " .. #r.missing .. " game functions missing, " .. (type(r.errors) == "table" and #r.errors or 0) .. " logged errors.")
  print("  It is saved when you /reload or log out. Then tell Claude, and it can read exactly what worked.")
  for label, v in pairs(r.read) do if tostring(v):find("^ERROR") then print("  |cffff4040" .. label .. "|r " .. tostring(v):sub(1, 120)) end end
end
end

do
-- =====================================================================================
-- Looks: a glow while he talks, sparkles, and movement (hop, wing flaps, nod, shiver, tilt)
-- =====================================================================================
O.defaults.fancy = true
local ICON, ICON_X = 80, 28   -- he is drawn full length now, so the picture is taller
local glow = pal:CreateTexture(nil, "BACKGROUND")
glow:SetSize(118, 118)
glow:SetPoint("CENTER", pal, "LEFT", ICON_X, 0)
glow:SetTexture(MEDIA .. "owl_glow.tga")
if glow.SetBlendMode then glow:SetBlendMode("ADD") end
glow:Hide()

local sparks = {}
for i = 1, 12 do
  local s = pal:CreateTexture(nil, "OVERLAY")
  s:SetTexture(MEDIA .. "owl_spark.tga")
  s:SetSize(12, 12)
  s:Hide()
  sparks[i] = s
end
local burstT, burstN, burstReach, bigBurstUntil = nil, 0, 44, 0
local function Burst(big)
  burstT, burstN, burstReach = 0, big and 12 or 6, big and 78 or 46
end

local move = { kind = nil, t = 0, dur = 0 }
local rot, lastDX, lastDY, lastScale, lastRot, flapOn, glowT = 0, 0, 0, nil, 0, false, 0
local function Place(dx, dy, scale, r)
  if dx ~= lastDX or dy ~= lastDY or scale ~= lastScale then
    lastDX, lastDY, lastScale = dx, dy, scale
    pal.icon:ClearAllPoints()
    pal.icon:SetPoint("CENTER", pal, "LEFT", ICON_X + dx, dy)
    pal.icon:SetSize(ICON * scale, ICON * scale)
  end
  if r ~= lastRot and pal.icon.SetRotation then
    lastRot = r
    pal.icon:SetRotation(r)
    pal.hat:SetRotation(r)
    if pal.outfit then pal.outfit:SetRotation(r) end
    if pal.layers then for i = 1, #pal.layers do pal.layers[i]:SetRotation(r) end end
  end
end

-- his size on screen: /owl size 160 (a percentage; 100 is the small original)
O.defaults.owlSize = 160
local function ApplySize()
  local pct = tonumber(OwlHUDDB and OwlHUDDB.owlSize) or 160
  if pct < 50 then pct = 50 elseif pct > 300 then pct = 300 end
  ICON = 80 * pct / 100
  -- keep his right side clear of the speech bubble as he grows
  ICON_X = math.min(28, 60 - ICON * 0.335)
  glow:SetSize(ICON * 1.45, ICON * 1.45)
  glow:ClearAllPoints()
  glow:SetPoint("CENTER", pal, "LEFT", ICON_X, 0)
  perch:SetSize(54 * pct / 100, 54 * pct / 100)
  lastScale = nil
end
O.On("PLAYER_LOGIN", function() O.Try("owl size", ApplySize) end)
O.commands.size = function(arg)
  local n = tonumber(arg)
  if not n or n < 50 or n > 300 then
    O.Print("owl size is " .. tostring(OwlHUDDB.owlSize or 160) .. ". Set it with /owl size 50 to 300 (160 is the usual).")
    return
  end
  OwlHUDDB.owlSize = math.floor(n)
  ApplySize()
  O.Print("owl size: " .. OwlHUDDB.owlSize)
end

Owl.base = function() return ICON_X, ICON end
local spin = 0
O.OwlBurst = function(big) if OwlHUDDB.fancy then Burst(big) end end
O.OwlSpin = function() if OwlHUDDB.fancy then move.kind, move.t, move.dur = "spin", 0, 0.9 end end
O.OwlGlowColor = function(r, g, b) if glow.SetVertexColor then glow:SetVertexColor(r, g, b) end end
O.OwlGlowColor(1, 0.84, 0.43)
local MOVES = { excited = { "hop", 1.3 }, happy = { "nod", 0.55 }, worried = { "shiver", 0.9 }, sleepy = { "sway", 2.6 } }
O.OwlMood = function(mood)
  if not OwlHUDDB.fancy then return end
  local m = MOVES[mood or ""]
  if flapOn then flapOn = false end
  if not m then move.kind = nil return end
  move.kind, move.t, move.dur = m[1], 0, m[2]
  if mood == "excited" then Burst(Now() < bigBurstUntil) end
end
O.On("PLAYER_LEVEL_UP", function() bigBurstUntil = Now() + 20 end)

O.OwlPlaces = true   -- the talking bob in Journey.lua is handed to Place() below
local function LooksStep(e)
  local bob = (pal:IsShown() and Owl.Talking() and type(pal.bob) == "number") and pal.bob or 0
  if not pal:IsShown() or not OwlHUDDB.fancy or O.unlocked then
    if glow:IsShown() then glow:Hide() end
    if burstT then burstT = nil for i = 1, #sparks do sparks[i]:Hide() end end
    move.kind = nil
    Place(0, bob, 1, 0)
    rot = 0
    return
  end
  -- the glow breathes while a line is up
  glowT = glowT + e
  if Owl.Talking() then
    if not glow:IsShown() then glow:Show() end
    glow:SetAlpha(0.42 + 0.2 * math.sin(glowT * 3.2))
  elseif glow:IsShown() then glow:Hide() end

  local dx, dy, scale, want = 0, 0, 1, 0
  if move.kind then
    move.t = move.t + e
    local p = move.t / move.dur
    if p >= 1 then
      if move.kind == "hop" and flapOn then flapOn = false SetArt(pal.icon, "owl_excited.tga") end
      move.kind = nil
    elseif move.kind == "hop" then
      -- three bounces, each lower than the last, wings flapping
      local b = (p * 3) % 1
      dy = math.sin(b * math.pi) * 11 * (1 - p * 0.75)
      local up = math.floor(move.t / 0.13) % 2 == 1
      if up ~= flapOn then
        flapOn = up
        if not SetArt(pal.icon, up and "owl_flap.tga" or "owl_excited.tga") then pal.icon:SetTexture(MEDIA .. "owl_excited.tga") end
      end
    elseif move.kind == "nod" then
      dy = -math.sin(p * math.pi * 2) * 2.5
      scale = 1 + 0.05 * math.sin(p * math.pi)
    elseif move.kind == "shiver" then
      dx = math.sin(move.t * 46) * 1.6 * (1 - p)
      scale = 1 + 0.09 * math.sin(p * math.pi)
    elseif move.kind == "sway" then
      want = math.sin(p * math.pi * 2) * 0.07
    elseif move.kind == "spin" then
      spin = p * math.pi * 2
      dy = math.sin(p * math.pi) * 8
    end
  elseif pal.menu and pal.menu:IsShown() and not Owl.Talking() then
    want = 0.17   -- head tilt: he is listening
  end
  rot = rot + (want - rot) * math.min(1, e * 9)
  if math.abs(rot) < 0.002 and want == 0 then rot = 0 end
  if move.kind ~= "spin" then spin = 0 end
  Place(dx, dy + bob, scale, rot + spin)

  if burstT then
    burstT = burstT + e
    local p = burstT / 0.85
    if p >= 1 then
      burstT = nil
      for i = 1, #sparks do sparks[i]:Hide() end
    else
      local out = 1 - (1 - p) * (1 - p)
      for i = 1, burstN do
        local s = sparks[i]
        local a = (i / burstN) * math.pi * 2 + 0.4
        local reach = 18 + (burstReach - 18) * out * (0.75 + 0.25 * ((i * 7) % 3) / 2)
        s:ClearAllPoints()
        s:SetPoint("CENTER", pal, "LEFT", ICON_X + math.cos(a) * reach * ICON / 80, math.sin(a) * reach * ICON / 80 + 4)
        local size = 15 * (1 - p * 0.6) * ICON / 80
        s:SetSize(size, size)
        s:SetAlpha(1 - p * p)
        if not s:IsShown() then s:Show() end
      end
    end
  end
end

local looksDead = false
local looksDriver = CreateFrame("Frame")
looksDriver:SetScript("OnUpdate", function(_, e)
  if looksDead then return end
  local ok, err = pcall(LooksStep, e)
  if not ok then
    looksDead = true
    O.OwlPlaces = nil
    pcall(function() pal.icon:ClearAllPoints() pal.icon:SetPoint("CENTER", pal, "LEFT", ICON_X, 0) pal.icon:SetSize(ICON, ICON) end)
    glow:Hide()
    for i = 1, #sparks do sparks[i]:Hide() end
    O.Print("|cffff4040owl animations turned off:|r " .. tostring(err))
  end
end)

O.commands.fancy = function()
  OwlHUDDB.fancy = not OwlHUDDB.fancy
  O.Print("owl glow and animations" .. (OwlHUDDB.fancy and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

end

-- =====================================================================================
-- His wardrobe: things he wears, goals he sets himself to earn them, livelier movement,
-- and the owls of friends in your group
-- =====================================================================================
O.defaults.friendOwls = true
O.defaults.goals = true
Owl.WardrobeSetup = function()   -- a function of its own: Lua allows 200 local names in each

local Sub, Count = Owl.lib.Sub, Owl.lib.Count
local SLOTS = { "hat", "cloak", "neck", "extra", "perch", "aura", "gem" }
local SLOT_NAME = { hat = "Hat", cloak = "Cloak", neck = "Neck", extra = "Carried", perch = "Perch", aura = "Aura", gem = "Torch" }
-- the part of each picture shown on a wardrobe button (left, right, top, bottom)
local CROP = { hat = { 0.279, 0.721, 0, 0.443 }, cloak = { 0.167, 0.833, 0.333, 1 }, neck = { 0.344, 0.656, 0.456, 0.768 },
  extra = { 0.271, 0.70, 0.469, 0.898 }, perch = { 0.24, 0.76, 0.479, 1 }, aura = { 0, 1, 0, 1 } }
-- id, slot, picture, name, bond level that grants it (0 = his from the start)
local ITEMS = {
  { "wizard", "hat", "cos_hat_wizard", "Starweaver's hat" }, { "horned", "hat", "cos_hat_horned", "Horned war helm" }, { "elven", "hat", "cos_hat_elven", "Silverleaf circlet" },
  { "dragonskull", "hat", "cos_hat_dragon", "Dragon-skull crown" }, { "circlet", "hat", "cos_hat_circlet", "Circlet of the bonded", 5 },
  { "blue", "cloak", "cos_cloak_blue", "Traveller's blue cloak", 4 }, { "runed", "cloak", "cos_cloak_runed", "Runed silk cloak" }, { "scale", "cloak", "cos_cloak_dragon", "Dragonscale cloak" },
  { "starlight", "cloak", "cos_cloak_starlight", "Starlight mantle" },
  { "scarf", "neck", "cos_neck_scarf", "Red scarf", 2 }, { "ruby", "neck", "cos_neck_ruby", "Ruby amulet" }, { "emerald", "neck", "cos_neck_emerald", "Emerald amulet" },
  { "amethyst", "neck", "cos_neck_amethyst", "Amethyst amulet" }, { "fang", "neck", "cos_neck_fang", "Raptor-fang necklace" },
  { "satchel", "extra", "cos_extra_satchel", "Adventurer's satchel", 3 },
  { "branch", "perch", "cos_perch_branch", "Old branch", 0 }, { "crystal", "perch", "cos_perch_crystal", "Crystal spire" }, { "books", "perch", "cos_perch_books", "Stack of spellbooks" },
  { "sword", "perch", "cos_perch_sword", "Sword in the stone" }, { "skull", "perch", "cos_perch_skull", "Giant's skull" },
  { "laurel", "hat", "cos_hat_laurel", "Fellowship laurel", nil, "Beat 150 foes together with friends who have owls." },
  { "braid", "neck", "cos_neck_braid", "Friendship braid", nil, "Your owl becomes Friends with another owl (30 minutes grouped)." },
  { "lantern", "extra", "cos_extra_lantern", "Twin lantern", nil, "Your owl becomes Best friends with another owl (300 minutes grouped)." },
  { "campfire", "perch", "cos_perch_campfire", "Campfire", nil, "Beat 500 foes together with friends who have owls." },
  { "embers", "aura", "cos_aura_embers", "Drifting embers" }, { "frost", "aura", "cos_aura_frost", "Frost motes" }, { "runes", "aura", "cos_aura_runes", "Ring of runes" },
}
-- rare finds: a lantern hidden in every dungeon, a gem in some zones
local LANTERN_NAMES = { "Ragefire", "Deadmines", "Wailing Caverns", "Shadowfang", "Stockade", "Blackfathom", "Gnomeregan", "Razorfen Kraul", "Scarlet", "Razorfen Downs",
  "Uldaman", "Zul'Farrak", "Maraudon", "Sunken Temple", "Blackrock Depths", "Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance" }
local DUNGEON_ALIAS = { [14] = "atal'hakkar", [16] = "blackrock spire", [9] = "scarlet" }
local GEMS = { { "Westfall", "Westfall torch" }, { "Redridge Mountains", "Redridge torch" }, { "Duskwood", "Duskwood torch" }, { "Wetlands", "Wetlands torch" },
  { "Stranglethorn Vale", "Stranglethorn torch" }, { "Arathi Highlands", "Arathi torch" }, { "The Barrens", "Barrens torch" }, { "Ashenvale", "Ashenvale torch" },
  { "Tanaris", "Tanaris torch" }, { "Un'Goro Crater", "Un'Goro torch" }, { "Winterspring", "Winterspring torch" }, { "Burning Steppes", "Steppes torch" },
  { "Felwood", "Felwood torch" }, { "Hillsbrad Foothills", "Hillsbrad torch" }, { "Thousand Needles", "Needles torch" }, { "Desolace", "Desolace torch" } }
-- how good a rare find is: each tier is harder to come by than the one before
local TIERS = { { "Common", "ffffffff", 60, 1, 1, 1 }, { "Uncommon", "ff1eff00", 25, 0.12, 1, 0 }, { "Rare", "ff0070dd", 10, 0, 0.44, 0.87 },
  { "Epic", "ffa335ee", 4, 0.64, 0.21, 0.93 }, { "Legendary", "ffff8000", 1, 1, 0.5, 0 } }
local RARE = { extra = {}, gem = {} }
for i, name in ipairs(LANTERN_NAMES) do
  local d = Owl.DUNGEONS and Owl.DUNGEONS[i]
  ITEMS[#ITEMS + 1] = { "l" .. i, "extra", "cos_lantern_" .. i, name .. " lantern", nil, nil, d and d[1] or name }
  RARE.extra[i] = "l" .. i
end
for i, g in ipairs(GEMS) do
  ITEMS[#ITEMS + 1] = { "g" .. i, "gem", "cos_gem_" .. i, g[2], nil, nil, g[1] }
  RARE.gem[i] = "g" .. i
end
local ITEM = {}
for _, it in ipairs(ITEMS) do ITEM[it[1]] = { id = it[1], slot = it[2], file = it[3] .. ".tga", name = it[4], bond = it[5], how = it[6], rare = it[7] } end
-- what he sets himself, easiest first. stat, how many, the words, and "abs" when it is a total and not counted from the day he set it
local GOALS = {
  { "wizard", "quests", 15, "hand in %d quests" }, { "crystal", "level", 2, "gain %d levels" }, { "fang", "raptor", 50, "beat %d raptors" },
  { "horned", "kills", 250, "win %d fights" }, { "books", "days", 5, "play on %d different days" }, { "ruby", "gold", 0, "hold %d gold at once", "abs" },
  { "elven", "places", 25, "find %d places new to me" }, { "sword", "streak", 20, "win %d fights in a row without dying", "abs" }, { "emerald", "k_Beast", 150, "beat %d beasts" },
  { "runed", "quests", 35, "hand in %d quests" }, { "skull", "k_Undead", 60, "beat %d undead" }, { "amethyst", "k_Humanoid", 100, "beat %d humanoids" },
  { "embers", "kills", 400, "win %d fights" }, { "dragonskull", "level", 5, "gain %d levels" }, { "starlight", "days", 10, "play on %d different days" },
  { "frost", "places", 60, "find %d places new to me" }, { "scale", "k_Dragonkin", 20, "beat %d dragonkin" }, { "runes", "own", 12, "own %d things to wear", "abs" },
}
local GOAL = {}
for i, g in ipairs(GOALS) do GOAL[g[1]] = { item = g[1], stat = g[2], n = g[3], words = g[4], abs = g[5] == "abs", order = i } end

local function Cos()
  local c = Sub(Record(), "cos")
  Sub(c, "own") Sub(c, "worn") Sub(c, "stats") Sub(c, "goals") Sub(c, "skip")
  if not c.own.branch then
    c.own.branch = true
    if c.worn.perch == nil then c.worn.perch = "branch" end
  end
  return c
end
local function Stat(key)
  local c = Cos()
  if key == "level" then return Level()
  elseif key == "gold" then return math.floor((Owl.Money and Num(Owl.Money()) or 0) / 10000)
  elseif key == "own" then return Count(c.own)
  elseif key == "places" then return Count(Sub(c.stats, "seen"))
  elseif key == "days" then return Count(Sub(c.stats, "dayset")) end
  return Num(c.stats[key]) or 0
end

-- ---------- the layers of a dressed owl ----------
local function Layer(holder, layer, sub)
  local tex = holder:CreateTexture(nil, layer)
  if tex.SetDrawLayer then pcall(tex.SetDrawLayer, tex, layer, sub) end
  tex:Hide()
  return tex
end
local function Flip(tex, mirror)
  if tex.SetTexCoord then if mirror then tex:SetTexCoord(1, 0, 0, 1) else tex:SetTexCoord(0, 1, 0, 1) end end
end
-- a stack is: aura, perch, owl, cloak, neck, extra, hat. "own" stacks get their own owl and hat pictures.
local function Stack(holder, icon, hat)
  local s = { holder = holder, look = {} }
  s.aura, s.perch = Layer(holder, "BACKGROUND", 1), Layer(holder, "BACKGROUND", 2)
  s.ownOwl = icon == nil
  s.owl = icon or holder:CreateTexture(nil, "ARTWORK")
  -- the crest sits just above him (its picture is cut to fit round his head), so spread wings pass behind it
  s.crest = Layer(holder, "ARTWORK", 1)
  s.mark = Layer(holder, "ARTWORK", 2)
  s.cloak, s.neck, s.extra = Layer(holder, "ARTWORK", 3), Layer(holder, "ARTWORK", 4), Layer(holder, "ARTWORK", 5)
  s.gem = Layer(holder, "ARTWORK", 6)
  s.ownHat = hat == nil
  s.hat = hat or Layer(holder, "OVERLAY", 2)
  for _, slot in ipairs({ "crest", "mark", "cloak", "neck", "extra", "gem" }) do s[slot]:SetAllPoints(s.owl) end
  if s.ownHat then s.hat:SetAllPoints(s.owl) end
  return s
end
-- ---------- his body: plumage, the shape of his head, and markings ----------
local PLUMES = { "Great horned", "Snowy", "Tawny", "Dusk", "Frost", "Ember", "Grove", "Shadow", "Starlit", "Gilded" }
local CRESTS = { "Horned tufts", "Round head", "Swept crest", "Antlers", "Crystal horns" }
local MARKS = { [0] = "No markings", "Wing runes", "War paint", "Ember veins" }
local plume = 1   -- his own plumage, kept here so pictures can be swapped without asking each time
local function OwlFile(file, p)
  if type(file) ~= "string" or not p or p <= 1 or not PLUMES[p] then return file end
  if file:find("^owl[%w_]*%.tga$") then return "p" .. p .. "_" .. file end
  return file
end
local function CrestFile(crest, p)
  if crest == 1 or crest == 3 then return "crest" .. crest .. "_p" .. ((p and PLUMES[p]) and p or 1) .. ".tga" end
  if crest == 4 then return "crest_antlers.tga" end
  if crest == 5 then return "crest_crystal.tga" end
  return nil
end
-- his own pictures are set from many places by plain name; this swaps in the plumage he wears
local skinned = {}
local function Skin(tex)
  if not tex or rawget(tex, "owlSkinned") then return end
  local orig = tex.SetTexture
  rawset(tex, "owlSkinned", true)
  tex.SetTexture = function(self, path, ...)
    rawset(self, "owlPath", path)
    rawset(self, "owlShown", nil)
    if type(path) == "string" and plume > 1 then
      local dir, file = path:match("^(.*\\)(owl[%w_]*%.tga)$")
      if file then path = dir .. OwlFile(file, plume) end
    end
    rawset(self, "owlShown", path)
    local a, b = orig(self, path, ...)
    -- if the game will not show that picture, fall back to the plain one so he never goes missing
    local okT, got = pcall(self.GetTexture, self)
    if okT and got == nil and type(path) == "string" and path:find("owl", 1, true) then
      local log = type(OwlHUDDB) == "table" and OwlHUDDB or nil
      if log then
        if type(log.artLog) ~= "table" then log.artLog = {} end
        if #log.artLog < 30 then log.artLog[#log.artLog + 1] = "no picture: " .. tostring(path):gsub("^.*\\", "") end
      end
      orig(self, MEDIA .. "owl.tga")
    end
    return a, b
  end
  skinned[#skinned + 1] = tex
end
-- the game fetches a picture the first time it is asked for, and shows nothing until it arrives. With his ears, scarf
-- and perch now separate pictures, that left them hanging in the air while his body blinked out. So every picture of
-- the plumage in use is fetched ahead of time and held.
local FRAME_FILES = { "owl.tga", "owl_happy.tga", "owl_worried.tga", "owl_sleepy.tga", "owl_excited.tga", "owl_blink.tga", "owl_left.tga", "owl_right.tga", "owl_flap.tga",
  "owl_stretch.tga", "owl_squint.tga", "owl_nervous.tga", "owl_cold.tga", "owl_fly1.tga", "owl_fly2.tga" }
local holdFrame, held, heldSets = nil, {}, {}
local function Preload(p)
  p = (p and PLUMES[p]) and p or 1
  if heldSets[p] then return end
  heldSets[p] = true
  if not holdFrame then
    holdFrame = CreateFrame("Frame", nil, UIParent)
    holdFrame:SetSize(2, 2)
    holdFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    holdFrame:SetAlpha(0.02)
  end
  for _, file in ipairs(FRAME_FILES) do
    local tex = holdFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetSize(2, 2)
    tex:SetPoint("BOTTOMLEFT", holdFrame, "BOTTOMLEFT", 0, 0)
    tex:SetTexture(MEDIA .. OwlFile(file, p))
    held[#held + 1] = tex
  end
end
local function Reskin()
  for _, tex in ipairs(skinned) do local path = rawget(tex, "owlPath") if type(path) == "string" then tex:SetTexture(path) end end
end
local function DressBody(s, body, mirror)
  local p, crest, mark = 1, 1, 0
  if type(body) == "table" then p, crest, mark = body.p or 1, body.c or 1, body.m or 0 end
  if not PLUMES[p] then p = 1 end
  if not CRESTS[crest] then crest = 1 end
  if not MARKS[mark] then mark = 0 end
  s.body = { p = p, c = crest, m = mark }
  pcall(Preload, p)
  if s.ownOwl then
    s.face = s.face or "owl.tga"
    s.owl:SetTexture(MEDIA .. OwlFile(s.face, p))
  end
  local file = CrestFile(crest, p)
  if file then s.crest:SetTexture(MEDIA .. file) Flip(s.crest, mirror) s.crest:Show() else s.crest:Hide() end
  if mark > 0 then s.mark:SetTexture(MEDIA .. "mark_" .. mark .. ".tga") Flip(s.mark, mirror) s.mark:Show() else s.mark:Hide() end
end
-- a glow in the tier's colour around a rare lantern or torch; brighter and livelier the rarer it is
local HALO_AT = { extra = { 0.348, 0.781 }, gem = { 0.734, 0.391 } }
local function Halos(s, t, fancy, mirror)
  for slot, at in pairs(HALO_AT) do
    local tier = s.tiers and s.tiers[slot]
    local halo = s.halo and s.halo[slot]
    if tier and tier >= 2 and s.look[slot] then
      if not halo then
        s.halo = s.halo or {}
        halo = s.holder:CreateTexture(nil, "ARTWORK")
        if halo.SetDrawLayer then pcall(halo.SetDrawLayer, halo, "ARTWORK", 7) end
        halo:SetTexture(MEDIA .. "owl_glow.tga")
        if halo.SetBlendMode then halo:SetBlendMode("ADD") end
        s.halo[slot] = halo
      end
      local w, h = s.owl:GetWidth(), s.owl:GetHeight()
      if type(w) == "number" and type(h) == "number" and w > 0 then
        local size = w * (0.2 + 0.07 * tier)
        local x = s.mirror and (1 - at[1]) or at[1]
        halo:ClearAllPoints()
        halo:SetPoint("CENTER", s.owl, "TOPLEFT", w * x, -h * at[2])
        halo:SetSize(size, size)
      end
      local c = TIERS[tier]
      if halo.SetVertexColor then halo:SetVertexColor(c[4], c[5], c[6]) end
      halo:SetAlpha(fancy and (0.3 + 0.1 * tier + 0.06 * tier * math.sin(t * (1.5 + tier * 0.7))) or (0.3 + 0.1 * tier))
      if not halo:IsShown() then halo:Show() end
    elseif halo and halo:IsShown() then halo:Hide() end
  end
end
local function Dress(s, look, mirror)
  if mirror ~= nil then s.mirror = mirror end
  for _, slot in ipairs(SLOTS) do
    local it = look and ITEM[look[slot] or ""]
    if it and it.slot ~= slot then it = nil end
    local tex = s[slot]
    if slot ~= "hat" or s.ownHat then
      s.look[slot] = it and it.id or nil
      if slot == "extra" or slot == "gem" then s.tiers = s.tiers or {} s.tiers[slot] = (it and it.rare and look.tiers and look.tiers[slot]) or nil end
      if it then
        tex:SetTexture(MEDIA .. it.file)
        Flip(tex, mirror)
        tex:Show()
      else tex:Hide() end
    end
  end
  if mirror ~= nil then Flip(s.owl, mirror) end
  DressBody(s, look and look.body, s.mirror)
end

local perchFrame = _G.OwlHUDPerch
Skin(pal.icon)
if perchFrame then Skin(perchFrame.icon) end
local palStack = Stack(pal, pal.icon, pal.hat)
local perchStack = perchFrame and Stack(perchFrame, perchFrame.icon, perchFrame.hat)
pal.layers = { palStack.cloak, palStack.neck, palStack.extra, palStack.gem, palStack.crest, palStack.mark }
if perchStack then
  perchStack.perch:SetAllPoints(perchFrame)
  perchStack.aura:SetPoint("CENTER", perchFrame, "CENTER", 0, 0)
end

local function BestTier(c)
  local best = 0
  for id in pairs(c.own) do if ITEM[id] and ITEM[id].rare then best = math.max(best, Num(Sub(c, "tier")[id]) or 1) end end
  return best
end
local function PalBest()
  local best = 0
  if Owl.social then for _, p in pairs(Owl.social.Soc().pals) do if type(p) == "table" then best = math.max(best, Num(p.mins) or 0) end end end
  return best
end
-- is this choice open to him yet, and if not, how is it earned
local BODY_RULES = {
  p = { [5] = { "Reach bond level 3 (Trusted).", function() return (Owl.BondLevel and Owl.BondLevel() or 1) >= 3 end },
    [6] = { "Find any rare lantern or torch.", function(c) return BestTier(c) >= 1 end },
    [7] = { "Own 8 things in the wardrobe.", function(c) return Count(c.own) >= 8 end },
    [8] = { "Find a lantern or torch of Rare tier or better.", function(c) return BestTier(c) >= 3 end },
    [9] = { "Your owl becomes Friends with another owl.", function() return PalBest() >= 30 end },
    [10] = { "Find a Legendary lantern or torch.", function(c) return BestTier(c) >= 5 end } },
  c = { [4] = { "Own 6 things in the wardrobe.", function(c) return Count(c.own) >= 6 end },
    [5] = { "Find a lantern or torch of Epic tier or better.", function(c) return BestTier(c) >= 4 end } },
  m = { [2] = { "Win 200 fights.", function(c) return (Num(c.stats.kills) or 0) >= 200 end },
    [3] = { "Reach level 35.", function() return Level() >= 35 end } },
}
local BODY_LISTS = { p = PLUMES, c = CRESTS, m = MARKS }
local BODY_WORD = { p = "plumage", c = "head", m = "markings" }
local function BodyOpen(key, i)
  local rule = BODY_RULES[key][i]
  if not rule then return true end
  local ok, yes = pcall(rule[2], Cos())
  return ok and yes and true or false, rule[1]
end
local function Body()
  local b = Sub(Cos(), "body")
  if not PLUMES[b.p or 0] then b.p = 1 end
  if not CRESTS[b.c or 0] then b.c = 1 end
  if not MARKS[b.m or -1] then b.m = 0 end
  return b
end
local function Worn()
  local body = Body()
  if OwlHUDDB.outfit == false then return { perch = "branch", body = { p = body.p, c = body.c, m = body.m } } end
  local c, look = Cos(), { body = { p = body.p, c = body.c, m = body.m } }
  for _, slot in ipairs(SLOTS) do
    local id = c.worn[slot]
    if id and c.own[id] and ITEM[id] and ITEM[id].slot == slot then
      look[slot] = id
      if ITEM[id].rare then look.tiers = look.tiers or {} look.tiers[slot] = Num(Sub(c, "tier")[id]) or 1 end
    end
  end
  return look
end
local function LookText(look)
  local parts = {}
  for i, slot in ipairs(SLOTS) do
    parts[i] = look[slot] or ""
    if look[slot] and look.tiers and look.tiers[slot] then parts[i] = parts[i] .. "." .. look.tiers[slot] end
  end
  local b = look.body
  parts[#SLOTS + 1] = b and ("b" .. (b.p or 1) .. "." .. (b.c or 1) .. "." .. (b.m or 0)) or ""
  return table.concat(parts, ",")
end
local function ReadLook(text)
  local look, i = {}, 0
  for part in (tostring(text or "") .. ","):gmatch("([^,]*),") do
    i = i + 1
    local slot = SLOTS[i]
    if i == #SLOTS + 1 then
      local bp, bc, bm = part:match("^b(%d+)%.(%d+)%.(%d+)$")
      if bp then look.body = { p = tonumber(bp), c = tonumber(bc), m = tonumber(bm) } end
    end
    local id, tier = part:match("^([^%.]*)%.?(%d?)$")
    if slot and id and ITEM[id] and ITEM[id].slot == slot then
      look[slot] = id
      if ITEM[id].rare then look.tiers = look.tiers or {} look.tiers[slot] = math.max(1, math.min(#TIERS, tonumber(tier) or 1)) end
    end
  end
  return look
end
local function TierOf(id) return math.max(1, math.min(#TIERS, Num(Sub(Cos(), "tier")[id]) or 1)) end
-- "Epic Deadmines lantern", in the tier's colour when asked
local function Shown(id, tier, coloured)
  local it = ITEM[id]
  if not it then return "?" end
  if not it.rare then return it.name end
  local t = TIERS[tier or TierOf(id)]
  local text = t[1] .. " " .. it.name
  return coloured and ("|c" .. t[2] .. text .. "|r") or text
end

local wardrobe, RefreshWardrobe   -- made further down
local lookSent, sendLookAt = nil, nil
local function ApplyLook()
  local look = Worn()
  pcall(Preload, look.body.p)
  if look.body.p ~= plume then plume = look.body.p Reskin() end
  Dress(palStack, look)
  if perchStack then Dress(perchStack, look) end
  for _, holder in ipairs({ pal, perchFrame }) do if holder and holder.outfit then holder.outfit:Hide() end end
  if wardrobe and wardrobe:IsShown() and RefreshWardrobe then RefreshWardrobe() end
  local text = LookText(look)
  if text ~= lookSent then
    lookSent, sendLookAt = text, Now() + 1.5
    if Owl.cos and Owl.cos.onLook then pcall(Owl.cos.onLook, text) end
  end
end
-- a worn hat comes before the holiday hats
local baseHat = O.OwlHat
O.OwlHat = function()
  local ok, c = pcall(Cos)
  if ok and OwlHUDDB.outfit ~= false then
    local id = c.worn.hat
    if id and c.own[id] and ITEM[id] and ITEM[id].slot == "hat" then return ITEM[id].file end
  end
  if baseHat then return baseHat() end
end

-- ---------- earning things ----------
-- what he has to say about them waits its turn: a busy fight must not swallow the news
local news = {}
local function Tell(key, text) news[#news + 1] = { key = key, text = text, till = Now() + 180 } end
local function Wear(id)
  local it, c = ITEM[id], Cos()
  if not (it and c.own[id]) then return false end
  c.worn[it.slot] = id
  ApplyLook()
  return true
end
local function Unlock(id, how, quiet)
  local it, c = ITEM[id], Cos()
  if not it or c.own[id] then return false end
  c.own[id] = true
  c.worn[it.slot] = id
  ApplyLook()
  pcall(Note, Name() .. " earned the " .. Shown(id) .. ".")
  if Owl.cos and Owl.cos.onUnlock then pcall(Owl.cos.onUnlock, id, it.rare and TierOf(id) or nil) end
  if not quiet then
    if O.OwlSpin then pcall(O.OwlSpin) end
    if O.OwlBurst then pcall(O.OwlBurst, true) end
    Tell("cosgot" .. id, (how or "I earned something") .. ". The " .. Shown(id) .. " is mine! I am wearing it now.")
  end
  return true
end
local function BondGifts(quiet)
  local level = Owl.BondLevel and Owl.BondLevel() or 1
  for _, it in ipairs(ITEMS) do
    local item = ITEM[it[1]]
    if item.bond and item.bond > 0 and level >= item.bond then Unlock(item.id, "Our bond grew", quiet) end
  end
end
O.OwlOutfit = function() BondGifts(false) ApplyLook() end

local function Words(goal) local def = GOAL[goal.id] return def and def.words:format(goal.n) or "?" end
local function Progress(goal)
  local def = GOAL[goal.id]
  if not def then return 0 end
  local have = Stat(def.stat) - (Num(goal.base) or 0)
  if have < 0 then have = 0 elseif have > goal.n then have = goal.n end
  return have
end
local function Start(def)
  local goal = { id = def.item, n = def.n, base = def.abs and 0 or Stat(def.stat) }
  if def.stat == "gold" then goal.n = math.max(10, math.ceil((Stat("gold") * 1.5 + 5) / 5) * 5) end
  return goal
end
local function NextDef(c)
  local best, bestKey
  for _, raw in ipairs(GOALS) do
    local def = GOAL[raw[1]]
    local busy = c.own[def.item]
    for _, g in ipairs(c.goals) do if g.id == def.item then busy = true end end
    if not busy then
      local key = (Num(c.skip[def.item]) or 0) * 100 + def.order
      if not bestKey or key < bestKey then best, bestKey = def, key end
    end
  end
  return best
end
local function FillGoals(announce)
  local c, added = Cos(), {}
  while #c.goals < 3 do
    local def = NextDef(c)
    if not def then break end
    c.goals[#c.goals + 1] = Start(def)
    added[#added + 1] = c.goals[#c.goals]
  end
  if #added == 0 or not announce or OwlHUDDB.goals == false then return end
  if #added > 1 then
    Tell("cosgoals" .. added[1].id, "I have set myself " .. #added .. " goals. When we reach one I earn something new to wear. Click me and open the wardrobe to see them.")
  else
    Tell("cosgoal" .. added[1].id, "A new goal for me: " .. Words(added[1]) .. ". There is a " .. ITEM[added[1].id].name .. " in it.")
  end
end
local function BodyNews()
  local c = Cos()
  local seen = Sub(c, "bodySeen")
  for key, rules in pairs(BODY_RULES) do
    for i in pairs(rules) do
      local id = key .. i
      if not seen[id] and BodyOpen(key, i) then
        seen[id] = true
        Tell("bodyopen" .. id, "Something new for me: " .. BODY_LISTS[key][i] .. (key == "p" and " plumage" or key == "c" and " for my head" or " markings") .. ". It is waiting in the wardrobe.")
      end
    end
  end
end
local function CheckGoals()
  pcall(BodyNews)
  local c = Cos()
  for i = #c.goals, 1, -1 do
    local goal = c.goals[i]
    if not GOAL[goal.id] or c.own[goal.id] then
      table.remove(c.goals, i)
    else
      local have = Progress(goal)
      if have >= goal.n then
        table.remove(c.goals, i)
        Unlock(goal.id, "Goal reached: " .. Words(goal))
      elseif not goal.half and goal.n >= 10 and have * 2 >= goal.n then
        goal.half = true
        if OwlHUDDB.goals ~= false then Tell("coshalf" .. goal.id, "Halfway to my " .. ITEM[goal.id].name .. ": " .. have .. " of " .. goal.n .. ". I set out to " .. Words(goal) .. ".") end
      end
    end
  end
  FillGoals(true)
end
local checkAt = nil
local function Soon() checkAt = Now() + 1 end

local kindOf = {}
O.On("PLAYER_TARGET_CHANGED", function()
  if not Q("UnitExists", "target") then return end
  local name, kind = Str(Plain(UnitName("target"))), Str(Call("UnitCreatureType", "target")[1])
  if name and kind then kindOf[name] = kind end
end)
local cheerAt = nil
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local name = msg:match("^(.-) dies")
  if not name or name == "" then return end
  local s = Cos().stats
  s.kills = (Num(s.kills) or 0) + 1
  s.streak = (Num(s.streak) or 0) + 1
  if name:lower():find("raptor", 1, true) then s.raptor = (Num(s.raptor) or 0) + 1 end
  local kind = kindOf[name]
  if kind then s["k_" .. kind] = (Num(s["k_" .. kind]) or 0) + 1 end
  cheerAt = Now()
  Soon()
end)
O.On("PLAYER_DEAD", function() Cos().stats.streak = 0 end)

-- ---------- rare finds: lanterns in dungeons, gems in a few zones ----------
O.defaults.rareFinds = true
local luck = { roll = function() return math.random() end, tier = function() return math.random() end, boss = 0.03, trash = 0.001, gem = 0.003, gemRare = 0.20 }
local function Norm(s) return (tostring(s or ""):lower():gsub("^the ", "")) end
local function DungeonHere()
  local r = Call("IsInInstance")
  if not r[1] or r[2] ~= "party" then return nil end
  local name = Norm(Str(Call("GetInstanceInfo")[1]) or Zone())
  for i, d in ipairs(Owl.DUNGEONS or {}) do
    local want = DUNGEON_ALIAS[i] or Norm(d[1])
    if name:find(want, 1, true) or want:find(name, 1, true) then return i end
  end
end
local function GemHere()
  local zone = Zone()
  for i, g in ipairs(GEMS) do if g[1] == zone then return i end end
end
local function RollTier()
  local total = 0
  for _, t in ipairs(TIERS) do total = total + t[3] end
  local pick, sum = luck.tier() * total, 0
  for i = #TIERS, 1, -1 do   -- the rarest sits at the bottom of the roll
    sum = sum + TIERS[i][3]
    if pick < sum then return i end
  end
  return 1
end
local FOUND = { extra = { "Something glinted in the dark and I grabbed it", "Wait. Behind that one. Do you see it glowing", "I have heard of these and never seen one" },
  gem = { "There was a torch still burning back there and I have it now", "Look what was burning under that one", "It never goes out. I checked" } }
local TIER_LINE = { [4] = "An Epic one. Look at it. LOOK at it.", [5] = "LEGENDARY. I am shaking. Tell everyone. Tell them twice." }
local function Find(id, chance)
  local it = ITEM[id]
  if not it or OwlHUDDB.rareFinds == false then return false end
  if luck.roll() >= chance then return false end
  local c = Cos()
  local tiers = Sub(c, "tier")
  local tier = RollTier()
  local s = Sub(c.stats, "finds")
  s[id] = (Num(s[id]) or 0) + 1
  if not c.own[id] then
    tiers[id] = tier
    local lines = FOUND[it.slot] or FOUND.gem
    Unlock(id, lines[math.random(#lines)] .. ((tier == 2 or tier == 4) and ". An " or ". A ") .. TIERS[tier][1]:lower() .. " find from " .. it.rare .. (TIER_LINE[tier] and (". " .. TIER_LINE[tier]:gsub("%.$", "")) or ""))
    pcall(Note, "A rare find in " .. it.rare .. ": the " .. Shown(id) .. ".")
    return true
  end
  local had = TierOf(id)
  if tier <= had then return false end
  tiers[id] = tier
  ApplyLook()
  if O.OwlSpin then pcall(O.OwlSpin) end
  if O.OwlBurst then pcall(O.OwlBurst, true) end
  Tell("costier" .. id .. tier, "A better one! My " .. it.name .. " was " .. TIERS[had][1] .. ". Now it is " .. TIERS[tier][1] .. "." .. (TIER_LINE[tier] and (" " .. TIER_LINE[tier]) or ""))
  pcall(Note, "The " .. it.name .. " from " .. it.rare .. " is " .. TIERS[tier][1] .. " now.")
  if Owl.cos and Owl.cos.onUnlock then pcall(Owl.cos.onUnlock, id, tier) end
  return true
end
local bossAt = -100
local function BossDown()
  if Now() - bossAt < 5 then return end
  bossAt = Now()
  local i = DungeonHere()
  if i then Find("l" .. i, luck.boss) end
end
O.On("BOSS_KILL", function() O.Try("owl rare boss", BossDown) end)
O.On("ENCOUNTER_END", function(_, _, _, _, success) if Plain(success) == 1 then O.Try("owl rare boss", BossDown) end end)
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  local name = type(msg) == "string" and msg:match("^(.-) dies")
  if not name or name == "" then return end
  local i = DungeonHere()
  if i then Find("l" .. i, luck.trash) return end
  local g = GemHere()
  if g then
    local isRare = type(Sub(Record(), "rares")[name]) == "table"
    Find("g" .. g, isRare and luck.gemRare or luck.gem)
  end
end)
local function RareList(slot, title, where)
  local c = Cos()
  local found = 0
  for _, id in ipairs(RARE[slot]) do if c.own[id] then found = found + 1 end end
  O.Print("|cff66ccff" .. title .. "|r  " .. found .. " of " .. #RARE[slot] .. " found")
  for i, id in ipairs(RARE[slot]) do
    local it = ITEM[id]
    local d = slot == "extra" and Owl.DUNGEONS and Owl.DUNGEONS[i]
    local range = d and (" (levels " .. d[2] .. " to " .. d[3] .. ")") or ""
    print("  " .. (c.own[id] and Shown(id, nil, true) or ("|cff909090" .. it.name .. "|r")) .. " - " .. it.rare .. range .. (c.worn[slot] == id and "  |cffffd100wearing|r" or ""))
  end
  print("  " .. where)
  local parts, total = {}, 0
  for _, t in ipairs(TIERS) do total = total + t[3] end
  for _, t in ipairs(TIERS) do parts[#parts + 1] = "|c" .. t[2] .. t[1] .. "|r " .. math.floor(t[3] / total * 100 + 0.5) .. "%" end
  print("  When one turns up: " .. table.concat(parts, ", ") .. ". A better one replaces what you have.")
end
-- a window for the collection, so it is something to look at and not a list scrolling past in chat
local finds
local FIND_CROP = { extra = { 0.227, 0.473, 0.629, 0.922, 40, 48 }, gem = { 0.637, 0.828, 0.285, 0.586, 30, 48 } }
local FIND_ODDS = { extra = "Every dungeon hides one. 3 in 100 from each boss, 1 in 1,000 from anything else in there.",
  gem = "These zones each hide one. 3 in 1,000 from anything you beat there, 1 in 5 from the zone's rare creatures." }
local function RefreshFinds()
  local c, slot = Cos(), finds.slot
  local crop = FIND_CROP[slot]
  local counts = {}
  for _, key in ipairs({ "extra", "gem" }) do
    local n = 0
    for _, id in ipairs(RARE[key]) do if c.own[id] then n = n + 1 end end
    counts[key] = n
  end
  finds.title:SetText(Name() .. "'s rare finds")
  finds.tabs.extra.label:SetText("Lanterns  " .. counts.extra .. " of " .. #RARE.extra)
  finds.tabs.gem.label:SetText("Torches  " .. counts.gem .. " of " .. #RARE.gem)
  for key, tab in pairs(finds.tabs) do if key == slot then tab.bg:SetColorTexture(0.72, 0.55, 0.14, 1) else tab.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95) end end
  for i, cell in ipairs(finds.cells) do
    local id = RARE[slot][i]
    local it = id and ITEM[id]
    if it then
      cell.icon:SetTexture(MEDIA .. it.file)
      if cell.icon.SetTexCoord then cell.icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4]) end
      cell.icon:SetSize(crop[5], crop[6])
      local d = slot == "extra" and Owl.DUNGEONS and Owl.DUNGEONS[i]
      local where = it.rare .. (d and (", levels " .. d[2] .. " to " .. d[3]) or "")
      if c.own[id] then
        if cell.icon.SetVertexColor then cell.icon:SetVertexColor(1, 1, 1) end
        cell.name:SetText(Shown(id, nil, true) .. (c.worn[slot] == id and "  |cffffd100worn|r" or ""))
        cell.where:SetText("|cff40ff40Found.|r " .. where)
      else
        if cell.icon.SetVertexColor then cell.icon:SetVertexColor(0.2, 0.2, 0.24) end
        cell.name:SetText("|cff909090" .. it.name .. "|r")
        cell.where:SetText("|cff707070" .. where .. "|r")
      end
      cell.icon:Show() cell.name:Show() cell.where:Show()
    else
      cell.icon:Hide() cell.name:Hide() cell.where:Hide()
    end
  end
  local parts, total = {}, 0
  for _, t in ipairs(TIERS) do total = total + t[3] end
  for _, t in ipairs(TIERS) do parts[#parts + 1] = "|c" .. t[2] .. t[1] .. "|r " .. math.floor(t[3] / total * 100 + 0.5) .. "%" end
  finds.foot:SetText(FIND_ODDS[slot] .. "\nWhen one turns up: " .. table.concat(parts, ",  ") .. ". A better one replaces what you have.")
end
local function ShowFinds(slot)
  if not finds then
    local COLS, CW, CH = 4, 186, 58
    local W, H = COLS * CW + 28, 5 * CH + 138
    finds = CreateFrame("Frame", "OwlHUDFinds", UIParent)
    finds:SetSize(W, H)
    finds:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    finds:SetFrameStrata("DIALOG")
    finds:EnableMouse(true)
    finds:SetMovable(true)
    finds:SetClampedToScreen(true)
    finds:RegisterForDrag("LeftButton")
    finds:SetScript("OnDragStart", function(f) f:StartMoving() end)
    finds:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    finds.bg = finds:CreateTexture(nil, "BACKGROUND")
    finds.bg:SetAllPoints()
    finds.bg:SetColorTexture(0.06, 0.05, 0.03, 0.96)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = finds:CreateTexture(nil, "BORDER")
      line:SetColorTexture(0.89, 0.7, 0.29, 0.95)
      if side == "TOP" or side == "BOTTOM" then
        line:SetPoint(side .. "LEFT", finds, side .. "LEFT", 0, 0) line:SetPoint(side .. "RIGHT", finds, side .. "RIGHT", 0, 0) line:SetHeight(2)
      else
        line:SetPoint("TOP" .. side, finds, "TOP" .. side, 0, 0) line:SetPoint("BOTTOM" .. side, finds, "BOTTOM" .. side, 0, 0) line:SetWidth(2)
      end
    end
    finds.title = finds:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    finds.title:SetPoint("TOPLEFT", 14, -12)
    local function Tab(x, width, onClick)
      local b = CreateFrame("Button", nil, finds)
      b:SetSize(width, 24)
      b:SetPoint("TOPLEFT", finds, "TOPLEFT", x, -40)
      b.bg = b:CreateTexture(nil, "BACKGROUND")
      b.bg:SetAllPoints()
      b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      b.label:SetPoint("CENTER", 0, 0)
      b:SetScript("OnClick", function() O.Try("owl finds", onClick) end)
      return b
    end
    finds.tabs = { extra = Tab(14, 190, function() finds.slot = "extra" RefreshFinds() end), gem = Tab(210, 190, function() finds.slot = "gem" RefreshFinds() end) }
    local close = Tab(W - 84, 70, function() finds:Hide() end)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", finds, "TOPRIGHT", -8, -8)
    close.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95)
    close.label:SetText("Close")
    finds.cells = {}
    for i = 1, COLS * 5 do
      local x, y = 14 + ((i - 1) % COLS) * CW, -76 - math.floor((i - 1) / COLS) * CH
      local cell = {}
      cell.icon = finds:CreateTexture(nil, "ARTWORK")
      cell.icon:SetPoint("TOPLEFT", finds, "TOPLEFT", x, y)
      cell.name = finds:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell.name:SetPoint("TOPLEFT", finds, "TOPLEFT", x + 46, y - 8)
      cell.name:SetWidth(CW - 50)
      cell.where = finds:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell.where:SetPoint("TOPLEFT", finds, "TOPLEFT", x + 46, y - 24)
      cell.where:SetWidth(CW - 50)
      for _, fs in ipairs({ cell.name, cell.where }) do if fs.SetJustifyH then fs:SetJustifyH("LEFT") end if fs.SetWordWrap then fs:SetWordWrap(true) end end
      finds.cells[i] = cell
    end
    finds.foot = finds:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    finds.foot:SetPoint("BOTTOMLEFT", finds, "BOTTOMLEFT", 14, 12)
    finds.foot:SetWidth(W - 28)
    if finds.foot.SetJustifyH then finds.foot:SetJustifyH("LEFT") end
    finds:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OwlHUDFinds") end
  end
  if finds:IsShown() and finds.slot == slot then finds:Hide() return end
  finds.slot = slot
  RefreshFinds()
  finds:Show()
end
O.commands.lanterns = function(arg)
  if arg == "list" then
    RareList("extra", "Rare lanterns", "Every dungeon hides one: 3 in 100 from each boss, 1 in 1000 from anything else in there. Dress him in /owl wardrobe.")
    return
  end
  ShowFinds("extra")
end
O.commands.torches = function(arg)
  if arg == "list" then
    RareList("gem", "Rare torches", "3 in 1000 from anything you beat in that zone, 1 in 5 from its rare creatures.")
    return
  end
  ShowFinds("gem")
end
O.commands.gems = O.commands.torches
O.commands.rarefinds = function()
  OwlHUDDB.rareFinds = OwlHUDDB.rareFinds == false
  O.Print("rare lanterns and torches" .. (OwlHUDDB.rareFinds and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
O.On("QUEST_TURNED_IN", function() local s = Cos().stats s.quests = (Num(s.quests) or 0) + 1 Soon() end)
O.On("PLAYER_LEVEL_UP", Soon)
O.On("PLAYER_MONEY", Soon)
local function SeePlace()
  local s = Cos().stats
  local place = Owl.lib.SubZone and Owl.lib.SubZone()
  local seen = Sub(s, "seen")
  if place and not seen[place] and Count(seen) < 400 then seen[place] = true Soon() end
  local days = Sub(s, "dayset")
  local today = tostring(math.floor(Clock() / 86400))
  if not days[today] and Count(days) < 400 then days[today] = true Soon() end
end
O.On("ZONE_CHANGED", SeePlace)
O.On("ZONE_CHANGED_NEW_AREA", SeePlace)
O.On("ZONE_CHANGED_INDOORS", SeePlace)

Owl.cos = { Cos = Cos, Worn = Worn, Unlock = Unlock, Check = CheckGoals, Fill = FillGoals, Progress = Progress, ITEM = ITEM, GOAL = GOAL, Look = LookText, luck = luck, RARE = RARE, DungeonHere = DungeonHere, TIERS = TIERS, Shown = Shown, Body = Body, BodyOpen = BodyOpen, OwlFile = OwlFile, PLUMES = PLUMES, heldSets = heldSets, stacks = { pal = palStack, perch = perchStack }, ORDER = {} }
for i, it in ipairs(ITEMS) do Owl.cos.ORDER[i] = it[1] end
do
-- ---------- friends' owls ----------
local friends, friendOrder, slots = {}, {}, {}
Owl.cos.friends, Owl.cos.slots = friends, slots
local FRIEND_MAX = 3
local function FriendFrame(i)
  if slots[i] then return slots[i] end
  local f = CreateFrame("Frame", "OwlHUDFriendOwl" .. i, UIParent)
  f:SetSize(40, 40)
  f.stack = Stack(f)
  f.stack.owl:SetTexture(MEDIA .. "owl.tga")
  f.stack.perch:SetAllPoints(f)
  f.stack.aura:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  -- the name sits beside each owl, not under it, so a column of them stays tidy and the words never run together
  f.label:SetPoint("RIGHT", f, "LEFT", -5, 0)
  if f.label.SetJustifyH then f.label:SetJustifyH("RIGHT") end
  if f.label.SetSpacing then f.label:SetSpacing(2) end
  f.emote = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- the word it says pops up at its shoulder, clear of the owl stacked above it
  f.emote:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 8, -10)
  f.emote:Hide()
  f.t, f.hop, f.blinkAt, f.face = math.random() * 6, 0, 3, "owl.tga"
  f.emoteUntil, f.who = false, false
  f:Hide()
  slots[i] = f
  return f
end
local function LayoutFriends()
  for i = 1, FRIEND_MAX do
    local who = friendOrder[i]
    local data = who and friends[who]
    if data and OwlHUDDB.friendOwls ~= false then
      local f = FriendFrame(i)
      f.who = who
      local look = data.look or { perch = "branch" }
      local short = (tostring(who):gsub("%-.*$", ""))
      f.label:ClearAllPoints()
      if slots.row then
        -- in a dungeon they line up beside him, every one on a branch so the branches run together; just a name under each
        local onBranch = {}
        for k, v in pairs(look) do onBranch[k] = v end
        onBranch.perch = "branch"
        Dress(f.stack, onBranch, true)
        f.label:SetPoint("TOP", f, "BOTTOM", 0, -2)
        if f.label.SetJustifyH then f.label:SetJustifyH("CENTER") end
        f.label:SetText(short)
      else
        Dress(f.stack, look, true)
        f.label:SetPoint("RIGHT", f, "LEFT", -5, 0)
        if f.label.SetJustifyH then f.label:SetJustifyH("RIGHT") end
        -- gold: the owl's name. grey under it: whose owl it is, and where they are when they are not with you
        local under = tostring(data.owl):find(short, 1, true) and "" or short
        if data.far and data.note then under = under .. (under ~= "" and "  " or "") .. data.note end
        if data.away then under = under .. (under ~= "" and "  " or "") .. "far off" end
        f.label:SetText(data.owl .. (under ~= "" and ("\n|cffb0b0b0" .. under .. "|r") or ""))
      end
    elseif slots[i] then
      slots[i].who = false
      slots[i]:Hide()
    end
  end
end
-- a friend's owl moves when something happens: a plain hop, or an act ("talk" when it has something to say,
-- "cheer" for good news), with a word over its head
local function FriendHop(who, word, act)
  for i = 1, FRIEND_MAX do
    local f = slots[i]
    if f and f.who == who then
      f.hop = 1
      if act then f.hop, f.act, f.actT, f.actDur = 0, act, 0, (act == "cheer" and 1.8 or 1.4) end
      if word and not (Owl.stage and Owl.stage.Bubble and Owl.stage.Bubble(f, word, 2.5)) then f.emote:SetText(word) f.emote:Show() f.emoteUntil = Now() + 2.5 end
    end
  end
end
local function AddFriend(who, owl, look)
  local data = friends[who]
  if not data then
    if #friendOrder >= 8 then return end
    data = { owl = owl, at = Now() }
    friends[who] = data
    friendOrder[#friendOrder + 1] = who
  end
  data.owl = owl
  if look then data.look = look end
  LayoutFriends()
  FriendHop(who)
end
-- is this friend online? true, false, or nil when the friends list does not know them
local function ListSays(name)
  if not (Owl.FL) then return nil end
  for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
    local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
    local n = ok and type(info) == "table" and Str(Plain(info.name))
    if n and Owl.First((n:gsub("%-.*$", ""))) == name then return Plain(info.connected) and true or false end
  end
  return nil
end
-- Friends' owls are kept between sessions (who they are and what they wear), so the moment a friend shows as online
-- their owl is beside yours, group or no group. He also keeps calling to any friend he has not heard back from.
local helloAt, listAt = {}, -100
local function SeekFriends()
  if OwlHUDDB.farOwls == false or OwlHUDDB.social == false then return end
  if not (Owl.FL) then return end
  -- ask the game for a fresh friends list now and then; without this it can sit empty or stale after logging in
  if Now() - listAt > 60 then listAt = Now() if type(C_FriendList) == "table" and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end end
  local saved = type(OwlHUDDB.friendLooks) == "table" and OwlHUDDB.friendLooks or {}
  local met = type(OwlHUDDB.journal) == "table" and type(OwlHUDDB.journal.owls) == "table" and OwlHUDDB.journal.owls or {}
  local me = Me()
  for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
    local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
    local name = ok and type(info) == "table" and Plain(info.connected) and Str(Plain(info.name))
    if name then
      local listed = name:gsub("%-.*$", "")
      name = Owl.First(listed)
      Owl.Full(name, listed)
    end
    if name and name ~= me then
      local s = saved[name]
      if not friends[name] and type(s) == "table" and #friendOrder < 8 then
        local okL, look = pcall(ReadLook, s.look)
        friends[name] = { owl = Str(s.owl) or "Owl", at = Now(), far = true, look = okL and look or nil }
        friendOrder[#friendOrder + 1] = name
      end
      local data = friends[name]
      -- the friends list shows their level, so he notices a level-up even if their owl never says a word
      local lvl = Num(Plain(info.level))
      if data and lvl and lvl > 0 then
        if data.level and lvl > data.level then
          if Owl.LevelSay then
            local theirs = tostring(data.owl)
            Owl.LevelSay(name, "owllevel" .. name, { name .. " just hit level " .. lvl .. ". " .. theirs .. " will not stop hooting about it.", name .. " is level " .. lvl .. " now. Well done, " .. name .. ".",
              "Level " .. lvl .. " for " .. name .. ". " .. theirs .. " looks very pleased." }, 30)
          end
          FriendHop(name, "Ding!", "cheer")
          if Owl.cos.Idle then pcall(Owl.cos.Idle, "cheer", 1) end
        end
        data.level = lvl
        -- the friends list also says where they are, so the grey line under the name fills in before their owl writes
        local area = Str(Plain(info.area))
        if area and not data.note then data.note = lvl .. ", " .. area end
      end
      if not (data and data.heard) and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local every = (s or met[name]) and 45 or 300
        if Now() - (helloAt[name] or -1000) > every then
          helloAt[name] = Now()
          pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "HELLO|" .. Name() .. "|" .. tostring(Level()), "WHISPER", Owl.Addr(name))
        end
      end
    end
  end
end
-- an owl stays beside yours while its player is in your group or shows as online; a friend who is not on your
-- friends list stays while their owl keeps in touch
local dropAt = 15
local function DropFriends()
  if Q("IsInRaid") then return end
  pcall(SeekFriends)
  local keep = {}
  if Q("IsInGroup") then for _, name in ipairs(Owl.lib.PartyNames()) do keep[name] = true end end
  for i = #friendOrder, 1, -1 do
    local who = friendOrder[i]
    local data = friends[who]
    local stay = keep[who]
    if not stay and data and OwlHUDDB.farOwls ~= false then
      local listed = ListSays(who)
      stay = listed == true or (listed == nil and Now() - (data.at or 0) < 330)
    end
    if data then data.far = not keep[who] end
    if stay then
      if data then data.leaving = nil end
    elseif data and Owl.stage and not data.leaving then
      -- it flies off before it is gone
      data.leaving = Now()
      dropAt = Now() + 1.3
    elseif not data or not data.leaving or Now() - data.leaving >= 1.1 then
      friends[who] = nil
      table.remove(friendOrder, i)
    else dropAt = Now() + 0.5 end
  end
  LayoutFriends()
end
O.On("GROUP_ROSTER_UPDATE", function() dropAt = Now() + 1.5 sendLookAt = Now() + 4 end)
local netBefore = Owl.onNet
local lookReplyAt = -100
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if friends[sender] then friends[sender].at = Now() end
  if kind == "HELLO" or kind == "HI" then
    AddFriend(sender, owl)
    if Now() - lookReplyAt > 5 then lookReplyAt = Now() sendLookAt = Now() + 1 end
  elseif kind == "LOOK" then
    AddFriend(sender, owl, ReadLook(extra))
  elseif kind == "PING" then
    if friends[sender] then friends[sender].note = extra ~= "" and extra or nil LayoutFriends() end
  elseif kind == "UP" then
    if friends[sender] then
      -- one short line, and only if he had told you they were down
      if friends[sender].dead then Say("friendup" .. sender, { sender .. " is back up.", sender .. " is on their feet again.", owl .. " says " .. sender .. " is alive again." }, 60, "c") end
      friends[sender].dead = nil
      FriendHop(sender)
    end
  elseif friends[sender] then
    -- word that their player has died: the owl keels over, as yours does
    if (kind == "NEWS" and extra:find("^died")) or (kind == "CARE" and extra:find("^down,")) or (kind == "N" and extra:find("^DL:")) then friends[sender].dead = Now()
    elseif kind == "LEVEL" or (kind == "NEWS" and extra:find("^reached level")) then
      FriendHop(sender, "Ding!", "cheer")
      if Owl.cos.Idle then pcall(Owl.cos.Idle, "cheer", 1) end
    elseif kind == "HOOT" or kind == "WANT" or kind == "NEWS" or kind == "CARE" or kind == "GIFT" or kind == "THANKS" then
      -- it has something to say: it bobs as it talks, and yours turns his head to listen
      FriendHop(sender, kind == "HOOT" and "Hoo!" or kind == "WANT" and "Ooh!" or kind == "CARE" and "Hey!" or kind == "GIFT" and "For you!" or kind == "THANKS" and "Thanks!" or "News!", "talk")
      if Owl.cos.Idle then pcall(Owl.cos.Idle, "tilt", 1.2) end
    else FriendHop(sender) end
  end
  -- remember this owl and what it wears, for next time
  local data = friends[sender]
  if data then
    data.heard = true
    if type(OwlHUDDB.friendLooks) ~= "table" then OwlHUDDB.friendLooks = {} end
    local keep = OwlHUDDB.friendLooks
    local n = 0
    for _ in pairs(keep) do n = n + 1 end
    if keep[sender] or n < 20 then
      if type(keep[sender]) ~= "table" then keep[sender] = {} end
      keep[sender].owl = data.owl
      if kind == "LOOK" and extra ~= "" then keep[sender].look = extra end
    end
  end
end
-- tell the other owls when you are back on your feet, so theirs can stand yours up again
local function SendUp()
  if Q("UnitIsDeadOrGhost", "player") then return end
  if Owl.net then pcall(Owl.net.Send, "UP", "") end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    for who, data in pairs(friends) do
      if data.far then pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "UP|" .. Name() .. "|", "WHISPER", Owl.Addr(who)) end
    end
  end
end
O.On("PLAYER_ALIVE", SendUp)
O.On("PLAYER_UNGHOST", SendUp)
-- a level-up is told straight to every friend whose owl is beside yours, grouped or not
O.On("PLAYER_LEVEL_UP", function(level)
  -- every owl beside yours cheers for you
  for who in pairs(friends) do FriendHop(who, "Hoo!", "cheer") end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  local lvl = tostring(Num(Plain(level)) or Level())
  for who, data in pairs(friends) do
    if data.far then pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "LEVEL|" .. Name() .. "|" .. lvl, "WHISPER", Owl.Addr(who)) end
  end
end)
-- a friend in your party can simply be looked at; one far away is down until their owl says otherwise (or four minutes pass)
local function FriendDead(who, data)
  if not data.far then
    for i = 1, 4 do
      local unit = "party" .. i
      if Str(Plain(UnitName(unit))) == who then
        data.dead = Q("UnitIsDeadOrGhost", unit) and (data.dead or Now()) or nil
        -- in trouble: under about a third of their health. Far off: out of reach of your heals and buffs.
        local hp, max = Q("UnitHealth", unit), Q("UnitHealthMax", unit)
        data.low = (not data.dead and type(hp) == "number" and type(max) == "number" and max > 0 and hp / max < 0.35) or false
        local inRange, checked = Q("UnitInRange", unit)
        data.awayNow = (checked == true and inRange == false and Q("UnitIsConnected", unit) ~= false) or false
        return data.dead ~= nil
      end
    end
  end
  data.low, data.awayNow = false, false
  if data.dead and Now() - data.dead > 240 then data.dead = nil end
  return data.dead ~= nil
end
local FRIEND_LAYERS = { "owl", "crest", "mark", "cloak", "neck", "extra", "gem", "hat", "scarf", "wing" }
local function SpinFriend(f, r)
  for _, slot in ipairs(FRIEND_LAYERS) do
    local tex = f.stack[slot]
    if tex and tex.SetRotation then pcall(tex.SetRotation, tex, r) end
  end
end
local function PoseFriend(f)
  local data = friends[f.who]
  local dead = data and FriendDead(f.who, data) or false
  local s = f.stack
  -- hurt badly: a worried face and a "!" until they are safe. Your owl looks their way (see the perch, far above).
  local low = (data and data.low and not dead) or false
  if low ~= (f.low or false) then
    f.low = low
    if low then f.emote:SetText("|cffff4040!|r") f.emote:Show() f.emoteUntil = false
    else f.emote:Hide() end
    if not dead and not f.visit then
      local want = low and "owl_worried.tga" or "owl.tga"
      f.face, s.face = want, want
      s.owl:SetTexture(MEDIA .. OwlFile(want, s.body and s.body.p))
    end
  end
  if low or (data and data.dead and not data.far and Now() - data.dead < 10) then Owl.troubleAt = Now() end
  -- wandered out of reach: say so under the name (after a few seconds, so a jump or a corner does not flicker it)
  if data then
    local awayNow = data.awayNow or false
    if awayNow ~= (data.away or false) then
      f.awayT = (f.awayT or 0) + 1
      if f.awayT >= 6 then f.awayT = 0 data.away = awayNow LayoutFriends() end
    else f.awayT = 0 end
  end
  if dead == (f.wasDead or false) then return end
  f.wasDead = dead
  f.act, f.rotKey = nil, 0
  SpinFriend(f, dead and -0.5 or 0)
  for _, slot in ipairs(FRIEND_LAYERS) do
    local tex = s[slot]
    if tex and tex.SetVertexColor then pcall(tex.SetVertexColor, tex, dead and 0.55 or 1, dead and 0.55 or 1, dead and 0.64 or 1) end
  end
  local want = dead and "owl_blink.tga" or (f.low and "owl_worried.tga" or "owl.tga")
  f.face, s.face = want, want
  s.owl:SetTexture(MEDIA .. OwlFile(want, s.body and s.body.p))
  f.blinkAt = f.t + 3
  if dead then f.hop = 0 else f.hop = 1 end
end
-- Where each friend's owl sits. Out in the world: a column at his shoulder. In a dungeon: a row beside him, all on
-- one line of branches. Now and then, when grouped and nothing is happening, one flies over to sit with him a moment.
local VISIT_OUT, VISIT_SIT, VISIT_BACK = 0.9, 4, 0.9
local function PlaceFriend(f, i, w, colDown, e)
  local row = slots.row
  local size = w * (row and 0.62 or 0.47)
  local step = (i - 1) * (size + w * 0.06)
  local vx, vy = 0, 0
  if f.visit then
    f.visit = f.visit + e
    local t, p = f.visit, nil
    if f.wasDead or row then p = nil
    elseif t < VISIT_OUT then p = t / VISIT_OUT
    elseif t < VISIT_OUT + VISIT_SIT then p = 1
    elseif t < VISIT_OUT + VISIT_SIT + VISIT_BACK then p = 1 - (t - VISIT_OUT - VISIT_SIT) / VISIT_BACK end
    local s = f.stack
    if not p then
      -- home again
      f.visit, f.landed = nil, nil
      f.label:SetAlpha(1)
      if s.look.perch then s.perch:Show() end
      local want = f.wasDead and "owl_blink.tga" or (f.low and "owl_worried.tga" or "owl.tga")
      f.face, s.face = want, want
      s.owl:SetTexture(MEDIA .. OwlFile(want, s.body and s.body.p))
      f.blinkAt = f.t + 2
    else
      local ease = p * p * (3 - 2 * p)
      s.perch:Hide()
      vx = (8 + size * 0.5) * ease
      vy = (colDown and (step - (w - size)) or -step) * ease + ((p < 1) and math.sin(p * math.pi) * size * 0.35 or 0)
      local want = "owl.tga"
      if p < 1 then want = (math.floor(t / 0.14) % 2 == 0) and "owl_fly1.tga" or "owl_fly2.tga" end
      if want ~= f.face then
        f.face, s.face = want, want
        s.owl:SetTexture(MEDIA .. OwlFile(want, s.body and s.body.p))
      end
      if p == 1 and not f.landed then
        f.landed = true
        f.emote:SetText("Hoo!") f.emote:Show() f.emoteUntil = Now() + 2
        if Owl.cos.Idle then pcall(Owl.cos.Idle, "hop", 0.7) end
      end
    end
  end
  if Owl.stage and Owl.stage.Offset then
    local okS, ox, oy = pcall(Owl.stage.Offset, f, i, size, e)
    if okS and type(ox) == "number" and type(oy) == "number" then vx, vy = vx + ox, vy + oy end
  end
  f:SetSize(size, size)
  f:ClearAllPoints()
  if row then f:SetPoint("BOTTOMRIGHT", perchFrame, "BOTTOMLEFT", 2 - (i - 1) * size * 0.9 + vx, vy)
  elseif colDown then f:SetPoint("TOPRIGHT", perchFrame, "TOPLEFT", -8 + vx, -step + vy)
  else f:SetPoint("BOTTOMRIGHT", perchFrame, "BOTTOMLEFT", -8 + vx, step + vy) end
  return size
end
-- once a frame: are we in a dungeon (checked every couple of seconds), and is it time for a visit
local function FriendScene(now, fancy)
  if now >= (slots.rowAt or 0) then
    slots.rowAt = now + 2
    local inside, kind = Q("IsInInstance")
    local row = ((inside and kind == "party") or OwlHUDDB.friendColumn ~= true) and true or false
    slots.inside = (inside and kind == "party") and true or false
    if row ~= (slots.row or false) then slots.row = row LayoutFriends() end
  end
  if not slots.visitAt then slots.visitAt = now + 90 + math.random() * 120 end
  if now < slots.visitAt then return end
  slots.visitAt = now + 150 + math.random() * 210
  if not fancy or slots.row or Plain(UnitAffectingCombat("player")) == true then return end
  local can = {}
  for i = 1, FRIEND_MAX do
    local f = slots[i]
    local data = f and f.who and friends[f.who]
    if data and f:IsShown() and not data.far and not f.wasDead and not f.low and not f.visit then can[#can + 1] = f end
  end
  local f = can[1] and can[math.random(#can)]
  if f then
    f.visit, f.landed, f.act = 0, nil, nil
    f.label:SetAlpha(0)
    f.stack.perch:Hide()
  end
end
O.defaults.farOwls = true
O.commands.farowls = function()
  OwlHUDDB.farOwls = OwlHUDDB.farOwls == false
  DropFriends()
  O.Print("friends' owls beside yours when they are online but not grouped" .. (OwlHUDDB.farOwls and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
O.commands.friendowl = function()
  OwlHUDDB.friendOwls = OwlHUDDB.friendOwls == false
  LayoutFriends()
  O.Print("friends' owls beside yours" .. (OwlHUDDB.friendOwls and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- livelier: he breathes, hops, preens and reacts while he waits ----------
local idle = { kind = nil, t = 0, dur = 0, nextAt = 12 }
local IDLE = { { "hop", 0.7 }, { "puff", 1.4 }, { "tilt", 1.6 }, { "peck", 0.9 }, { "shuffle", 1.2 }, { "wiggle", 0.8 } }
local function Idle(kind, dur) idle.kind, idle.t, idle.dur = kind, 0, dur or 1 end
Owl.cos.Idle, Owl.cos.Hop, Owl.cos.Layout = Idle, FriendHop, LayoutFriends
O.On("PLAYER_REGEN_DISABLED", function() if not idle.kind then Idle("startle", 0.35) end end)
local t, lastKey, auraSpin, wasFlying, baseX, baseSize, newsAt, watchT = 0, nil, 0, nil, nil, nil, 0, 0
local function Motion(e, dozing, dead)
  local dx, dy, sx, sy, r = 0, 0, 1, 1, 0
  local breath = dozing and math.sin(t * 1.1) * 0.03 or math.sin(t * 2.1) * 0.014
  sy = 1 + breath
  sx = 1 - breath * 0.4
  -- you are dead: he keels over where he sits (he used to drop three owl-heights below his perch, upright and
  -- wide awake, because the fall was measured in the wrong unit) and lies there until you are back
  if dead then
    idle.kind = nil
    idle.deadT = math.min((idle.deadT or 0) + e, 0.7)
    local p = idle.deadT / 0.7
    local fall = p * p * (3 - 2 * p)
    -- a small bounce as he lands
    local bump = (p > 0.75 and p < 1) and math.sin((p - 0.75) / 0.25 * math.pi) * 0.02 or 0
    return 0.05 * fall, -0.06 * fall + bump, 1 + 0.05 * fall, 1 - 0.12 * fall, 0.5 * fall
  end
  idle.deadT = 0
  if idle.kind then
    idle.t = idle.t + e
    local p = idle.t / idle.dur
    if p >= 1 then idle.kind = nil
    elseif idle.kind == "hop" or idle.kind == "cheer" then
      local b = (p * 2) % 1
      dy = math.sin(b * math.pi) * (idle.kind == "cheer" and 0.16 or 0.1) * (1 - p * 0.5)
      sy = sy + 0.05 * math.sin(b * math.pi)
    elseif idle.kind == "puff" then
      local k = math.sin(p * math.pi)
      sx, sy = sx + 0.09 * k, sy + 0.07 * k
      dx = math.sin(idle.t * 40) * 0.012 * k
    elseif idle.kind == "tilt" then r = math.sin(p * math.pi) * 0.16
    elseif idle.kind == "peck" then
      dy = -math.abs(math.sin(p * math.pi * 2)) * 0.05
      r = -math.abs(math.sin(p * math.pi * 2)) * 0.1
    elseif idle.kind == "shuffle" then dx = math.sin(p * math.pi * 2) * 0.07
    elseif idle.kind == "wiggle" then r = math.sin(p * math.pi * 4) * 0.07 * (1 - p)
    elseif idle.kind == "dance" then
      dx = math.sin(p * math.pi * 6) * 0.08
      dy = math.abs(math.sin(p * math.pi * 6)) * 0.07
      r = math.sin(p * math.pi * 6) * 0.12
    elseif idle.kind == "bow" then
      local k = math.sin(p * math.pi)
      dy, r, sy = -0.04 * k, -0.22 * k, sy - 0.06 * k
    elseif idle.kind == "dropin" then
      -- falls onto his perch and bounces
      if p < 0.55 then local q = p / 0.55 dy = (1 - q * q) * 1.7
      else local q = (p - 0.55) / 0.45 dy = math.sin(q * math.pi) * 0.14 * (1 - q) sy = sy - 0.1 * math.max(0, 1 - q * 4) sx = sx + 0.08 * math.max(0, 1 - q * 4) end
    elseif idle.kind == "popin" then
      -- out of nowhere, spinning, a little too big, then settles
      local k = p < 0.6 and (p / 0.6) * 1.2 or 1.2 - (p - 0.6) / 0.4 * 0.2
      sx, sy = k, k
      r = (1 - p) * (1 - p) * math.pi * 2
    elseif idle.kind == "rollin" then
      -- tumbles in along the branch
      local q = 1 - p
      dx = -q * q * 1.9
      r = -dx * 3.2
      dy = math.abs(math.sin(p * math.pi * 3)) * 0.07 * q
    elseif idle.kind == "swoopin" then
      local ease = p * p * (3 - 2 * p)
      dx = -(1 - ease) * 2.1
      dy = (1 - ease) * 0.9 + math.sin(p * math.pi) * 0.3
      r = (1 - ease) * 0.25
    elseif idle.kind == "peekin" then
      -- comes up from below, stops to look, then hops up
      if p < 0.35 then dy = -1 + (p / 0.35) * 0.55
      elseif p < 0.7 then dy = -0.45
      else local q = (p - 0.7) / 0.3 dy = -0.45 * (1 - q) + math.sin(q * math.pi) * 0.18 end
    elseif idle.kind == "startle" then
      dy = math.sin(p * math.pi) * 0.12
      sy = sy + 0.08 * math.sin(p * math.pi)
    end
  end
  return dx, dy, sx, sy, r
end
local function LiveStep(e)
  t = t + e
  local now = Now()
  if checkAt and now >= checkAt then checkAt = nil O.Try("owl goals", CheckGoals) end
  if news[1] and now >= newsAt then
    newsAt = now + 2
    if now > news[1].till or Say(news[1].key, news[1].text, 0) then table.remove(news, 1) end
  end
  if dropAt and now >= dropAt then dropAt = now + 15 O.Try("owl friends", DropFriends) end
  if sendLookAt and now >= sendLookAt then
    sendLookAt = nil
    if Owl.net and lookSent then pcall(Owl.net.Send, "LOOK", lookSent) end
  end
  -- where the talking owl stands: his perch and aura stay put while he hops
  if Owl.base then
    local x, size = Owl.base()
    if x ~= baseX or size ~= baseSize then
      baseX, baseSize = x, size
      for _, tex in ipairs({ palStack.perch, palStack.aura }) do
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", pal, "LEFT", x, 0)
      end
      palStack.perch:SetSize(size, size)
      palStack.aura:SetSize(size * 1.25, size * 1.25)
    end
  end
  -- a watch on the talking owl's own picture: if it is ever hidden, see-through or shrunk, put it right and note what was wrong
  watchT = watchT + e
  if watchT >= 0.5 and pal:IsShown() then
    watchT = 0
    local icon, wrong = pal.icon, nil
    local alpha, w, h = icon:GetAlpha(), icon:GetWidth(), icon:GetHeight()
    local okT, got = pcall(icon.GetTexture, icon)
    if not icon:IsShown() then wrong = "hidden" icon:Show()
    elseif type(alpha) == "number" and alpha < 0.95 then wrong = "alpha " .. string.format("%.2f", alpha) icon:SetAlpha(1)
    elseif type(w) == "number" and type(h) == "number" and (w < 20 or h < 20) then wrong = "size " .. math.floor(w) .. "x" .. math.floor(h)
    elseif okT and got == nil then wrong = "no texture, asked " .. tostring(rawget(icon, "owlShown")):gsub("^.*\\", "") icon:SetTexture(MEDIA .. "owl.tga") end
    local ok2, layer, sub = pcall(icon.GetDrawLayer, icon)
    if wrong then
      if type(OwlHUDDB.artLog) ~= "table" then OwlHUDDB.artLog = {} end
      if #OwlHUDDB.artLog < 30 then OwlHUDDB.artLog[#OwlHUDDB.artLog + 1] = "talking owl " .. wrong .. " layer " .. tostring(layer) .. "/" .. tostring(sub) .. " said: " .. tostring(pal.text and pal.text.GetText and pal.text:GetText() or ""):sub(1, 50) end
    end
  end
  auraSpin = (auraSpin + e * 0.35) % (math.pi * 2)
  local fancy = OwlHUDDB.fancy and not O.unlocked
  for _, s in ipairs({ palStack, perchStack }) do
    if s and s.look.aura and s.aura.SetRotation then
      s.aura:SetRotation(fancy and auraSpin or 0)
      s.aura:SetAlpha(fancy and (0.75 + 0.25 * math.sin(t * 2.3)) or 1)
    end
  end
  for _, s in ipairs({ palStack, perchStack }) do if s then Halos(s, t, fancy) end end
  for i = 1, FRIEND_MAX do if slots[i] and slots[i].who then Halos(slots[i].stack, t, fancy) end end
  if Owl.cos.preview then Halos(Owl.cos.preview, t, fancy) end
  for _, s in ipairs({ palStack, perchStack }) do
    if s then
      for _, slot in ipairs({ "extra", "gem" }) do
        local it = s.look[slot] and ITEM[s.look[slot]]
        if it then s[slot]:SetAlpha((fancy and it.rare) and (0.8 + 0.2 * math.sin(t * 3.1 + (slot == "gem" and 1.3 or 0))) or 1) end
      end
    end
  end
  if not perchStack then return end
  local w = perchFrame:GetWidth()
  if type(w) ~= "number" or w <= 0 then w = 86 end
  local flying = fancy and O.OwlFlying and O.OwlFlying() or false
  if flying ~= wasFlying then
    wasFlying = flying
    -- in the air he leaves the perch, the cloak and the satchel behind
    for _, s in ipairs({ palStack, perchStack }) do
      for _, slot in ipairs({ "perch", "cloak", "extra" }) do if flying then s[slot]:Hide() elseif s.look[slot] then s[slot]:Show() end end
      if flying then s.mark:Hide() elseif s.body and s.body.m > 0 then s.mark:Show() end
    end
  end
  local dx, dy, sx, sy, r = 0, 0, 1, 1, 0
  -- dead or a ghost: he goes grey, like the owls of fallen friends do, and colours again when you live
  local dead = Q("UnitIsDeadOrGhost", "player") and true or false
  if dead ~= (idle.grey or false) then
    idle.grey = dead
    for _, tex in ipairs({ perchFrame.icon, perchStack.cloak, perchStack.neck, perchStack.extra, perchStack.gem, perchStack.crest, perchStack.mark, perchFrame.hat }) do
      if tex and tex.SetVertexColor then pcall(tex.SetVertexColor, tex, dead and 0.55 or 1, dead and 0.55 or 1, dead and 0.64 or 1) end
    end
    if not dead then Idle("hop", 0.7) end
  end
  if fancy and perchFrame:IsShown() then
    if flying and not dead then
      dy, r = math.sin(t * 2.6) * 0.07 + 0.05, math.sin(t * 1.3) * 0.05
    else
      local dozing = perchFrame.z and perchFrame.z:IsShown()
      if cheerAt then
        if now - cheerAt < 0.5 and not idle.kind and math.random(3) == 1 then Idle("cheer", 0.8) end
        cheerAt = nil
      end
      if not idle.kind and not dozing and not dead and now >= idle.nextAt then
        local pick = IDLE[math.random(#IDLE)]
        Idle(pick[1], pick[2])
        idle.nextAt = now + 8 + math.random() * 14
      end
      dx, dy, sx, sy, r = Motion(e, dozing, dead)
    end
  else idle.kind = nil end
  local key = math.floor(dx * 400) .. ":" .. math.floor(dy * 400) .. ":" .. math.floor(sx * 400) .. ":" .. math.floor(sy * 400) .. ":" .. math.floor(r * 200) .. ":" .. math.floor(w)
  if key ~= lastKey then
    lastKey = key
    local icon = perchFrame.icon
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOM", perchFrame, "BOTTOM", dx * w, dy * w)
    icon:SetSize(w * sx, w * sy)
    perchStack.aura:SetSize(w * 1.25, w * 1.25)
    if icon.SetRotation then
      for _, tex in ipairs({ icon, perchStack.cloak, perchStack.neck, perchStack.extra, perchStack.gem, perchStack.crest, perchStack.mark, perchFrame.hat }) do tex:SetRotation(r) end
    end
  end
  -- friends' owls sit in a column at his left shoulder, facing him. Two of them stand as tall as he does.
  -- The column hangs down from his head when he is in the top half of the screen, and climbs from his feet otherwise.
  local colDown = false
  do
    local okC, _, cy = pcall(perchFrame.GetCenter, perchFrame)
    local ps, us, uh = perchFrame:GetEffectiveScale(), UIParent:GetEffectiveScale(), UIParent:GetHeight()
    if okC and type(cy) == "number" and type(ps) == "number" and type(us) == "number" and type(uh) == "number" then colDown = cy * ps > uh * us * 0.5 end
  end
  FriendScene(now, fancy)
  for i = 1, FRIEND_MAX do
    local f = slots[i]
    if f and f.who then
      local show = OwlHUDDB.tips and OwlHUDDB.perch and OwlHUDDB.friendOwls ~= false and not O.unlocked
      if show ~= f:IsShown() then if show then f:Show() else f:Hide() end end
      if show then
        local size = PlaceFriend(f, i, w, colDown, e)
        f.t = f.t + e
        f.deadT = (f.deadT or 1) + e
        if f.deadT >= 0.5 then f.deadT = 0 PoseFriend(f) end
        local down = f.wasDead and true or false
        local hop = 0
        if f.hop > 0 and not down then
          f.hop = f.hop - e * 1.3
          hop = math.abs(math.sin(f.hop * math.pi * 2)) * 0.14 * math.max(f.hop, 0)
        end
        -- what it is doing right now: talking, cheering, or a small move of its own every so often
        local rot = 0
        if down then f.act = nil
        elseif f.act then
          f.actT = f.actT + e
          local p = f.actT / f.actDur
          if p >= 1 then f.act = nil
          elseif f.act == "talk" then hop, rot = hop + math.abs(math.sin(p * math.pi * 6)) * 0.06, math.sin(p * math.pi * 6) * 0.05
          elseif f.act == "cheer" then hop = hop + math.abs(math.sin(p * math.pi * 5)) * 0.2 * (1 - p * 0.4)
          elseif f.act == "tilt" then rot = math.sin(p * math.pi) * 0.16
          elseif f.act == "wiggle" then rot = math.sin(p * math.pi * 4) * 0.08 * (1 - p) end
        elseif fancy and not f.visit and not f.busy and f.t >= (f.idleAt or 6) then
          local pick = math.random(5)
          if pick == 1 then f.hop = 1
          elseif pick >= 4 and Owl.stage and Owl.stage.Glance then pcall(Owl.stage.Glance, f, pick == 4 and "owl_left.tga" or "owl_right.tga", 1.2)
          else f.act, f.actT, f.actDur = (pick == 2 and "tilt" or "wiggle"), 0, 1.3 end
          f.idleAt = f.t + 8 + math.random() * 14
        end
        if not down then
          rot = rot + (f.spin or 0)
          local rk = math.floor(rot * 200 + 0.5)
          if rk ~= (f.rotKey or 0) then f.rotKey = rk SpinFriend(f, rot) end
        end
        local b = (fancy and not down) and math.sin(f.t * 2) * 0.014 or 0
        f.stack.owl:ClearAllPoints()
        -- down: slumped, squashed and still, eyes shut, until their player is up again
        if down then
          f.stack.owl:SetPoint("BOTTOM", f, "BOTTOM", 0, -size * 0.05)
          f.stack.owl:SetSize(size * 1.04, size * 0.9)
        else
          local pop = f.pop or 1
          f.stack.owl:SetPoint("BOTTOM", f, "BOTTOM", 0, hop * size)
          f.stack.owl:SetSize(size * (1 - b * 0.4) * pop, size * (1 + b) * pop)
        end
        f.stack.aura:SetSize(size * 1.25, size * 1.25)
        if not down and not f.visit and not f.busy and f.t >= f.blinkAt then
          local want = f.face == "owl_blink.tga" and (f.low and "owl_worried.tga" or "owl.tga") or "owl_blink.tga"
          f.face = want
          f.stack.face = want
          f.stack.owl:SetTexture(MEDIA .. OwlFile(want, f.stack.body and f.stack.body.p))
          f.blinkAt = f.t + (want ~= "owl_blink.tga" and 2.5 + math.random() * 5 or 0.14)
        end
        if f.emoteUntil and now >= f.emoteUntil then f.emoteUntil = false f.emote:Hide() end
      end
    end
  end
end
local liveDead = false
local liveDriver = CreateFrame("Frame")
liveDriver:SetScript("OnUpdate", function(_, e)
  if liveDead then return end
  local ok, err = pcall(LiveStep, e)
  if not ok then
    liveDead = true
    pcall(function() perchFrame.icon:ClearAllPoints() perchFrame.icon:SetAllPoints() end)
    for i = 1, FRIEND_MAX do if slots[i] then slots[i]:Hide() end end
    O.Print("|cffff4040owl wardrobe movement turned off:|r " .. tostring(err))
  end
end)

end
do
-- ---------- the wardrobe window ----------
local W, H, BTN = 660, 620, 44
wardrobe = CreateFrame("Frame", "OwlHUDWardrobe", UIParent)
wardrobe:SetSize(W, H)
wardrobe:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
wardrobe:SetFrameStrata("DIALOG")
wardrobe:EnableMouse(true)
wardrobe:SetMovable(true)
wardrobe:SetClampedToScreen(true)
wardrobe:RegisterForDrag("LeftButton")
wardrobe:SetScript("OnDragStart", function(f) f:StartMoving() end)
wardrobe:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
wardrobe.bg = wardrobe:CreateTexture(nil, "BACKGROUND")
wardrobe.bg:SetAllPoints()
wardrobe.bg:SetColorTexture(0.06, 0.05, 0.03, 0.96)
for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
  local line = wardrobe:CreateTexture(nil, "BORDER")
  line:SetColorTexture(0.89, 0.7, 0.29, 0.95)
  if side == "TOP" or side == "BOTTOM" then
    line:SetPoint(side .. "LEFT", wardrobe, side .. "LEFT", 0, 0) line:SetPoint(side .. "RIGHT", wardrobe, side .. "RIGHT", 0, 0) line:SetHeight(2)
  else
    line:SetPoint("TOP" .. side, wardrobe, "TOP" .. side, 0, 0) line:SetPoint("BOTTOM" .. side, wardrobe, "BOTTOM" .. side, 0, 0) line:SetWidth(2)
  end
end
wardrobe.title = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
wardrobe.title:SetPoint("TOPLEFT", 14, -12)
wardrobe.sub = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
wardrobe.sub:SetPoint("TOPLEFT", 15, -32)
wardrobe.sub:SetText("Click a thing to wear it or take it off. Dark ones are not earned yet: click one to see how.")
wardrobe:Hide()
if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OwlHUDWardrobe") end

local preview = CreateFrame("Frame", nil, wardrobe)
preview:SetSize(200, 200)
preview:SetPoint("TOPLEFT", 14, -58)
preview.stack = Stack(preview)
preview.stack.owl:SetAllPoints(preview)
preview.stack.face = "owl_happy.tga"
preview.stack.owl:SetTexture(MEDIA .. "owl_happy.tga")
preview.stack.perch:SetAllPoints(preview)
preview.stack.aura:SetPoint("CENTER", preview, "CENTER", 0, 0)
preview.stack.aura:SetSize(250, 250)
Owl.cos.preview = preview.stack

local function Plain2(b)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95)
  b:SetScript("OnEnter", function(self) if not self.on then self.bg:SetColorTexture(0.34, 0.25, 0.08, 0.98) end end)
  b:SetScript("OnLeave", function(self) if not self.on then self.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95) end end)
end
local info = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
info:SetPoint("TOPLEFT", 14, -266)
info:SetWidth(200)
if info.SetJustifyH then info:SetJustifyH("LEFT") end

local function HowTo(it)
  local c = Cos()
  if c.own[it.id] then return it.name .. (c.worn[it.slot] == it.id and "\n|cff40ff40Wearing it.|r" or "\n|cffffd100His.|r Click to wear.") end
  if it.bond and it.bond > 0 then return it.name .. "\n|cff909090Comes with bond level " .. it.bond .. ". /owl bond shows how close you are.|r" end
  if it.how then return it.name .. "\n|cff909090" .. it.how .. " /owl pals|r" end
  local def = GOAL[it.id]
  for _, g in ipairs(c.goals) do
    if g.id == it.id then return it.name .. "\n|cffffd100His goal now:|r " .. Words(g) .. " (" .. Progress(g) .. " of " .. g.n .. ")" end
  end
  if def then return it.name .. "\n|cff909090A later goal: " .. def.words:format(def.n > 0 and def.n or 0):gsub(" 0 ", " more ") .. ".|r" end
  return it.name
end

local itemButtons, goalRows = {}, {}
local bySlot = {}
for _, it in ipairs(ITEMS) do if not it[7] then bySlot[it[2]] = bySlot[it[2]] or {} table.insert(bySlot[it[2]], ITEM[it[1]]) end end
local pickers = {}
local function OwnedRare(slot)
  local c, list = Cos(), {}
  for _, id in ipairs(RARE[slot]) do if c.own[id] then list[#list + 1] = id end end
  return list
end
local function Picker(row, slot, title)
  local y = -58 - (row - 1) * (BTN + 6)
  local label = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 230, y - 14)
  label:SetText(title)
  local p = { slot = slot }
  local function Arrow(x, text, step)
    local b = CreateFrame("Button", nil, wardrobe)
    b:SetSize(BTN, BTN - 8)
    b:SetPoint("TOPLEFT", wardrobe, "TOPLEFT", x, y - 4)
    Plain2(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text)
    b:SetScript("OnClick", function()
      O.Try("owl wardrobe rare", function()
        local c, list = Cos(), OwnedRare(slot)
        if #list == 0 then
          info:SetText(slot == "gem" and "No torches yet.\n|cff909090Some zones hide one. A very small chance from anything you beat there, a better one from rare creatures. /owl torches|r"
            or "No rare lanterns yet.\n|cff909090Every dungeon hides one. A small chance from each boss, a tiny one from anything else in there. /owl lanterns|r")
          return
        end
        local at = 0
        for i, id in ipairs(list) do if c.worn[slot] == id then at = i end end
        at = at + step
        if at > #list then at = 0 elseif at < 0 then at = #list end
        c.worn[slot] = list[at] or false
        ApplyLook()
        RefreshWardrobe()
        info:SetText(list[at] and (Shown(list[at], nil, true) .. "\n|cff40ff40Found in " .. ITEM[list[at]].rare .. ".|r") or "")
      end)
    end)
    return b
  end
  p.prev = Arrow(300, "<", -1)
  p.text = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  p.text:SetPoint("TOPLEFT", wardrobe, "TOPLEFT", 300 + BTN + 10, y - 6)
  if p.text.SetJustifyH then p.text:SetJustifyH("LEFT") end
  p.nextB = Arrow(300 + BTN + 10 + 250, ">", 1)
  pickers[#pickers + 1] = p
end
Picker(7, "extra", "Lantern")
Picker(8, "gem", "Torch")
for row, slot in ipairs(SLOTS) do
  if slot == "gem" then break end
  local y = -58 - (row - 1) * (BTN + 6)
  local label = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 230, y - 14)
  label:SetText(SLOT_NAME[slot])
  for i, it in ipairs(bySlot[slot] or {}) do
    local b = CreateFrame("Button", nil, wardrobe)
    b:SetSize(BTN, BTN)
    b:SetPoint("TOPLEFT", wardrobe, "TOPLEFT", 300 + (i - 1) * (BTN + 6), y)
    Plain2(b)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 3, -3)
    b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    b.tex:SetTexture(MEDIA .. it.file)
    local c = CROP[slot]
    if b.tex.SetTexCoord then b.tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
    b.item = it
    b:SetScript("OnClick", function()
      O.Try("owl wardrobe click", function()
        local cos = Cos()
        if cos.own[it.id] then
          if cos.worn[slot] == it.id then cos.worn[slot] = false else cos.worn[slot] = it.id end
          ApplyLook()
          if O.OwlWardrobeSound then pcall(O.OwlWardrobeSound) end
        end
        RefreshWardrobe()
        info:SetText(HowTo(it))
      end)
    end)
    itemButtons[#itemButtons + 1] = b
  end
end
local goalsHead = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
goalsHead:SetPoint("TOPLEFT", 14, -(58 + 8 * (BTN + 6) + 10))
goalsHead:SetText("Goals he has set himself")
for i = 1, 3 do
  local y = -(58 + 8 * (BTN + 6) + 10) - 22 - (i - 1) * 26
  local line = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  line:SetPoint("TOPLEFT", 14, y - 5)
  local swap = CreateFrame("Button", nil, wardrobe)
  swap:SetSize(120, 22)
  swap:SetPoint("TOPRIGHT", wardrobe, "TOPRIGHT", -12, y)
  Plain2(swap)
  swap.label = swap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  swap.label:SetPoint("CENTER", 0, 0)
  swap.label:SetText("A different goal")
  swap:SetScript("OnClick", function() O.Try("owl goal swap", function() O.commands.goals("swap " .. i) RefreshWardrobe() end) end)
  goalRows[i] = { line = line, swap = swap }
end
local close = CreateFrame("Button", nil, wardrobe)
close:SetSize(70, 22)
close:SetPoint("TOPRIGHT", wardrobe, "TOPRIGHT", -8, -8)
Plain2(close)
close.label = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
close.label:SetPoint("CENTER", 0, 0)
close.label:SetText("Close")
close:SetScript("OnClick", function() wardrobe:Hide() end)
local bare = CreateFrame("Button", nil, wardrobe)
bare:SetSize(150, 22)
bare:SetPoint("TOPRIGHT", wardrobe, "TOPRIGHT", -86, -8)
Plain2(bare)
bare.label = bare:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bare.label:SetPoint("CENTER", 0, 0)
bare.label:SetText("Take everything off")
bare:SetScript("OnClick", function() O.Try("owl wardrobe bare", function()
  local c = Cos()
  for _, slot in ipairs(SLOTS) do c.worn[slot] = slot == "perch" and "branch" or false end
  ApplyLook() RefreshWardrobe() info:SetText("")
end) end)

local trial, bodyRows = {}, {}
local function BodyRow(n, key)
  local y = -350 - (n - 1) * 34
  local row = { key = key }
  local function Arrow(x, text, step)
    local b = CreateFrame("Button", nil, wardrobe)
    b:SetSize(26, 28)
    b:SetPoint("TOPLEFT", wardrobe, "TOPLEFT", x, y)
    Plain2(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text)
    b:SetScript("OnClick", function()
      O.Try("owl wardrobe body", function()
        local list, body = BODY_LISTS[key], Body()
        local first, last = key == "m" and 0 or 1, key == "m" and #list or #list
        local at = (trial[key] or body[key]) + step
        if at > last then at = first elseif at < first then at = last end
        local open, how = BodyOpen(key, at)
        if open then
          body[key], trial[key] = at, nil
          ApplyLook()
          info:SetText(list[at] .. "\n|cff40ff40His " .. BODY_WORD[key] .. " now.|r")
        else
          trial[key] = at
          info:SetText(list[at] .. "\n|cffff8040Trying it on. Not earned yet:|r " .. tostring(how))
        end
        RefreshWardrobe()
      end)
    end)
    return b
  end
  row.prev = Arrow(14, "<", -1)
  row.text = wardrobe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.text:SetPoint("TOPLEFT", wardrobe, "TOPLEFT", 44, y - 2)
  row.text:SetWidth(140)
  row.nextB = Arrow(188, ">", 1)
  bodyRows[#bodyRows + 1] = row
end
BodyRow(1, "p")
BodyRow(2, "c")
BodyRow(3, "m")
wardrobe:SetScript("OnHide", function() trial = {} end)
RefreshWardrobe = function()
  local c = Cos()
  local owned = Count(c.own)
  local rareOwned, rareAll = #OwnedRare("extra") + #OwnedRare("gem"), #RARE.extra + #RARE.gem
  wardrobe.title:SetText(Name() .. "'s wardrobe  |cffffd100" .. (owned - rareOwned) .. " of " .. (#ITEMS - rareAll) .. "|r   |cff66ccffrare finds " .. rareOwned .. " of " .. rareAll .. "|r")
  for _, p in ipairs(pickers) do
    local list, worn = OwnedRare(p.slot), c.worn[p.slot]
    local it = worn and ITEM[worn]
    p.text:SetText(((it and it.rare and c.own[worn]) and Shown(worn, nil, true) or "|cff909090none worn|r") .. "\n|cff909090" .. #list .. " of " .. #RARE[p.slot] .. " found|r")
  end
  local shown, body = Worn(), Body()
  for _, key in ipairs({ "p", "c", "m" }) do if trial[key] then shown.body[key] = trial[key] end end
  Dress(preview.stack, shown)
  for _, row in ipairs(bodyRows) do
    local list, at = BODY_LISTS[row.key], trial[row.key] or body[row.key]
    local open = BodyOpen(row.key, at)
    local n, total = 0, 0
    for i = (row.key == "m" and 0 or 1), #list do total = total + 1 if BodyOpen(row.key, i) then n = n + 1 end end
    row.text:SetText((open and "|cffffffff" or "|cffff8040") .. list[at] .. "|r\n|cff909090" .. BODY_WORD[row.key] .. ", " .. n .. " of " .. total .. " open|r")
  end
  for _, b in ipairs(itemButtons) do
    local it = b.item
    local own, on = c.own[it.id], c.worn[it.slot] == it.id and OwlHUDDB.outfit ~= false
    b.on = own and on
    if b.tex.SetVertexColor then if own then b.tex:SetVertexColor(1, 1, 1) else b.tex:SetVertexColor(0.16, 0.16, 0.2) end end
    if b.on then b.bg:SetColorTexture(0.72, 0.55, 0.14, 1) else b.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95) end
  end
  for i = 1, 3 do
    local g, row = c.goals[i], goalRows[i]
    if g and GOAL[g.id] then
      local w = Words(g)
      row.line:SetText(w:sub(1, 1):upper() .. w:sub(2) .. ": |cffffd100" .. Progress(g) .. " of " .. g.n .. "|r  for the " .. ITEM[g.id].name)
      row.swap:Show()
    else
      row.line:SetText(i == 1 and "|cff909090Nothing left to earn. He has it all.|r" or "")
      row.swap:Hide()
    end
  end
end
O.commands.wardrobe = function()
  if wardrobe:IsShown() then wardrobe:Hide() return end
  CheckGoals()
  RefreshWardrobe()
  info:SetText("")
  wardrobe:Show()
end
O.commands.goals = function(arg)
  local c = Cos()
  local n = tostring(arg or ""):match("^swap%s*(%d)")
  if arg == "off" or arg == "on" then
    OwlHUDDB.goals = arg == "on"
    O.Print("the owl talking about his goals" .. (OwlHUDDB.goals and ": |cff40ff40on|r" or ": |cffff4040off|r (they still count)"))
    return
  end
  if n then
    local g = c.goals[tonumber(n)]
    if not g then O.Print("no goal number " .. n .. ".") return end
    c.skip[g.id] = (Num(c.skip[g.id]) or 0) + 1
    table.remove(c.goals, tonumber(n))
    local def = NextDef(c)
    if not def then def = GOAL[g.id] end
    table.insert(c.goals, tonumber(n), Start(def))
    O.Print(Name() .. " swapped that goal for: " .. Words(c.goals[tonumber(n)]) .. " (for the " .. ITEM[def.item].name .. ").")
    return
  end
  CheckGoals()
  O.Print(Name() .. "'s goals (" .. Count(c.own) .. " of " .. #ITEMS .. " things earned):")
  for i, g in ipairs(c.goals) do
    local w = Words(g)
    print("  " .. i .. ". " .. w:sub(1, 1):upper() .. w:sub(2) .. ": " .. Progress(g) .. " of " .. g.n .. "  ->  " .. ITEM[g.id].name)
  end
  if #c.goals == 0 then print("  Nothing left to earn.") end
  print("  /owl wardrobe to dress him. /owl goals swap 2 trades the second goal for another. /owl goals off stops him talking about them.")
end
O.commands.outfit = function()
  OwlHUDDB.outfit = OwlHUDDB.outfit == false
  ApplyLook()
  O.Print("the things he wears" .. (OwlHUDDB.outfit and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
local function BodyCommand(key)
  return function(arg)
    local list, body = BODY_LISTS[key], Body()
    local want = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if want ~= "" then
      for i = (key == "m" and 0 or 1), #list do
        if list[i]:lower():find(want, 1, true) then
          local open, how = BodyOpen(key, i)
          if open then body[key] = i ApplyLook() O.Print(Name() .. "'s " .. BODY_WORD[key] .. ": " .. list[i] .. ".")
          else O.Print(list[i] .. " is not earned yet. " .. tostring(how)) end
          return
        end
      end
    end
    O.Print("|cffffd100" .. Name() .. "'s " .. BODY_WORD[key] .. "|r")
    for i = (key == "m" and 0 or 1), #list do
      local open, how = BodyOpen(key, i)
      print("  " .. (open and "|cff40ff40" or "|cff909090") .. list[i] .. "|r" .. (body[key] == i and "  |cffffd100his now|r" or "") .. (open and "" or ("  - " .. tostring(how))))
    end
    print("  Pick one: /owl " .. (key == "p" and "plumage snowy" or key == "c" and "head antlers" or "marks runes") .. ", or use the arrows under his picture in /owl wardrobe.")
  end
end
O.commands.plumage, O.commands.head, O.commands.marks = BodyCommand("p"), BodyCommand("c"), BodyCommand("m")
O.commands.wear = function(arg)
  local want = tostring(arg or ""):lower()
  for _, it in ipairs(ITEMS) do
    local item = ITEM[it[1]]
    if want ~= "" and (item.id == want or item.name:lower():find(want, 1, true)) then
      if Wear(item.id) then O.Print(Name() .. " puts on the " .. item.name .. ".") else O.Print(Name() .. " has not earned the " .. item.name .. " yet. /owl goals") end
      return
    end
  end
  O.Print("wear what? Try /owl wardrobe, or /owl wear scarf.")
end
end


-- ---------- the first meeting: a name, his feathers, and how much he should do ----------
do
local NAMES = { "Hooty", "Archimedes", "Pip", "Bramble", "Nyx", "Sorrel", "Orin", "Moss", "Juniper", "Quill", "Tallow", "Wren" }
local HELPER_COMMANDS = { sell = "sell", repair = "repair", fastloot = "loot", classic = "classic", sides = "sides", questMark = "questmark", gatherMark = "gather", ding = "ding" }
local win, choice, RefreshWelcome = nil, "owl", nil
local function Finish()
  if OwlHUDDB.setup ~= "new" then return end
  OwlHUDDB.setup = choice
  OwlHUDDB.firstRunDone = true
  if choice == "full" then
    for _, key in ipairs(O.HELPERS or {}) do
      local fn = O.commands[HELPER_COMMANDS[key] or ""]
      if not OwlHUDDB[key] and type(fn) == "function" then O.Try("owl setup " .. key, fn, "") end
    end
    if O.FullSetup then O.Try("owl setup", O.FullSetup) end
  end
  Say("welcome1", "I am " .. Name() .. ". I watch, I remember, and I talk. Click me for everything I can do.", 0)
  Say("welcome2", "Right-click me if I am ever too chatty. And look in my wardrobe: I have goals of my own.", 0)
  if O.OwlBurst then pcall(O.OwlBurst, true) end
end
local function Build()
  if win then return win end
  local W, H = 640, 452
  win = CreateFrame("Frame", "OwlHUDWelcome", UIParent)
  win:SetSize(W, H)
  win:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
  win:SetFrameStrata("DIALOG")
  win:EnableMouse(true)
  win.bg = win:CreateTexture(nil, "BACKGROUND")
  win.bg:SetAllPoints()
  win.bg:SetColorTexture(0.06, 0.05, 0.03, 0.97)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = win:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.89, 0.7, 0.29, 0.95)
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT", win, side .. "LEFT", 0, 0) line:SetPoint(side .. "RIGHT", win, side .. "RIGHT", 0, 0) line:SetHeight(2)
    else
      line:SetPoint("TOP" .. side, win, "TOP" .. side, 0, 0) line:SetPoint("BOTTOM" .. side, win, "BOTTOM" .. side, 0, 0) line:SetWidth(2)
    end
  end
  local function Text(font, x, y, text, width)
    local fs = win:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", x, y)
    if width then fs:SetWidth(width) if fs.SetJustifyH then fs:SetJustifyH("LEFT") end end
    fs:SetText(text)
    return fs
  end
  win.title = Text("GameFontNormalLarge", 16, -14, "Hoo. I am your owl.")
  Text("GameFontHighlightSmall", 17, -36, "Four quick choices and we are off. You can change every one of them later by clicking me.")
  local view = CreateFrame("Frame", nil, win)
  view:SetSize(190, 190)
  view:SetPoint("TOPLEFT", 16, -70)
  win.stack = Stack(view)
  win.stack.face = "owl_happy.tga"
  win.stack.owl:SetAllPoints(view)
  win.stack.owl:SetTexture(MEDIA .. "owl_happy.tga")
  win.stack.perch:SetAllPoints(view)
  win.stack.aura:SetPoint("CENTER", view, "CENTER", 0, 0)
  win.nameShown = Text("GameFontNormalLarge", 16, -268, "", 190)
  if win.nameShown.SetJustifyH then win.nameShown:SetJustifyH("CENTER") end
  win.buttons = {}
  local function Button(x, y, width, label, isOn, onClick)
    local b = CreateFrame("Button", nil, win)
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", win, "TOPLEFT", x, y)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(label)
    b.isOn = isOn
    b:SetScript("OnClick", function() O.Try("owl welcome", onClick) RefreshWelcome() end)
    win.buttons[#win.buttons + 1] = b
    return b
  end
  local X = 232
  Text("GameFontNormal", X, -70, "1. My name")
  for i, name in ipairs(NAMES) do
    Button(X + ((i - 1) % 4) * 98, -90 - math.floor((i - 1) / 4) * 28, 94, name, function() return Name() == name end, function() OwlHUDDB.owlName = name ApplyName() end)
  end
  Text("GameFontHighlightSmall", X, -180, "or type one and press Enter:")
  local box = CreateFrame("EditBox", nil, win)
  box:SetSize(170, 22)
  box:SetPoint("TOPLEFT", win, "TOPLEFT", X + 176, -175)
  if box.SetFontObject then box:SetFontObject("GameFontHighlight") end
  if box.SetAutoFocus then box:SetAutoFocus(false) end
  if box.SetMaxLetters then box:SetMaxLetters(16) end
  box.bg = box:CreateTexture(nil, "BACKGROUND")
  box.bg:SetAllPoints()
  box.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95)
  box:SetScript("OnEnterPressed", function(self)
    local text = tostring(self:GetText() or ""):gsub("[^%a ]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 16)
    if text ~= "" then OwlHUDDB.owlName = text:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b:lower() end) ApplyName() end
    if self.ClearFocus then self:ClearFocus() end
    RefreshWelcome()
  end)
  box:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
  Text("GameFontNormal", X, -210, "2. My feathers")
  for i = 1, 4 do Button(X + (i - 1) * 98, -230, 94, PLUMES[i], function() return Body().p == i end, function() Body().p = i ApplyLook() end) end
  Text("GameFontNormal", X, -264, "3. My head")
  for i = 1, 3 do Button(X + (i - 1) * 131, -284, 127, CRESTS[i], function() return Body().c == i end, function() Body().c = i ApplyLook() end) end
  Text("GameFontNormal", X, -318, "4. What should I do for you?")
  Button(X, -338, 193, "Just the owl", function() return choice == "owl" end, function() choice = "owl" end)
  Button(X + 197, -338, 193, "The owl and his helpers", function() return choice == "full" end, function() choice = "full" end)
  win.explain = Text("GameFontHighlightSmall", X, -368, "", 392)
  local go = Button(W - 16 - 170, -(H - 38), 170, "Let us go", function() return true end, function() win:Hide() end)
  go.label:SetFontObject("GameFontNormal")
  win:SetScript("OnHide", function() O.Try("owl welcome done", Finish) end)
  win:Hide()
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "OwlHUDWelcome") end
  return win
end
RefreshWelcome = function()
  if not win then return end
  win.nameShown:SetText(Name())
  for _, b in ipairs(win.buttons) do
    local ok, on = pcall(b.isOn)
    if ok and on then b.bg:SetColorTexture(0.72, 0.55, 0.14, 1) else b.bg:SetColorTexture(0.16, 0.12, 0.06, 0.95) end
  end
  win.explain:SetText(choice == "owl" and "He watches, warns, remembers and talks, and changes nothing else. Nothing is sold, repaired or added to your screen."
    or "As well as the owl: grey junk is sold and gear repaired at vendors, loot is picked up fast, and hearts, side bars and quest markers are added to your screen.")
  Dress(win.stack, Worn())
end
O.commands.welcome = function()
  Build()
  RefreshWelcome()
  win:Show()
end
O.On("PLAYER_LOGIN", function()
  if OwlHUDDB.setup ~= "new" then return end
  if C_Timer and C_Timer.After then C_Timer.After(4, function() O.Try("owl welcome", O.commands.welcome) end) else O.Try("owl welcome", O.commands.welcome) end
end)
Owl.cos.welcome = { Finish = Finish, Pick = function(c) choice = c end, Window = function() return win end }
end
O.On("PLAYER_LOGIN", function()
  O.Try("owl wardrobe", function()
    BondGifts(true)
    ApplyLook()
    SeePlace()
    if C_Timer and C_Timer.After then C_Timer.After(25, function() O.Try("owl goals", function() FillGoals(true) end) end) else FillGoals(true) end
  end)
end)
end
O.Try("owl wardrobe setup", Owl.WardrobeSetup)
O.OwlTestCos = function() return Owl.cos end

-- =====================================================================================
-- Owls among friends: emotes, gifts, hoot-offs, looking out for each other's players,
-- friendships, shared goals, owl post, and where everyone is
-- =====================================================================================
O.defaults.social = true
Owl.SocialSetup = function()
local Sub, Count, PartyNames = Owl.lib.Sub, Owl.lib.Count, Owl.lib.PartyNames
local cos = Owl.cos
local function On() return OwlHUDDB.social ~= false end
local function Soc()
  local s = Sub(Record(), "social")
  Sub(s, "pals") Sub(s, "duel") Sub(s, "inbox") Sub(s, "outbox") Sub(s, "notes") Sub(s, "gifts")
  return s
end
local function Cap(name) name = tostring(name or "") return name:sub(1, 1):upper() .. name:sub(2) end
local function Strip(text, limit) return (tostring(text or ""):gsub("[|%c]", ""):sub(1, limit or 60)) end
local function After(seconds, fn)
  if C_Timer and C_Timer.After then C_Timer.After(seconds, function() O.Try("owl friends later", fn) end) else O.Try("owl friends later", fn) end
end

-- who is here this session: [name] = { owl, obj = {}, kills = n, told = {} }
local peers = {}
local function Grouped(name)
  if Q("IsInRaid") then return peers[name] ~= nil end
  for _, n in ipairs(PartyNames()) do if n == name then return true end end
  return false
end
local function Here()
  local list = {}
  for name in pairs(peers) do if Grouped(name) then list[#list + 1] = name end end
  table.sort(list)
  return list
end
local function FriendOnline(name)
  if Grouped(name) then return true end
  if Owl.FL then
    for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
      local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
      local n = ok and type(info) == "table" and Plain(info.connected) and Str(Plain(info.name))
      if n and Owl.First((n:gsub("%-.*$", ""))) == name then return true end
    end
  end
  return false
end
local function Party(kind, extra) return Owl.net and Owl.net.Send(kind, extra) or false end
local function Whisper(who, kind, extra)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  return (pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", kind .. "|" .. Name() .. "|" .. tostring(extra or ""), "WHISPER", Owl.Addr(who)))
end
local function To(who, kind, extra) if Grouped(who) then return Party(kind, extra) end return Whisper(who, kind, extra) end
-- friends whose owls are beside yours without a group
local function Far()
  local list = {}
  for name in pairs(cos.friends or {}) do if not Grouped(name) then list[#list + 1] = name end end
  table.sort(list)
  return list
end
local function OnlineFriends()
  local set, list = {}, {}
  if Owl.FL then
    for i = 1, math.min(Num(Plain(Owl.FL.GetNumFriends())) or 0, 100) do
      local ok, info = pcall(Owl.FL.GetFriendInfoByIndex, i)
      local n = ok and type(info) == "table" and Plain(info.connected) and Str(Plain(info.name))
      if n then
        local listed = n:gsub("%-.*$", "")
        n = Owl.First(listed)
        Owl.Full(n, listed)
        if not set[n] and n ~= Me() and #list < 20 then set[n] = true list[#list + 1] = n end
      end
    end
  end
  return list
end
local function Whereabouts() return Level() .. ", " .. Strip(Zone(), 40) end
local function HelloFar()
  if not On() or OwlHUDDB.farOwls == false then return end
  for _, name in ipairs(OnlineFriends()) do if not Grouped(name) then Whisper(name, "HELLO", Level()) end end
end
local function OwlOf(name)
  if peers[name] and peers[name].owl then return peers[name].owl end
  local pal = Soc().pals[name]
  return type(pal) == "table" and pal.owl or (name .. "'s owl")
end
-- the friend a command is meant for: a name, or the only owl here, or your target
local function Who(arg)
  arg = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  local here = Here()
  if arg ~= "" then
    for name in pairs(peers) do if name:lower() == arg then return name end end
    for name in pairs(Soc().pals) do if name:lower() == arg then return name end end
    return Cap(arg)
  end
  local target = Q("UnitExists", "target") and Str(Plain(UnitName("target")))
  if target and peers[target] then return target end
  if #here >= 1 then return here[1] end
  local far = Far()
  if #far >= 1 then return far[1] end
  return nil
end
local function NeedWho(what)
  O.Print("who? Group with a friend who has an owl, or name them: /owl " .. what .. " Thicc")
end

-- ---------- friendships between owls ----------
local PAL = { { 0, "Acquainted" }, { 30, "Friends" }, { 120, "Good friends" }, { 300, "Best friends" } }
local function PalLevel(mins) local level = 1 for i, p in ipairs(PAL) do if mins >= p[1] then level = i end end return level end
local function Pal(name, owl)
  local pals = Soc().pals
  if type(pals[name]) ~= "table" then
    if Count(pals) >= 40 then return { mins = 0 } end
    pals[name] = { mins = 0, owl = owl, met = Clock() }
  end
  if owl and owl ~= "" and owl ~= "An owl" then pals[name].owl = owl end
  return pals[name]
end
local function PalGifts()
  local best = 1
  for _, p in pairs(Soc().pals) do if type(p) == "table" then best = math.max(best, PalLevel(Num(p.mins) or 0)) end end
  if best >= 2 then cos.Unlock("braid", "Our owls are friends now") end
  if best >= 4 then cos.Unlock("lantern", "Best friends, the owls and their people") end
end
local function AddMinutes(name, n)
  local p = Pal(name, peers[name] and peers[name].owl)
  local before = PalLevel(Num(p.mins) or 0)
  p.mins = (Num(p.mins) or 0) + n
  local after = PalLevel(p.mins)
  if after > before then
    Say("pal" .. name .. after, OwlOf(name) .. " and I are " .. PAL[after][2]:lower() .. " now. That is thanks to you and " .. name .. ".", 0)
    pcall(Note, Name() .. " and " .. OwlOf(name) .. " became " .. PAL[after][2]:lower() .. ".")
    PalGifts()
  end
end
local function Peer(name, owl)
  local p = peers[name]
  if not p then p = { obj = {}, kills = 0, told = {} } peers[name] = p end
  if owl and owl ~= "" then p.owl = owl end
  Pal(name, owl)
  return p
end

-- ---------- emotes ----------
local EMOTES = {
  bow = { word = "bows", me = "bow", mine = { "I bowed. Very dignified.", "A proper bow." }, got = "%s bows to us. I bowed back, lower." },
  dance = { word = "dances", me = "dance", mine = { "Watch these feet.", "I am dancing. Do not film this." }, got = "%s is dancing. Fine. I am dancing too." },
  five = { word = "High five!", me = "cheer", mine = { "Wing up!", "High five. High wing. You know what I mean." }, got = "%s wants a high five. Wing up!" },
  hug = { word = "hugs", me = "puff", mine = { "A hug, sent by owl.", "I puffed up and hugged." }, got = "%s sent a hug. I am puffed up to twice my size." },
}
local function DoEmote(kind, arg)
  local e = EMOTES[kind]
  if cos.Idle then pcall(cos.Idle, e.me, kind == "dance" and 2.4 or 1.2) end
  local who = Who(arg)
  if who and On() and (Grouped(who) or (cos.friends and cos.friends[who])) then
    To(who, "EMOTE", kind .. "," .. who .. ",0")
    Say("emo" .. kind .. Now(), e.mine, 0, "c")
  elseif #Here() > 0 and On() then
    Party("EMOTE", kind .. ",,0")
    Say("emo" .. kind .. Now(), e.mine, 0, "c")
  else
    Say("emo" .. kind .. Now(), e.mine, 0, "c")
  end
end
for kind in pairs(EMOTES) do O.commands[kind] = function(arg) DoEmote(kind, arg) end end

-- ---------- hoot-offs ----------
local duel = { with = nil, roll = 0, till = 0 }
local function DuelResult(name, mine, theirs)
  local score = Soc().duel
  if type(score[name]) ~= "table" then score[name] = { w = 0, l = 0 } end
  local s = score[name]
  local owl = OwlOf(name)
  local line
  if mine > theirs then
    s.w = s.w + 1
    line = "Hoot-off! I hooted " .. mine .. ", " .. owl .. " hooted " .. theirs .. ". I win. That is " .. s.w .. " to " .. s.l .. "."
    if cos.Idle then pcall(cos.Idle, "cheer", 1) end
  else
    s.l = s.l + 1
    line = "Hoot-off! " .. owl .. " hooted " .. theirs .. ", I hooted " .. mine .. ". " .. owl .. " wins. " .. s.w .. " to " .. s.l .. ". I want a rematch."
    if cos.Hop then pcall(cos.Hop, name, "Hoo!") end
  end
  Say("duel" .. name .. Now(), line, 0, "c")
end
O.commands.hootoff = function(arg)
  local who = Who(arg)
  if not who then NeedWho("hootoff") return end
  if not FriendOnline(who) then O.Print(who .. " is not around for a hoot-off.") return end
  if Now() < duel.till then O.Print("one hoot-off at a time.") return end
  duel.with, duel.roll, duel.till = who, math.random(100), Now() + 8
  To(who, "DUEL", who .. "," .. duel.roll)
  O.Print(Name() .. " challenges " .. OwlOf(who) .. " to a hoot-off...")
end

-- ---------- gifts ----------
local TREATS = { "a honey cake", "a shiny button", "a fat moth", "a sprig of mint", "a smooth river stone", "a toy mouse", "a ribbon", "a candied beetle" }
O.commands.gift = function(arg)
  local who = Who(arg)
  if not who then NeedWho("gift") return end
  if not FriendOnline(who) then O.Print(who .. " is not online. Try /owl post " .. who .. " <a note> and I will deliver it later.") return end
  local s = Soc()
  local today = math.floor(Clock() / 86400)
  local g = s.gifts[who]
  if type(g) ~= "table" or g.day ~= today then g = { day = today, n = 0 } s.gifts[who] = g end
  if g.n >= 3 then O.Print("three gifts a day for " .. OwlOf(who) .. ". Any more and they will get spoiled.") return end
  g.n = g.n + 1
  local i = math.random(#TREATS)
  To(who, "GIFT", who .. "," .. i)
  if Owl.AddBond then pcall(Owl.AddBond, 1) end
  Say("gift" .. who .. Now(), "I sent " .. OwlOf(who) .. " " .. TREATS[i] .. ". From both of us.", 0, "c")
end

-- ---------- looking out for each other ----------
local myCare = {}
local CARE = {
  dur = "%s says %s's gear is about to break. Point them at a repairer.",
  food = "%s says %s is almost out of food and water. Share some?",
  bags = "%s says %s's bags are full.",
}
local function CareCheck()
  if #Here() == 0 or Plain(UnitAffectingCombat("player")) then return end
  local now = {}
  local okD, dur = pcall(Durability)
  if okD and type(dur) == "number" then now.dur = dur < 0.1 end
  local okS, food = pcall(Supplies)
  if okS and type(food) == "number" then now.food = food < 5 end
  local okB, free = pcall(Owl.FreeBagSlots)
  if okB and type(free) == "number" then now.bags = free <= 0 end
  for kind, bad in pairs(now) do
    if bad and not myCare[kind] then Party("CARE", kind .. ",") end
    myCare[kind] = bad
  end
end
O.On("PLAYER_DEAD", function()
  if #Here() > 0 and On() then Party("CARE", "down," .. Strip(Owl.lib.SubZone and Owl.lib.SubZone() or Zone(), 40)) end
end)

-- ---------- quest progress, side by side ----------
local myObj = {}
local function Compare(name, what)
  local mine, theirs = myObj[what], peers[name] and peers[name].obj[what]
  if not (mine and theirs) or not Grouped(name) then return end
  local key = "objsync" .. name .. what .. mine.have .. theirs.have
  if mine.have >= mine.need and theirs.have < theirs.need then
    Say(key, name .. " still needs " .. (theirs.need - theirs.have) .. " more " .. what .. ". You are done, so stay and help.", 0)
  elseif theirs.have >= theirs.need and mine.have < mine.need then
    Say(key, name .. " is done with " .. what .. ". You need " .. (mine.need - mine.have) .. " more.", 0)
  elseif mine.have >= mine.need and theirs.have >= theirs.need then
    Say("objboth" .. name .. what, "You and " .. name .. " are both done with " .. what .. ". On we go.", 0)
  end
end
local baseObjective = O.OwlObjective
O.OwlObjective = function(what, have, need)
  local result = false
  if baseObjective then result = baseObjective(what, have, need) end
  if On() and type(what) == "string" and type(have) == "number" and type(need) == "number" then
    what = Strip(what, 50)
    myObj[what] = { have = have, need = need }
    if #Here() > 0 then
      Party("OBJ", have .. "/" .. need .. ":" .. what)
      for _, name in ipairs(Here()) do Compare(name, what) end
    end
  end
  return result
end

-- ---------- everyone's ready check ----------
local ready = { till = 0, replies = {} }
local function MyReady()
  local ok, good, bad = pcall(ReadyReport)
  if not ok or type(bad) ~= "table" then return "ok" end
  if #bad == 0 then return "ok" end
  return Strip(table.concat(bad, "; "), 80)
end
local function ReadyDone()
  if ready.till == 0 then return end
  ready.till = 0
  O.Print("|cffffd100Ready check, by owl|r")
  local mine = MyReady()
  print("  " .. Me() .. ": " .. (mine == "ok" and "|cff40ff40ready|r" or ("|cffff8040" .. mine .. "|r")))
  local notReady = mine == "ok" and 0 or 1
  for _, name in ipairs(PartyNames()) do
    local r = ready.replies[name]
    if r == nil then print("  " .. name .. ": |cff909090no owl answered|r")
    elseif r == "ok" then print("  " .. name .. ": |cff40ff40ready|r")
    else notReady = notReady + 1 print("  " .. name .. ": |cffff8040" .. r .. "|r") end
  end
  Say("readyall" .. Now(), notReady == 0 and "Every owl says ready. Go." or (notReady .. (notReady == 1 and " of us is" or " of us are") .. " not ready. The list is in chat."), 0, "c")
end
O.commands.readyall = function()
  if not Q("IsInGroup") then O.Print("you are not in a group. /owl ready checks just you.") return end
  ready.till, ready.replies = Now() + 3, {}
  Party("RDYQ", "")
  O.Print("asking the other owls...")
end

-- ---------- the party's kills, a goal for everyone, and the recap ----------
local sessKills, sentKills, wasHere = 0, 0, false
local SHARED = { { 150, "laurel", "Fellowship laurel" }, { 500, "campfire", "Campfire" } }
local function SharedCheck(before)
  local s = Soc()
  local total = Num(s.partyKills) or 0
  for _, g in ipairs(SHARED) do
    if total >= g[1] then
      cos.Unlock(g[2], "Together we beat " .. g[1] .. " foes")
    elseif before < g[1] / 2 and total >= g[1] / 2 then
      Say("sharedhalf" .. g[2], "Halfway to the " .. g[3] .. ": " .. total .. " of " .. g[1] .. " foes beaten together with friends.", 0)
    end
  end
end
local function AddShared(n)
  local s = Soc()
  local before = Num(s.partyKills) or 0
  s.partyKills = before + n
  SharedCheck(before)
end
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not msg:match("^(.-) dies") then return end
  if #Here() == 0 then return end
  sessKills = sessKills + 1
  AddShared(1)
end)
local function Board()
  local rows = { { Me(), sessKills } }
  for name, p in pairs(peers) do if (p.kills or 0) > 0 or Grouped(name) then rows[#rows + 1] = { name, p.kills or 0 } end end
  table.sort(rows, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
  return rows
end
local function Recap()
  local rows = Board()
  if #rows < 2 or rows[1][2] == 0 then return end
  local parts = {}
  for _, r in ipairs(rows) do parts[#parts + 1] = (r[1] == Me() and "you" or r[1]) .. " " .. r[2] end
  local top = rows[1][1]
  local tie = rows[2][2] == rows[1][2]
  local line = "Session over. Kills: " .. table.concat(parts, ", ") .. ". " .. (tie and "A tie at the top." or (top == Me() and "You take it." or (top .. " takes it.")))
  Say("recap" .. Now(), line, 0)
  O.Print(line)
  pcall(Note, "Played with " .. table.concat(Here(), ", ") .. ".")
end
O.commands.party = function()
  local here = Here()
  if #here == 0 then O.Print("no friends' owls in your group right now.") return end
  O.Print("|cffffd100The party, by owl|r  (foes beaten together, ever: " .. (Num(Soc().partyKills) or 0) .. ")")
  for _, r in ipairs(Board()) do print("  " .. r[1] .. ": " .. r[2] .. " kills this session") end
  for _, name in ipairs(here) do
    for what, o in pairs(peers[name].obj) do print("  " .. name .. ": " .. what .. " " .. o.have .. "/" .. o.need) end
  end
end

-- ---------- showing off, and a look in their wardrobe ----------
cos.onUnlock = function(id, tier)
  if not On() then return end
  local text = id .. (tier and ("." .. tier) or "")
  if #Here() > 0 then Party("GOT", text) end
  if tier and tier >= 4 then for _, name in ipairs(Far()) do Whisper(name, "GOT", text) end end   -- the big ones reach friends anywhere
end
O.commands.peek = function(arg)
  local who = Who(arg)
  if not who then NeedWho("peek") return end
  if not FriendOnline(who) then O.Print(who .. " is not online.") return end
  To(who, "PEEKQ", "")
  O.Print("asking " .. OwlOf(who) .. " to open the wardrobe...")
end
local function OwnText()
  local c, parts = cos.Cos(), {}
  local length = 0
  for i, id in ipairs(cos.ORDER) do
    if c.own[id] and length + #tostring(i) + 1 <= 80 then parts[#parts + 1] = tostring(i) length = length + #tostring(i) + 1 end
  end
  return table.concat(parts, ".")
end

-- ---------- notes the owls trade ----------
local notesSent = {}
local function SendNotes(name)
  if notesSent[name] then return end
  notesSent[name] = true
  local n = 0
  for rare, r in pairs(Sub(Record(), "rares")) do
    if type(r) == "table" and r.place and n < 3 then
      n = n + 1
      To(name, "NOTE", Strip(rare, 40) .. "@" .. Strip(r.place, 40))
    end
  end
end

-- ---------- owl post ----------
local function Flush(name)
  local s = Soc()
  local box = s.outbox[name]
  if type(box) ~= "table" then return end
  for _, m in ipairs(box) do To(name, "POST", m.id .. "," .. m.text) end
end
O.commands.post = function(arg, raw)
  local s = Soc()
  local text = tostring(raw or arg or "")
  local name, note = text:match("^(%S+)%s+(.+)$")
  if not name then
    O.Print("|cffffd100Owl post|r")
    local any = false
    for i = math.max(1, #s.inbox - 7), #s.inbox do
      local m = s.inbox[i]
      any = true
      print("  From " .. tostring(m.from) .. " (" .. Owl.lib.When(m.at) .. "): " .. tostring(m.text))
    end
    for who, box in pairs(s.outbox) do
      for _, m in ipairs(box) do any = true print("  |cff909090Waiting to deliver to " .. who .. ": " .. m.text .. "|r") end
    end
    if not any then print("  Nothing yet.") end
    print("  Send one: /owl post Thicc back at eight, save me the boss")
    return
  end
  name = Who(name)
  note = Strip(note, 70)
  if type(s.outbox[name]) ~= "table" then s.outbox[name] = {} end
  if #s.outbox[name] >= 3 then O.Print("three notes are already waiting for " .. name .. ". They go when " .. name .. " is on.") return end
  s.postId = (Num(s.postId) or 0) % 900 + 1
  table.insert(s.outbox[name], { id = s.postId, text = note, at = Clock() })
  if FriendOnline(name) then
    Flush(name)
    Say("postsent" .. Now(), "Off I go. A note for " .. name .. ".", 0, "c")
  else
    Say("postkept" .. Now(), "I will carry that to " .. name .. " the moment I see them online.", 0, "c")
  end
end
O.On("CHAT_MSG_SYSTEM", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" then return end
  local who = msg:match("%[([^%]]+)%]") or msg:match("^(%S+) has come online")
  if not who or not msg:find("online", 1, true) then return end
  who = who:gsub("%-.*$", "")
  if type(Soc().outbox[who]) == "table" and #Soc().outbox[who] > 0 then After(6, function() Flush(who) end) end
  if On() and OwlHUDDB.farOwls ~= false then After(8, function() Whisper(who, "HELLO", Level()) end) end
end)

-- ---------- where is everyone ----------
local whereTill = 0
O.commands.where = function()
  local asked = 0
  for name in pairs(Soc().pals) do
    if FriendOnline(name) then asked = asked + 1 To(name, "WHEREQ", "") end
  end
  if Q("IsInGuild") and C_ChatInfo and C_ChatInfo.SendAddonMessage then
    asked = asked + 1
    pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "WHEREQ|" .. Name() .. "|", "GUILD")
  end
  if asked == 0 then O.Print("none of your owl friends are online that I can see. Add them to your friends list and I can check.") return end
  whereTill = Now() + 4
  O.Print("asking the owls where everyone is...")
end
O.commands.pals = function()
  local s = Soc()
  O.Print("|cffffd100" .. Name() .. "'s friends|r")
  local any = false
  for name, p in pairs(s.pals) do
    if type(p) == "table" then
      any = true
      local level = PalLevel(Num(p.mins) or 0)
      local d = s.duel[name]
      local nextAt = PAL[level + 1]
      print("  " .. tostring(p.owl or "an owl") .. " (" .. name .. "): " .. PAL[level][2] .. ", " .. math.floor(Num(p.mins) or 0) .. " minutes together"
        .. (nextAt and (", " .. PAL[level + 1][2] .. " at " .. nextAt[1]) or "") .. (type(d) == "table" and (". Hoot-offs " .. d.w .. " to " .. d.l) or ""))
    end
  end
  if not any then print("  None yet. Group with a friend who runs OwlHUD.") end
  print("  /owl bow | dance | five | hug | hootoff | gift | peek | post | where | party | readyall")
end
O.commands.social = function()
  OwlHUDDB.social = OwlHUDDB.social == false
  O.Print("owls talking to friends' owls" .. (OwlHUDDB.social and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

-- ---------- what the other owls tell him ----------
local cheerAt = -100
local function Cheer(name, sendIt)
  if Now() - cheerAt < 10 then return end
  cheerAt = Now()
  if cos.Idle then pcall(cos.Idle, "cheer", 1.4) end
  if O.OwlBurst then pcall(O.OwlBurst, true) end
  for _, n in ipairs(Here()) do if cos.Hop then pcall(cos.Hop, n, "Hoo!", "cheer") end end
  if sendIt then
    if #Here() > 0 then Party("CHEER", Strip(name, 40)) end
    if #Here() > 0 then Say("cheer" .. Now(), "Every owl in the party is cheering. " .. tostring(name) .. " is down!", 0, "c") end
  end
end
O.On("BOSS_KILL", function(_, name) if On() then Cheer(Str(Plain(name)) or "The boss", true) end end)
O.On("ENCOUNTER_END", function(_, name, _, _, success) if On() and Plain(success) == 1 then Cheer(Str(Plain(name)) or "The boss", true) end end)

-- every owl says which version it is, so mismatches are said out loud instead of things quietly not working
local versions, verWait, verSent, verTold = {}, {}, {}, {}
local function VersionNews(sender, owl, theirs)
  if verTold[sender] then return end
  verTold[sender] = true
  if theirs < O.VERSION then
    Say("verold" .. sender, owl .. " is on an older OwlHUD than me. " .. sender .. " needs the update, or some of what our owls do together will not work.", 0)
  elseif theirs > O.VERSION then
    Say("vernew" .. sender, owl .. " is on a newer OwlHUD than me. Ask " .. sender .. " for the update.", 0)
  end
end
O.commands.version = function()
  O.Print("version " .. O.VERSION_TEXT .. ".")
  for name, v in pairs(versions) do
    print("  " .. name .. ": " .. (v == O.VERSION and "|cff40ff40the same version|r" or v == 0 and "|cffff8040an older version|r" or v < O.VERSION and "|cffff8040older|r" or "|cff66ccffnewer|r"))
  end
end
local farAt = {}
cos.onLook = function(text) if On() then for _, name in ipairs(Far()) do Whisper(name, "LOOK", text) end end end
local function ZonePing() if On() then for _, name in ipairs(Far()) do Whisper(name, "PING", Whereabouts()) end end end
O.On("ZONE_CHANGED_NEW_AREA", function() After(3, ZonePing) end)
O.On("PLAYER_LEVEL_UP", function() After(3, ZonePing) end)
local netBefore = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if not On() then return end
  extra = tostring(extra or "")
  local s = Soc()
  if kind == "VER" then
    local v = tonumber(extra)
    if v then versions[sender], verWait[sender] = v, nil VersionNews(sender, owl, v) end
    return
  end
  if kind == "HELLO" or kind == "HI" then
    Peer(sender, owl)
    if Now() - (verSent[sender] or -100) > 60 then verSent[sender] = Now() To(sender, "VER", O.VERSION) end
    if versions[sender] == nil and not verWait[sender] then verWait[sender] = { at = Now() + 25, owl = owl } end
    if not Grouped(sender) and OwlHUDDB.farOwls ~= false and Now() - (farAt[sender] or -100) > 20 then
      farAt[sender] = Now()
      if kind == "HELLO" then Whisper(sender, "HI", Level()) end
      Whisper(sender, "LOOK", cos.Look(cos.Worn()))
      Whisper(sender, "PING", Whereabouts())
    end
    After(3, function() SendNotes(sender) Flush(sender) end)
    return
  end
  local known = peers[sender] or s.pals[sender]
  if Grouped(sender) then Peer(sender, owl) end
  if kind == "EMOTE" then
    local what, target, re = extra:match("^(%a+),([^,]*),(%d)")
    local e = what and EMOTES[what]
    if not e or (target ~= "" and target ~= Me()) then return end
    if cos.Hop then pcall(cos.Hop, sender, e.word) end
    if re == "0" then
      Say("emogot" .. what .. sender, e.got:format(owl), 20, "c")
      After(1.2, function()
        if cos.Idle then pcall(cos.Idle, e.me, what == "dance" and 2.4 or 1.2) end
        if target == Me() then To(sender, "EMOTE", what .. "," .. sender .. ",1") end
      end)
    end
  elseif kind == "CHEER" then
    Cheer(extra, false)
  elseif kind == "DUEL" then
    local target, roll = extra:match("^([^,]+),(%d+)")
    roll = tonumber(roll)
    if target ~= Me() or not roll or roll < 1 or roll > 100 then return end
    local mine = math.random(100)
    while mine == roll do mine = math.random(100) end
    To(sender, "DUELR", sender .. "," .. roll .. "," .. mine)
    Peer(sender, owl)
    DuelResult(sender, mine, roll)
  elseif kind == "DUELR" then
    local target, mine, theirs = extra:match("^([^,]+),(%d+),(%d+)")
    if target ~= Me() or duel.with ~= sender or tonumber(mine) ~= duel.roll then return end
    duel.with, duel.till = nil, 0
    DuelResult(sender, duel.roll, tonumber(theirs))
  elseif kind == "GIFT" then
    local target, i = extra:match("^([^,]+),(%d+)")
    local treat = TREATS[tonumber(i) or 0]
    if target ~= Me() or not treat then return end
    Peer(sender, owl)
    if Owl.AddBond then pcall(Owl.AddBond, 3) end
    if cos.Idle then pcall(cos.Idle, "cheer", 1) end
    Say("giftgot" .. sender .. Now(), owl .. " sent me " .. treat .. ", from " .. sender .. ". Tell them thank you. I already did.", 0, "c")
    To(sender, "THANKS", sender .. "," .. i)
  elseif kind == "THANKS" then
    local target, i = extra:match("^([^,]+),(%d+)")
    if target == Me() and TREATS[tonumber(i) or 0] then Say("thanks" .. sender .. Now(), owl .. " says thank you for " .. TREATS[tonumber(i)] .. ".", 0) end
  elseif kind == "CARE" then
    local what, detail = extra:match("^(%a+),(.*)$")
    if not what or not Grouped(sender) then return end
    if what == "down" then
      local near = detail ~= "" and (" near " .. detail) or ""
      Owl.DeathSay(sender, "caredown" .. sender, { owl .. " says " .. sender .. " is down" .. near .. ".", sender .. " is down" .. near .. ". " .. owl .. " is calling for help.",
        sender .. " has fallen" .. near .. ". Get to them if you can." }, 60, "c")
    elseif CARE[what] then
      Say("care" .. what .. sender, CARE[what]:format(owl, sender), 600)
    end
  elseif kind == "OBJ" then
    local have, need, what = extra:match("^(%d+)/(%d+):(.+)$")
    if not what or not peers[sender] then return end
    if Count(peers[sender].obj) < 40 or peers[sender].obj[what] then peers[sender].obj[what] = { have = tonumber(have), need = tonumber(need) } end
    Compare(sender, what)
  elseif kind == "RDYQ" then
    if Grouped(sender) then Party("RDY", MyReady()) end
  elseif kind == "RDY" then
    if ready.till > 0 then ready.replies[sender] = extra == "" and "ok" or extra end
  elseif kind == "K" then
    local n = tonumber(extra)
    local p = peers[sender]
    if not (n and p) or not Grouped(sender) then return end
    local delta = n - (p.kills or 0)
    p.kills = n
    if delta > 0 and delta <= 200 then AddShared(delta) end
  elseif kind == "GOT" then
    local id, tier = extra:match("^([^%.]*)%.?(%d?)$")
    local it = cos.ITEM[id or ""]
    tier = tonumber(tier)
    if it and known and it.rare then
      local name = cos.Shown(id, tier or 1)
      local line = (tier or 1) >= 5 and (sender .. " found a " .. name .. ". LEGENDARY. " .. owl .. " will be unbearable.")
        or (tier or 1) >= 4 and (sender .. " found an " .. name .. ". I am not jealous. I am extremely jealous.")
        or (owl .. " found a " .. name .. " in " .. it.rare .. ". We should go there.")
      Say("got" .. sender .. extra, line, 0)
      if cos.Hop then pcall(cos.Hop, sender, (tier or 1) >= 4 and "!!!" or "Ta-da!") end
    elseif it and known then
      Say("got" .. sender .. extra, { owl .. " just earned the " .. it.name .. ". I am not jealous. I am a little jealous.", sender .. "'s owl has a new " .. it.name .. ". We should get one." }, 0)
      if cos.Hop then pcall(cos.Hop, sender, "Ta-da!") end
    end
  elseif kind == "PEEKQ" then
    if known then To(sender, "OWN", OwnText()) end
  elseif kind == "OWN" then
    local names = {}
    for i in extra:gmatch("%d+") do local it = cos.ITEM[cos.ORDER[tonumber(i)] or ""] if it then names[#names + 1] = it.name end end
    O.Print("|cffffd100" .. owl .. "'s wardrobe|r (" .. sender .. "): " .. #names .. " of " .. #cos.ORDER)
    for first = 1, #names, 4 do print("  " .. table.concat(names, ", ", first, math.min(first + 3, #names))) end
  elseif kind == "NOTE" then
    local rare, place = extra:match("^(.-)@(.+)$")
    if not rare or rare == "" or not known then return end
    if not s.notes[rare] and Count(s.notes) < 60 and not Sub(Record(), "rares")[rare] then
      s.notes[rare] = { place = place, from = sender }
      Say("notes" .. sender, owl .. " told me about a rare creature: " .. rare .. ", seen in " .. place .. ". Worth a look when we pass.", 1800)
    end
  elseif kind == "POST" then
    local id, text = extra:match("^(%d+),(.+)$")
    if not id or not known then return end
    Whisper(sender, "POSTOK", id)
    for _, m in ipairs(s.inbox) do if m.from == sender and m.id == tonumber(id) and Clock() - (m.at or 0) < 86400 then return end end
    table.insert(s.inbox, { from = sender, id = tonumber(id), text = text, at = Clock() })
    while #s.inbox > 20 do table.remove(s.inbox, 1) end
    Say("post" .. sender .. id .. Now(), "Owl post from " .. sender .. ": " .. text, 0, "c")
    if cos.Hop then pcall(cos.Hop, sender, "Post!") end
  elseif kind == "POSTOK" then
    local box = s.outbox[sender]
    if type(box) == "table" then
      for i = #box, 1, -1 do if box[i].id == tonumber(extra) then table.remove(box, i) end end
      if #box == 0 then s.outbox[sender] = nil end
    end
  elseif kind == "WHEREQ" then
    Whisper(sender, "HERE", Level() .. "," .. Strip(Zone(), 40))
  elseif kind == "HERE" then
    local level, zone = extra:match("^(%d+),(.+)$")
    if level and Now() < whereTill + 6 then
      Pal(sender, owl)
      O.Print(owl .. " says " .. sender .. " is in " .. zone .. " at level " .. level .. ".")
    end
  end
end

-- ---------- the clock ----------
local acc1, acc20, acc60, postAt, pingAt = 0, 0, 0, 300, 120
local driver = CreateFrame("Frame")
local dead = false
local function Step(e)
  acc1 = acc1 + e
  if acc1 < 1 then return end
  local dt = acc1
  acc1 = 0
  if ready.till > 0 and Now() >= ready.till then ReadyDone() end
  if not On() then return end
  for name, w in pairs(verWait) do
    if Now() >= w.at then verWait[name] = nil if versions[name] == nil then versions[name] = 0 VersionNews(name, w.owl, 0) end end
  end
  local here = Here()
  if #here == 0 and wasHere then
    wasHere = false
    Recap()
    sessKills, sentKills, myCare = 0, 0, {}
    for name, p in pairs(peers) do p.kills, p.obj = 0, {} end
  elseif #here > 0 then wasHere = true end
  acc20 = acc20 + dt
  if acc20 >= 20 then
    acc20 = 0
    if #here > 0 then
      CareCheck()
      if sessKills ~= sentKills then sentKills = sessKills Party("K", sessKills) end
    end
  end
  acc60 = acc60 + dt
  if acc60 >= 60 then
    acc60 = 0
    for _, name in ipairs(here) do AddMinutes(name, 1) end
  end
  pingAt = pingAt - dt
  if pingAt <= 0 then
    pingAt = 120
    ZonePing()
  end
  postAt = postAt - dt
  if postAt <= 0 then
    postAt = 300
    for name, box in pairs(Soc().outbox) do if type(box) == "table" and #box > 0 and FriendOnline(name) then Flush(name) end end
  end
end
driver:SetScript("OnUpdate", function(_, e)
  if dead then return end
  local ok, err = pcall(Step, e)
  if not ok then dead = true O.Print("|cffff4040owl friends turned off:|r " .. tostring(err)) end
end)
O.On("PLAYER_LOGIN", function() O.Try("owl pals", PalGifts) postAt = 30 After(10, HelloFar) end)
Owl.social = { peers = peers, Soc = Soc, Here = Here, Step = Step }
end
O.Try("owl friends setup", Owl.SocialSetup)
O.OwlTestSocial = function() return Owl.social end

-- =====================================================================================
-- Notes the owls pass each other: dangers, enemy players, rares, drops, quests, vendors,
-- gathering spots, flight paths, wish lists, spare goods, dungeons, hours, gossip, records
-- =====================================================================================
O.defaults.notes = true
Owl.NotesSetup = function()
local Sub, Count, PartyNames, SubZone = Owl.lib.Sub, Owl.lib.Count, Owl.lib.PartyNames, Owl.lib.SubZone
local cos, so = Owl.cos, Owl.social
local function On() return OwlHUDDB.social ~= false and OwlHUDDB.notes ~= false end
local function Soc() return so.Soc() end
local function Know()
  local k = Sub(Soc(), "know")
  Sub(k, "foes") Sub(k, "hours") Sub(k, "recs") Sub(k, "wish") Sub(k, "levels") Sub(k, "told")
  return k
end
local function Strip(text, limit) return (tostring(text or ""):gsub("[|%c]", ""):sub(1, limit or 40)) end
local function Lower(s) return tostring(s or ""):lower() end
local function Grouped(name) for _, n in ipairs(so.Here()) do if n == name then return true end end return false end
local function Friends()
  local set, list = {}, {}
  for _, n in ipairs(so.Here()) do if not set[n] then set[n] = true list[#list + 1] = n end end
  for n in pairs(cos.friends or {}) do if not set[n] then set[n] = true list[#list + 1] = n end end
  return list
end
local function Known(name) return so.peers[name] ~= nil or Soc().pals[name] ~= nil end
local function OwlOf(name)
  if so.peers[name] and so.peers[name].owl then return so.peers[name].owl end
  local pal = Soc().pals[name]
  return type(pal) == "table" and pal.owl or (name .. "'s owl")
end

-- ---------- sending, a little at a time ----------
local outbox, outAt = {}, 0
local function Raw(who, kind, text)
  if Grouped(who) then return Owl.net and Owl.net.Send(kind, text) end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", kind .. "|" .. Name() .. "|" .. text, "WHISPER", Owl.Addr(who)) end
end
-- who == nil means every friend's owl in reach
local function Out(who, kind, text)
  if not On() or #outbox >= 40 then return end
  text = Strip(text, 88)
  if who then outbox[#outbox + 1] = { who, kind, text } return end
  local party = false
  for _, n in ipairs(Friends()) do
    if Grouped(n) then
      if not party then party = true outbox[#outbox + 1] = { n, kind, text } end
    else outbox[#outbox + 1] = { n, kind, text } end
  end
end

-- ---------- hearing: one piece of gossip every few minutes, the rest waits ----------
local gossip, gossipAt = {}, -1000
local function Gossip(key, line, urgent)
  if urgent then Say(key, line, 0, "c") return end
  if #gossip < 6 then gossip[#gossip + 1] = { key, line, Now() + 900 } end
end

-- ---------- what he knows that is worth passing on ----------
local function TopFoes(limit)
  local list = {}
  for mob, f in pairs(Sub(Record(), "foes")) do if type(f) == "table" and (Num(f.deaths) or 0) > 0 then list[#list + 1] = { mob, f.deaths, f.deathZone or "" } end end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  while #list > limit do table.remove(list) end
  return list
end
local function UsualHour()
  local best, bestN, total = nil, 0, 0
  for hour, n in pairs(Sub(Record(), "hours")) do
    n = Num(n) or 0
    total = total + n
    if n > bestN then best, bestN = tonumber(hour), n end
  end
  if best and total >= 5 then return best end
end
local function MyRecords()
  local r = Sub(Record(), "records")
  return (Num(r.xp) or 0) .. "," .. (Num(r.kills) or 0) .. "," .. (Num(r.fastLevel) and math.floor(r.fastLevel) or 0)
end
local function MyWish()
  if type(Owl.WornRanks) ~= "function" or Plain(UnitAffectingCombat("player")) then return nil end
  local ok, list = pcall(Owl.WornRanks)
  if not ok or type(list) ~= "table" then return nil end
  local ranked = {}
  for _, e in ipairs(list) do if not e.best and Num(e.rank) and e.slot then ranked[#ranked + 1] = e end end
  table.sort(ranked, function(a, b) return a.rank > b.rank end)
  local parts = {}
  for i = 1, math.min(3, #ranked) do parts[i] = ranked[i].slot .. "=" .. ranked[i].rank end
  return #parts > 0 and table.concat(parts, ",") or nil
end
local greeted, greetAt = {}, {}
local function Introduce(name)
  if greeted[name] or not On() then return end
  greeted[name] = true
  for _, f in ipairs(TopFoes(3)) do Out(name, "N", "D:" .. Strip(f[1], 36) .. "@" .. Strip(f[3], 30) .. "#" .. f[2]) end
  local hour = UsualHour()
  if hour then Out(name, "N", "H:" .. hour) end
  Out(name, "N", "REC:" .. MyRecords())
  local wish = MyWish()
  if wish then Out(name, "N", "W:" .. wish) end
end

-- ---------- things that happen to you, passed on as they happen ----------
local levels, lastTarget = {}, nil
O.On("PLAYER_TARGET_CHANGED", function()
  if not Q("UnitExists", "target") then return end
  local name = Str(Plain(UnitName("target")))
  if not name then return end
  if Q("UnitCanAttack", "player", "target") and not Q("UnitIsPlayer", "target") then
    lastTarget = name
    local level = Num(Plain(UnitLevel("target")))
    if level and level > 0 then levels[name] = level end
    local f = Know().foes[name]
    if On() and type(f) == "table" then
      Say("knowfoe" .. name, "Careful. That one has killed " .. tostring(f.who) .. " " .. (f.n == 1 and "once" or (tostring(f.n) .. " times")) .. ". " .. OwlOf(f.who) .. " told me.", 900)
    end
  end
end)
O.On("PLAYER_DEAD", function()
  if not On() or #Friends() == 0 then return end
  local mob = lastTarget
  -- a warning about a dangerous creature is only sent when a creature did it
  local killer = Owl.killer
  if type(killer) == "table" then
    if killer.player or killer.pet then return end
    if killer.sure then mob = killer.name end
  end
  if not mob then return end
  local f = Sub(Record(), "foes")[mob]
  local n = type(f) == "table" and (Num(f.deaths) or 0) or 0
  Out(nil, "N", "DL:" .. Strip(mob, 36) .. "@" .. Strip(Zone(), 30) .. "#" .. math.max(1, n))
  local level = levels[mob]
  if level and level <= Level() - 5 then Out(nil, "N", "GOS:low," .. Strip(mob, 36) .. "," .. level) end
end)
Owl.onEnemy = function(name, what)
  if not On() or #Friends() == 0 then return end
  Out(nil, "N", "E:" .. Strip(name, 20) .. "," .. Strip(what, 24) .. "@" .. Strip(SubZone() or Zone(), 28) .. "~" .. Strip(Zone(), 28))
end
O.On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  msg = Plain(msg)
  local name = type(msg) == "string" and msg:match("^(.-) dies")
  if not name or not On() or #Friends() == 0 then return end
  local rare = Sub(Record(), "rares")[name]
  if type(rare) == "table" then Out(nil, "N", "RK:" .. Strip(name, 36) .. "@" .. Strip(rare.place or Zone(), 36)) end
end)
local baseSaid = O.OwlSaid
O.OwlSaid = function(text, ...)
  if baseSaid then pcall(baseSaid, text, ...) end
  if type(text) ~= "string" or not On() or #Friends() == 0 then return end
  if text:find("fighting with a fishing pole", 1, true) then Out(nil, "N", "GOS:pole,,0")
  elseif text:find("That one hurt. I flew.", 1, true) or text:find("Gravity. It gets everyone", 1, true) then Out(nil, "N", "GOS:fall,,0")
  elseif text:find("^You do not have the flight path for ") then Out(nil, "NQ", "F:" .. Strip(Zone(), 40)) end
end

-- ---------- quests: how long they took the others ----------
local function QuestTitle(id)
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
    if ok and Str(Plain(title)) then return Plain(title) end
  end
  return "that quest"
end
O.On("QUEST_ACCEPTED", function(a, b)
  local id = Num(Plain(b)) or Num(Plain(a))
  if not id then return end
  local s = Soc()
  local starts = Sub(s, "qstart")
  if Count(starts) < 60 then starts[tostring(id)] = Clock() end
  if On() and #Friends() > 0 then Out(nil, "NQ", "Q:" .. id) end
end)
O.On("QUEST_TURNED_IN", function(id)
  id = Num(Plain(id))
  if not id then return end
  local s = Soc()
  local starts, done = Sub(s, "qstart"), Sub(s, "qdone")
  local began = Num(starts[tostring(id)])
  starts[tostring(id)] = nil
  if Count(done) >= 400 then return end
  done[tostring(id)] = { m = began and math.max(1, math.floor((Clock() - began) / 60)) or 0, l = Level(), p = Strip(SubZone() or Zone(), 30) }
end)

-- ---------- what a quest wants: has a friend's owl seen it drop? ----------
local askedDrop = {}
local baseObjective = O.OwlObjective
O.OwlObjective = function(what, have, need)
  local result = false
  if baseObjective then result = baseObjective(what, have, need) end
  if On() and type(what) == "string" and not askedDrop[what] and #Friends() > 0 and Num(have) and Num(need) and have < need then
    askedDrop[what] = true
    Out(nil, "NQ", "DR:" .. Strip(what, 50))
  end
  return result
end
local function DropOf(what)
  local want, best = Lower(what), nil
  for mob, d in pairs(Sub(Record(), "drops")) do
    if type(d) == "table" then
      for item, n in pairs(d) do
        if Lower(item) == want and (not best or n > best[2]) then best = { mob, n } end
      end
    end
  end
  if not best then return nil end
  return best[1], best[2], Num(Sub(Record(), "tally")[best[1]]) or 0
end

-- ---------- asking around when you are short of something ----------
local askedZone = {}
local function VendorHere(kind)
  for name, v in pairs(Sub(Record(), "vendors")) do if type(v) == "table" and v.zone == Zone() and v[kind] then return name, v.place end end
end
local function ZoneAsks()
  if not On() or #Friends() == 0 or Plain(UnitAffectingCombat("player")) then return end
  local zone = Zone()
  local function once(key) if askedZone[key .. zone] then return false end askedZone[key .. zone] = true return true end
  local okD, dur = pcall(Durability)
  if okD and type(dur) == "number" and dur < 0.25 and not VendorHere("repair") and once("r") then Out(nil, "NQ", "V:" .. Strip(zone, 40) .. ",repair") end
  local okS, food = pcall(Supplies)
  if okS and type(food) == "number" and food < 5 and not VendorHere("food") and once("f") then Out(nil, "NQ", "V:" .. Strip(zone, 40) .. ",food") end
  local picks = Sub(Record(), "picks")
  if next(picks) and type(picks[zone]) ~= "table" and once("g") then Out(nil, "NQ", "G:" .. Strip(zone, 40)) end
end
O.commands.whohas = function(arg)
  arg = Strip(tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", ""), 30)
  if arg == "" then O.Print("who has what? Try /owl whohas silk") return end
  if #Friends() == 0 then O.Print("none of your friends' owls are in reach right now.") return end
  Out(nil, "NQ", "M:" .. arg)
  O.Print("asking the other owls who has " .. arg .. "...")
end
local function Has(word)
  word = Lower(word)
  local best, bestN = nil, 0
  local function look(t) if type(t) == "table" then for item, n in pairs(t) do n = Num(n) or 0 if Lower(item):find(word, 1, true) and n > bestN then best, bestN = item, n end end end end
  local ok, stock = pcall(Owl.lib.ScanStock)
  if ok then look(stock) end
  look(Record().bank)
  return best, bestN
end

-- ---------- all of you in range for the same dungeon ----------
local function DungeonCheck()
  if not On() or type(Owl.DUNGEONS) ~= "table" then return end
  local k = Know()
  local names, parts, lv = Friends(), { "you " .. Level() }, { Level() }
  if #names == 0 then return end
  table.sort(names)
  for _, n in ipairs(names) do
    local l = Num(k.levels[n])
    if not l then return end
    lv[#lv + 1] = l
    parts[#parts + 1] = n .. " " .. l
  end
  for _, d in ipairs(Owl.DUNGEONS) do
    local all = (not Owl.MineDungeon) or Owl.MineDungeon(d)
    for _, l in ipairs(lv) do if l < d[2] or l > d[3] then all = false end end
    local key = d[1] .. ":" .. table.concat(names, ",")
    if all and not k.told[key] then
      if Count(k.told) < 200 then k.told[key] = true end
      Gossip("dungall" .. key, (#lv == 2 and "Both" or ("All " .. #lv)) .. " of you are in range for " .. d[1] .. " now: " .. table.concat(parts, ", ") .. ".")
      return
    end
  end
end
local function SetLevel(name, level)
  level = tonumber(level)
  if not level or level < 1 or level > 80 then return end
  local k = Know()
  if k.levels[name] ~= level then k.levels[name] = level DungeonCheck() end
end

-- ---------- that goes in a slot a friend is weak in ----------
local EQUIP = { INVTYPE_HEAD = "helmet", INVTYPE_SHOULDER = "shoulders", INVTYPE_CLOAK = "cloak", INVTYPE_CHEST = "chest piece", INVTYPE_ROBE = "chest piece", INVTYPE_WRIST = "bracers",
  INVTYPE_HAND = "gloves", INVTYPE_WAIST = "belt", INVTYPE_LEGS = "leggings", INVTYPE_FEET = "boots", INVTYPE_FINGER = "ring", INVTYPE_NECK = "necklace",
  INVTYPE_WEAPON = "weapon", INVTYPE_2HWEAPON = "weapon", INVTYPE_WEAPONMAINHAND = "weapon" }
O.On("CHAT_MSG_LOOT", function(msg)
  msg = Plain(msg)
  if type(msg) ~= "string" or not On() or not msg:find("^You receive") then return end
  local link = msg:match("(|Hitem:.-|h%[.-%]|h)")
  if not link or not (C_Item and C_Item.GetItemInfoInstant) then return end
  local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
  local slot = ok and EQUIP[Plain(equipLoc) or ""]
  if not slot then return end
  local item = link:match("%[(.-)%]") or "that"
  for _, name in ipairs(Friends()) do
    local wish = Know().wish[name]
    if type(wish) == "table" and wish[slot] then
      Say("wish" .. name .. item, item .. " goes in the " .. slot .. " slot, and that is " .. name .. "'s weakest piece (ranked #" .. wish[slot] .. "). Worth asking if they can use it.", 0)
      return
    end
  end
end)

-- ---------- answers to what other owls ask ----------
local function Answer(sender, extra)
  local kind, rest = extra:match("^(%u+):(.*)$")
  if not kind then return end
  local rec = Record()
  if kind == "Q" then
    local done = Sub(Soc(), "qdone")[rest]
    if type(done) == "table" then Out(sender, "N", "QX:" .. rest .. "," .. (Num(done.m) or 0) .. "," .. (Num(done.l) or 0) .. "@" .. Strip(done.p, 30)) end
  elseif kind == "DR" then
    local mob, n, kills = DropOf(rest)
    if mob then Out(sender, "N", "DR:" .. Strip(rest, 34) .. "<" .. Strip(mob, 30) .. "#" .. n .. "/" .. kills) end
  elseif kind == "V" then
    local zone, what = rest:match("^(.-),(%a+)$")
    if what == "repair" or what == "food" then
      for name, v in pairs(Sub(rec, "vendors")) do
        if type(v) == "table" and v.zone == zone and v[what] then Out(sender, "N", "V:" .. Strip(name, 36) .. "@" .. Strip(v.place, 30) .. "," .. what) return end
      end
    end
  elseif kind == "G" then
    local picks = Sub(rec, "picks")[rest]
    if type(picks) == "table" then
      local list = {}
      for place, n in pairs(picks) do list[#list + 1] = { place, Num(n) or 0 } end
      table.sort(list, function(a, b) return a[2] > b[2] end)
      if list[1] then Out(sender, "N", "G:" .. Strip(list[1][1], 34) .. (list[2] and (";" .. Strip(list[2][1], 34)) or "")) end
    end
  elseif kind == "F" then
    for node in pairs(Sub(rec, "flightKnown")) do
      if type(node) == "string" and node:find(rest, 1, true) then Out(sender, "N", "F:" .. Strip(rest, 40)) return end
    end
  elseif kind == "L" then
    local where = Sub(rec, "levelPlace")[tonumber(rest) or 0]
    if Str(where) then Out(sender, "N", "L:" .. rest .. "," .. Strip(where, 60)) end
  elseif kind == "M" then
    local item, n = Has(rest)
    if item then Out(sender, "N", "M:" .. Strip(item, 50) .. "=" .. n) end
  end
end

-- ---------- what the other owls tell him ----------
local sightings = {}
local function Hear(sender, owl, extra)
  local kind, rest = extra:match("^(%u+):(.*)$")
  if not kind then return end
  local k = Know()
  if kind == "D" or kind == "DL" then
    local mob, zone, n = rest:match("^(.-)@(.-)#(%d+)$")
    if not mob or mob == "" then return end
    if Count(k.foes) < 120 or k.foes[mob] then k.foes[mob] = { who = sender, n = tonumber(n), zone = zone } end
    local told = Owl.deathSaid and Owl.deathSaid[sender]
    if kind == "DL" and zone == Zone() and not Grouped(sender) and not (told and Now() - told < 45) then Gossip("dl" .. sender .. mob, owl .. " says " .. mob .. " just got " .. sender .. ", here in " .. zone .. ". Careful.") end
  elseif kind == "E" then
    local name, what, place, zone = rest:match("^(.-),(.-)@(.-)~(.+)$")
    if not name then return end
    table.insert(sightings, 1, { who = sender, name = name, what = what, place = place, zone = zone, at = Clock() })
    while #sightings > 8 do table.remove(sightings) end
    if zone == Zone() then Say("esee" .. name, owl .. " spotted an enemy player in " .. place .. ": " .. name .. ", " .. what .. ". Just now.", 120, "c") end
  elseif kind == "RK" then
    local rare, place = rest:match("^(.-)@(.+)$")
    if not rare then return end
    local notes = Soc().notes
    if type(notes[rare]) ~= "table" and Count(notes) < 60 then notes[rare] = { place = place, from = sender } end
    if type(notes[rare]) == "table" then notes[rare].killed = Clock() end
    Gossip("rk" .. rare, owl .. " says " .. sender .. " just killed " .. rare .. " in " .. place .. ". It will be a while before it is back.")
  elseif kind == "QX" then
    local id, mins, level, place = rest:match("^(%d+),(%d+),(%d+)@(.*)$")
    if not id then return end
    mins = tonumber(mins)
    Gossip("qx" .. sender .. id, sender .. " did " .. QuestTitle(tonumber(id)) .. " at level " .. level .. "." .. (mins > 0 and (" It took about " .. (mins >= 90 and (math.floor(mins / 60 + 0.5) .. " hours") or (mins .. " minutes")) .. ".") or "")
      .. (place ~= "" and (" Handed in at " .. place .. ".") or ""), true)
  elseif kind == "DR" then
    local what, mob, n, kills = rest:match("^(.-)<(.-)#(%d+)/(%d+)$")
    if not what then return end
    n, kills = tonumber(n), tonumber(kills)
    local rate = (kills > 0 and n > 0 and kills >= n) and (", about 1 kill in " .. math.max(1, math.floor(kills / n + 0.5))) or ""
    Gossip("dr" .. what, owl .. " has seen " .. what .. " drop from " .. mob .. rate .. ".", true)
  elseif kind == "V" then
    local name, place, what = rest:match("^(.-)@(.-),(%a+)$")
    if name then Gossip("v" .. what .. Zone(), owl .. " knows " .. (what == "repair" and "a repairer" or "someone selling food and drink") .. " in this zone: " .. name .. ", in " .. place .. ".", true) end
  elseif kind == "G" then
    local a, b = rest:match("^([^;]+);?(.*)$")
    if a then Gossip("g" .. Zone(), owl .. " says " .. sender .. "'s best gathering here is around " .. a .. ((b and b ~= "") and (" and " .. b) or "") .. ".") end
  elseif kind == "F" then
    Gossip("f" .. sender .. rest, sender .. " already has the flight path here. Pick yours up and you can both fly in.")
  elseif kind == "L" then
    local level, where = rest:match("^(%d+),(.+)$")
    if level then Gossip("l" .. sender .. level, sender .. " was in " .. where:gsub(":.*$", "") .. " when they reached level " .. level .. ".") end
  elseif kind == "M" then
    local item, n = rest:match("^(.-)=(%d+)$")
    if item then
      O.Print(owl .. " says " .. sender .. " has " .. n .. " " .. item .. ".")
      Say("has" .. sender .. item, owl .. " says " .. sender .. " has " .. n .. " " .. item .. ".", 0, "c")
    end
  elseif kind == "H" then
    local hour = tonumber(rest)
    if hour and hour >= 0 and hour <= 23 then k.hours[sender] = hour end
  elseif kind == "W" then
    local wish = {}
    for slot, rank in rest:gmatch("([%a ]+)=(%d+)") do wish[slot] = tonumber(rank) end
    k.wish[sender] = wish
  elseif kind == "REC" then
    local xp, kills, fast = rest:match("^(%d+),(%d+),(%d+)$")
    if not xp then return end
    local new = { xp = tonumber(xp), kills = tonumber(kills), fast = tonumber(fast) }
    local old, mine = k.recs[sender], Sub(Record(), "records")
    if type(old) == "table" then
      if (Num(mine.kills) or 0) > 0 and (old.kills or 0) <= mine.kills and new.kills > mine.kills then
        Gossip("reck" .. sender .. new.kills, sender .. " just beat your record for most kills in a session: " .. new.kills .. " to your " .. mine.kills .. ".")
      elseif (Num(mine.xp) or 0) > 0 and (old.xp or 0) <= mine.xp and new.xp > mine.xp then
        Gossip("recx" .. sender .. new.xp, sender .. " just beat your record for most XP in a session: " .. new.xp .. " to your " .. mine.xp .. ".")
      elseif Num(mine.fastLevel) and new.fast > 0 and new.fast < mine.fastLevel and ((old.fast or 0) == 0 or old.fast >= mine.fastLevel) then
        Gossip("recf" .. sender .. new.fast, sender .. " just levelled faster than your fastest level. We cannot have that.")
      end
    end
    k.recs[sender] = new
  elseif kind == "GOS" then
    local what, mob, level = rest:match("^(%a+),(.-),(%d+)$")
    if what == "low" then Gossip("gos" .. sender .. mob, owl .. " says " .. sender .. " just died to a level " .. level .. " " .. mob .. ". I promised not to tell. I am telling.")
    elseif what == "pole" then Gossip("gospole" .. sender, owl .. " says " .. sender .. " has been fighting with a fishing pole.")
    elseif what == "fall" then Gossip("gosfall" .. sender, owl .. " says " .. sender .. " fell off something tall. Again.") end
  end
end

local netBefore = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if not On() then return end
  extra = tostring(extra or "")
  if kind == "HELLO" or kind == "HI" or kind == "LEVEL" then
    SetLevel(sender, extra:match("^(%d+)"))
    if kind ~= "LEVEL" then greetAt[sender] = Now() + 5 end
  elseif kind == "PING" then
    SetLevel(sender, extra:match("^(%d+)"))
  elseif kind == "N" then
    if Known(sender) then Hear(sender, owl, extra) end
  elseif kind == "NQ" then
    if Known(sender) then Answer(sender, extra) end
  end
end
O.On("PLAYER_LEVEL_UP", function(level)
  level = Num(Plain(level)) or Level()
  if On() and #Friends() > 0 then Out(nil, "NQ", "L:" .. level) end
  if C_Timer and C_Timer.After then C_Timer.After(4, function() O.Try("owl dungeon range", DungeonCheck) end) end
end)

-- ---------- /owl notes: what the other owls have told him ----------
O.commands.notes = function(arg)
  if arg == "on" or arg == "off" then
    OwlHUDDB.notes = arg == "on"
    O.Print("owls trading notes" .. (OwlHUDDB.notes and ": |cff40ff40on|r" or ": |cffff4040off|r"))
    return
  end
  local k, s = Know(), Soc()
  O.Print("|cffffd100What the other owls have told " .. Name() .. "|r")
  local any = false
  for _, e in ipairs(sightings) do
    if Clock() - e.at < 1800 then any = true print("  Enemy player " .. e.name .. " (" .. e.what .. ") in " .. e.place .. ", " .. e.zone .. ", " .. Owl.lib.When(e.at) .. ". From " .. e.who .. ".") end
  end
  local n = 0
  for mob, f in pairs(k.foes) do
    if type(f) == "table" and n < 8 then n = n + 1 any = true print("  " .. mob .. " killed " .. tostring(f.who) .. " " .. tostring(f.n) .. "x" .. ((f.zone and f.zone ~= "") and (" in " .. f.zone) or "") .. ".") end
  end
  n = 0
  for rare, r in pairs(s.notes) do
    if type(r) == "table" and n < 8 then n = n + 1 any = true print("  Rare: " .. rare .. " in " .. tostring(r.place) .. (Num(r.killed) and (", killed " .. Owl.lib.When(r.killed)) or "") .. ". From " .. tostring(r.from) .. ".") end
  end
  for who, wish in pairs(k.wish) do
    local parts = {}
    for slot, rank in pairs(wish) do parts[#parts + 1] = slot .. " (#" .. rank .. ")" end
    if #parts > 0 then any = true table.sort(parts) print("  " .. who .. " could use a better " .. table.concat(parts, ", ") .. ".") end
  end
  for who, hour in pairs(k.hours) do any = true print("  " .. who .. " is usually on around " .. hour .. ":00.") end
  if not any then print("  Nothing yet. They trade when you and a friend are online together.") end
  print("  /owl whohas silk asks friends' owls who is holding something. /owl notes off stops the trading.")
end

-- ---------- the clock ----------
local acc, zoneAt, hourAt = 0, 60, 90
local driver = CreateFrame("Frame")
local dead = false
local function Step(e)
  acc = acc + e
  if acc < 1 then return end
  local dt = acc
  acc = 0
  local now = Now()
  if outbox[1] and now >= outAt then
    outAt = now + 1.5
    local m = table.remove(outbox, 1)
    Raw(m[1], m[2], m[3])
  end
  if not On() then return end
  for name, at in pairs(greetAt) do if now >= at then greetAt[name] = nil Introduce(name) end end
  if gossip[1] and now - gossipAt >= 150 and not Plain(UnitAffectingCombat("player")) then
    local g = table.remove(gossip, 1)
    if now <= g[3] and Say(g[1], g[2], 0) then gossipAt = now end
  end
  zoneAt = zoneAt - dt
  if zoneAt <= 0 then zoneAt = 60 ZoneAsks() end
  if hourAt then
    hourAt = hourAt - dt
    if hourAt <= 0 then
      hourAt = nil
      local hour = tonumber(type(date) == "function" and select(2, pcall(date, "%H")) or "")
      if hour then
        for who, usual in pairs(Know().hours) do
          if usual == hour and not cos.friends[who] and not Grouped(who) then Gossip("usual" .. who, who .. " is usually on around now. Not yet, it seems.") break end
        end
      end
    end
  end
end
driver:SetScript("OnUpdate", function(_, e)
  if dead then return end
  local ok, err = pcall(Step, e)
  if not ok then dead = true O.Print("|cffff4040owl notes turned off:|r " .. tostring(err)) end
end)
Owl.notes = { Step = Step, Know = Know, outbox = outbox, gossip = gossip, Introduce = Introduce, quiet = function() gossipAt = -1000 end, forget = function(name) greeted[name] = nil end }
end
O.Try("owl notes setup", Owl.NotesSetup)
O.OwlTestNotes = function() return Owl.notes end

-- =====================================================================================
-- In the air: on a flight path he stops reacting to what is on the ground below, and
-- talks about the places you pass over instead, with what he remembers of you there
-- =====================================================================================
O.defaults.flytalk = true
Owl.FlyTalkSetup = function()
local Sub, Count = Owl.lib.Sub, Owl.lib.Count
local function OnTaxi() return Q("UnitOnTaxi", "player") and true or false end
-- on a flight only these kinds of line get through: the flight itself, and answers to things you asked for
local ALLOW = { "fly", "flight", "ask", "hoot", "post", "gift", "duel", "emo", "thanks", "has", "cos", "body", "pal", "got", "remind", "named", "readyall", "pat", "trick" }
O.OwlGate = function(key)
  if OwlHUDDB.flytalk == false or type(key) ~= "string" or not OnTaxi() then return true end
  for _, prefix in ipairs(ALLOW) do if key:sub(1, #prefix) == prefix then return true end end
  return false
end

local ZONES = {
  ["Elwynn Forest"] = { "Elwynn. Every wolf down there has a grudge against somebody's level 3.", "Elwynn Forest. It all started somewhere like that." },
  ["Westfall"] = { "Westfall. Fields, scarecrows, and trouble in red masks.", "Westfall. From up here you cannot even smell the gnolls." },
  ["Redridge Mountains"] = { "Redridge. That lake is prettier than it has any right to be.", "Redridge Mountains. The orcs up in the hills never look up. Good." },
  ["Duskwood"] = { "Duskwood. I see perfectly well in the dark and I still do not like it.", "Duskwood. Nothing down there sleeps. Some of it should." },
  ["Stranglethorn Vale"] = { "Stranglethorn. Green all the way down, and everything in it bites.", "Stranglethorn Vale. Keep flying. I mean it." },
  ["Loch Modan"] = { "Loch Modan. A lot of water behind one dam and a great deal of faith.", "Loch Modan. Dwarves build things you can see from the clouds." },
  ["Wetlands"] = { "The Wetlands. I can feel my feathers getting damp from here.", "Wetlands. Crocolisks look like logs from up here. So do the logs." },
  ["Arathi Highlands"] = { "Arathi. Wide, windy, and fought over since before either of us.", "Arathi Highlands. Good hunting country, if you are an owl." },
  ["Hillsbrad Foothills"] = { "Hillsbrad. Those two towns have never once got along.", "Hillsbrad Foothills. Pretty. Loud. Somebody is always fighting down there." },
  ["Alterac Mountains"] = { "Alterac. Snow, ogres, and ruins nobody misses.", "The Alterac Mountains. Cold enough up here already, thank you." },
  ["The Hinterlands"] = { "The Hinterlands. Proper owl country. I have cousins down there.", "Hinterlands. Trolls on the ground, gryphons in the air. I prefer the air." },
  ["Dun Morogh"] = { "Dun Morogh. Snow as far as I can see, and I can see far.", "Dun Morogh. Somewhere under all that white is a very warm tavern." },
  ["Searing Gorge"] = { "The Searing Gorge. The air tastes like a forge.", "Searing Gorge. Do not drop anything. It will not come back." },
  ["Burning Steppes"] = { "The Burning Steppes. Even the sky looks singed.", "Burning Steppes. There are dragons down there. Fly casually." },
  ["Badlands"] = { "The Badlands. Rock, dust, and things that eat rock and dust.", "Badlands. Nobody named it by accident." },
  ["Swamp of Sorrows"] = { "The Swamp of Sorrows. It earned the name.", "Swamp of Sorrows. Something big is asleep in that water." },
  ["Blasted Lands"] = { "The Blasted Lands. I do not like the colour of that sky.", "Blasted Lands. That is where the trouble first came through." },
  ["Western Plaguelands"] = { "The Western Plaguelands. Hold your breath. I am.", "Western Plaguelands. Farms once. Not any more." },
  ["Eastern Plaguelands"] = { "The Eastern Plaguelands. Nothing down there is as dead as it should be.", "Eastern Plaguelands. Higher, please. Higher." },
  ["Tirisfal Glades"] = { "Tirisfal. Quiet, the way a held breath is quiet.", "Tirisfal Glades. Even the trees look tired." },
  ["Silverpine Forest"] = { "Silverpine. Something howls down there most nights.", "Silverpine Forest. Lovely trees. Terrible neighbours." },
  ["Stormwind City"] = { "Stormwind. All those rooftops and not one decent perch.", "Stormwind from above. The canals look like someone drew them with a ruler." },
  ["Ironforge"] = { "Ironforge. A whole city inside a mountain. No sky at all. Imagine.", "Ironforge. I can smell the forge smoke from here." },
  ["Darkshore"] = { "Darkshore. Long, grey, and the tide brings in strange things.", "Darkshore. The sea has been throwing things at that beach for years." },
  ["Ashenvale"] = { "Ashenvale. Trees older than any kingdom, and they know it.", "Ashenvale. The forest is listening. It usually is." },
  ["Teldrassil"] = { "Teldrassil. A whole land grown on one tree. Show-offs.", "Teldrassil. Best branches in the world, I will give them that." },
  ["The Barrens"] = { "The Barrens. It goes on. And on. And then it goes on.", "The Barrens. From up here it is almost peaceful. Almost." },
  ["Stonetalon Mountains"] = { "Stonetalon. Somebody has been cutting down that forest and the forest is angry.", "Stonetalon Mountains. Sharp peaks. Sharp winds." },
  ["Desolace"] = { "Desolace. The name did not oversell it.", "Desolace. Grey ground, grey sky, and centaurs who are angry about both." },
  ["Dustwallow Marsh"] = { "Dustwallow Marsh. Mud with ambitions.", "Dustwallow. Everything down there is either sinking or biting." },
  ["Thousand Needles"] = { "Thousand Needles. I counted once. It is more than a thousand.", "Thousand Needles. Do not look down. Actually, do. It is something." },
  ["Tanaris"] = { "Tanaris. Sand, sun, and goblins selling both.", "Tanaris. I can see the heat from here." },
  ["Feralas"] = { "Feralas. Green and deep and full of things with too many teeth.", "Feralas. A forest that has never been told no." },
  ["Un'Goro Crater"] = { "Un'Goro. Everything in that crater is enormous. I checked.", "Un'Goro Crater. The lizards down there think they are in charge. They are." },
  ["Felwood"] = { "Felwood. That forest is sick and it knows it.", "Felwood. Do not drink anything green down there." },
  ["Winterspring"] = { "Winterspring. Cold, clear, and full of owls. My kind of place.", "Winterspring. The air up here could cut glass." },
  ["Azshara"] = { "Azshara. Autumn colours over drowned ruins.", "Azshara. Beautiful. Nobody goes there. Wonder why." },
  ["Silithus"] = { "Silithus. Sand that moves on its own. No, thank you.", "Silithus. Things live under that sand. Many things." },
  ["Durotar"] = { "Durotar. Red rock and stubborn people.", "Durotar. Hot, dry, and proud of it." },
  ["Mulgore"] = { "Mulgore. Green plains under an enormous sky.", "Mulgore. The calmest place I have ever flown over." },
}
local GENERIC = { "I could fly this myself, you know. Slower, but with dignity.", "Our ride is showing off. I can tell.", "Do not look down. I am looking down for both of us.",
  "Good wind today.", "From up here the world looks like a map somebody spilled.", "I have opinions about this one's wing form. I am keeping them to myself.",
  "Hold on to your hat. And to mine.", "This is the only time you see things the way I do.", "Nobody can reach us up here. Enjoy it.",
  "I would wave at the people down there, but: wings.", "Flying is mostly falling and missing. I read that somewhere.", "The clouds are closer than they look. They always are." }
local TAKEOFF = { "Up we go.", "And we are off. Mind the first drop.", "Wings out. Well, theirs.", "Off the ground at last." }
local LANDING = { "Down we come. Feet on the ground.", "And landed. I prefer wings, but fine.", "Here we are. That was the easy part.", "Solid ground. Your sort of place." }

-- what he remembers of you in the place below
local function Personal(zone)
  local rec, lines = Record(), {}
  local worst, worstN
  for mob, f in pairs(Sub(rec, "foes")) do
    if type(f) == "table" and f.deathZone == zone and (Num(f.deaths) or 0) > 0 and (not worstN or f.deaths > worstN) then worst, worstN = mob, f.deaths end
  end
  if worst then lines[#lines + 1] = zone .. ". " .. worst .. " got you down there" .. (worstN > 1 and (", " .. worstN .. " times") or "") .. ". From up here it looks very small." end
  for level, where in pairs(Sub(rec, "levelPlace")) do
    if type(where) == "string" and where:sub(1, #zone) == zone and tonumber(level) then
      lines[#lines + 1] = zone .. ". You reached level " .. tostring(level) .. " down there. I remember the noise you made."
      break
    end
  end
  local spent = Num(Sub(rec, "zoneTime")[zone])
  if spent and spent >= 3600 then
    local hours = math.floor(spent / 3600 + 0.5)
    lines[#lines + 1] = zone .. ". We have spent " .. (hours == 1 and "an hour" or (hours .. " hours")) .. " down there, you and I."
  end
  local ok, q = pcall(Owl.lib.ScanQuests)
  local n = ok and type(q) == "table" and type(q.zones) == "table" and Num(q.zones[zone])
  if n and n > 0 then lines[#lines + 1] = zone .. ". " .. (n == 1 and "One of your quests is" or (n .. " of your quests are")) .. " down there, waiting." end
  if Owl.cos and Owl.cos.RARE then
    local c = Owl.cos.Cos()
    for _, id in ipairs(Owl.cos.RARE.gem) do
      local it = Owl.cos.ITEM[id]
      if it and it.rare == zone then
        if c.own[id] then lines[#lines + 1] = zone .. ". That is where we found my " .. it.name .. "."
        else lines[#lines + 1] = zone .. ". Somewhere down there is a torch with my name on it. We have not found it yet." end
      end
    end
  end
  if Owl.social then
    local know = Sub(Owl.social.Soc(), "know")
    for mob, f in pairs(Sub(know, "foes")) do
      if type(f) == "table" and f.zone == zone and f.who then
        lines[#lines + 1] = zone .. ". " .. tostring(f.who) .. " keeps getting killed down there by " .. mob .. ". Their owl told me."
        break
      end
    end
  end
  for name, r in pairs(Sub(rec, "rares")) do
    if type(r) == "table" and type(r.place) == "string" and r.zone == zone then lines[#lines + 1] = zone .. ". We saw " .. name .. " down there once." break end
  end
  return lines
end

local flying, nextAt, saidZone, lastLine, started = false, 0, {}, nil, 0
local function Pick(list)
  if #list == 0 then return nil end
  local line = list[math.random(#list)]
  if line == lastLine and #list > 1 then line = list[(math.random(#list - 1))] end
  lastLine = line
  return line
end
local function ZoneLine(zone)
  local mine = Personal(zone)
  -- what he remembers of you there comes first, most of the time
  if #mine > 0 and (not ZONES[zone] or math.random(3) > 1) then return Pick(mine) end
  if ZONES[zone] then return Pick(ZONES[zone]) end
  return nil
end
local function Over()
  local zone = Zone()
  if zone == "parts unknown" or saidZone[zone] then return false end
  local line = ZoneLine(zone)
  if not line then return false end
  if Say("flyzone" .. zone .. Now(), line, 0, "c") then
    saidZone[zone] = true
    nextAt = Now() + 40 + math.random() * 30
    return true
  end
  return false
end
O.On("ZONE_CHANGED_NEW_AREA", function()
  if flying and OwlHUDDB.flytalk ~= false and Now() - started > 6 then O.Try("owl flight talk", Over) end
end)

local acc = 0
local driver = CreateFrame("Frame")
local dead = false
local function Step(e)
  acc = acc + e
  if acc < 1 then return end
  acc = 0
  local now = OnTaxi()
  if now and not flying then
    flying, started, saidZone = true, Now(), {}
    saidZone[Zone()] = true          -- no need to describe the place you are leaving
    nextAt = Now() + 22 + math.random() * 12
    if OwlHUDDB.flytalk ~= false and OwlHUDDB.tips then Say("flyup" .. Now(), TAKEOFF, 0, "c") end
  elseif flying and not now then
    flying = false
    if OwlHUDDB.flytalk ~= false and OwlHUDDB.tips and Now() - started > 30 and math.random(2) == 1 then Say("flydown" .. Now(), LANDING, 0, "c") end
  elseif flying and OwlHUDDB.flytalk ~= false and Now() >= nextAt then
    if not Over() then
      Say("flyidle" .. Now(), Pick(GENERIC), 0, "c")
      nextAt = Now() + 45 + math.random() * 35
    end
  end
end
driver:SetScript("OnUpdate", function(_, e)
  if dead then return end
  local ok, err = pcall(Step, e)
  if not ok then dead = true O.OwlGate = nil O.Print("|cffff4040owl flight talk turned off:|r " .. tostring(err)) end
end)
O.commands.flytalk = function()
  OwlHUDDB.flytalk = OwlHUDDB.flytalk == false
  O.Print("his talk on flight paths" .. (OwlHUDDB.flytalk and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
Owl.flytalk = { Step = Step, ZONES = ZONES, Personal = Personal }
end
O.Try("owl flight talk setup", Owl.FlyTalkSetup)
O.OwlTestFly = function() return Owl.flytalk end

-- =====================================================================================
-- More to say: extra wordings for everyday events, a memory of what he has already said
-- that lasts between sessions, quirks that differ from owl to owl, and what he knows
-- about warriors who tank and priests who walk in shadow
-- =====================================================================================
O.defaults.variety = true
Owl.VoiceSetup = function()
local Sub, Count = Owl.lib.Sub, Owl.lib.Count
local CLASS = Owl.class or select(2, UnitClass("player"))

-- ---------- more ways to say the everyday things ----------
local MORE = {
  dur10 = { "Your gear is one bad pull from breaking. Repair.", "Everything you are wearing is held together by hope. Find an anvil.", "Red gear. Repair before anything else." },
  dur25 = { "Your gear is looking tired. Repair when you pass a vendor.", "A repair soon would be wise.", "Dents everywhere. Next vendor, yes?" },
  bags0 = { "Not one free slot. Something has to go.", "Your bags are full to the seams.", "No room left. The next drop stays on the ground." },
  bags2 = { "Nearly out of bag space.", "Two slots left, maybe. Time to sell.", "Your bags are groaning." },
  talent = { "There is a talent point burning a hole in your pocket.", "An unspent talent point. It does nothing sitting there.", "You have a point to spend. I would not wait." },
  trainer = { "A new level means new things at the trainer.", "Your trainer will want to see you.", "Trainer visit when you are next in town." },
  late = { "It is very late out there. I am an owl. What is your excuse?", "Past one in the morning. One more quest, then bed?", "The hour is small. Just an observation." },
  rested = { "You are well rested. Kills count for more for a while.", "Rested. Make it count.", "That rest paid off: bonus XP until it runs dry." },
  rareelite = { "Rare and elite, both. Either a prize or a funeral.", "That one is rare, elite and probably angry.", "A rare elite. Think first. Then think again." },
  rare = { "That is a rare one. They do not come round often.", "A rare creature! Do not let it wander off.", "Rare. I would take the shot." },
  boss = { "A boss. Deep breath.", "That is the big one. Everything you have.", "Boss. I will watch from slightly further back." },
  elite = { "Elite. Hits harder than it looks.", "That one is elite. Bring a friend, or bring everything.", "An elite. Not impossible. Not easy." },
  skull = { "A skull over its head means no.", "That one is so far above you I cannot read its level.", "Walk away from that one. Briskly." },
  grey = { "Not worth the swing. No XP in that one.", "Too small to teach you anything.", "Leave it. It has nothing for you." },
  closecall = { "That was nearly my turn to carry you.", "Too close. Bandage, eat, breathe.", "I saw my whole life go by. It was mostly mice." },
  lowmana = { "Your mana is nearly gone. Drink.", "Running dry. Sit a moment.", "No blue left. A drink before the next one." },
  praise = { "Tidy.", "That is how it is done.", "I blinked and it was over.", "No notes.", "Very neat. I shall tell the others." },
  dead = { "Well. That happened.", "We walk it off. Literally.", "I am choosing to call that a tactical pause.", "It got lucky. We will be back." },
  resting = { "An inn. Log off here and you wake up rested.", "A proper roof. Good place to stop for the night.", "Rest here and tomorrow's kills pay better." },
  breath = { "Air! Up! Now!", "You are not a fish. Surface.", "Your breath is running out." },
  afk = { "Go on. I will mind things.", "Take your time. I am not going anywhere.", "I shall guard the body." },
  back = { "Oh good, you are back.", "Welcome back. Nothing ate you.", "There you are. I kept your place." },
  solo = { "Back to the two of us.", "Just you and me again. As it should be.", "Quiet again." },
  rez = { "They are bringing you back. Take it!", "A resurrection. Accept, accept.", "Someone wants you alive. Say yes." },
  goodloot = { "Now that is worth carrying.", "Oh, that is a nice one.", "Look at that. Keep that." },
  wake = { "I was thinking with my eyes closed.", "Awake. I was always awake.", "Mm? Yes. Ready." },
  restedout = { "The rested bonus is spent. Ordinary XP now.", "No more bonus. It was good while it lasted.", "Rest ran out. Back to honest work." },
  gearnone = { "Your hands are empty. Equip something!", "No weapon. Brave, but no.", "You are unarmed. I cannot stress this enough." },
  gearpole = { "That is a fishing pole. The enemy is not a fish.", "You are hitting it with your fishing rod.", "Wrong tool. Weapon, please." },
  gearbroken = { "Your weapon has broken. Repair it now.", "That weapon is in pieces. Vendor.", "A broken weapon hits like a wet leaf. Repair." },
  adds3 = { "Three of them on you. Everything you have, or your feet.", "That is three. Cooldowns or run.", "Three at once! This is a bad pull." },
  sawshot = { "Was I in that one? I was mid-blink.", "Send that to someone. I look good.", "A picture. Good. Proof we were here." },
  sawskim = { "You did not read a word of that quest, did you.", "Accepted in under a second. Bold.", "I read it for you. We are fine." },
  sawfall = { "That fall cost you. Mind the edge.", "You dropped. I glided. One of us is hurt.", "Ow. Even I felt that." },
  sawswim = { "Still swimming. I am keeping my feathers out of it.", "That is a lot of water for one day.", "I will meet you on the far bank." },
  sawstill = { "We have been standing here a while. I am not complaining.", "Four minutes in one spot. Good book?", "Nothing is happening. I rather like it." },
  knowhour = { "This is not your usual hour. Trouble sleeping?", "You, here, now? That is new.", "An odd time for you. I notice these things." },
  knowstop = { "You usually stop about now. Or one more?", "This is your bedtime, by my count.", "About now is when you call it a night." },
  mail = { "Post for you. Check a mailbox when you pass one.", "A letter is waiting." },
  group = { "Company! Buffs out, and say hello.", "A group. Stay close and watch the healer." },
  dungeon = { "A dungeon. Stay with the group and mind the patrols.", "Inside we go. Let the tank set the pace." },
  alive = { "Up you get. Eat something before the next fight.", "Alive again. Buffs first, then onward." },
  ready = { "Ready check. Buffs, food, water?", "They are asking if you are ready. Are you?" },
}
-- the same, in the voice he has been given
local VOICE_MORE = {
  sage = {
    afk = { "Go. The world will keep.", "Step away. I shall keep the watch and my own counsel." },
    alive = { "Once more among the living. Use it well.", "The lesson is paid for. Carry it." },
    back = { "You return, and nothing was lost.", "The watch was quiet. Welcome back." },
    bags0 = { "A full pack carries nothing new. Let something go.", "No room remains. What will you part with?" },
    bags2 = { "Your pack grows heavy. Travel lighter.", "Little room is left. Choose what matters." },
    closecall = { "One breath from the end. Remember it.", "That margin was thin as a feather." },
    dead = { "The ground teaches what the sky cannot.", "A hard lesson. Walk back and think on it.", "Even the patient fall. Rise slowly." },
    dur25 = { "Worn gear is a slow wound. Mend it.", "The edge dulls. Seek a smith when the road allows." },
    elite = { "That one is stronger than its kind. Weigh it first.", "An elite. Courage is not the same as haste." },
    goodloot = { "A worthy find. Keep it close.", "Fortune leaves gifts for those who look." },
    grey = { "There is no lesson in that one. Pass it by.", "Strength spent on the weak is strength wasted." },
    hello = { "The dawn finds you ready, I hope.", "We begin again. I am glad of it." },
    late = { "The night is deep. Even owls say so.", "The hour is late, and tired hands make poor choices." },
    lowmana = { "The well is low. Wait for it to fill.", "Power spent must be regathered. Sit." },
    mail = { "Word has come for you. Read it when you may.", "A letter waits. News keeps, but not forever." },
    praise = { "Clean. Nothing wasted.", "That was the right way to do it.", "Patience, then precision. Good." },
    rare = { "A rare creature. Such chances do not return quickly.", "Seldom seen, that one. Decide swiftly." },
    resting = { "A roof and a fire. Rest here and wake stronger.", "Stop here tonight. Tomorrow rewards the rested." },
    skull = { "That one is beyond you today. There is no shame in the long way round.", "Know your measure. That is far above it." },
    solo = { "The company has gone. The road is ours again.", "Alone once more. It suits us." },
    talent = { "You have grown, and not yet chosen how. Choose.", "A talent waits to be spent. Do not let wisdom sit idle." },
    trainer = { "There is more to learn. Your trainer waits.", "A new level. Seek your teacher." },
    wake = { "I was listening to the quiet.", "Rest is not sleep. I heard everything." },
  },
  sarcastic = {
    afk = { "Sure. I will just stand here. Guarding.", "Off you go. I will hold down the entire world." },
    alive = { "And we are back. Try not to do that again.", "Alive again. Let us see how long this lasts." },
    back = { "Oh, you came back. I had almost redecorated.", "Finally. I was running out of things to stare at." },
    bags0 = { "Bags full. Shocking. Truly nobody saw this coming.", "No space. Maybe sell one of the nine grey things." },
    bags2 = { "Almost out of bag space. I am sure it will sort itself out.", "Two slots left. Keep picking things up, see what happens." },
    closecall = { "Very relaxing. Do that again and I am leaving.", "Almost dead. Excellent planning." },
    dead = { "Bold strategy. Did not work.", "Well, that was a choice.", "I would say I told you so, but I was busy watching." },
    dur25 = { "Your gear is falling apart. It matches the plan.", "Repairs. When you get a moment between disasters." },
    elite = { "Elite. But sure, go ahead, what is the worst that could happen.", "That one is elite. I will be over here." },
    goodloot = { "Something good, for once.", "Look at that. The universe owed you one." },
    grey = { "Yes, bully the small one. Very impressive.", "No XP in that. But do go on." },
    hello = { "Oh good, you are up.", "Back again. The world trembles. Slightly." },
    late = { "It is the middle of the night. But who needs sleep.", "Past one. I am sure tomorrow-you will be thrilled." },
    lowmana = { "Out of mana. Who could have predicted casting uses mana.", "Empty. Sit down before you fall down." },
    mail = { "You have mail. Probably not a prize.", "Mail. Try to contain yourself." },
    praise = { "Fine. That was good. Do not let it go to your head.", "Competent. I am as surprised as you are.", "Adequate. High praise, from me." },
    rare = { "A rare one. Try not to miss it.", "Rare spawn. No pressure." },
    resting = { "An inn. Somewhere you cannot get into trouble.", "A bed. Use it." },
    skull = { "Skull level. By all means, poke it.", "That one would kill you by accident." },
    solo = { "Alone again. More snacks for me.", "They left. I cannot imagine why." },
    talent = { "A talent point. Sitting there. Doing nothing. Like some people.", "You could spend that point any day now." },
    trainer = { "New level. The trainer would love your money.", "Go and see the trainer. Bring gold." },
    wake = { "I was not asleep. You were not interesting.", "Resting my eyes. From you." },
  },
}
O.OwlMore = function(key, lines, voiced)
  if OwlHUDDB.variety == false then return nil end
  local extra = MORE[key]
  if voiced then extra = (VOICE_MORE[OwlHUDDB.voice or ""] or {})[key] end
  if not extra then return nil end
  local all = {}
  if type(lines) == "table" then for _, l in ipairs(lines) do all[#all + 1] = l end elseif type(lines) == "string" then all[1] = lines else return nil end
  for _, l in ipairs(extra) do all[#all + 1] = l end
  return all
end

-- ---------- a memory of what he has said that outlasts the session ----------
local function Long()
  local s = Sub(Record(), "said")
  if type(s.list) ~= "table" then s.list = {} end
  return s
end
local longReady = false
local function LongSet()
  if not longReady then
    longReady = true
    Owl.longSet = {}
    for _, t in ipairs(Long().list) do Owl.longSet[t] = true end
  end
  return Owl.longSet
end
Owl.SaidBefore = function(text) local ok, set = pcall(LongSet) return ok and set[text] == true end
local baseSaid = O.OwlSaid
O.OwlSaid = function(text, ...)
  if baseSaid then pcall(baseSaid, text, ...) end
  if type(text) ~= "string" or #text > 140 or text:find("%d") then return end   -- lines with numbers in are new every time anyway
  local ok, set = pcall(LongSet)
  if not ok or set[text] then return end
  local list = Long().list
  set[text] = true
  list[#list + 1] = text
  while #list > 320 do set[table.remove(list, 1)] = nil end
end

-- ---------- quirks: every owl is a little different ----------
local function Hash(text)
  local h = 5381
  for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
  return h
end
local SNACKS = { "a fat field mouse", "honey cake", "candied beetles", "smoked trout", "a warm cricket pie", "toasted moths", "bog frogs", "roast vole", "sweet buns from Stormwind", "river shrimp", "a nice plump grub", "salted crickets" }
local FEARS = { "geese", "deep water", "gnomish machines", "thunder", "the colour of fel fire", "cats with nothing to do", "very small spiders", "murloc singing", "enclosed barrels", "bats, who are just rude mice" }
local HOBBIES = { "count the stars and lose my place", "rearrange your bags in my head", "practise looking wise", "compose letters to owls I have never met", "watch the moon and judge it", "sharpen my talons on your boots", "listen to the wind and disagree with it", "plan routes we never take", "name the clouds", "hum. Quietly. You have never caught me" }
local HOMES = { "a hollow oak in Elwynn", "the rafters of a Duskwood barn", "a cliff over Loch Modan", "a bell tower in Stormwind", "a pine in Winterspring", "an old mill in Westfall", "a ruin in Ashenvale", "a lighthouse on the coast", "the eaves of an inn nobody remembers", "a crooked tree in Tirisfal" }
local RIVALS = { "Ravens", "Gulls", "Hawks", "Parrots", "Crows", "Vultures", "Roosters", "Pigeons" }
local quirk
local function Quirk()
  if quirk then return quirk end
  local h = Hash(Me() .. "/" .. Name() .. "/owl")
  local function pick(list, salt) return list[(math.floor(h / salt) % #list) + 1] end
  quirk = { snack = pick(SNACKS, 1), fear = pick(FEARS, 13), hobby = pick(HOBBIES, 171), home = pick(HOMES, 2311), rival = pick(RIVALS, 30011), number = (math.floor(h / 97) % 9) + 3 }
  return quirk
end
local function QuirkLines()
  local q = Quirk()
  return {
    "I would trade this whole zone for " .. q.snack .. ".", "Do not tell anyone, but I am afraid of " .. q.fear .. ". Slightly.",
    "When you are asleep I " .. q.hobby .. ".", "I was hatched in " .. q.home .. ". I do not like to boast, but it shows.",
    q.rival .. " think they are clever. They are not.", "My lucky number is " .. q.number .. ". Do with that what you will.",
    "If we ever pass " .. q.home .. ", say nothing. I owe someone there a favour.", "You know what would improve today? " .. q.snack:sub(1, 1):upper() .. q.snack:sub(2) .. ".",
    "I dreamed about " .. q.fear .. " again. I handled it very bravely.", "A " .. q.rival:lower():gsub("s$", "") .. " looked at me the wrong way this morning. I am still deciding what to do about it.",
  }
end
O.commands.quirks = function()
  local q = Quirk()
  O.Print("|cffffd100About " .. Name() .. "|r")
  print("  Hatched in " .. q.home .. ". Favourite food: " .. q.snack .. ". Afraid of " .. q.fear .. ".")
  print("  When you are asleep: likes to " .. q.hobby:gsub("%.$", "") .. ". Lucky number " .. q.number .. ". Does not get on with " .. q.rival:lower() .. ".")
  print("  These come from his name and yours, so no two owls are the same. Rename him with /owl name and you get a different owl.")
end

local IDLE = {
  "I have been counting your footsteps. I lost count. I started again.", "That cloud looks like a mouse. They all do, if you want it enough.",
  "You walk very loudly for someone who is being hunted most of the time.", "I like this bit. Nothing is on fire.", "Do you think the fish know about us?",
  "If I had hands I would carry a very small sword.", "Somewhere a quest giver is standing exactly where they stood yesterday.", "I have decided to be mysterious today. That is all I will say.",
  "You have a good face for adventuring. Durable.", "The wind changed. Nothing to worry about. Probably.", "I keep a list of everything that has tried to eat us. It is long.",
  "Feathers are more work than they look.", "I could have been a library owl. I chose this.", "Tell me if I am talking too much. I will ignore it, but tell me.",
  "Every innkeeper thinks you are the first to ask for a room. Let them.", "I trust about four people and you are two of them.", "That rock has been following us. No. Different rock.",
  "One day they will write about this. I will check the spelling.", "I do my best thinking on your shoulder. Do not move suddenly.", "The trick to flying is not to think about the ground.",
  "I heard a rumour about treasure. I started it, but still.", "Mice are a breakfast food. I will not be taking questions.", "You dropped something earlier. No, wait. That was your dignity, in the lake.",
  "It is too quiet. I say that every day and I am right about once a week.", "I have opinions about boots. Yours pass.", "Left, I think. No reason. Just a feeling.",
  "I am keeping an eye on things. Both eyes, in fact. They are very large.", "There is a perfectly good branch over there and we are walking past it.", "I do not sleep. I wait.",
  "If anyone asks, I am the brains of this operation.",
}
local CLASS_IDLE = {
  WARRIOR = { "You hit things until they stop. I respect the simplicity.", "A shield is just a door you carry with you.", "They all aim at you first. I think you like it.",
    "Rage is a strange thing to run on. It works, though.", "Hold the line. I will hold the commentary.", "That armour weighs more than I do. Considerably.",
    "When you shout, things come running at you. On purpose. Remarkable.", "I have never seen anyone so pleased to be hit." },
  PRIEST = { "You wear the dark very well.", "The shadows listen to you. I find that reassuring. Mostly.", "A healer who chose to hurt things. I am not judging. I am taking notes.",
    "That purple haze suits you.", "You whisper at things and they fall over. Efficient.", "Is it cold in there, in the Shadowform? You can tell me.",
    "Mind your mana. It is the only thing between us and a long walk.", "I can never tell if you are praying or plotting." },
  PALADIN = { "The Light likes you. I can tell. It is a bit showy about it.", "Heavy armour, big sword, and you can heal. Greedy.", "You glow when you fight. It ruins my night vision.",
    "A hammer for justice. I prefer talons, but I see the appeal." },
}
local basePersonal = O.OwlPersonal
O.OwlPersonal = function(...)
  if OwlHUDDB.variety ~= false and math.random(3) == 1 then
    local pool = {}
    for _, l in ipairs(IDLE) do pool[#pool + 1] = l end
    for _, l in ipairs(CLASS_IDLE[CLASS] or {}) do pool[#pool + 1] = l end
    if math.random(4) == 1 then pool = QuirkLines() end
    local fresh = {}
    for _, l in ipairs(pool) do if not Owl.SaidBefore(l) then fresh[#fresh + 1] = l end end
    if #fresh > 0 then return fresh[math.random(#fresh)] end
    if #pool > 0 and math.random(2) == 1 then return pool[math.random(#pool)] end
  end
  if basePersonal then return basePersonal(...) end
end

-- ---------- class knowledge: the warrior who tanks, the priest in shadow ----------
local function Knows(spell)
  if type(O.OwlBookIds) == "table" and O.OwlBookIds[spell] then return true end
  return type(OwlHUDDB.spellsKnown) == "table" and OwlHUDDB.spellsKnown[spell] == true
end
local function HasShield()
  local link = Str(Call("GetInventoryItemLink", "player", 17)[1])
  if not link or not (C_Item and C_Item.GetItemInfoInstant) then return false end
  local ok, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, link)
  return ok and Plain(loc) == "INVTYPE_SHIELD"
end
local function Tanking() return CLASS == "WARRIOR" and (HasShield() or Call("UnitGroupRolesAssigned", "player")[1] == "TANK") end
local function Shadow() return CLASS == "PRIEST" and (Knows("Shadowform") or Knows("Mind Flay")) end
Owl.role = { Tanking = Tanking, Shadow = Shadow }

if type(O.OwlClassTips) == "table" then
  local tips = O.OwlClassTips
  tips.WARRIOR = tips.WARRIOR or {}
  for _, l in ipairs({ "Every block gives you 5 rage here. A shield is a rage engine.", "Thunder Clap works in Defensive Stance in Forever. Open every pack with it.",
    "Revenge the moment it lights up. Nothing is cheaper for the threat.", "Tactical Mastery is free: you keep 10 rage when you change stance.",
    "Taunt is for the one that got away. Challenging Shout is for when they all did.", "Demoralizing Shout on a big pull takes the sting out of it.",
    "Victory Rush after a kill costs nothing. Press it.", "Shield Wall is back every 15 minutes here. Do not die with it unused.",
    "Strength is threat: Rend and Sunder Armor scale with your attack power.", "Wait for the healer's mana. You set the pace." }) do tips.WARRIOR[#tips.WARRIOR + 1] = l end
  tips.PRIEST = tips.PRIEST or {}
  for _, l in ipairs({ "Let Mind Flay finish. Each tick hits harder than the last.", "Devouring Plague is every priest's spell here, not just the undead.",
    "Shadow Word: Death bites back if they live. Use it to finish.", "Vampiric Embrace can always be running: 30 seconds on, 30 second cooldown.",
    "You can dispel without leaving Shadowform. Healing is what breaks it.", "Mind Blast draws a lot of attention. Let the tank settle in first.",
    "Shadow Word: Pain, then wand, costs almost nothing. Good for the last sliver.", "Divine Spirit and Fortitude before the pull, not during.",
    "Spirit Tap after a kill: that is your free mana. Do not waste it sitting.", "Silence interrupts here as well. Save it for the heal." }) do tips.PRIEST[#tips.PRIEST + 1] = l end
end
if type(Owl.CLASS_FACTS) == "table" then
  Owl.CLASS_FACTS.WARRIOR = {
    { "rage block shield specialization", "Shield Specialization gives 5 rage every time you block in Forever, not 1. Master of Defense adds 5 more on a dodge or parry with a shield up." },
    { "thunder clap defensive stance aoe pack", "Thunder Clap works in Defensive Stance here, scales with attack power, and is back every 6 seconds. It is your pack opener." },
    { "charge vanguard defensive", "Vanguard lets you Charge without leaving Defensive Stance. It is one point, around level 30." },
    { "tactical mastery stance dance swap", "Tactical Mastery is free at level 14: you keep 10 rage when you change stance." },
    { "battle shout buff", "Battle Shout comes at level 1 here, lasts longer, and reaches the whole raid." },
    { "shield wall retaliation recklessness cooldown", "Shield Wall and Retaliation are 15 minute cooldowns in Forever and no longer share one with Recklessness." },
    { "sunder armor rend threat strength attack power", "Rend and Sunder Armor threat grows with your attack power, so strength is threat as well as damage." },
    { "rage crit starved armor", "Crits give 75% more rage, and rage from being hit ignores your armour. A well-armoured tank is not starved here." },
    { "shield slam 40 talent protection", "Shield Slam is the 31-point Protection talent, so level 40. Dual spec opens at 40 too." },
    { "taunt challenging shout loose", "Taunt for one loose enemy. Challenging Shout, from 26, pulls everything near you for a few seconds." },
    { "revenge improved", "Improved Revenge adds 60% to Revenge here. Press it every time it lights up." },
    { "tank talents build protection", "A common leveling tank build: Shield Specialization, Improved Revenge, Improved Thunder Clap, Last Stand, Master of Defense, Defiance, then Vanguard." },
  }
  Owl.CLASS_FACTS.PRIEST = {
    { "devouring plague undead", "Devouring Plague belongs to every priest in Forever, from level 20. It has a 24 second cooldown and lasts as long." },
    { "shadow word death execute backlash", "Shadow Word: Death comes at 32. If the target survives it, you lose 30% of your own health. Use it to finish, not to open." },
    { "shadowform form talent", "Shadowform halves the mana cost of shadow spells, adds 10% shadow damage and takes 15% off physical hits. No healing spells in it, but dispels still work." },
    { "mind flay channel improved", "Improved Mind Flay makes each tick hit 20% harder than the one before. A channel cut short loses its best part." },
    { "vampiric embrace heal party", "Vampiric Embrace heals your whole party while you deal damage: 30 seconds up, 30 second cooldown, so it can always be running." },
    { "vampiric touch", "There is no Vampiric Touch in Forever. Do not go looking for it." },
    { "shadow weaving debuff", "Shadow Weaving only raises your own damage here, up to 10% at five stacks." },
    { "fortitude divine spirit buff", "Divine Spirit is every priest's at level 30, and Fortitude has its old talent bonus built in." },
    { "silence interrupt", "Silence also interrupts for 3 seconds in Forever." },
    { "stats hit spell damage gear", "For dungeons and raids: hit first, then shadow and spell damage, then crit. Intellect and spirit come last." },
    { "threat aggro mind blast tank", "Mind Blast and Devouring Plague pull a lot of threat. Open with Shadow Word: Pain and let the tank get a hold." },
    { "rotation shadow priority", "Shadow priority: Shadow Word: Pain and Devouring Plague up, Mind Blast when ready, Shadow Word: Death when you can afford it, Mind Flay in every gap." },
  }
end
if type(Owl.LEVEL_FACTS) == "table" then
  Owl.LEVEL_FACTS.WARRIOR = { [10] = "Defensive Stance and Taunt come from your class quest at 10.", [14] = "Level 14: Demoralizing Shout at the trainer, and Tactical Mastery for free.",
    [20] = "Victory Rush and Cleave at the trainer.", [24] = "Execute at the trainer: your finisher.", [26] = "Challenging Shout at the trainer: it taunts everything near you.",
    [28] = "Shield Wall at the trainer. It is a 15 minute cooldown here.", [30] = "Berserker Stance and Intercept. Vanguard is in reach too: Charge in Defensive Stance.",
    [36] = "Whirlwind at the trainer.", [38] = "Pummel at the trainer: a proper interrupt.", [40] = "Your 31st talent point. For Protection that is Shield Slam." }
  Owl.LEVEL_FACTS.PRIEST = { [20] = "Devouring Plague at the trainer. Every priest gets it here.", [25] = "Binding Heal at the trainer.", [30] = "Divine Spirit at the trainer, no talent needed.",
    [32] = "Shadow Word: Death at the trainer. It bites back if the target lives.", [40] = "Your 31st talent point. For Shadow that is Shadowform." }
end
if type(O.OwlAnswers) == "table" and (CLASS == "WARRIOR" or CLASS == "PRIEST") then
  local A = O.OwlAnswers
  local function Points() local n = Call("GetNumUnspentTalents")[1] return type(n) == "number" and n or 0 end
  if CLASS == "WARRIOR" then
    A.rotation = function()
      if Tanking() then
        return { "Tanking: Charge in, Thunder Clap, then Sunder Armor on the main target.", "Revenge every time it lights up. Shield Block for the heavy hits.", "Taunt the moment something leaves you. Demoralizing Shout on big pulls." }
      end
      return { "Charge, Rend on anything that will live a while, then your hardest strike as rage allows.", "Execute once they are low, and Victory Rush after every kill: it is free." }
    end
    A.group = function()
      if Tanking() then
        return { "You set the pace. Check the healer's mana before each pull.", "Pick one target and hit it first. Thunder Clap holds the rest.", "One loose? Taunt. All loose? Challenging Shout.", "Turn them away from the group, and keep Battle Shout up." }
      end
      return { "Let the tank hit first, then attack what the tank is attacking.", "Hamstring runners. Pummel or Shield Bash the casters.", "Battle Shout before the pull." }
    end
    A.talent = function()
      local out = { "For tanking: Shield Specialization first. Every block is 5 rage here.", "Then Improved Revenge and Improved Thunder Clap, Last Stand, Master of Defense and Defiance.", "Vanguard around 30 lets you Charge in Defensive Stance. Shield Slam is your 31st point, at 40." }
      if Points() > 0 then out[#out + 1] = "And you have a point waiting right now." end
      return out
    end
  else
    A.rotation = function()
      if Shadow() then
        return { "Shadow Word: Pain and Devouring Plague on the target, Mind Blast whenever it is ready.", "Fill every gap with Mind Flay, and let it finish: each tick hits harder than the last.", "Shadow Word: Death only when you can take the hit back. Keep Vampiric Embrace running." }
      end
      return { "Shield, Shadow Word: Pain, then Smite or your wand.", "Spirit Tap after each kill is free mana. Keep moving while it lasts." }
    end
    A.group = function()
      if Shadow() then
        return { "Mind Blast and Devouring Plague pull a lot of threat. Let the tank get a firm hold first.", "Vampiric Embrace heals the whole party while you fight. Keep it up.", "You can dispel in Shadowform. Healing means dropping it, so only in an emergency.", "Fortitude and Divine Spirit on everyone before the first pull." }
      end
      return { "Stay behind the tank and watch every health bar, yours included.", "Shield the tank before the pull, and Fade if something turns on you.", "Fortitude on everyone. Drink whenever the group stops." }
    end
    A.talent = function()
      local out = { "Shadow is the leveling tree. Spirit Tap early: it pays for itself every kill.", "Mind Flay, then Improved Mind Flay. Vampiric Embrace sits at 16 points.", "Shadowform is the 31-point talent: half mana on shadow spells and 10% more shadow damage." }
      if Points() > 0 then out[#out + 1] = "And you have a point waiting right now." end
      return out
    end
  end
end

-- ---------- buffs and stances worth keeping up ----------
local BUFFS = {
  PRIEST = { { "Power Word: Fortitude", "Fortitude", { "No Fortitude on you.", "Your Fortitude has run out.", "Fortitude is down. One cast." } },
    { "Inner Fire", "Inner Fire", { "Inner Fire is not up.", "No Inner Fire. It costs almost nothing.", "Your Inner Fire has gone out." } },
    { "Divine Spirit", "Spirit", { "No Divine Spirit on you.", "Divine Spirit has lapsed." } },
    { "Shadowform", "Shadowform", { "You are out of Shadowform.", "No Shadowform. Everything costs double like this.", "Back into the shadows? You dropped the form." }, shadow = true } },
  WARRIOR = { { "Battle Shout", "Battle Shout", { "No Battle Shout on the group.", "Battle Shout has run out.", "The group is missing your shout." }, group = true } },
}
local function Buffed()
  if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then return nil end
  local names = {}
  for i = 1, 40 do
    local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
    if not ok then return nil end
    if not data then break end
    local name = Plain(data.name)
    if type(name) ~= "string" then return nil end
    names[#names + 1] = name
  end
  return names
end
local function StanceName()
  for i = 1, 4 do
    local r = Call("GetShapeshiftFormInfo", i)
    if r[2] == true and r[4] and O.SpellName then
      local ok, name = pcall(O.SpellName, r[4])
      if ok and type(Plain(name)) == "string" then return Plain(name) end
    end
  end
end
local function BuffCheck()
  if not OwlHUDDB.tips or OwlHUDDB.warnBuffs == false then return end
  if Plain(UnitAffectingCombat("player")) or Q("UnitIsDeadOrGhost", "player") or Q("UnitOnTaxi", "player") or Q("IsResting") or Q("IsMounted") then return end
  if Level() < 12 then return end
  local list = BUFFS[CLASS]
  local grouped = Q("IsInGroup") and true or false
  if list then
    local have = Buffed()
    if have then
      for _, b in ipairs(list) do
        local skip = (b.group and not grouped) or (b.shadow and (not Shadow() or (grouped and Call("UnitGroupRolesAssigned", "player")[1] == "HEALER")))
        if not skip and Knows(b[1]) then
          local up = false
          for _, name in ipairs(have) do if name:find(b[2], 1, true) then up = true end end
          if not up and Say("nobuff" .. b[1], b[3], 600) then return end
        end
      end
    end
  end
  if CLASS == "WARRIOR" and grouped and HasShield() then
    local inside = Call("IsInInstance")
    local stance = inside[1] and inside[2] == "party" and StanceName()
    if stance and stance ~= "Defensive Stance" and stance:find("Stance", 1, true) then
      Say("stance", { "You are holding a shield in " .. stance .. ". Defensive Stance for tanking.", stance .. ", with a shield, in a dungeon. Did you mean Defensive?" }, 600)
    end
  end
end
local acc = 0
local driver = CreateFrame("Frame")
local dead = false
driver:SetScript("OnUpdate", function(_, e)
  if dead then return end
  acc = acc + e
  if acc < 20 then return end
  acc = 0
  local ok, err = pcall(BuffCheck)
  if not ok then dead = true O.Print("|cffff4040owl buff reminders turned off:|r " .. tostring(err)) end
end)
O.commands.variety = function()
  OwlHUDDB.variety = OwlHUDDB.variety == false
  O.Print("his extra wordings and small talk" .. (OwlHUDDB.variety and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end
Owl.voice = { VOICE_MORE = VOICE_MORE, MORE = MORE, Quirk = Quirk, QuirkLines = QuirkLines, BuffCheck = BuffCheck, IDLE = IDLE }
end
O.Try("owl voice setup", Owl.VoiceSetup)
O.OwlTestVoice = function() return Owl.voice end

-- =====================================================================================
-- /owl owl: everything he can do
-- =====================================================================================
O.commands.owl = function()
  O.Print(Name() .. " the owl:")
  print("  /owl ask  - ask him about talents, trainers, where to go, your rotation")
  print("  /owl journal  - the journal he keeps of your journey")
  print("  /owl name Hooty  - name him")
  print("  /owl voice  - cheerful, sage or sarcastic")
  print("  /owl chatty  - how often he makes small talk")
  print("  /owl goal 100 mount  - a savings goal he cheers you toward")
  print("  /owl wave  - hoot at the owls of friends in your group")
  print("  /owl watch horde  - a word he listens for in chat; /owl unwatch to remove")
  print("  /owl sense  - his lookout for enemy players near you, on or off")
  print("  /owl auctions  - what the auction house has sent to your mail")
  print("  /owl me  - everything he knows about your character")
  print("  /owl quests | stock | gold | foes  - your quest log by zone, gathered goods, gold in and out, what has hurt you")
  print("  /owl deep  - his memory of fights, quests, gold and friends, on or off")
  print("  Say his name (or \"owl\") in /say and he answers: try thanks, how are you, where are we, tell me a joke, good night.")
  print("  /owl options  - every setting in one window (or just click the owl).  /owl note <text>  - jot something down for Claude.  /owl report  - a check of what works")
  print("  /owl flights  - flight paths you have not picked up yet")
  print("  /owl mood  - what temper he woke up in today.  /owl flavor  - his asides, on or off")
  print("  /owl tip  - something he knows about Forever.  /owl know camping  - ask him about a subject (legacy, mount, judgement, herbs ...)")
  print("  /owl lfg | join | rep | mana  - groups forming for your level, ask for a spot, reputation gained, healing and damage per mana")
  print("  /owl route | needs | worth | hunt  - a walking order for quests here, what quests still need, what your bags sell for, your weakest gear")
  print("  /owl yearbook | bets | secrets | request | family  - a page per level, his bets on you, secrets found, what he asked for, your other characters")
  print("  /owl pull  - sizes up your target.  /owl plan  - what to do this session.  /owl week  - the week so far")
  print("  /owl collection | rival | bank [word]  - what you have met, the board against friends, what is in your bank")
  print("  /owl text 16  - the size of his words (10 to 26)")
  print("  /owl notes  - what friends' owls have told him (dangers, enemy players, rares, wish lists).  /owl whohas silk  - who is holding something")
  print("  /owl pals  - his owl friends.  /owl bow | dance | five | hug [name]  - he does it, and their owl answers")
  print("  /owl hootoff | gift | peek [name]  - a hoot-off, a treat for their owl, a look in their wardrobe")
  print("  /owl party | readyall | where  - the party's kills and quest progress, everyone's ready check, where friends are")
  print("  /owl post Thicc back at eight  - a note his owl delivers, now or when they are next on.  /owl social  - all of this on or off")
  print("  /owl version  - which version you have, and whether friends' owls match.  /owl welcome  - the first-meeting window again")
  print("  /owl quirks  - what makes this owl himself: where he hatched, what he eats, what he fears.  /owl variety  - his extra wordings, on or off")
  print("  /owl flytalk  - on flight paths he talks about the places below and ignores what is on the ground, on or off")
  print("  /owl plumage | head | marks  - his feathers, the shape of his head, and markings. Some are earned.")
  print("  (/owl lanterns list and /owl torches list print the same thing in chat instead of opening the window)")
  print("  /owl lanterns | torches  - the rare finds: a lantern hidden in every dungeon, a torch in some zones, Common to Legendary.  /owl rarefinds  - on or off")
  print("  /owl wardrobe | goals | wear scarf  - dress him, see the goals he has set himself, put one thing on")
  print("  /owl friendowl  - friends' owls beside yours in a group, on or off.  /owl goals swap 2  - trade a goal for another")
  print("  /owl outfit | bubble  - the things he wears on or off; parchment or dark speech bubble")
  print("  /owl bond | pat | trick  - your bond with him, a pat on the head, and a trick once he trusts you")
  print("  /owl pace | records | herbs | vendors  - time to the next milestone, your bests, your gathering spots, vendors he knows")
  print("  /owl bis  - upgrade and quest reward advice from Forever Leveling BiS, on or off")
  print("  /owl ready  - a quick check that you are set for a dungeon or a long trip")
  print("  /owl stats  - this session: XP an hour, time to next level, kills, gold")
  print("  /owl remind 20 check auctions  - he reminds you in 20 minutes")
  print("  /owl spells  - spells in your spellbook that are on no bar")
  print("  /owl replies  - the quick-reply buttons under a whisper, on or off")
  print("  /owl hoot  - make him say something now")
  print("  /owl perch | hats | tips  - his perch, his hats, or all of him, on or off")
  print("  /owl fancy  - his glow, sparkles and movement, on or off")
  print("  /owl size 160  - how big he is (50 to 300)")
  print("  click him: left to skip or open the menu, right to hush him for ten minutes")
end

-- =====================================================================================
-- Quiet signals: the small standing reminders are said once a session. After that he
-- shows a word over his head for a few seconds instead of saying the whole thing again.
-- =====================================================================================
do
O.defaults.signals = true
local SIGNAL = { bags2 = "Bags", dur25 = "Repair", mail = "Mail", talent = "Talent", trainer = "Trainer" }
local spoken, shownAt, badge, badgeUntil = {}, {}, nil, 0
local function Badge(word)
  local perch = _G.OwlHUDPerch
  if not perch or not perch:IsShown() then return false end
  if not badge then
    badge = perch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge:SetPoint("BOTTOM", perch, "TOP", 0, 2)
  end
  badge:SetText("|cffffd100" .. word .. "|r")
  badge:Show()
  badgeUntil = GetTime() + 6
  if C_Timer and C_Timer.After then
    C_Timer.After(6.2, function() if badge and GetTime() >= badgeUntil then badge:Hide() end end)
  end
  return true
end
local gateBefore = O.OwlGate
O.OwlGate = function(key)
  if gateBefore then
    local ok, pass = pcall(gateBefore, key)
    if ok and pass == false then return false end
  end
  local word = type(key) == "string" and SIGNAL[key]
  if not word or OwlHUDDB.signals == false then return true end
  local now = GetTime()
  -- the first time this session he says it properly
  if not spoken[key] then spoken[key] = now return true end
  -- after that: the word over his head, at most once every ten minutes. If the word cannot be shown, he speaks.
  if now - spoken[key] < 60 then return false end
  if now - (shownAt[key] or -1000) < 600 then return false end
  if not (C_Timer and C_Timer.After) or not Badge(word) then return true end
  shownAt[key] = now
  return false
end
O.commands.signals = function()
  OwlHUDDB.signals = OwlHUDDB.signals == false
  O.Print("a word over his head instead of repeating small reminders" .. (OwlHUDDB.signals and ": |cff40ff40on|r" or ": |cffff4040off|r (he says them each time)"))
end
end

-- =====================================================================================
-- Weather, step one: find out what the game will tell him. Nothing here speaks or shows.
-- /owl report lists every weather function and event the game has, for Claude to read.
-- (This is how C_Weather.GetCurrentWeather and the WEATHER_CHANGED event were found.)
-- =====================================================================================
do
local EVENTS = { "WEATHER_UPDATE", "WEATHER_CHANGED", "ZONE_WEATHER_UPDATE", "ZONE_WEATHER_CHANGED", "PLAYER_WEATHER_UPDATE", "PLAYER_WEATHER_CHANGED", "CURRENT_WEATHER_CHANGED",
  "WEATHER_STATE_CHANGED", "AREA_WEATHER_UPDATE", "WEATHER_INFO_UPDATE", "WEATHER_FORECAST_UPDATE", "WORLD_WEATHER_UPDATE", "SEASON_CHANGED", "WEATHER_TYPE_CHANGED" }
local heard = {}
local ok, listener = pcall(CreateFrame, "Frame")
if ok and listener then
  for _, event in ipairs(EVENTS) do
    if pcall(listener.RegisterEvent, listener, event) then heard[#heard + 1] = event end
  end
  -- it only needed to learn which events exist; it does not listen any more
  pcall(listener.UnregisterAllEvents, listener)
end
-- the scratch notes from finding all this out are no longer kept
O.On("PLAYER_LOGIN", function()
  OwlHUDDB.weatherLog = nil
  if type(OwlHUDDB.weatherNotes) == "table" then OwlHUDDB.weatherNotes["parts unknown"] = nil end
end)
local function Has(text, word) return type(text) == "string" and text:lower():find(word, 1, true) ~= nil end
local function Show(v)
  v = Plain(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for k, x in pairs(v) do if #parts < 12 then parts[#parts + 1] = tostring(k) .. "=" .. tostring(Plain(x)) end end
  table.sort(parts)
  return "{" .. table.concat(parts, ",") .. "}"
end
Owl.probe = Owl.probe or {}
Owl.probe.weather = function()
  local out = { "events[" .. table.concat(heard, ",") .. "]" }
  local function try(label, fn)
    -- only plain questions are asked (GetX, IsX, HasX); nothing that might change anything is called
    local last = label:match("([^%.]+)$") or label
    if not (last:find("^Get") or last:find("^Is") or last:find("^Has")) then return end
    local got = { pcall(fn) }
    if not got[1] then out[#out + 1] = label .. "()=ERROR" return end
    local parts = {}
    for i = 2, math.min(#got, 6) do parts[#parts + 1] = Show(got[i]) end
    out[#out + 1] = label .. "()=" .. table.concat(parts, ";")
  end
  for name, v in pairs(_G) do
    if type(name) == "string" then
      if Has(name, "weather") or Has(name, "forecast") then
        if type(v) == "table" then
          local members = {}
          pcall(function() for k, x in pairs(v) do members[#members + 1] = tostring(k) .. ":" .. type(x) end end)
          table.sort(members)
          out[#out + 1] = name .. "{" .. table.concat(members, ","):sub(1, 400) .. "}"
          pcall(function() for k, x in pairs(v) do if type(x) == "function" then try(name .. "." .. tostring(k), x) end end end)
        else
          out[#out + 1] = name .. ":" .. type(v)
          if type(v) == "function" then try(name, v) end
        end
      elseif name:sub(1, 2) == "C_" and type(v) == "table" then
        pcall(function()
          for k, x in pairs(v) do
            if Has(k, "weather") or Has(k, "forecast") then
              out[#out + 1] = name .. "." .. k .. ":" .. type(x)
              if type(x) == "function" then try(name .. "." .. k, x) end
            end
          end
        end)
      end
    end
  end
  if type(Enum) == "table" then
    for name, v in pairs(Enum) do
      if Has(name, "weather") and type(v) == "table" then
        local members = {}
        for k, x in pairs(v) do members[#members + 1] = tostring(k) .. "=" .. tostring(x) end
        table.sort(members)
        out[#out + 1] = "Enum." .. name .. "{" .. table.concat(members, ",") .. "}"
      end
    end
  end
  local zones = 0
  for _ in pairs(type(OwlHUDDB.weatherNotes) == "table" and OwlHUDDB.weatherNotes or {}) do zones = zones + 1 end
  out[#out + 1] = "zonesWatched=" .. zones .. " IsIndoors:" .. type(_G.IsIndoors) .. " UnitInRange:" .. type(_G.UnitInRange) .. " face=" .. tostring(Owl.wxFace)
  -- the report keeps the whole answer, not just the first line of it
  OwlHUDDB.weatherProbe = out
  return table.concat(out, " | "):sub(1, 600)
end
end

-- =====================================================================================
-- Weather, step two: the real thing. The game says what the weather is right now
-- (C_Weather.GetCurrentWeather: a type and how hard it is coming down) and nothing about
-- what comes next. So he watches, writes down every spell of weather he sees start and
-- stop in each zone, and works out the usual from his own notes. Owls share sightings.
-- =====================================================================================
do
O.defaults.weather = true
table.insert(Owl.moods, 1, { "skyclear", "happy" })
local KIND = { [1] = "rain", [2] = "snow", [3] = "sand", [4] = "misc" }
local WORD = { rain = "rain", snow = "snow", sand = "a sandstorm", misc = "strange weather" }
local FACE = { snow = "owl_cold.tga", sand = "owl_squint.tga" }
local START = {
  rain = { "It has started to rain.", "Rain. I am keeping my feathers out of it.", "Drizzle. Owls do not love drizzle." },
  rainhard = { "A proper downpour. I am soaked already.", "Heavy rain. Nobody will hear us coming, at least." },
  snow = { "It is snowing. Look at that.", "Snow. I am fluffing up." },
  snowhard = { "A blizzard. Stay where I can see you.", "Heavy snow. I can barely see my own wings." },
  sand = { "Sandstorm. Eyes shut. Mine, I mean.", "Sand in my feathers. I will be finding it for a week." },
  misc = { "The weather has turned strange. I do not have a word for it." },
}
local STOP = { rain = { "The rain has stopped.", "Dry again. Finally." }, snow = { "The snow has stopped." }, sand = { "The sand has settled." }, misc = { "The sky is back to normal." } }

local function Read()
  if not (C_Weather and C_Weather.GetCurrentWeather) then return nil, 0, false end
  local ok, w = pcall(C_Weather.GetCurrentWeather)
  if not ok or type(w) ~= "table" then return nil, 0, false end
  local kind = KIND[Num(Plain(w.type)) or 0]
  local hard = Num(Plain(w.intensity)) or 0
  if hard < 0.05 then kind = nil end
  return kind, hard, true
end
local function Notes(zone)
  if type(OwlHUDDB.weatherNotes) ~= "table" then OwlHUDDB.weatherNotes = {} end
  local n = OwlHUDDB.weatherNotes[zone]
  if type(n) ~= "table" then n = {} OwlHUDDB.weatherNotes[zone] = n end
  if type(n.spells) ~= "table" then n.spells = {} end
  if type(n.gaps) ~= "table" then n.gaps = {} end
  if type(n.count) ~= "table" then n.count = {} end
  n.watched, n.wet = Num(n.watched) or 0, Num(n.wet) or 0
  return n
end
-- the middle value of what he has seen: the usual, not thrown off by one long storm
local function Usual(list, kind)
  local v = {}
  for _, e in ipairs(list) do
    if type(e) == "table" and (not kind or e.k == kind) and Num(e.d) then v[#v + 1] = e.d elseif not kind and Num(e) then v[#v + 1] = e end
  end
  if #v < 3 then return nil end
  table.sort(v)
  return v[math.floor((#v + 1) / 2)]
end
local function Mins(seconds)
  local m = math.floor(seconds / 60 + 0.5)
  if m < 1 then return "under a minute" end
  return m == 1 and "a minute" or (m .. " minutes")
end
local function Tell(zone, kind)
  if OwlHUDDB.social == false then return end
  local text = zone:gsub("[;|]", ""):sub(1, 50) .. ";" .. kind
  if Owl.net then pcall(Owl.net.Send, "WX", text) end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    for who, data in pairs(Owl.cos and Owl.cos.friends or {}) do
      if data.far then pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "WX|" .. Name() .. "|" .. text, "WHISPER", Owl.Addr(who)) end
    end
  end
end

-- cur: what is falling now, in which zone, since when; "whole" means he saw it begin
local cur = { zone = nil, kind = nil, since = 0, peak = 0, whole = false, dryFrom = nil, seen = false }
local want, wantN, lastAt = nil, 0, nil
local function Step()
  if OwlHUDDB.weather == false then Owl.wxFace = nil return end
  local now, zone = Now(), Zone()
  -- under a roof or in a dungeon the sky tells him nothing: hold everything as it was
  if Q("IsIndoors") or Q("IsInInstance") or Q("UnitOnTaxi", "player") then
    lastAt = nil
    cur.pausedAt = cur.pausedAt or now
    return
  end
  local kind, hard, can = Read()
  if not can or zone == "parts unknown" then return end
  -- back under the sky after more than a couple of minutes away: he cannot know what he missed, so whatever is
  -- falling now did not "begin" in front of him, and the dry spell he was timing no longer counts
  if cur.pausedAt then
    if now - cur.pausedAt > 120 then cur.seen, cur.whole, cur.dryFrom = false, false, nil end
    cur.pausedAt = nil
  end
  local notes = Notes(zone)
  if zone ~= cur.zone then
    -- a new zone: whatever was falling in the last one is not finished, just out of sight
    cur.zone, cur.kind, cur.whole, cur.dryFrom, cur.seen, cur.peak = zone, nil, false, nil, false, 0
    want, wantN, lastAt = nil, 0, nil
  end
  if lastAt then
    local dt = math.min(now - lastAt, 30)
    notes.watched = notes.watched + dt
    if cur.kind then notes.wet = notes.wet + dt end
  end
  lastAt = now
  if kind == cur.kind then
    want, wantN = nil, 0
    if kind and hard > cur.peak then cur.peak = hard end
    cur.seen = true
    return
  end
  -- a change has to hold for two looks in a row, so a flicker at the edge is not a new storm
  if want == kind and wantN >= 1 then wantN = wantN + 1 else want, wantN = kind, 1 end
  if cur.seen and wantN < 2 then return end
  want, wantN = nil, 0
  local was = cur.kind
  if was then
    if cur.whole then
      notes.spells[#notes.spells + 1] = { k = was, d = math.floor(now - cur.since), p = math.floor(cur.peak * 100) / 100 }
      while #notes.spells > 30 do table.remove(notes.spells, 1) end
    end
    if not kind then
      cur.dryFrom = now
      local line = STOP[was][math.random(#STOP[was])]
      local gap = Usual(notes.gaps)
      if gap then line = line .. " Going by my notes, the next is about " .. Mins(gap) .. " off." end
      Say("skyclear" .. was, line, 600)
      Tell(zone, "clear")
    end
  end
  if kind then
    -- he saw it begin only if he was already watching this zone under a clear sky
    cur.whole = cur.seen and not was
    if cur.whole and cur.dryFrom then
      notes.gaps[#notes.gaps + 1] = math.floor(now - cur.dryFrom)
      while #notes.gaps > 30 do table.remove(notes.gaps, 1) end
    end
    cur.dryFrom = nil
    notes.count[kind] = (Num(notes.count[kind]) or 0) + 1
    local pool = (hard >= 0.6 and START[kind .. "hard"]) or START[kind]
    local line = pool[math.random(#pool)]
    local long = Usual(notes.spells, kind)
    if long then line = line .. " Here it usually lasts about " .. Mins(long) .. "." end
    Say("weather" .. kind, line, 900)
    Tell(zone, kind)
  end
  cur.kind, cur.since, cur.peak, cur.seen = kind, now, hard, true
  Owl.wxFace = kind and (FACE[kind] or (hard >= 0.6 and "owl_cold.tga") or nil) or nil
end
local function Safe() O.Try("owl weather", Step) end
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, e)
  acc = acc + e
  if acc >= 5 then acc = 0 Safe() end
end)
for _, event in ipairs({ "WEATHER_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
  O.On(event, function() acc = 3 end)
end

-- what the other owls have seen
Owl.wxHeard = {}
local netBefore = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if kind ~= "WX" or type(extra) ~= "string" then return end
  local zone, what = extra:match("^(.-);(%a+)$")
  if not zone or zone == "" then return end
  local n = 0
  for _ in pairs(Owl.wxHeard) do n = n + 1 end
  if n < 40 or Owl.wxHeard[zone] then Owl.wxHeard[zone] = { k = what, at = Now(), who = sender, owl = owl } end
end

O.commands.weather = function(arg)
  if arg == "off" or arg == "on" then
    OwlHUDDB.weather = arg == "on"
    if not OwlHUDDB.weather then Owl.wxFace = nil end
    O.Print("watching the weather" .. (OwlHUDDB.weather and ": |cff40ff40on|r" or ": |cffff4040off|r"))
    return
  end
  local zone = Zone()
  local kind, hard, can = Read()
  O.Print("|cffffd100Weather|r")
  if not can then print("  The game is not telling me the weather here.") return end
  print("  " .. zone .. " now: " .. (kind and (WORD[kind] .. ", " .. math.floor(hard * 100 + 0.5) .. "% strength") or "clear") .. (Q("IsIndoors") and " (you are indoors, so I am not counting this)" or "") .. ".")
  local notes = Notes(zone)
  if notes.watched < 600 then
    print("  I have only watched the sky here for " .. Mins(notes.watched) .. ". Too soon to say what is usual.")
  else
    print("  Watched here for " .. Mins(notes.watched) .. ": weather " .. math.floor(notes.wet / notes.watched * 100 + 0.5) .. "% of that time.")
    for _, k in ipairs({ "rain", "snow", "sand", "misc" }) do
      local long = Usual(notes.spells, k)
      if long then print("  " .. WORD[k]:gsub("^%l", string.upper) .. " here usually lasts about " .. Mins(long) .. " (" .. (notes.count[k] or 0) .. " seen).")
      elseif (Num(notes.count[k]) or 0) > 0 then print("  " .. WORD[k]:gsub("^%l", string.upper) .. " seen here " .. notes.count[k] .. (notes.count[k] == 1 and " time" or " times") .. ". I need three from start to finish before I will call a usual length.") end
    end
    local gap = Usual(notes.gaps)
    if gap then
      local line = "  Dry spells here usually last about " .. Mins(gap) .. "."
      if not kind and cur.zone == zone and cur.dryFrom then line = line .. " This one is " .. Mins(Now() - cur.dryFrom) .. " old." end
      print(line)
    else print("  What comes next: I cannot say yet. I need to see three dry spells here from end to end.") end
  end
  for z, h in pairs(Owl.wxHeard) do
    if Now() - h.at < 1800 then print("  " .. tostring(h.owl) .. " (" .. tostring(h.who) .. ") saw " .. (WORD[h.k] or "clear skies") .. " in " .. z .. " " .. Mins(Now() - h.at) .. " ago.") end
  end
end
end

-- =====================================================================================
-- Other players: he remembers who has killed you and whom you have beaten, by name.
-- The one who has killed you most is your nemesis. The one you keep beating, you bully.
-- =====================================================================================
do
O.defaults.pvpMemory = true
table.insert(Owl.moods, 1, { "pvpdeath", "worried" })
table.insert(Owl.moods, 1, { "pvpkill", "excited" })
local function Book()
  local rec = Owl.Record()
  if type(rec.pvp) ~= "table" then rec.pvp = {} end
  if type(rec.pvp.by) ~= "table" then rec.pvp.by = {} end
  if type(rec.pvp.won) ~= "table" then rec.pvp.won = {} end
  return rec.pvp
end
local function Key(name) return Owl.First(tostring(name):gsub("%-.*$", "")) end
local function Entry(list, name)
  local e = list[name]
  if type(e) ~= "table" then
    -- room for 150 names: when full, the oldest one-off meeting is forgotten
    local n, oldest, oldestAt = 0, nil, nil
    for k, v in pairs(list) do
      n = n + 1
      if type(v) == "table" and (Num(v.n) or 0) <= 1 and (not oldestAt or (Num(v.last) or 0) < oldestAt) then oldest, oldestAt = k, Num(v.last) or 0 end
    end
    if n >= 150 and oldest then list[oldest] = nil end
    e = { n = 0 }
    list[name] = e
  end
  e.n = Num(e.n) or 0
  return e
end
local function Top(list)
  local best, bestN = nil, 0
  for name, e in pairs(list) do
    if type(e) == "table" and (Num(e.n) or 0) > bestN then best, bestN = name, e.n end
  end
  return best, bestN
end
local function Times(n) return n == 1 and "once" or (n == 2 and "twice" or (n .. " times")) end

-- what he knows of the enemy players he has seen: level and class, for the first line about them
local seenAs = {}
local enemyBefore = Owl.onEnemy
Owl.onEnemy = function(name, what)
  if type(name) == "string" and type(what) == "string" then seenAs[Key(name)] = what end
  if enemyBefore then return enemyBefore(name, what) end
end

-- you died, and a player did it
O.On("PLAYER_DEAD", function()
  local killer = Owl.killer
  if OwlHUDDB.pvpMemory == false or type(killer) ~= "table" or not killer.player or type(killer.name) ~= "string" then return end
  local book, name = Book(), Key(killer.name)
  if name == "" or name == Me() then return end
  local e = Entry(book.by, name)
  e.n, e.last, e.zone = e.n + 1, Clock(), Zone()
  if seenAs[name] then e.what = seenAs[name] end
  local nemesis = Top(book.by)
  local line
  if e.n == 1 then line = name .. " killed you." .. (e.what and (" A " .. e.what .. ".") or "") .. " I have written the name down."
  elseif e.n == 2 then line = name .. " again. That is twice."
  else line = name .. " again. " .. e.n .. " times now." .. (nemesis == name and " That one is your nemesis." or "") end
  local won = type(book.won[name]) == "table" and Num(book.won[name].n) or 0
  if won > 0 and e.n > 1 then line = line .. " You have beaten them " .. Times(won) .. "." end
  local function say() Say("pvpdeath" .. name .. e.n, line, 0) end
  if C_Timer and C_Timer.After then C_Timer.After(3, function() pcall(say) end) else say() end
end)

-- you beat a player: the combat log says so when you land the killing blow, the honor message when you get credit
local countedAt = {}
Owl.onPvpKill = function(who)
  if OwlHUDDB.pvpMemory == false or type(who) ~= "string" then return end
  local name = Key(who)
  if name == "" or name == Me() then return end
  if countedAt[name] and Now() - countedAt[name] < 20 then return end
  countedAt[name] = Now()
  local book = Book()
  local e = Entry(book.won, name)
  e.n, e.last, e.zone = e.n + 1, Clock(), Zone()
  if seenAs[name] then e.what = seenAs[name] end
  local by = type(book.by[name]) == "table" and Num(book.by[name].n) or 0
  local line
  if e.n == 1 then line = by > 0 and ("You beat " .. name .. ". Revenge: they had killed you " .. Times(by) .. ".") or ("You beat " .. name .. ". First time for that one.")
  elseif by > 0 and e.n == by then line = "That evens it with " .. name .. ": " .. e.n .. " each."
  elseif e.n == 3 then line = "Three wins over " .. name .. ". They must dread the sight of you."
  elseif e.n == 5 then line = "Five wins over " .. name .. ". At this point you are bullying them."
  elseif e.n % 10 == 0 then line = e.n .. " wins over " .. name .. ". Leave some for the others." end
  if line then Say("pvpkill" .. name .. e.n, line, 0, "c") end
end
O.On("CHAT_MSG_COMBAT_HONOR_GAIN", function(msg)
  msg = Plain(msg)
  local name = type(msg) == "string" and msg:match("^(.-) dies, honorable kill")
  if name and name ~= "" then Owl.onPvpKill(name) end
end)

-- when he spots one of them again: tacked onto the line he already says, not a line of its own
Owl.pvpNote = function(who)
  if OwlHUDDB.pvpMemory == false then return nil end
  local book, name = Book(), Key(who)
  local by = type(book.by[name]) == "table" and Num(book.by[name].n) or 0
  local won = type(book.won[name]) == "table" and Num(book.won[name].n) or 0
  if by == 0 and won == 0 then return nil end
  if by > 0 and won > 0 then return " The score: you " .. won .. ", them " .. by .. "." end
  if by > 0 then return " They have killed you " .. Times(by) .. "." .. ((by >= 3 and Top(book.by) == name) and " Your nemesis." or "") end
  if won >= 3 then return " You have beaten them " .. Times(won) .. ". Go easy." end
  return " You have beaten them before."
end

-- for his idle remarks about you
Owl.pvpFacts = function()
  if OwlHUDDB.pvpMemory == false then return {} end
  local book, out = Book(), {}
  local nemesis, nemesisN = Top(book.by)
  if nemesis and nemesisN >= 2 then out[#out + 1] = "Your nemesis is " .. nemesis .. ": killed you " .. Times(nemesisN) .. ". I have not forgotten." end
  local victim, victimN = Top(book.won)
  if victim and victimN >= 3 then out[#out + 1] = "You have beaten " .. victim .. " " .. Times(victimN) .. ". Some would call that bullying." end
  local wins, losses = 0, 0
  for _, e in pairs(book.won) do wins = wins + (type(e) == "table" and Num(e.n) or 0) end
  for _, e in pairs(book.by) do losses = losses + (type(e) == "table" and Num(e.n) or 0) end
  if wins + losses >= 3 then out[#out + 1] = "Against other players: " .. wins .. (wins == 1 and " win, " or " wins, ") .. losses .. (losses == 1 and " loss" or " losses") .. ", by my count." end
  return out
end

O.commands.pvp = function(arg)
  if arg == "off" or arg == "on" then
    OwlHUDDB.pvpMemory = arg == "on"
    O.Print("remembering other players" .. (OwlHUDDB.pvpMemory and ": |cff40ff40on|r" or ": |cffff4040off|r"))
    return
  end
  local book = Book()
  local function list(title, t, verb)
    local rows = {}
    for name, e in pairs(t) do if type(e) == "table" and (Num(e.n) or 0) > 0 then rows[#rows + 1] = { name, e.n, e.what, e.zone } end end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    print("  " .. title .. (#rows == 0 and " nobody yet." or ""))
    for i = 1, math.min(#rows, 8) do
      local r = rows[i]
      print("    " .. r[1] .. (r[3] and (" (" .. r[3] .. ")") or "") .. ": " .. verb .. " " .. Times(r[2]) .. (r[4] and (", last in " .. r[4]) or "") .. ".")
    end
  end
  O.Print("|cffffd100Other players|r")
  list("Killed you:", book.by, "killed you")
  list("You have beaten:", book.won, "beaten")
  print("  Combat log: " .. (Owl.clog and Owl.clog.registered and (Owl.clog.named > 0 and "reading it." or "listening, nothing aimed at you yet this session.") or "not available, so he goes by who had you targeted."))
end
Owl.probe = Owl.probe or {}
Owl.probe.pvp = function()
  local book, by, won = Book(), 0, 0
  for _ in pairs(book.by) do by = by + 1 end
  for _ in pairs(book.won) do won = won + 1 end
  local k = Owl.killer
  return "clog registered=" .. tostring(Owl.clog and Owl.clog.registered) .. " events=" .. tostring(Owl.clog and Owl.clog.events) .. " hitsOnYouNamed=" .. tostring(Owl.clog and Owl.clog.named)
    .. " fn=" .. type(CombatLogGetCurrentEventInfo) .. " killedBy=" .. by .. " beaten=" .. won
    .. " lastKiller=" .. (type(k) == "table" and (tostring(k.name) .. "/player=" .. tostring(k.player) .. "/sure=" .. tostring(k.sure)) or "none")
end
end

-- =====================================================================================
-- The things friends notice first: awards after a dungeon, a reading of your character
-- the day you meet him, owls that talk to each other, and a recap when you log off.
-- =====================================================================================
do
local function Scrub(text, limit) return (tostring(text):gsub("[;|%c]", ""):sub(1, limit)) end
local function Later(seconds, fn)
  if C_Timer and C_Timer.After then C_Timer.After(seconds, function() O.Try("owl extras", fn) end) else O.Try("owl extras", fn) end
end
local function Span(seconds)
  local m = math.floor(seconds / 60 + 0.5)
  if m < 60 then return m .. " min" end
  return math.floor(m / 60) .. " h " .. (m % 60) .. " min"
end

-- ---------- 1. dungeon awards ----------
-- Every owl in the party tells the others how its player did (deaths, lowest health, killing blows, levels), and
-- then they all hand out the same awards. It happens when the first of you walks out after a run of eight minutes
-- or more, or when anyone types /owl awards.
O.defaults.awards = true
local rows, announcedAt, repliedAt = {}, {}, {}
local function Run()
  local rec = Owl.Record()
  return type(rec.run) == "table" and rec.run.name and rec.run or nil
end
local function MyRow(run)
  return { deaths = Num(run.deaths) or 0, low = math.floor(Num(run.low) or 100), blows = Num(run.blows) or 0, levels = Num(run.levels) or 0 }
end
local function Tell(dungeon, run, asking)
  local r = MyRow(run)
  if Owl.net then pcall(Owl.net.Send, "AWD", dungeon .. ";" .. r.deaths .. ";" .. r.low .. ";" .. r.blows .. ";" .. r.levels .. ";" .. (asking and 1 or 0)) end
end
local function Announce(dungeon)
  if OwlHUDDB.awards == false then return end
  if announcedAt[dungeon] and Now() - announcedAt[dungeon] < 1200 then return end
  local set = rows[dungeon]
  if type(set) ~= "table" then return end
  local names = {}
  for name in pairs(set) do names[#names + 1] = name end
  if #names < 2 then return end
  table.sort(names)
  announcedAt[dungeon] = Now()
  local parts = {}
  -- Floor Inspector: the most deaths
  local most, mostN, shared = nil, 0, false
  for _, name in ipairs(names) do
    local d = set[name].deaths
    if d > mostN then most, mostN, shared = name, d, false elseif d == mostN and d > 0 then shared = true end
  end
  if most then parts[#parts + 1] = "Floor Inspector: " .. most .. (shared and " (shared)" or "") .. ", " .. mostN .. (mostN == 1 and " death" or " deaths") end
  -- Closest Shave: got lowest and lived to tell
  local shave, shaveN = nil, 20
  for _, name in ipairs(names) do
    local low = set[name].low
    if low > 0 and low < shaveN then shave, shaveN = name, low end
  end
  if shave then parts[#parts + 1] = "Closest Shave: " .. shave .. ", down to " .. shaveN .. "% health" end
  -- Finisher: the most killing blows, when one of you is clearly ahead
  local fin, finN, finTie = nil, 4, false
  for _, name in ipairs(names) do
    local b = set[name].blows
    if b > finN then fin, finN, finTie = name, b, false elseif b == finN then finTie = true end
  end
  if fin and not finTie then parts[#parts + 1] = "Finisher: " .. fin .. ", " .. finN .. " killing blows" end
  -- Untouchable: the only one who never died, when somebody did
  if mostN > 0 then
    local clean = {}
    for _, name in ipairs(names) do if set[name].deaths == 0 then clean[#clean + 1] = name end end
    if #clean == 1 then parts[#parts + 1] = "Untouchable: " .. clean[1] .. ", not one death" end
  end
  -- Ding: levelled in there
  local dinged = {}
  for _, name in ipairs(names) do if set[name].levels > 0 then dinged[#dinged + 1] = name end end
  if #dinged > 0 then parts[#parts + 1] = "Ding: " .. table.concat(dinged, " and ") .. " levelled in there" end
  while #parts > 3 do table.remove(parts) end
  local line
  if #parts == 0 then line = "A clean run of " .. dungeon .. ". Nobody died and nobody came close. No awards for falling over."
  else line = "Awards for " .. dungeon .. ". " .. table.concat(parts, ". ") .. "." end
  if Owl.stage and Owl.stage.Notice then
    local show = {}
    for _, part in ipairs(parts) do show[#show + 1] = (part:gsub("^([^:]+):", function(name) return Owl.stage.Key(name) .. ":" end)) end
    if #show == 0 then show[1] = "Nobody died and nobody came close." end
    pcall(Owl.stage.Notice, (#parts == 0 and "A clean run: " or "Awards: ") .. dungeon, show, 9)
  end
  O.Print("|cffffd100" .. (#parts == 0 and "A clean run" or "Awards") .. "|r  " .. dungeon)
  for _, part in ipairs(parts) do print("   " .. part) end
  Say("awards" .. dungeon .. Now(), line, 0, "uc")
  if Owl.cos then
    if Owl.cos.Idle then pcall(Owl.cos.Idle, "cheer", 1.2) end
    for _, name in ipairs(names) do if name ~= Me() and Owl.cos.Hop then pcall(Owl.cos.Hop, name, "Hoo!", "cheer") end end
  end
end
local function Begin(byHand)
  local run = Run()
  if not run then
    if byHand then O.Print("no dungeon run to give awards for. Use this at the end of a dungeon, with your group.") end
    return
  end
  if not Q("IsInGroup") then
    if byHand then O.Print("awards need your group. You are on your own.") end
    return
  end
  if not byHand and Clock() - (Num(run.start) or Clock()) < 480 then return end
  local dungeon = Scrub(run.name, 30)
  if byHand then announcedAt[dungeon] = nil elseif announcedAt[dungeon] and Now() - announcedAt[dungeon] < 1200 then return end
  rows[dungeon] = rows[dungeon] or {}
  rows[dungeon][Me()] = MyRow(run)
  Tell(dungeon, run, true)
  Later(6, function() Announce(dungeon) end)
  if byHand then O.Print("asking the other owls how their players did...") end
end
O.commands.awards = function(arg)
  if arg == "off" or arg == "on" then
    OwlHUDDB.awards = arg == "on"
    O.Print("awards after a dungeon" .. (OwlHUDDB.awards and ": |cff40ff40on|r" or ": |cffff4040off|r"))
    return
  end
  Begin(true)
end
-- what he keeps count of during a run
O.On("PLAYER_LEVEL_UP", function() local run = Run() if run then run.levels = (Num(run.levels) or 0) + 1 end end)
Owl.onBlow = function() local run = Run() if run and not run.leftAt then run.blows = (Num(run.blows) or 0) + 1 end end
local watchAcc, wasInside, leftAt = 0, false, nil
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, e)
  watchAcc = watchAcc + e
  if watchAcc < 0.5 then return end
  watchAcc = 0
  O.Try("owl awards", function()
    local inside, kind = Q("IsInInstance")
    inside = (inside and kind == "party") and true or false
    local dead = Q("UnitIsDeadOrGhost", "player") and true or false
    if inside then
      leftAt = nil
      local run = Run()
      local hp, max = Plain(UnitHealth("player")), Plain(UnitHealthMax("player"))
      if run and not dead and type(hp) == "number" and type(max) == "number" and max > 0 and hp > 0 then
        local pct = math.floor(hp / max * 100)
        if pct < (Num(run.low) or 100) then run.low = pct end
      end
    elseif wasInside and not dead then
      -- walked out alive (releasing after a death also puts you outside, which is not the end of a run)
      leftAt = Now()
    end
    if leftAt and not inside and Now() - leftAt >= 8 then
      leftAt = nil
      if not dead and OwlHUDDB.awards ~= false then Begin(false) end
    end
    wasInside = inside
  end)
end)

-- ---------- 2. the reading: the first time he meets you, he sizes you up ----------
local function Reading(byHand)
  local rec = Owl.Record()
  if not byHand then
    if rec.readingDone then return end
    rec.readingDone = true
    -- only for someone he has just met; an old friend does not need introducing
    if (Num(rec.sessions) or 0) > 2 then return end
  end
  local race, class = Plain((UnitRace("player"))), Plain((UnitClass("player")))
  local lines = { "So. " .. Me() .. ", level " .. Level() .. (type(race) == "string" and (" " .. race) or "") .. (type(class) == "string" and (" " .. class) or "") .. ". Hold still. Let me look at you." }
  local me = type(Owl.me) == "table" and Owl.me or {}
  -- what you are wearing
  local good, plain, worn = 0, 0, 0
  for _, item in pairs(type(me.gear) == "table" and me.gear or {}) do
    if type(item) == "table" then
      worn = worn + 1
      local q = Num(item.quality) or 1
      if q >= 2 then good = good + 1 else plain = plain + 1 end
    end
  end
  if worn >= 4 then
    local ilvl = Num(me.ilvl)
    local verdict = "Respectable."
    if ilvl and ilvl >= Level() + 4 then verdict = "Better dressed than most at your level."
    elseif ilvl and ilvl <= Level() - 6 then verdict = "You are dressed for a level you left a while ago."
    elseif plain > good then verdict = "More plain pieces than good ones. We will work on that." end
    lines[#lines + 1] = good .. (good == 1 and " good piece" or " good pieces") .. " of gear and " .. plain .. " plain. " .. verdict
  end
  -- your trades
  local trades = {}
  for _, p in ipairs(type(me.profs) == "table" and me.profs or {}) do if type(p) == "table" and type(p[1]) == "string" then trades[#trades + 1] = p[1] end end
  if #trades == 0 then
    -- only said once he has actually read your skills; an empty list before that proves nothing
    if me.gathered then lines[#lines + 1] = "No professions that I can see. Travelling light." end
  elseif #trades == 1 then lines[#lines + 1] = trades[1] .. ", and nothing else. A specialist."
  else lines[#lines + 1] = trades[1] .. " and " .. trades[2] .. (#trades > 2 and (", and " .. (#trades - 2) .. " more") or "") .. ". Good. An owl likes someone with a trade." end
  -- company and coin
  local money = Owl.Money and Owl.Money()
  local gold = type(money) == "number" and math.floor(money / 10000) or nil
  if type(me.guild) == "string" and me.guild ~= "" then lines[#lines + 1] = "Guild: " .. me.guild .. ". So you do have friends."
  elseif gold and gold < 1 then lines[#lines + 1] = "No guild, and less than one gold to your name. We will fix both."
  elseif gold then lines[#lines + 1] = "No guild, " .. gold .. " gold. A lone wolf with an owl." end
  lines[#lines + 1] = "That will do. I am your owl now. Click me, or type /owl."
  for i, text in ipairs(lines) do Later((i - 1) * 7, function() Say("reading" .. i .. Now(), text, 0, "c") end) end
end
O.commands.reading = function() Reading(true) end
local metAt = nil
O.On("PLAYER_ENTERING_WORLD", function()
  if metAt then return end
  metAt = Now()
  Later(14, function() Reading(false) end)
end)

-- ---------- 3. owls that talk to each other ----------
-- When you group with a friend whose owl he knows, the two owls trade a line. Both players see the same exchange:
-- which pair of lines, and which owl opens, is worked out the same way on both sides.
O.defaults.banter = true
local BANTER = {
  { "Fancy meeting you here.", "I go where the snacks go." },
  { "Is yours behaving?", "Define behaving." },
  { "Mine pulled the whole room yesterday.", "Mine fell off a bridge. Twice." },
  { "Nice perch.", "It came with the job." },
  { "How many deaths today?", "I stopped counting. It felt rude." },
  { "Ready for this?", "I was hatched ready." },
  { "Do you ever sleep?", "Only when they are in town." },
  { "Mine thinks they are in charge.", "Let them. It keeps them busy." },
  { "Have you eaten?", "Twice. Do not tell mine." },
  { "Same plan as last time?", "There was a plan?" },
  { "Yours looks tired.", "Yours looks lost." },
  { "I have a good feeling about today.", "You said that last time." },
}
local banterAt = {}
local function Grouped(name)
  if not Q("IsInGroup") or Q("IsInRaid") then return false end
  for _, n in ipairs(Owl.lib and Owl.lib.PartyNames and Owl.lib.PartyNames() or {}) do if n == name then return true end end
  return false
end
local function Banter(sender, owl)
  if OwlHUDDB.banter == false or OwlHUDDB.social == false or not Grouped(sender) then return end
  if banterAt[sender] and Now() - banterAt[sender] < 1800 then return end
  banterAt[sender] = Now()
  local me = Me()
  local first, second = me, sender
  if sender < me then first, second = sender, me end
  local key, h = first .. second, math.floor(Clock() / 86400)
  for i = 1, #key do h = (h * 31 + key:byte(i)) % 100003 end
  local pair = BANTER[h % #BANTER + 1]
  local theirs = tostring(owl)
  local function they(text)
    if Owl.stage and Owl.stage.Speak and Owl.stage.Speak(sender, text, 4) then return end
    Say("banter" .. sender .. Now(), theirs .. " says: \"" .. text .. "\"", 0, "c")
    if Owl.cos and Owl.cos.Hop then pcall(Owl.cos.Hop, sender, "...", "talk") end
  end
  local function mine(text)
    Say("banterme" .. sender .. Now(), "To " .. theirs .. ": \"" .. text .. "\"", 0, "c")
    if Owl.cos and Owl.cos.Idle then pcall(Owl.cos.Idle, "tilt", 1.2) end
  end
  if first == me then
    Later(4, function() mine(pair[1]) end)
    Later(10, function() they(pair[2]) end)
  else
    Later(4, function() they(pair[1]) end)
    Later(10, function() mine(pair[2]) end)
  end
end

local netBefore = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if kind == "HELLO" or kind == "HI" then
    Later(2, function() Banter(sender, owl) end)
  elseif kind == "AWD" and type(extra) == "string" then
    local dungeon, deaths, low, blows, levels, asking = extra:match("^(.-);(%d+);(%d+);(%d+);(%d+);(%d)$")
    if not dungeon or dungeon == "" or not Grouped(sender) then return end
    rows[dungeon] = rows[dungeon] or {}
    rows[dungeon][sender] = { deaths = tonumber(deaths), low = tonumber(low), blows = tonumber(blows), levels = tonumber(levels) }
    local run = Run()
    local same = run and Scrub(run.name, 30) == dungeon
    if asking == "1" then
      -- someone called for the awards: give my player's numbers, and get ready to announce with everyone else
      if announcedAt[dungeon] and Now() - announcedAt[dungeon] > 60 then announcedAt[dungeon] = nil end
      if same then
        rows[dungeon][Me()] = MyRow(run)
        if not repliedAt[dungeon] or Now() - repliedAt[dungeon] > 30 then
          repliedAt[dungeon] = Now()
          Tell(dungeon, run, false)
        end
      end
    end
    if rows[dungeon][Me()] then Later(6, function() Announce(dungeon) end) end
  end
end

-- ---------- 4. the recap when you log off ----------
local loginLevel, loginClock = nil, Clock()
O.On("PLAYER_ENTERING_WORLD", function() if not loginLevel then loginLevel = Level() end end)
local function Recap()
  local s = Owl.session
  if type(s) ~= "table" or not s.start then return nil end
  local played = math.max(1, Now() - s.start)
  local out = {}
  local levels = loginLevel and (Level() - loginLevel) or 0
  out[1] = "This session: " .. Span(played) .. ", " .. (Num(s.kills) or 0) .. " kills, " .. (Num(s.deaths) or 0) .. ((Num(s.deaths) or 0) == 1 and " death" or " deaths")
    .. (levels > 0 and (", " .. levels .. (levels == 1 and " level" or " levels") .. " gained") or "") .. "."
  local money = Owl.Money and Owl.Money()
  if type(money) == "number" and type(s.money) == "number" and O.Money then
    local diff = money - s.money
    if math.abs(diff) >= 100 then out[#out + 1] = (diff >= 0 and "Gold earned: " or "Gold spent: ") .. O.Money(math.abs(diff)) .. "." end
  end
  local rec = Owl.Record()
  if type(rec.pvp) == "table" then
    local beat, lost, worst, worstAt = 0, 0, nil, 0
    for name, e in pairs(type(rec.pvp.won) == "table" and rec.pvp.won or {}) do if type(e) == "table" and (Num(e.last) or 0) >= loginClock then beat = beat + 1 end end
    for name, e in pairs(type(rec.pvp.by) == "table" and rec.pvp.by or {}) do
      if type(e) == "table" and (Num(e.last) or 0) >= loginClock then
        lost = lost + 1
        if e.last > worstAt then worst, worstAt = name, e.last end
      end
    end
    if beat + lost > 0 then out[#out + 1] = "Other players: " .. beat .. " beaten, " .. lost .. " got you." .. (worst and (" Last one was " .. worst .. ".") or "") end
  end
  return out, played
end
O.commands.recap = function()
  local lines = Recap()
  if not lines then O.Print("nothing to recap yet.") return end
  O.Print("|cffffd100Recap|r")
  for _, text in ipairs(lines) do print("  " .. text) end
  if Owl.stage and Owl.stage.Notice then pcall(Owl.stage.Notice, "This session", lines, 9) end
end
local recapAt = -1000
O.On("PLAYER_CAMPING", function()
  local lines, played = Recap()
  if not lines or played < 600 or Now() - recapAt < 120 then return end
  recapAt = Now()
  O.commands.recap()
  Say("recap" .. Now(), lines[1], 0, "uc")
end)

-- for the report: which friends he can see, and through which list
Owl.probe = Owl.probe or {}
Owl.probe.friends = function()
  local total, online, bnet, known = 0, 0, 0, {}
  local saved = type(OwlHUDDB.friendLooks) == "table" and OwlHUDDB.friendLooks or {}
  for i = 1, Owl.FL.GetNumFriends() do
    local info = Owl.FL.GetFriendInfoByIndex(i)
    if type(info) == "table" then
      total = total + 1
      if info.connected then online = online + 1 end
      if info.bnet then bnet = bnet + 1 end
      local first = Owl.First((tostring(info.name):gsub("%-.*$", "")))
      if info.connected and saved[first] and #known < 6 then known[#known + 1] = first .. (info.bnet and "(bnet)" or "") end
    end
  end
  local beside = 0
  for _ in pairs(Owl.cos and Owl.cos.friends or {}) do beside = beside + 1 end
  return "listed=" .. total .. " online=" .. online .. " viaBattleNet=" .. bnet .. " onlineWithOwl[" .. table.concat(known, ",") .. "] owlsBeside=" .. beside
    .. " BNGetNumFriends:" .. type(_G.BNGetNumFriends) .. " C_BattleNet:" .. type(_G.C_BattleNet)
end
end

-- =====================================================================================
-- The stage: owls that arrive with a flourish, speak from their own bubbles, hold things in their wings,
-- wear their player's colours, and can be pointed at to see who they are.
-- =====================================================================================
do
local stage = {}
Owl.stage = stage
local cos = Owl.cos
local slots, friends = cos.slots, cos.friends
local perch = _G.OwlHUDPerch
local function Call0(obj, method, ...)
  if obj and obj[method] then local ok, a, b = pcall(obj[method], obj, ...) if ok then return a, b end end
  return nil
end
local function PlumeOf(f) return f.stack and f.stack.body and f.stack.body.p or nil end
local function PlumeFile(name, p)
  if type(p) == "number" and p > 1 and p <= 10 then return MEDIA .. "p" .. p .. "_" .. name end
  return MEDIA .. name
end
local function Face(f, name, secs)
  f.face, f.stack.face = name, name
  f.stack.owl:SetTexture(MEDIA .. cos.OwlFile(name, PlumeOf(f)))
  if secs then f.blinkAt = f.t + secs end
end
local function Calm(f) return (f.wasDead and "owl_blink.tga") or (f.low and "owl_worried.tga") or "owl.tga" end
stage.Glance = function(f, name, secs)
  if f.wasDead or f.low or f.visit or f.busy or f.napping then return end
  Face(f, name, secs or 1.2)
end

-- ---------- a rounded panel, for the dusk bubble ----------
local CORNER = 7
local function Panel(frame, layer)
  local p = { parts = {}, bars = {} }
  local function Corner(point, u0, u1, v0, v1)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(MEDIA .. "corner.tga")
    t:SetSize(CORNER, CORNER)
    t:SetPoint(point, frame, point, 0, 0)
    if t.SetTexCoord then t:SetTexCoord(u0, u1, v0, v1) end
    p.parts[#p.parts + 1] = t
  end
  Corner("TOPLEFT", 0, 1, 0, 1) Corner("TOPRIGHT", 1, 0, 0, 1) Corner("BOTTOMLEFT", 0, 1, 1, 0) Corner("BOTTOMRIGHT", 1, 0, 1, 0)
  local function Bar(a, ax, ay, b, bx, by)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetPoint("TOPLEFT", frame, a, ax, ay)
    t:SetPoint("BOTTOMRIGHT", frame, b, bx, by)
    p.bars[#p.bars + 1] = t
  end
  Bar("TOPLEFT", CORNER, 0, "TOPRIGHT", -CORNER, -CORNER)
  Bar("TOPLEFT", 0, -CORNER, "BOTTOMRIGHT", 0, CORNER)
  Bar("BOTTOMLEFT", CORNER, CORNER, "BOTTOMRIGHT", -CORNER, 0)
  p.Color = function(r, g, b, a)
    for _, t in ipairs(p.parts) do if t.SetVertexColor then t:SetVertexColor(r, g, b, a) end end
    for _, t in ipairs(p.bars) do t:SetColorTexture(r, g, b, a) end
  end
  p.Shown = function(on)
    for _, t in ipairs(p.parts) do if on then t:Show() else t:Hide() end end
    for _, t in ipairs(p.bars) do if on then t:Show() else t:Hide() end end
  end
  return p
end
stage.Panel = Panel
local STYLE = {
  parchment = { 0.93, 0.86, 0.70, 0.97, 0.17, 0.10, 0.04 },
  dark = { 0.05, 0.04, 0.02, 0.9, 1, 1, 1 },
  dusk = { 0.0, 0.02, 0.09, 0.74, 1, 1, 1 },
}
local function Style() return STYLE[OwlHUDDB.bubble or ""] or STYLE.parchment end

-- his own bubble in the dusk style: a soft dark box, white letters, and a small blinking mark when he has finished
local duskPanel, nextMark, markT, lastText, stillFor = nil, nil, 0, nil, 0
stage.Dusk = function(on)
  local bubble = pal and pal.bubble
  if not bubble then return end
  if on and not duskPanel then
    duskPanel = Panel(bubble, "BACKGROUND")
    nextMark = bubble:CreateTexture(nil, "OVERLAY")
    nextMark:SetTexture(MEDIA .. "next.tga")
    nextMark:SetSize(11, 11)
    nextMark:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", -7, 5)
    if nextMark.SetVertexColor then nextMark:SetVertexColor(0.45, 0.75, 1, 1) end
    nextMark:Hide()
  end
  if duskPanel then
    duskPanel.Shown(on)
    if on then duskPanel.Color(STYLE.dusk[1], STYLE.dusk[2], STYLE.dusk[3], STYLE.dusk[4]) end
  end
  if nextMark and not on then nextMark:Hide() end
  if on then
    bubble.bg:SetColorTexture(0, 0, 0, 0)
    if pal.name then pal.name:SetTextColor(0.55, 0.8, 1) end
  end
  for _, line in ipairs(bubble.lines or {}) do if on then line:Hide() else line:Show() end end
end
-- once, the dusk bubble becomes the one he uses (he can change it back with /owl bubble)
O.On("PLAYER_LOGIN", function()
  if not OwlHUDDB.duskOffered then
    OwlHUDDB.duskOffered = true
    OwlHUDDB.bubble = "dusk"
    if Owl.ApplyBubble then pcall(Owl.ApplyBubble) end
  end
end)

-- ---------- a friend's owl speaks from its own bubble ----------
local function MakeBubble(f)
  local b = CreateFrame("Frame", nil, f)
  if b.SetFrameStrata then b:SetFrameStrata("HIGH") end
  b.panel = Panel(b, "BACKGROUND")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  if b.text.SetJustifyH then b.text:SetJustifyH("LEFT") end
  b.tail = b:CreateTexture(nil, "ARTWORK")
  b.tail:SetTexture(MEDIA .. "bubble_tail.tga")
  b.tail:SetSize(9, 12)
  b:Hide()
  f.bub = b
  return b
end
stage.Bubble = function(f, text, secs)
  if type(text) ~= "string" or text == "" or not f:IsShown() then return false end
  local b = f.bub or MakeBubble(f)
  local st = Style()
  b.panel.Color(st[1], st[2], st[3], st[4])
  b.text:SetTextColor(st[5], st[6], st[7])
  local dark = st[5] == 1
  if b.text.SetShadowColor then b.text:SetShadowColor(0, 0, 0, dark and 1 or 0) end
  if b.text.SetShadowOffset then b.text:SetShadowOffset(dark and 1 or 0, dark and -1 or 0) end
  local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local wide = #plain > 28
  b.text:SetWidth(wide and 168 or 0)
  b.text:SetText(text)
  local tw = Num(Call0(b.text, "GetStringWidth")) or (#plain * 6)
  local th = Num(Call0(b.text, "GetStringHeight")) or 12
  if wide then tw = 168 end
  b:SetSize(math.max(26, tw + 16), math.max(20, th + 12))
  b:ClearAllPoints()
  b.tail:ClearAllPoints()
  local size = Num(f:GetWidth()) or 40
  if slots.row then
    b:SetPoint("BOTTOM", f, "TOP", 0, size * 0.12 + 6)
    b.tail:SetPoint("TOP", b, "BOTTOM", 0, 2)
    if b.tail.SetRotation then pcall(b.tail.SetRotation, b.tail, math.pi / 2) end
  else
    b:SetPoint("RIGHT", f, "LEFT", -11, 0)
    b.tail:SetPoint("LEFT", b, "RIGHT", -2, 0)
    if b.tail.SetRotation then pcall(b.tail.SetRotation, b.tail, 0) end
    if b.tail.SetTexCoord then b.tail:SetTexCoord(1, 0, 0, 1) end
    f.label:SetAlpha(0)
  end
  if st == STYLE.parchment then b.tail:Show() else b.tail:Hide() end
  b:Show()
  if not f.low and not f.napping then f.emote:Hide() f.emoteUntil = false end
  -- the words write themselves out
  f.bubLen, f.bubShown = #plain, 0
  if b.text.SetAlphaGradient then pcall(b.text.SetAlphaGradient, b.text, 0, 8) end
  f.bubUntil = Now() + (secs or 3) + #plain / 40
  local data = friends[f.who]
  if data and #plain > 6 then data.said = plain end
  return true
end
-- a whole line, from that owl: its bubble, a bob as it talks, and every other owl turns to look
stage.Speak = function(who, text, secs)
  for i = 1, 3 do
    local f = slots[i]
    if f and f.who == who and f:IsShown() and not f.busy and not f.wasDead then
      if not stage.Bubble(f, text, secs or 3.5) then return false end
      if cos.Hop then pcall(cos.Hop, who, nil, "talk") end
      for k = 1, 3 do
        local other = slots[k]
        if other and other ~= f and other.who then stage.Glance(other, k > i and "owl_left.tga" or "owl_right.tga", 1.6) end
      end
      if cos.Idle then pcall(cos.Idle, "tilt", 1.2) end
      return true
    end
  end
  return false
end

-- ---------- who they are: class, level, where, asleep at the keys ----------
local classByName, infoAt, infos = nil, -100, {}
local function ClassFile(name)
  if type(name) ~= "string" or name == "" then return nil end
  if type(_G.RAID_CLASS_COLORS) == "table" and _G.RAID_CLASS_COLORS[name] then return name end
  if not classByName then
    classByName = {}
    for _, t in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
      if type(t) == "table" then for file, loc in pairs(t) do if type(loc) == "string" then classByName[loc] = file end end end
    end
  end
  return classByName[name] or classByName[name:sub(1, 1):upper() .. name:sub(2):lower()] or name:upper():gsub("%s", "")
end
local function Info(who, data)
  if Now() - infoAt > 5 then
    infoAt = Now()
    infos = {}
    for i = 1, math.min(Owl.FL.GetNumFriends(), 200) do
      local e = Owl.FL.GetFriendInfoByIndex(i)
      if type(e) == "table" and e.connected and type(e.name) == "string" then
        infos[Owl.First((e.name:gsub("%-.*$", "")))] = { class = e.class, level = e.level, area = e.area, afk = e.afk }
      end
    end
  end
  local out = { class = nil, level = nil, area = nil, afk = false, className = nil }
  local e = infos[who]
  if e then out.className, out.class, out.level, out.area, out.afk = e.class, ClassFile(e.class), e.level, e.area, e.afk and true or false end
  if data and not data.far then
    for i = 1, 4 do
      local unit = "party" .. i
      if Plain(UnitName(unit)) == who then
        local loc, file = Q("UnitClass", unit)
        if type(file) == "string" then out.class, out.className = file, type(loc) == "string" and loc or out.className end
        local lvl = Q("UnitLevel", unit)
        if type(lvl) == "number" and lvl > 0 then out.level = lvl end
        out.afk = Q("UnitIsAFK", unit) and true or false
        out.area = nil
      end
    end
  end
  out.level = out.level or (data and Num(data.level)) or nil
  return out
end
local function ClassColor(file)
  local c = type(_G.RAID_CLASS_COLORS) == "table" and file and _G.RAID_CLASS_COLORS[file]
  if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
  return nil
end

-- ---------- nicknames: what your owl calls each of them ----------
local NICKS = { "Big %s", "%s the Brave", "Captain %s", "Old %s", "Sir %s", "%s the Bold", "Lucky %s", "%s the Unstoppable", "Trusty %s", "%s the Loud", "Young %s", "%s of the Many Deaths" }
Owl.Nick = function(who)
  if type(who) ~= "string" or who == "" then return who end
  if type(OwlHUDDB.nicks) ~= "table" then OwlHUDDB.nicks = {} end
  local have = OwlHUDDB.nicks[who]
  if type(have) == "string" and have ~= "" then return have end
  local h = 7
  for i = 1, #who do h = (h * 31 + who:byte(i)) % 100003 end
  local made = NICKS[h % #NICKS + 1]:format(who)
  OwlHUDDB.nicks[who] = made
  return made
end
O.commands.nick = function(arg, raw)
  local text = (type(raw) == "string" and raw ~= "" and raw or arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local who, rest = text:match("^(%S+)%s*(.-)$")
  if not who or who == "" then
    O.Print("|cffffd100What he calls your friends|r")
    local any = false
    for name in pairs(friends) do any = true print("  " .. name .. ": " .. Owl.Nick(name)) end
    if not any then print("  No friends' owls beside him right now.") end
    print("  Change one with /owl nick Paul Captain Paul")
    return
  end
  who = Owl.First(who:sub(1, 1):upper() .. who:sub(2))
  if rest == "" then O.Print("he calls " .. who .. ": " .. Owl.Nick(who)) return end
  if type(OwlHUDDB.nicks) ~= "table" then OwlHUDDB.nicks = {} end
  OwlHUDDB.nicks[who] = rest:gsub("[|%c]", ""):sub(1, 30)
  O.Print("he will call " .. who .. ": " .. OwlHUDDB.nicks[who])
end

-- ---------- catchphrase: the line your owl says when it lands beside a friend's ----------
local cpAt = {}
local function SendCatch(who)
  local line = OwlHUDDB.catch
  if type(line) ~= "string" or line == "" or OwlHUDDB.social == false then return end
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  if cpAt[who] and Now() - cpAt[who] < 600 then return end
  cpAt[who] = Now()
  pcall(C_ChatInfo.SendAddonMessage, "OwlHUD", "CP|" .. Name() .. "|" .. line, "WHISPER", Owl.Addr(who))
end
O.commands.catchphrase = function(arg, raw)
  local text = (type(raw) == "string" and raw ~= "" and raw or arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    O.Print("his catchphrase: " .. ((type(OwlHUDDB.catch) == "string" and OwlHUDDB.catch ~= "") and ("\"" .. OwlHUDDB.catch .. "\"") or "none yet") .. ". Set one with /owl catchphrase Fear the beak")
    return
  end
  if text:lower() == "off" then OwlHUDDB.catch = nil O.Print("catchphrase cleared.") return end
  OwlHUDDB.catch = text:gsub("[|;%c]", ""):sub(1, 40)
  cpAt = {}
  for who in pairs(friends) do SendCatch(who) end
  O.Print("his catchphrase: \"" .. OwlHUDDB.catch .. "\". Your friends' screens show it when your owl lands beside theirs.")
end
local netBefore = Owl.onNet
Owl.onNet = function(kind, sender, owl, extra)
  if netBefore then pcall(netBefore, kind, sender, owl, extra) end
  if kind == "HELLO" or kind == "HI" then SendCatch(sender)
  elseif kind == "CP" and type(extra) == "string" and friends[sender] then
    local line = extra:gsub("[|;%c]", ""):sub(1, 40)
    friends[sender].catch = line ~= "" and line or nil
    local keep = type(OwlHUDDB.friendLooks) == "table" and OwlHUDDB.friendLooks[sender]
    if type(keep) == "table" then keep.catch = friends[sender].catch end
  end
end

-- ---------- the card you get by pointing at one ----------
local function Tip(f)
  local data = f.who and friends[f.who]
  if not data or not stage.CardTip then return end
  local tip = stage.CardTip()
  local info = Info(f.who, data)
  tip:SetOwner(f, "ANCHOR_LEFT")
  tip:AddLine(tostring(data.owl), 1, 0.82, 0)
  tip:AddLine(f.who .. "'s owl", 0.7, 0.7, 0.7)
  if info.level or info.className then
    local r, g, b = ClassColor(info.class)
    tip:AddLine((info.level and ("Level " .. info.level .. " ") or "") .. (info.className or ""), r or 1, g or 1, b or 1)
  end
  if data.dead then tip:AddLine("Down", 1, 0.3, 0.3)
  elseif data.low then tip:AddLine("Hurt badly", 1, 0.5, 0.2)
  elseif info.afk then tip:AddLine("Away from the keys", 0.7, 0.7, 1)
  elseif data.far then tip:AddLine(info.area and ("In " .. info.area) or "Online, somewhere else", 0.8, 0.8, 0.8)
  else tip:AddLine(data.away and "In your group, far off" or "In your group", 0.5, 1, 0.5) end
  tip:AddLine("Yours calls them: " .. Owl.Nick(f.who), 0.9, 0.8, 0.6)
  if data.catch then tip:AddLine("\"" .. data.catch .. "\"", 1, 1, 1, true) end
  if data.said then tip:AddLine("Last said: " .. data.said, 0.75, 0.75, 0.75, true) end
  tip:AddLine(data.far and "Click to whisper. Right-click to invite." or "Click to whisper.", 0.45, 0.75, 1)
  tip:Show()
end
local function Card(f)
  if f.carded then return end
  f.carded = true
  if not f.EnableMouse then return end
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self) O.Try("owl card", Tip, self) end)
  f:SetScript("OnLeave", function() if stage.CardTip then stage.CardTip():Hide() end end)
  f:SetScript("OnMouseUp", function(self, button)
    O.Try("owl card click", function()
      local data = self.who and friends[self.who]
      if not data then return end
      local to = Owl.Addr(self.who)
      if button == "RightButton" then
        if not data.far then return end
        if type(_G.C_PartyInfo) == "table" and _G.C_PartyInfo.InviteUnit then _G.C_PartyInfo.InviteUnit(to)
        elseif type(_G.InviteUnit) == "function" then _G.InviteUnit(to) end
      elseif type(_G.ChatFrame_SendTell) == "function" then _G.ChatFrame_SendTell(to)
      elseif type(_G.ChatFrame_OpenChat) == "function" then _G.ChatFrame_OpenChat("/w " .. to .. " ") end
    end)
  end)
end

-- ---------- rain, and the things an owl holds ----------
local rainAt, raining = -100, false
local function Raining()
  if Now() - rainAt < 3 then return raining end
  rainAt = Now()
  raining = false
  if OwlHUDDB.weather == false then return false end
  local w = _G.C_Weather
  if type(w) == "table" and w.GetCurrentWeather then
    local ok, kind, hard = pcall(w.GetCurrentWeather)
    if ok and type(kind) == "table" then kind, hard = kind.type, kind.intensity end
    kind, hard = Plain(kind), Plain(hard)
    if ok and kind == 1 and (type(hard) ~= "number" or hard > 0.05) and not Q("IsIndoors") then raining = true end
  end
  if stage.forceRain then raining = true end
  return raining
end
-- grand wings on a canvas twice the owl's, and an umbrella on one half as big again; both follow the owl itself
local function Extras(holder, owlTex, mirror)
  local x = {}
  x.wings = holder:CreateTexture(nil, "BACKGROUND", nil, 3)
  x.umb = holder:CreateTexture(nil, "OVERLAY", nil, 0)
  x.hold = holder:CreateTexture(nil, "OVERLAY", nil, 1)
  for _, t in ipairs({ x.wings, x.umb, x.hold }) do
    if mirror and t.SetTexCoord then t:SetTexCoord(1, 0, 0, 1) end
    t:Hide()
  end
  x.umb:SetTexture(MEDIA .. "umbrella.tga")
  x.owl = owlTex
  return x
end
local function ExtrasStep(x, size, plume, wingsFile, holding)
  if wingsFile ~= x.wingsFile or plume ~= x.plume then
    x.wingsFile = wingsFile
    if wingsFile then x.wings:SetTexture(PlumeFile(wingsFile, plume)) x.wings:Show() else x.wings:Hide() end
  end
  if holding ~= x.holding or plume ~= x.plume then
    x.holding = holding
    if holding then
      x.hold:SetTexture(PlumeFile("wing_hold.tga", plume))
      x.hold:Show() x.umb:Show()
    else x.hold:Hide() x.umb:Hide() end
  end
  x.plume = plume
  if size ~= x.size and (wingsFile or holding) then
    x.size = size
    for _, t in ipairs({ x.wings, x.hold }) do
      t:ClearAllPoints()
      t:SetPoint("CENTER", x.owl, "CENTER", 0, 0)
      t:SetSize(size * 2, size * 2)
    end
    x.umb:ClearAllPoints()
    x.umb:SetPoint("BOTTOM", x.owl, "BOTTOM", 0, 0)
    x.umb:SetSize(size * 1.5, size * 1.5)
  end
end
local function WingsFor(face, flourish)
  if type(face) == "string" then
    if face:find("owl_fly2", 1, true) then return "wings_up.tga" end
    if face:find("owl_fly1", 1, true) then return "wings_out.tga" end
  end
  if flourish then return "wings_up.tga" end
  return nil
end

-- ---------- how each one arrives, and how it leaves ----------
local ENTER = { "swoop", "drop", "pop", "roll", "peek" }
local ENTER_DUR = { swoop = 1.1, drop = 1.0, pop = 0.9, roll = 1.2, peek = 1.6 }
local LANDED = { "Hoo!", "Hoo hoo!", "Made it.", "Here!", "Ta-da!" }
local function Reset(f)
  f.enter, f.busy, f.pop, f.spin, f.napping, f.flourish = nil, nil, 1, 0, nil, nil
  if f.SetAlpha then f:SetAlpha(1) end
  f.label:SetAlpha(1)
  if f.bub then f.bub:Hide() end
  f.bubUntil = nil
  if f.stack.look.perch then f.stack.perch:Show() end
end
local function Landed(f, i, data)
  Reset(f)
  Face(f, "owl_happy.tga", 1.4)
  f.hop = 1
  f.flourish = Now() + 0.45
  stage.Bubble(f, data.catch or LANDED[math.random(#LANDED)], data.catch and 3.5 or 1.8)
  for k = 1, 3 do
    local other = slots[k]
    if other and other ~= f and other.who then stage.Glance(other, k > i and "owl_left.tga" or "owl_right.tga", 1.4) end
  end
  if cos.Idle then pcall(cos.Idle, "hop", 0.7) end
end
local function Decorate(f, data, size)
  local info = Info(f.who, data)
  local s = f.stack
  -- the name in their class colour
  local r, g, b = ClassColor(info.class)
  if f.label.SetTextColor then f.label:SetTextColor(r or 1, g or 0.82, b or 0) end
  -- a scarf in their class colour, when the owl is not already wearing something at its neck
  if not s.scarf then
    s.scarf = f:CreateTexture(nil, "ARTWORK", nil, 4)
    s.scarf:SetTexture(MEDIA .. "scarf_white.tga")
    s.scarf:SetAllPoints(s.owl)
    if s.scarf.SetTexCoord then s.scarf:SetTexCoord(1, 0, 0, 1) end
    s.scarf:Hide()
  end
  if r and not s.look.neck and OwlHUDDB.classScarf ~= false then
    if s.scarf.SetVertexColor then
      local k = f.wasDead and 0.55 or 1
      s.scarf:SetVertexColor(r * k, g * k, b * k)
    end
    s.scarf:Show()
  else s.scarf:Hide() end
  -- their level, on a small dark disc at the owl's foot
  if not f.badge then
    f.badge = f:CreateTexture(nil, "OVERLAY", nil, 3)
    f.badge:SetTexture(MEDIA .. "gem_white.tga")
    if f.badge.SetVertexColor then f.badge:SetVertexColor(0.07, 0.06, 0.05, 0.92) end
    f.badgeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.badgeText:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
  end
  if info.level and not f.busy then
    f.badge:ClearAllPoints()
    f.badge:SetPoint("CENTER", f, "BOTTOMLEFT", size * 0.14, size * 0.2)
    f.badge:SetSize(size * 0.4, size * 0.4)
    f.badgeText:SetText(tostring(info.level))
    if f.badgeText.SetTextColor then f.badgeText:SetTextColor(r or 1, g or 0.82, b or 0) end
    f.badge:Show() f.badgeText:Show()
  else f.badge:Hide() f.badgeText:Hide() end
  -- a helmet inside a dungeon, unless it already wears a hat
  local helm = slots.inside and not s.look.hat and true or false
  if helm then
    s.hat:SetTexture(MEDIA .. "hat_helm.tga")
    if s.hat.SetTexCoord then s.hat:SetTexCoord(1, 0, 0, 1) end
    s.hat:Show()
  elseif f.helm and not s.look.hat then s.hat:Hide() end
  f.helm = helm
  -- asleep while their player is away from the keys
  local nap = info.afk and not f.wasDead and not f.low and not f.busy and not f.visit
  if nap then
    if not f.napping then f.emote:SetText("|cffb0b0ffZzz|r") f.emote:Show() f.emoteUntil = false end
    f.napping = true
    Face(f, "owl_sleepy.tga", 3)
  elseif f.napping then
    f.napping = nil
    if not f.low then f.emote:Hide() end
    Face(f, Calm(f), 2)
  end
end
stage.Offset = function(f, i, size, e)
  local data = friends[f.who]
  if not data then return 0, 0 end
  local now = Now()
  if f.stageWho ~= f.who or not data.entered then f.stageWho = f.who Reset(f) Card(f) f.decT = 1 end
  if not f.extras then f.extras = Extras(f, f.stack.owl, true) f.stack.wing = f.extras.hold end
  -- its bubble: the words appear, then it closes
  if f.bubUntil then
    if now >= f.bubUntil then
      f.bubUntil = nil
      f.bub:Hide()
      if not f.busy then f.label:SetAlpha(1) end
    elseif f.bubShown and f.bubShown < f.bubLen + 10 and f.bub.text.SetAlphaGradient then
      f.bubShown = f.bubShown + e * 42
      pcall(f.bub.text.SetAlphaGradient, f.bub.text, math.floor(f.bubShown), 8)
    end
  end
  f.decT = (f.decT or 0) + e
  if f.decT >= 0.5 then f.decT = 0 Decorate(f, data, size) end
  local ox, oy = 0, 0
  local fly = (math.floor(now / 0.13) % 2 == 0) and "owl_fly1.tga" or "owl_fly2.tga"
  if data.leaving then
    -- a small hop, then up and away to the left
    local p = math.min((now - data.leaving) / 1.0, 1)
    f.busy, f.pop = true, 1
    f.label:SetAlpha(0)
    if f.bub then f.bub:Hide() end
    f.stack.perch:Hide()
    if f.badge then f.badge:Hide() f.badgeText:Hide() end
    if p < 0.15 then oy = math.sin(p / 0.15 * math.pi) * size * 0.2
    else
      local q = (p - 0.15) / 0.85
      ox, oy = -q * q * size * 3, q * size * 2.4
      f.spin = -0.25 * q
      if f.face ~= fly then Face(f, fly) end
      if f.SetAlpha then f:SetAlpha(1 - q * q) end
    end
  else
    if not data.entered then
      data.entered = true
      if not data.catch then
        local keep = type(OwlHUDDB.friendLooks) == "table" and OwlHUDDB.friendLooks[f.who]
        if type(keep) == "table" and type(keep.catch) == "string" then data.catch = keep.catch end
      end
      if OwlHUDDB.fancy and OwlHUDDB.entrances ~= false then
        f.enter = { kind = ENTER[math.random(#ENTER)], t = -0.4 * (i - 1) - 0.2, who = f.who }
      end
    end
    local en = f.enter
    if en and en.who ~= f.who then Reset(f) en = nil end
    if en then
      en.t = en.t + e
      f.busy = true
      f.label:SetAlpha(0)
      f.stack.perch:Hide()
      if en.t < 0 then
        if f.SetAlpha then f:SetAlpha(0) end
      else
        local p = en.t / ENTER_DUR[en.kind]
        if f.SetAlpha then f:SetAlpha(1) end
        if p >= 1 then Landed(f, i, data)
        elseif en.kind == "swoop" then
          local ease = p * p * (3 - 2 * p)
          ox = -(1 - ease) * size * 3.4
          oy = (1 - ease) * size * 1.7 + math.sin(p * math.pi) * size * 0.3
          f.spin = (1 - ease) * 0.3
          if f.face ~= fly then Face(f, fly) end
        elseif en.kind == "drop" then
          if p < 0.55 then
            local q = p / 0.55
            oy = (1 - q * q) * size * 3.2
            if f.face ~= "owl_fly2.tga" then Face(f, "owl_fly2.tga") end
          else
            local q = (p - 0.55) / 0.45
            oy = math.sin(q * math.pi) * size * 0.24 * (1 - q)
            if f.face ~= "owl_excited.tga" then Face(f, "owl_excited.tga") end
          end
        elseif en.kind == "pop" then
          f.pop = p < 0.6 and (0.1 + (p / 0.6) * 1.1) or (1.2 - (p - 0.6) / 0.4 * 0.2)
          f.spin = (1 - p) * (1 - p) * math.pi * 2
          if f.SetAlpha then f:SetAlpha(math.min(1, p * 3)) end
        elseif en.kind == "roll" then
          local q = 1 - p
          ox = -q * q * size * 3.2
          f.spin = -ox / size * 3
          oy = math.abs(math.sin(p * math.pi * 3)) * size * 0.12 * q
        elseif en.kind == "peek" then
          if p < 0.3 then oy = (-1 + (p / 0.3) * 0.55) * size if f.SetAlpha then f:SetAlpha(p / 0.3) end
          elseif p < 0.72 then
            oy = -0.45 * size
            local want = p < 0.5 and "owl_left.tga" or "owl_right.tga"
            if f.face ~= want then Face(f, want) end
          else
            local q = (p - 0.72) / 0.28
            oy = -0.45 * size * (1 - q) + math.sin(q * math.pi) * size * 0.28
            if f.face ~= "owl_excited.tga" then Face(f, "owl_excited.tga") end
          end
        end
      end
    elseif f.low and not f.wasDead then
      -- hurt badly: feathers on end
      f.spin = math.sin(now * 34) * 0.045
    elseif (f.spin or 0) ~= 0 then f.spin = 0 end
  end
  if f.flourish and now >= f.flourish then f.flourish = nil end
  local holding = Raining() and not f.wasDead and not f.busy and not f.visit
  ExtrasStep(f.extras, size * (f.pop or 1), PlumeOf(f), (not f.wasDead) and WingsFor(f.face, f.flourish) or nil, holding)
  return ox, oy
end

-- ---------- your own owl: grand wings, the umbrella, his entrances, and the mark on his bubble ----------
local MY_ENTER = { { "dropin", 1.1 }, { "popin", 0.9 }, { "rollin", 1.2 }, { "swoopin", 1.2 }, { "peekin", 1.6 } }
local myExtras, myFlourish, enteredAt = nil, nil, -100
local function Enter()
  if not OwlHUDDB.fancy or OwlHUDDB.entrances == false or not cos.Idle then return end
  if Q("UnitIsDeadOrGhost", "player") or Now() - enteredAt < 4 then return end
  enteredAt = Now()
  local pick = MY_ENTER[math.random(#MY_ENTER)]
  cos.Idle(pick[1], pick[2])
  myFlourish = Now() + pick[2] + 0.45
  stage.myLandAt = Now() + pick[2]
end
O.On("PLAYER_ENTERING_WORLD", function()
  if C_Timer and C_Timer.After then C_Timer.After(0.4, function() O.Try("owl entrance", Enter) end) end
end)
O.defaults.entrances = true
O.commands.enter = function(arg)
  if arg == "off" or arg == "on" then
    OwlHUDDB.entrances = arg == "on"
    O.Print("entrances" .. (OwlHUDDB.entrances and ": |cff40ff40on|r" or ": |cffff4040off|r"))
    return
  end
  -- everyone off the branch and back on again
  enteredAt = -100
  for _, data in pairs(friends) do data.entered = nil end
  Enter()
end
O.commands.branch = function()
  OwlHUDDB.friendColumn = OwlHUDDB.friendColumn ~= true
  slots.rowAt = 0
  O.Print("friends' owls sit " .. (OwlHUDDB.friendColumn and "in a column at his shoulder" or "along one branch beside him"))
end
O.commands.rain = function()
  stage.forceRain = not stage.forceRain
  rainAt = -100
  O.Print(stage.forceRain and "pretending it is raining, so you can see the umbrellas. /owl rain again to stop." or "back to the real weather.")
end
local acc = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, e)
  O.Try("owl stage", function()
    local now = Now()
    -- the blinking mark, once he has finished writing a line
    if nextMark then
      local text = pal.text and Call0(pal.text, "GetText")
      if text ~= lastText then lastText, stillFor = text, 0 else stillFor = stillFor + e end
      local done = OwlHUDDB.bubble == "dusk" and pal.bubble:IsShown() and type(text) == "string" and text ~= "" and stillFor > 0.5
      if done then
        markT = markT + e
        nextMark:Show()
        nextMark:SetAlpha(0.55 + 0.45 * math.sin(markT * 5))
      else nextMark:Hide() end
    end
    if not perch or not perch.icon or not perch:IsShown() then return end
    if not myExtras then myExtras = Extras(perch, perch.icon, false) end
    -- the dusk box opens with a small pop
    local open = pal.bubble:IsShown() and true or false
    if open and not stage.wasOpen then stage.openT = 0 end
    stage.wasOpen = open
    if stage.openT and pal.bubble.SetScale then
      stage.openT = stage.openT + e
      local p = math.min(stage.openT / 0.14, 1)
      pal.bubble:SetScale((OwlHUDDB.bubble == "dusk") and (0.72 + 0.28 * p * (2 - p)) or 1)
      if p >= 1 then stage.openT = nil end
    end
    local w = Num(perch.icon:GetWidth()) or 86
    local shown = rawget(perch.icon, "owlShown")
    local dead = Q("UnitIsDeadOrGhost", "player") and true or false
    local flying = O.OwlFlying and O.OwlFlying() or false
    if myFlourish and now >= myFlourish then myFlourish = nil end
    local flourish = myFlourish and stage.myLandAt and now >= stage.myLandAt
    local plume = cos.Body and cos.Body().p or nil
    ExtrasStep(myExtras, w, plume, (not dead) and WingsFor(shown, flourish) or nil, Raining() and not dead and not flying)
    -- when he speaks, the others turn to look at him
    acc = acc + e
    if acc >= 0.3 then
      acc = 0
      local said = pal.bubble:IsShown() and stage.lastSaid ~= lastText and type(lastText) == "string" and #lastText > 12
      if said and stillFor > 0.3 then
        stage.lastSaid = lastText
        for k = 1, 3 do if slots[k] and slots[k].who then stage.Glance(slots[k], "owl_left.tga", 1.5) end end
      end
    end
  end)
end)
end

-- =====================================================================================
-- The dusk look, carried further: a box that opens in the middle of the screen for the big moments,
-- a card of the same cloth when you point at an owl, and windows in the same colours.
-- =====================================================================================
do
local stage = Owl.stage
local DUSK = { 0.0, 0.02, 0.09, 0.8 }
local KEY = "|cffffd24a"
local function Hex(r, g, b) return ("|cff%02x%02x%02x"):format(math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end
local function Height(fs, fallback)
  local ok, h = pcall(function() return fs:GetStringHeight() end)
  return (ok and type(h) == "number" and h > 0) and h or fallback
end

-- ---------- the box ----------
O.defaults.notices = true
local box, queue, cur = nil, {}, nil
local function Build()
  box = CreateFrame("Frame", "OwlHUDNotice", UIParent)
  box:SetSize(440, 90)
  box:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 240)
  if box.SetFrameStrata then box:SetFrameStrata("HIGH") end
  box.panel = stage.Panel(box, "BACKGROUND")
  box.panel.Color(DUSK[1], DUSK[2], DUSK[3], DUSK[4])
  box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  box.title:SetPoint("TOP", box, "TOP", 0, -12)
  box.title:SetTextColor(0.55, 0.8, 1)
  box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  box.text:SetPoint("TOP", box.title, "BOTTOM", 0, -8)
  box.text:SetWidth(400)
  if box.text.SetJustifyH then box.text:SetJustifyH("CENTER") end
  if box.text.SetSpacing then box.text:SetSpacing(4) end
  if box.text.SetWordWrap then box.text:SetWordWrap(true) end
  box.mark = box:CreateTexture(nil, "OVERLAY")
  box.mark:SetTexture(MEDIA .. "next.tga")
  box.mark:SetSize(12, 12)
  box.mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -9, 7)
  if box.mark.SetVertexColor then box.mark:SetVertexColor(0.45, 0.75, 1, 1) end
  if box.EnableMouse then
    box:EnableMouse(true)
    box:SetScript("OnMouseUp", function() if cur then cur.till = math.min(cur.till, Now()) end end)
  end
  box:Hide()
end
-- title, then lines. Words wrapped in stage.Key(...) stand out in gold.
stage.Key = function(text) return KEY .. tostring(text) .. "|r" end
stage.Notice = function(title, lines, secs)
  if OwlHUDDB.notices == false or type(lines) ~= "table" then return false end
  if #queue >= 4 then return false end
  queue[#queue + 1] = { title = tostring(title), text = table.concat(lines, "\n"), secs = secs or 7 }
  return true
end
O.commands.notices = function()
  OwlHUDDB.notices = OwlHUDDB.notices == false
  O.Print("the box for big moments" .. (OwlHUDDB.notices and ": |cff40ff40on|r" or ": |cffff4040off|r"))
  if OwlHUDDB.notices then stage.Notice("Like this", { "Awards, level-ups and your recap", "open in a box " .. stage.Key("like this one") .. "." }, 5) end
end

-- ---------- the card ----------
local card, cardFrame
stage.CardTip = function()
  if card then return card end
  cardFrame = CreateFrame("Frame", "OwlHUDCard", UIParent)
  if cardFrame.SetFrameStrata then cardFrame:SetFrameStrata("TOOLTIP") end
  cardFrame.panel = stage.Panel(cardFrame, "BACKGROUND")
  cardFrame.panel.Color(DUSK[1], DUSK[2], DUSK[3], 0.9)
  cardFrame.text = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cardFrame.text:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 10, -9)
  if cardFrame.text.SetJustifyH then cardFrame.text:SetJustifyH("LEFT") end
  if cardFrame.text.SetSpacing then cardFrame.text:SetSpacing(3) end
  cardFrame:Hide()
  card = { lines = {} }
  card.SetOwner = function(self, owner) self.owner, self.lines = owner, {} end
  card.AddLine = function(self, text, r, g, b) self.lines[#self.lines + 1] = Hex(r, g, b) .. tostring(text) .. "|r" end
  card.Show = function(self)
    local fs = cardFrame.text
    fs:SetWidth(0)
    fs:SetText(table.concat(self.lines, "\n"))
    local okW, w = pcall(function() return fs:GetStringWidth() end)
    w = (okW and type(w) == "number" and w > 0) and w or 160
    if w > 230 then w = 230 fs:SetWidth(230) end
    cardFrame:SetSize(w + 20, Height(fs, #self.lines * 13) + 18)
    cardFrame:ClearAllPoints()
    if Owl.cos.slots.row then cardFrame:SetPoint("BOTTOM", self.owner, "TOP", 0, 10)
    else cardFrame:SetPoint("RIGHT", self.owner, "LEFT", -10, 0) end
    cardFrame:Show()
  end
  card.Hide = function() cardFrame:Hide() end
  return card
end

-- ---------- the windows ----------
local WINDOWS = { "OwlHUDOptions", "OwlHUDWardrobe", "OwlHUDFinds", "OwlHUDWelcome", "OwlHUDJournal" }
local themed, themeAcc = {}, 0
local function Theme()
  local style = OwlHUDDB.bubble == "dusk" and "dusk" or "plain"
  for _, name in ipairs(WINDOWS) do
    local f = _G[name]
    if type(f) == "table" and type(f.bg) == "table" and f.bg.SetColorTexture and themed[name] ~= style then
      if style == "dusk" then f.bg:SetColorTexture(0.02, 0.04, 0.13, 0.95)
      elseif themed[name] then f.bg:SetColorTexture(0.06, 0.05, 0.03, 0.96) end
      themed[name] = style
    end
  end
end

-- ---------- the moments that use the box ----------
O.On("PLAYER_LEVEL_UP", function(level)
  local n = Num(Plain(level)) or Level()
  stage.Notice("Level " .. n .. "!", { Me() .. " reached level " .. stage.Key(n) .. ".", Name() .. " does a small dance about it." }, 6)
  if Owl.cos.Idle then pcall(Owl.cos.Idle, "dance", 2) end
end)

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, e)
  O.Try("owl notice", function()
    themeAcc = themeAcc + e
    if themeAcc >= 1 then themeAcc = 0 Theme() end
    local now = Now()
    if not cur then
      if not queue[1] or Plain(UnitAffectingCombat("player")) == true then return end
      cur = table.remove(queue, 1)
      if not box then Build() end
      box.title:SetText(cur.title)
      box.text:SetText(cur.text)
      box:SetHeight(Height(box.text, 40) + 58)
      local plain = cur.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      cur.len, cur.shown, cur.t = #plain, 0, 0
      cur.till = now + cur.secs + cur.len / 40
      if box.text.SetAlphaGradient then pcall(box.text.SetAlphaGradient, box.text, 0, 10) end
      box.mark:Hide()
      if box.SetAlpha then box:SetAlpha(1) end
      box:Show()
      return
    end
    cur.t = cur.t + e
    -- it opens with a small pop, the words write themselves, a mark blinks when they are done, and it fades
    if box.SetScale then
      local p = math.min(cur.t / 0.16, 1)
      box:SetScale(0.7 + 0.3 * p * (2 - p))
    end
    if cur.shown < cur.len + 12 then
      cur.shown = cur.shown + e * 46
      if box.text.SetAlphaGradient then pcall(box.text.SetAlphaGradient, box.text, math.floor(cur.shown), 10) end
    else
      box.mark:Show()
      box.mark:SetAlpha(0.55 + 0.45 * math.sin(cur.t * 5))
    end
    if now >= cur.till then
      local q = (now - cur.till) / 0.35
      if q >= 1 then box:Hide() cur = nil
      elseif box.SetAlpha then box:SetAlpha(1 - q) end
    end
  end)
end)
end
