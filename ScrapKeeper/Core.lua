local _, ns = ...
ns.Core = {}

-- Fail closed: incomplete item metadata never authorizes a sale.
function ns.Core.CanSell(info, quest, price, keep)
    return info ~= nil and info.itemID ~= nil and info.quality == 0
        and not info.isLocked and not info.hasNoValue and not info.hasLoot
        and quest ~= nil and not quest.isQuestItem and quest.questID == nil
        and type(price) == "number" and price > 0
        and not keep[info.itemID]
end

function ns.Core.ItemID(text)
    local value = tonumber(text) or tonumber(text:match("item:(%d+)"))
    if value and value > 0 and value == math.floor(value) then return value end
end
