-- OwlHUD core: saved settings, safe event dispatch, slash commands.
local ADDON, O = ...

OwlHUDDB = OwlHUDDB or {}

O.defaults = { sell = true, repair = true, fastloot = true, sound = true, warnBuffs = true }
O.handlers = {}
O.VERSION, O.VERSION_TEXT = 41, "4.1"
-- the helpers beyond the owl himself: what "the full setup" switches on
O.HELPERS = { "sell", "repair", "fastloot", "classic", "sides", "questMark", "gatherMark", "ding" }
O.commands = {}
O.unlockHooks = {}
O.reported = {}

function O.Print(msg)
  print("|cffffd100OwlHUD|r " .. tostring(msg))
end

-- Run something without ever letting an error escape into the game UI.
function O.Try(label, fn, ...)
  local ok, a, b = pcall(fn, ...)
  if not ok then
    if not O.reported[label] then
      O.reported[label] = true
      O.Print("|cffff4040" .. label .. " problem:|r " .. tostring(a))
    end
    return false
  end
  return true, a, b
end

local ev = CreateFrame("Frame")
function O.On(event, fn)
  if not O.handlers[event] then
    O.handlers[event] = {}
    pcall(ev.RegisterEvent, ev, event)
  end
  table.insert(O.handlers[event], fn)
end
ev:SetScript("OnEvent", function(_, event, ...)
  local list = O.handlers[event]
  if not list then return end
  for i = 1, #list do
    O.Try(event, list[i], ...)
  end
end)

function O.SpellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok then return n end
  end
  return nil
end

function O.SetCVar(key, value)
  local ok, res
  if C_CVar and C_CVar.SetCVar then
    ok, res = pcall(C_CVar.SetCVar, key, tostring(value))
  elseif SetCVar then
    ok, res = pcall(SetCVar, key, tostring(value))
  end
  return ok and res ~= false
end

function O.GetCVarBool(key)
  if C_CVar and C_CVar.GetCVarBool then
    local ok, v = pcall(C_CVar.GetCVarBool, key)
    if ok then return v and true or false end
  end
  if GetCVarBool then
    local ok, v = pcall(GetCVarBool, key)
    if ok then return v and true or false end
  end
  return false
end

function O.Money(copper)
  copper = math.floor(copper or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local out = ""
  if g > 0 then out = out .. g .. "g " end
  if g > 0 or s > 0 then out = out .. s .. "s " end
  return out .. c .. "c"
end

function O.SetUnlocked(state)
  O.unlocked = state and true or false
  for i = 1, #O.unlockHooks do
    O.Try("unlock", O.unlockHooks[i], O.unlocked)
  end
end

O.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  if type(OwlHUDDB) ~= "table" then OwlHUDDB = {} end
  local fresh = next(OwlHUDDB) == nil
  for k, v in pairs(O.defaults) do
    if OwlHUDDB[k] == nil then OwlHUDDB[k] = v end
  end
  -- a brand-new install is just the owl until its owner says otherwise: nothing sold, repaired or added to the screen uninvited
  if fresh then
    OwlHUDDB.setup = "new"
    for _, key in ipairs(O.HELPERS) do OwlHUDDB[key] = false end
  end
end)

local function Toggle(key, label)
  OwlHUDDB[key] = not OwlHUDDB[key]
  O.Print(label .. (OwlHUDDB[key] and ": |cff40ff40on|r" or ": |cffff4040off|r"))
end

O.commands.unlock = function()
  O.SetUnlocked(true)
  O.Print("unlocked. Drag the green boxes, then /owl lock.")
end
O.commands.lock = function()
  O.SetUnlocked(false)
  O.Print("locked.")
end
O.commands.sell = function() Toggle("sell", "Auto-sell grey junk") end
O.commands.repair = function() Toggle("repair", "Auto-repair") end
O.commands.loot = function() Toggle("fastloot", "Fast loot") end
O.commands.sound = function() Toggle("sound", "Seal warning sound") end
O.commands.buffs = function() Toggle("warnBuffs", "Blessing / aura warnings") end

local function Help()
  O.Print("commands:")
  print("  /owl unlock  |  /owl lock  - move the combat cues and the tooltip spot")
  print("  /owl scale 1.2  - resize the combat cues")
  print("  /owl attack  - make Judgement and Holy Strike start attacking on a new target")
  print("  /owl gfx  - apply the extra graphics commands")
  print("  /owl chat  - move loot and XP spam to its own tab")
  print("  /owl sell | repair | loot | sound | buffs  - turn a feature on or off")
  print("  /owl classic  - hearts, lock-on bars, item box, clock: whole classic look on or off")
  print("  /owl bars  - just the black lock-on bars on or off")
  print("  /owl owl  - everything the owl can do: ask, journal, name, voice, goal")
  print("  /owl sides | selfbar | questmark | gather | ding  - the bars and markers around your character")
  print("  /owl tips  - the owl helper on or off")
  print("  /owl debug  - show what OwlHUD sees for seals and buffs")
end

SLASH_OWLHUD1 = "/owl"
SLASH_OWLHUD2 = "/owlhud"
SlashCmdList.OWLHUD = function(msg)
  local _, raw = (msg or ""):match("^(%S*)%s*(.-)$")
  msg = (msg or ""):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  local fn = O.commands[cmd]
  if fn then
    O.Try("/owl " .. cmd, fn, arg, raw)   -- raw keeps the capitals, for notes and names
  else
    Help()
  end
end
