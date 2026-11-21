-- OwlHUD chat cleanup: keep people in the main tab, move loot / XP / skill spam to a "Loot" tab.
local ADDON, O = ...

local NOISE = {
  "LOOT", "MONEY", "CURRENCY", "SKILL", "TRADESKILLS", "OPENING",
  "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "COMBAT_MISC_INFO", "PET_INFO",
}

local function RemoveGroup(frame, group)
  if frame.RemoveMessageGroup then frame:RemoveMessageGroup(group)
  elseif ChatFrame_RemoveMessageGroup then ChatFrame_RemoveMessageGroup(frame, group) end
end
local function AddGroup(frame, group)
  if frame.AddMessageGroup then frame:AddMessageGroup(group)
  elseif ChatFrame_AddMessageGroup then ChatFrame_AddMessageGroup(frame, group) end
end
local function ClearFrame(frame)
  if frame.RemoveAllMessageGroups then frame:RemoveAllMessageGroups()
  elseif ChatFrame_RemoveAllMessageGroups then ChatFrame_RemoveAllMessageGroups(frame) end
  if frame.RemoveAllChannels then frame:RemoveAllChannels()
  elseif ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
end

local function FindWindow(title)
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local name = GetChatWindowInfo(i)
    if name == title then return _G["ChatFrame" .. i] end
  end
  return nil
end

local function SplitChat()
  local main = ChatFrame1
  if not main then return false end
  local loot = FindWindow("Loot")
  if not loot and FCF_OpenNewWindow then
    loot = FCF_OpenNewWindow("Loot")
  end
  if not loot then return false end
  ClearFrame(loot)
  for _, group in ipairs(NOISE) do
    pcall(AddGroup, loot, group)
    pcall(RemoveGroup, main, group)
  end
  if FCF_SelectDockFrame then pcall(FCF_SelectDockFrame, main) end
  return true
end

O.commands.chat = function()
  if InCombatLockdown and InCombatLockdown() then
    O.Print("finish the fight first, then run /owl chat again.")
    return
  end
  local ok, done = O.Try("chat cleanup", SplitChat)
  if ok and done then
    O.Print("loot, money, XP and skill messages now go to the Loot tab. Your main tab is people only.")
  else
    O.Print("could not split chat automatically. Right-click the General tab, Filters, and untick Loot and Experience.")
  end
end
