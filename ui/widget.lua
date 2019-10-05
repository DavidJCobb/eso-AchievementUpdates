local Widget = {
   control = nil,
   pool    = nil,
   items   = {},
   timerRunning = false,
}
AchievementUpdates.Widget = Widget

local Item = {}
Item.__index = Item
local sequence = 0
function Item:new(achievement, criterion)
   local result = {
      achievement = achievement, -- Achievement object
      criterion   = criterion,   -- entry from the Achievement's criteria table
      firstShown  = GetGameTimeMilliseconds(), -- used to sort within the UI
      visible     = false,
      control     = nil,
      poolKey     = nil,
      dismissed   = false,
      dismissAnim = nil, -- nil == animation has finished or hasn't started
   }
   setmetatable(result, self)
   do -- used to sort when two items are added on the same frame
      sequence = sequence + 1
      result.sequence = sequence
      zo_callLater(function() sequence = 0 end, 1)
   end
   if type(criterion) == "number" then
      result.criterion = achievement.criteria[criterion]
   end
   result.lastUpdated = result.firstShown
   return result
end
function Item:dismiss()
   local control = self.control
   if self.dismissed or not control then
      return
   end
   self.dismissed = true
   local anim = control.anim
   if not anim then
      anim = ANIMATION_MANAGER:CreateTimelineFromVirtual("AchievementUpdates_CriterionDismiss", control)
      control.anim = anim
   end
   self.dismissAnim = anim
   local item = self
   self.dismissAnim:SetHandler("OnStop", function() item:dismissDone() end)
   self.dismissAnim:SetEnabled(true)
   self.dismissAnim:PlayFromStart()
   --
   if self.criterion then
      self.criterion.countChange = 0
   end
end
function Item:dismissDone()
   self.dismissAnim:SetHandler("OnStop", nil)
   self.dismissAnim:SetEnabled(false)
   self.dismissAnim = nil
end
function Item:redraw()
   if self.dismissed or not self.visible then
      return
   end
   local control = self.control
   if not control then
      local key
      control, key = Widget.pool:AcquireObject()
      self.control = control
      self.poolKey = key
      control:SetHidden(false)
   end
   if control.anim then
      --
      -- if the control has been recycled, then the fade-out animation 
      -- will have left it invisible
      --
      -- zenimax's APIs don't seem to handle this well at all; there's 
      -- no *readily-apparent* way to tell an animation, "hey, pal, why 
      -- don'cha go on and undo all that stuff y'just did?"
      --
      control:SetAlpha(1)
   end
   local achievement = self.achievement
   local criterion   = self.criterion
   control:GetNamedChild("AchName"):SetText(achievement.name)
   control:GetNamedChild("CritName"):SetText(criterion.description)
   if criterion.required == 1 then
      -- TODO: checkbox
      local bar = control:GetNamedChild("Bar")
      bar:SetMinMax(0, 1)
      bar:SetValue(1)
   else
      control:GetNamedChild("CritName"):SetText(zo_strformat(GetString(SI_ACHIEVEMENT_UPDATE_FORMAT_OBJECTIVE), criterion.description, criterion.completed, criterion.required, criterion.countChange))
      local bar = control:GetNamedChild("Bar")
      bar:SetMinMax(0, criterion.required)
      bar:SetValue(criterion.completed)
   end
end
function Item:show()
   if self.dismissed or self.visible then
      return
   end
   self.visible     = true
   self.lastUpdated = GetGameTimeMilliseconds()
end
function Item:slideUpBy(distance)
   local control = self.control
   if not control then
      return
   end
   local anim = control.animSlideUp
   if not anim then
      anim = ANIMATION_MANAGER:CreateTimelineFromVirtual("AchievementUpdates_SlideUp", control)
      control.animSlideUp = anim
   end
   anim:GetAnimation(1):SetTranslateDeltas(0, -distance)
   if distance > 0 then
      anim:PlayFromStart()
   else
      anim:Stop()
   end
