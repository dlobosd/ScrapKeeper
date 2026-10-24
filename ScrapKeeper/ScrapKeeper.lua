local addonName, ns = ...
local frame = CreateFrame("Frame")
local db, merchant, session
local LIMIT, INTERVAL, TIMEOUT = 12, 0.25, 3

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8bd450ScrapKeeper:|r " .. text)
end

local function Price(info)
    if not info or not info.hyperlink then return nil end
    return select(11, C_Item.GetItemInfo(info.hyperlink))
end

local function Candidate(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    local price = Price(info)
    if ns.Core.CanSell(info, quest, price, db.keep) then
        return {bag=bag, slot=slot, id=info.itemID, link=info.hyperlink,
            count=info.stackCount, value=price * info.stackCount}
    end
end

local function Scan()
    local found = {}
    -- Backpack + four equipped bags. Never scan bank or account storage.
    for bag = 0, 4 do
        for slot = C_Container.GetContainerNumSlots(bag), 1, -1 do
            local item = Candidate(bag, slot)
            if item then found[#found + 1] = item end
        end
    end
    return found
end

local function Finish(reason)
    local current = session
    session = nil
    if current then
        Say(("Confirmed %d stacks (%s). %s"):format(current.sold,
            GetCoinTextureString(current.value), reason or ""))
    end
end

local Step
Step = function(current)
    if session ~= current then return end
    if not merchant or not MerchantFrame:IsShown() or InCombatLockdown()
        or IsShiftKeyDown() or not db.enabled then
        Finish("Stopped.")
        return
    end
    if current.pending then
        local p = current.pending
        local info = C_Container.GetContainerItemInfo(p.bag, p.slot)
        -- A changed slot alone is ambiguous; only disappearance confirms a stack.
        if not info then
            current.sold = current.sold + 1
            current.value = current.value + p.value
            current.pending = nil
        elseif GetTime() - current.sentAt >= TIMEOUT then
            Finish("Sale was not confirmed; stopped without retrying.")
            return
        else
            C_Timer.After(INTERVAL, function() Step(current) end)
            return
        end
    end
    if current.sold >= LIMIT then Finish("12-stack safety limit reached."); return end
    local nextItem = table.remove(current.queue, 1)
    if not nextItem then Finish("Done."); return end
    -- Revalidate immediately before using the slot, including protected list.
    local fresh = Candidate(nextItem.bag, nextItem.slot)
    if fresh and fresh.id == nextItem.id and fresh.link == nextItem.link
        and fresh.count == nextItem.count then
        current.pending, current.sentAt = fresh, GetTime()
        C_Container.UseContainerItem(fresh.bag, fresh.slot)
    end
    C_Timer.After(INTERVAL, function() Step(current) end)
end

local function Start()
    if session or not merchant or IsShiftKeyDown() or InCombatLockdown() then return end
    local queue = Scan()
    if #queue == 0 then return end
    session = {queue=queue, sold=0, value=0}
    Step(session)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(ScrapKeeperDB) ~= "table" then ScrapKeeperDB = {} end
        db = ScrapKeeperDB
        if db.enabled == nil then db.enabled = true end
        if type(db.keep) ~= "table" then db.keep = {} end
    elseif event == "MERCHANT_SHOW" and db then
        merchant = true
        if db.enabled then Start() end
    elseif event == "MERCHANT_CLOSED" then
        merchant = false
        Finish("Merchant closed; any pending sale is excluded.")
    end
end)

SLASH_SCRAPKEEPER1 = "/scrapkeeper"
SLASH_SCRAPKEEPER2 = "/sk"
SlashCmdList.SCRAPKEEPER = function(input)
    if not db then return end
    local command, argument = input:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "on" or command == "off" then
        db.enabled = command == "on"
        if not db.enabled then Finish("Disabled.") end
        Say(db.enabled and "Automatic selling enabled." or "Automatic selling disabled.")
    elseif command == "keep" or command == "unkeep" then
        local id = ns.Core.ItemID(argument)
        if not id then Say("Use /sk " .. command .. " ITEM_ID or an item link."); return end
        db.keep[id] = command == "keep" or nil
        Say(("Item %d: %s"):format(id, db.keep[id] and "protected" or "unprotected"))
    elseif command == "list" then
        local ids = {}
        for id in pairs(db.keep) do ids[#ids + 1] = tostring(id) end
        table.sort(ids)
        Say("Protected IDs: " .. (#ids > 0 and table.concat(ids, ", ") or "none"))
    elseif command == "preview" then
        local items, value = Scan(), 0
        for _, item in ipairs(items) do value = value + item.value end
        Say(("%d eligible stacks, %s (maximum 12 per visit)."):format(#items, GetCoinTextureString(value)))
    else
        Say("/sk on | off | preview | keep ITEM_ID | unkeep ITEM_ID | list")
        Say("Hold Shift when opening a merchant to skip. Only grey items are eligible.")
    end
end
