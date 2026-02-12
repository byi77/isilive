local addonName, addonTable = ...

addonTable = addonTable or {}

local Notice = {}
addonTable.Notice = Notice

function Notice.CreateInviteHint(opts)
    opts = opts or {}
    local parent = opts.parent or UIParent
    local mainFrameGlobalName = opts.mainFrameGlobalName or "isiLiveMainFrame"

    local frame = CreateFrame("Frame", "isiLiveInviteHintFrame", parent)
    frame:SetSize(420, 46)
    frame:Hide()
    frame:SetFrameStrata("DIALOG")

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.65)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 0.82, 0)

    local endsAt = 0

    local function GetInviteAnchorFrame()
        local lfgListInviteDialog = rawget(_G, "LFGListInviteDialog")
        if lfgListInviteDialog and lfgListInviteDialog:IsShown() then
            return lfgListInviteDialog
        end
        local lfgDungeonReadyDialog = rawget(_G, "LFGDungeonReadyDialog")
        if lfgDungeonReadyDialog and lfgDungeonReadyDialog:IsShown() then
            return lfgDungeonReadyDialog
        end
        return nil
    end

    local function Position()
        local anchor = GetInviteAnchorFrame()
        frame:ClearAllPoints()

        if anchor then
            frame:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
            return
        end

        local globalMainFrame = rawget(_G, mainFrameGlobalName)
        if globalMainFrame and globalMainFrame:IsShown() then
            frame:SetPoint("TOP", globalMainFrame, "BOTTOM", 0, -8)
            return
        end

        frame:SetPoint("TOP", parent, "TOP", 0, -220)
    end

    local function Show(message, durationSeconds)
        text:SetText(message)
        Position()
        endsAt = GetTime() + (durationSeconds or 10)
        frame:Show()
    end

    frame:SetScript("OnUpdate", function(self, elapsed)
        if GetTime() >= endsAt then
            self:Hide()
            return
        end
        Position()
    end)

    return {
        frame = frame,
        Show = Show,
        Position = Position,
    }
end

