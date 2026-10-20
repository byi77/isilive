---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local function WithPersonalBest(callback)
    local state = { timed = { level = 14 }, overtime = { level = 12 } }
    ctx.with_globals({
      C_LFGList = {
        GetSearchResultInfo = function()
          return { activityIDs = { 101 } }
        end,
      },
      C_MythicPlus = {
        GetSeasonBestForMap = function(mapID)
          Assert.Equal(mapID, 501)
          if state.fail then
            error("unavailable")
          end
          return state.timed, state.overtime
        end,
      },
    }, function()
      local addon = ctx.load_modules({ "isiLive_lfg_personal_best.lua", "isiLive_lfg_view_hooks.lua" })
      addon.LFGEntryResolver.MapIDFromActivityIDs = function(ids)
        Assert.Equal(ids[1], 101)
        return 501
      end
      addon.LFGBonusModel.ResolveLocalizedText = function()
        return "Du: %s"
      end
      callback(addon, state)
    end)
  end

  test("LFG personal best uses the highest completed current-season dungeon level", function()
    WithPersonalBest(function(addon, state)
      Assert.Equal(addon.LFGPersonalBest.GetText(1), "Du: +14")
      state.overtime.level = 16
      Assert.Equal(addon.LFGPersonalBest.GetText(1), "Du: +16")
      state.timed, state.overtime = nil, nil
      Assert.Equal(addon.LFGPersonalBest.GetText(1), "Du: -")
    end)
  end)

  test("LFG personal best leaves unavailable ambiguous and secret data unresolved", function()
    WithPersonalBest(function(addon, state)
      state.fail = true
      Assert.Nil(addon.LFGPersonalBest.GetText(1))
      state.fail = false
      state.timed.level = "14"
      Assert.Nil(addon.LFGPersonalBest.GetText(1))
      state.timed.level = 14
      addon.LFGEntryResolver.MapIDFromActivityIDs = function()
        return nil
      end
      Assert.Nil(addon.LFGPersonalBest.GetText(1))
      local secret = {}
      addon.Validators.IsSecretValue = function(value)
        return value == secret
      end
      Assert.Nil(addon.LFGPersonalBest.GetText(secret))
      addon.LFGEntryResolver.MapIDFromActivityIDs = function()
        return 501
      end
      state.timed = secret
      Assert.Nil(addon.LFGPersonalBest.GetText(1))
      state.timed = { level = secret }
      Assert.Nil(addon.LFGPersonalBest.GetText(1))
    end)
  end)

  local function NewRow()
    local function Label(width, left)
      return {
        width = width,
        left = left,
        GetWidth = function(self)
          return self.width
        end,
        GetLeft = function(self)
          return self.left
        end,
        SetWidth = function(self, value)
          self.width = value
        end,
        SetHeight = function() end,
        SetJustifyH = function() end,
        SetTextColor = function(self, ...)
          self.color = { ... }
        end,
        SetWordWrap = function(self, value)
          self.wrap = value
        end,
        ClearAllPoints = function(self)
          self.point = nil
        end,
        SetPoint = function(self, ...)
          self.point = { ... }
        end,
        SetText = function(self, value)
          self.text = value
        end,
        Show = function(self)
          self.shown = true
        end,
        Hide = function(self)
          self.shown = false
        end,
      }
    end
    local row = { resultID = 1, Name = Label(160, 0), ActivityName = Label(160, 0), creations = 0 }
    row.CreateFontString = function(self)
      self.creations = self.creations + 1
      self.personal = Label(0, 120)
      return self.personal
    end
    return row, Label
  end

  test("LFG personal best renders without PGF and clears recycled unresolved rows", function()
    WithPersonalBest(function(addon, state)
      local row = NewRow()
      addon.LFGPersonalBest.Apply(row)
      Assert.Equal(row.personal.text, "Du: +14")
      Assert.True(row.personal.shown)
      Assert.Equal(row.personal.point[2], row)
      Assert.Equal(row.personal.point[4], -115)
      Assert.Equal(row.ActivityName.width, 114)
      Assert.Equal(row.Name.width, 160)
      Assert.False(row.personal.wrap)
      addon.LFGPersonalBest.Apply(row)
      Assert.Equal(row.creations, 1)
      Assert.Equal(row.ActivityName.width, 114)
      state.fail = true
      addon.LFGPersonalBest.Apply(row)
      Assert.False(row.personal.shown)
      Assert.Equal(row.personal.text, "")
      Assert.Equal(row.ActivityName.width, 160)
      state.fail = false
      state.timed, state.overtime = nil, nil
      addon.LFGPersonalBest.Apply(row)
      Assert.Equal(row.personal.text, "Du: -")
    end)
  end)

  test("LFG personal best replaces only the PGF leader level and survives disabled rating info", function()
    WithPersonalBest(function(addon)
      local row, Label = NewRow()
      local frame = { ExtraText = Label(35, 0), Rating = Label(35, 0), shown = true }
      frame.IsShown = function(self)
        return self.shown
      end
      frame.Rating.text, frame.Rating.shown = "3171", true
      frame.ExtraText.text, frame.ExtraText.shown = "+16", true
      local provider = { ratingInfoFrames = { [row] = frame }, AddRatingInfo = function() end }
      local update, hooks = nil, 0
      ctx.with_globals({
        PremadeGroupsFilter = { Debug = provider },
        hooksecurefunc = function(_, _, callback)
          update = callback
          hooks = hooks + 1
        end,
      }, function()
        addon.LFGPersonalBest.Apply(row)
        Assert.False(frame.ExtraText.shown)
        Assert.Equal(frame.Rating.text, "3171")
        Assert.True(frame.Rating.shown)
        Assert.Equal(row.personal.text, "Du: +14")
        Assert.Equal(row.personal.point[2], frame)
        -- PGF refresh resets both its own text and the dungeon-name budget.
        row.ActivityName.width = 160
        frame.ExtraText.text, frame.ExtraText.shown = "+12", true
        update(row)
        Assert.False(frame.ExtraText.shown)
        Assert.Equal(row.personal.text, "Du: +14")
        Assert.Equal(row.ActivityName.width, 114)
        Assert.Equal(hooks, 1)
        frame.shown = false
        update(row)
        Assert.True(row.personal.shown)
        Assert.Equal(row.personal.point[2], row)
        Assert.Equal(row.creations, 1)
      end)
    end)
  end)

  test("LFG personal best refreshes recycled Blizzard rows without PGF or mouseover", function()
    WithPersonalBest(function(addon, state)
      local hooks = {}
      local row = NewRow()
      ctx.with_globals({
        LFGListFrame = { SearchPanel = { ScrollBox = {} } },
        hooksecurefunc = function(name, callback)
          hooks[name] = callback
        end,
      }, function()
        addon.LFGViewHooks.Configure({
          updateSearchButton = addon.LFGPersonalBest.Apply,
          clearSearchCaches = function() end,
        })
        addon.LFGViewHooks.HookSearchPanel()
        hooks.LFGListSearchEntry_Update(row)
        Assert.Equal(row.personal.text, "Du: +14")
        state.timed.level = 15
        hooks.LFGListSearchEntry_Update(row)
        Assert.Equal(row.personal.text, "Du: +15")
        Assert.Equal(row.creations, 1)
      end)
    end)
  end)
end
