AchievementUpdates = {
   cache = {}, -- cache[achievementId] == Achievement instance
}

local Achievement -- set this after achievement.lua has loaded
local Widget      -- set this after widget.lua has loaded

--[[
   POTENTIAL IMPROVEMENTS:
   
    - Allow the player to change the maximum number of items 
      that can display.
      
    - Show "checkbox" items as actual checkboxes (will require 
      changing how we handle reflow, to account for items of 
      varying heights)
]]--

local function _buildCache()
   local data = {}
   for c = 1, GetNumAchievementCategories() do
      local name, subcategoryCount, achievementCount, _, _, _ = GetAchievementCategoryInfo(c)
      for a = 1, achievementCount do
         local id = GetAchievementId(c, s, a)
         if not IsAchievementComplete(id) then
            data[id] = Achievement:new(id)
            if not data[id]:hasAnyProgress() then
               data[id] = nil
            end
         end
      end
      for s = 1, subcategoryCount do
         local name, achievementCount, _, _, _ = GetAchievementSubCategoryInfo(c, s)
         for a = 1, achievementCount do
            local id = GetAchievementId(c, s, a)
            if not IsAchievementComplete(id) then
               data[id] = Achievement:new(id)
               if not data[id]:hasAnyProgress() then
                  data[id] = nil
               end
            end
         end
      end
   end
   AchievementUpdates.cache = data
end

local function OnAchievementUpdate(eventCode, achievementId)
   --
   -- This event does not provide information on which achievement 
   -- criteria were advanced, so we must rely on a cache to check 
   -- for differences.
   --
   local achievement = AchievementUpdates.cache[achievementId]
   local changes
   if not achievement then
      --
      -- Achievements are not cached unless they have progress. If 
      -- we're being notified about a completed achievement, then 
      -- skip it. Otherwise, cache the achievement, but flag all 
      -- progress as "new."
      --
      if IsAchievementComplete(achievementId) then
         return
      end
      achievement = Achievement:new(achievementId)
      AchievementUpdates.cache[achievementId] = achievement
      changes = achievement:flagAllProgressAsChanged()
   else
      changes = achievement:checkForUpdates()
   end
   if changes then
      --
      -- changes == array of changed criteria indices in the 
      --            achievement, if any changes occurred.
      --
      for i = 1, #changes do
         AchievementUpdates.Widget:showCriterion(achievement, changes[i])
      end
   end
   if achievement.completed then
      --
      -- We don't need to cache completed achievements, because 
      -- they cannot progress.
      --
      AchievementUpdates.cache[achievementId] = nil
   end
end

local function Initialize()
   Achievement = AchievementUpdates.Achievement
   Widget      = AchievementUpdates.Widget
   _buildCache()
   EVENT_MANAGER:RegisterForEvent("AchievementUpdates", EVENT_ACHIEVEMENT_UPDATED, OnAchievementUpdate)
   Widget:onAddonLoaded()
   if not AchievementUpdatesSavedata then
      AchievementUpdatesSavedata = {
         version = 1,
         widgetX = Widget.control:GetLeft() or  48,
         widgetY = Widget.control:GetTop()  or 190,
      }
   else
      local sd      = AchievementUpdatesSavedata
      local control = Widget.control
      control:ClearAnchors()
      control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sd.widgetX, sd.widgetY)
   end
end
local function OnAddonLoaded(eventCode, addonName)
   if addonName == "AchievementUpdates" then
      Initialize()
   end
end
EVENT_MANAGER:RegisterForEvent("AchievementUpdates", EVENT_ADD_ON_LOADED, OnAddonLoaded)

function AchievementUpdates.Test()
   local achievement = (function()
      for k, v in pairs(AchievementUpdates.cache) do
         local cc = #v.criteria
         if cc > 3 then
            for i = 1, cc do
               if v.criteria[i].required > 1 then
                  return v
               end
            end
         end
      end
   end)()
   do
      local count = 0
      local empty = 0
      for k, v in pairs(AchievementUpdates.cache) do
         count = count + 1
         local found = false
         for i, c in ipairs(v.criteria) do
            if c.completed > 0 then
               found = true
            end
         end
         if not found then
            empty = empty + 1
         end
      end
      d("There are " .. count .. " achievements cached (" .. empty .. " with no progress).")
   end
   if not achievement then
      d("no suitable achievement (this can't be right)")
      return
   end
   local Widget = AchievementUpdates.Widget
   Widget:showCriterion(achievement, 1)
   zo_callLater(function() Widget:showCriterion(achievement, 2) end, 100)
   zo_callLater(function() Widget:showCriterion(achievement, 3) end, 100)
   zo_callLater(function() Widget:showCriterion(achievement, 4) end, 1200)
   zo_callLater(function() Widget:showCriterion(achievement, 5) end, 2000)
   --zo_callLater(function() Widget:showCriterion(achievement, 1) end, 4000)
end