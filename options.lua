local menu = {
   name        = "AchievementUpdates",
   displayName = "Achievement Updates",
   type        = "panel",
}
local panel = {
   {  -- Reset position
      type    = "button",
      name    = GetString(SI_ACHIEVEMENT_UPDATE_OPTIONNAME_RESETPOS),
      tooltip = GetString(SI_ACHIEVEMENT_UPDATE_OPTIONDESC_RESETPOS),
      width   = "half",
      func    =
         function()
            AchievementUpdatesSavedata.widgetX =  48
            AchievementUpdatesSavedata.widgetY = 190
            AchievementUpdates.Widget:repositionFromSavedata()
         end,
   },
   {  -- Max updates to display at one time
      --
      type    = "slider",
      min     = 1,
      max     = 8,
      default = 3,
      name    = GetString(SI_ACHIEVEMENT_UPDATE_OPTIONNAME_MAXITEMS),
      tooltip = GetString(SI_ACHIEVEMENT_UPDATE_OPTIONDESC_MAXITEMS),
      getFunc =
         function()
            return AchievementUpdates.Widget.config.maxItemsToDisplay or 3
         end,
      setFunc =
         function(v)
            AchievementUpdatesSavedata.maxItemsToDisplay = v
            AchievementUpdates.Widget.config.maxItemsToDisplay = v
         end,
   },
}

function AchievementUpdates.registerLAMOptions()
   local LAM = LibStub:GetLibrary("LibAddonMenu-2.0")
   if not LAM then
      return
   end
   LAM:RegisterAddonPanel("AchievementUpdatesOptionsMenu", menu)
   LAM:RegisterOptionControls("AchievementUpdatesOptionsMenu", panel)
end