end
function Item:update()
   if self.dismissed then
      return
   end
   self.lastUpdated = GetGameTimeMilliseconds()
   self:redraw()
end
function Item:__tostring()
   return "[[" .. self.achievement.name .. "][" .. self.criterion.description .. "]]"
end
function Item.__lt(a, b)
   if a.firstShown < b.firstShown then
      return true
   end
   if a.firstShown == b.firstShown then
      return a.sequence < b.sequence
   end
   return false
end

function Widget:initialize(ctrl)
   self.control = ctrl
   do
      local factoryFunction =
         function(objectPool)
            return ZO_ObjectPool_CreateNamedControl(string.format("%sRow", self.control:GetName()), "AchievementUpdates_Criterion", objectPool, self.control)
         end
      self.pool = ZO_ObjectPool:New(factoryFunction, ZO_ObjectPool_DefaultResetControl)
   end
   --self.fragment = ZO_SimpleSceneFragment:New(control, "ItemTrigBlockMostKeys")
   --HUD_UI_SCENE:AddFragment(self.fragment)
end

local MAX_TO_DISPLAY = 3

local UPDATE_REGISTRATION_NAME = "AchievementUpdateWidgetTimer"
local MAX_SHOW_DURATION_MS     = 7500
local POLL_FREQUENCY_MS        = 200
local function _update()
   local now   = GetGameTimeMilliseconds()
   local count = #Widget.items
   local anyDeleted = false
   for i = 1, count do
      local item = Widget.items[i]
      if item.dismissed then
         if not item.dismissAnim then -- animation has completed
            Widget.pool:ReleaseObject(item.poolKey)
            Widget.items[i] = nil
            anyDeleted = true
         end
      elseif item.visible then
         if now - item.lastUpdated > MAX_SHOW_DURATION_MS then
            item:dismiss()
         end
      end
   end
   if anyDeleted then
      local list = {}
      local j    = 0
      for i = 1, count do
         local item = Widget.items[i]
         if item then
            j = j + 1
            list[j] = item
         end
      end
      Widget.items = list
      if j == 0 then
         Widget.timerRunning = false
         EVENT_MANAGER:UnregisterForUpdate(UPDATE_REGISTRATION_NAME)
      else
         Widget:reflow(count - j)
      end
   end
end

function Widget:reflow(countDeleted)
   table.sort(self.items, function(a, b) return a < b end)
   local count   = #self.items
   local yOffset = 0
   local itemHeight
   for i = 1, math.min(MAX_TO_DISPLAY, count) do
      local item = self.items[i]
      item:show()
      item:redraw()
      --
      local control = item.control
      if not itemHeight then
         local bar = control:GetNamedChild("Bar")
         itemHeight = bar:GetBottom() - control:GetTop()
      end
      if yOffset == 0 and countDeleted then
         yOffset = itemHeight * countDeleted
      end
      control:ClearAnchors()
      control:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, yOffset)
      do
         if countDeleted then
            item:slideUpBy(itemHeight * countDeleted)
         else
            item:slideUpBy(0)
         end
      end
      --
      yOffset = yOffset + itemHeight + 16
   end
end

function Widget:showCriterion(achievement, criteriaIndex)
   if not self.timerRunning then
      self.timerRunning = true
      EVENT_MANAGER:RegisterForUpdate(UPDATE_REGISTRATION_NAME, POLL_FREQUENCY_MS, _update)
   end
   local criterion = achievement.criteria[criteriaIndex]
   if not criterion then
      return
   end
   for i = 1, #self.items do
      local item = self.items[i]
      if item.achievement == achievement then
         if item.criterion == criterion then
            if not item.dismissed then
               item:update()
               return
            end
         end
      end
   end
   local item = Item:new(achievement, criterion)
   self.items[#self.items + 1] = item
   self:reflow()
end