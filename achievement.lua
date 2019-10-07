local Achievement = {}
Achievement.__index = Achievement

AchievementUpdates.Achievement = Achievement

function Achievement:new(id, last, getFullData)
   local result = setmetatable({}, self)
   if last then
      local n = id
      while n do
         id = n
         n = GetNextAchievementInLine(n)
      end
   end
   --
   local name, description, points, icon, completed, date, time = GetAchievementInfo(id)
   result.id          = id
   result.name        = name
   result.description = description
   result.points      = points
   result.icon        = icon
   result.completed   = completed
   result.date        = date
   result.time        = time
   --
   do
      local topLevelIdx, categoryIdx, achievementIdx = GetCategoryInfoFromAchievementId(id)
      result.category = topLevelIdx
      result.subcategory = categoryIdx
      result.indexInSubcategory = achievementIdx
   end
   --
   result.firstAchievementId = GetFirstAchievementInLine(id)
   result.prevAchievementId  = GetPreviousAchievementInLine(id) -- NOTE: broken
   result.nextAchievementId  = GetNextAchievementInLine(id)
   --
   result.criteria = {}
   result.totalCompleted = 0
   result.totalRequired  = 0
   for i = 1, GetAchievementNumCriteria(id) do
      local description, numCompleted, numRequired = GetAchievementCriterion(id, i)
      result.criteria[i] = {
         description = description,
         completed   = numCompleted,
         required    = numRequired, -- if == 1, then checkbox
         lastChange  = 0, -- the last single bit of progress added to the achievement
         countChange = 0, -- used by UI to show changes cumulatively, i.e. if you progress the achievement multiple times while the meter is on-screen, we show the total progress made while the meter is on-screen
      }
      result.totalCompleted = result.totalCompleted + numCompleted
      result.totalRequired  = result.totalRequired  + numRequired
   end
   --
   if getFullData then
      result.rewards = {
         collectibleId = nil,
         dyeId    = nil,
         itemName = nil,
         title    = nil,
      }
      do
         local has, reward = GetAchievementRewardCollectible(id)
         if has then
            result.rewards.collectibleId = reward
         end
         has, reward = GetAchievementRewardDye(id)
         if has then
            result.rewards.dyeId = reward
         end
         has, reward = GetAchievementRewardItem(id)
         if has then
            result.rewards.itemName = reward
         end
         has, reward = GetAchievementRewardTitle(id)
         if has then
            result.rewards.title = reward
         end
      end
   end
   --
   return result
end
function Achievement:checkForUpdates()
   local count   = 0
   local changes = {}
   local id      = self.id
   for i = 1, GetAchievementNumCriteria(id) do
      local criteria = self.criteria[i]
      local _, c, r = GetAchievementCriterion(id, i)
      if criteria.completed ~= c then
         criteria.lastChange = c - criteria.completed
         criteria.countChange = criteria.countChange + criteria.lastChange
         criteria.completed = c
         count = count + 1
         changes[count] = i
      end
   end
   local _, _, _, _, completed, date, time = GetAchievementInfo(achievementId)
   if completed then
      self.completed = completed
      self.date      = date
      self.time      = time
   end
   if count > 0 then
      return changes
   end
end
function Achievement:getAllNextAchievementIDs()
   local ids   = {}
   local count = 0
   local id = GetNextAchievementInLine(self.id)
   while (id ~= 0) do
      count = count + 1
      ids[count] = id
      id = GetNextAchievementInLine(id)
   end
   return ids
end
function Achievement:hasAnyProgress()
   for i, c in ipairs(self.criteria) do
      if c.completed > 0 then
         return true
      end
   end
   return false
end
function Achievement:isCurrentLineStep()
   if self.prevAchievementId ~= 0 then
      if not IsAchievementComplete(self.prevAchievementId) then
         return false
      end
   end
   if self.nextAchievementId ~= 0 then
      return not IsAchievementComplete(self.id)
   end
   return true
end
function Achievement:flagAllProgressAsChanged()
   local changes = {}
   local j = 1
   for i, c in ipairs(self.criteria) do
      if c.completed > 0 then
         changes[j] = i
         j = j + 1
         c.lastChange  = c.completed
         c.countChange = c.lastChange
      end
   end
   return changes
end
