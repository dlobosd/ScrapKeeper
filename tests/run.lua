local passed = 0
local function check(value, label)
    assert(value, label)
    passed = passed + 1
end
local ns = {}
assert(loadfile("ScrapKeeper/Core.lua"))("ScrapKeeper", ns)
local good = {itemID=1, quality=0, stackCount=2, hyperlink="item:1"}
local function copy(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
check(ns.Core.CanSell(good, {}, 10, {}), "grey item")
for _,field in ipairs({"isLocked","hasNoValue","hasLoot"}) do
    local item=copy(good); item[field]=true
    check(not ns.Core.CanSell(item, {}, 10, {}), field)
end
for _,quality in ipairs({1,2,3,4,5}) do
    local item=copy(good); item.quality=quality
    check(not ns.Core.CanSell(item, {}, 10, {}), "non-grey")
end
check(not ns.Core.CanSell(good, nil, 10, {}), "unknown quest data")
check(not ns.Core.CanSell(good, {isQuestItem=true}, 10, {}), "quest item")
check(not ns.Core.CanSell(good, {questID=42}, 10, {}), "quest starter")
check(not ns.Core.CanSell(good, {}, nil, {}), "uncached price")
check(not ns.Core.CanSell(good, {}, 0, {}), "zero price")
check(not ns.Core.CanSell(good, {}, 10, {[1]=true}), "protected")
check(ns.Core.ItemID("|Hitem:123:0|h[Test]|h")==123, "item link")
check(ns.Core.ItemID("-1")==nil and ns.Core.ItemID("1.5")==nil, "invalid IDs")

local eventHandler, bags, timers, now, calls, shift, combat, shown, failSale
DEFAULT_CHAT_FRAME={AddMessage=function() end}
SlashCmdList={}
CreateFrame=function() return {
    RegisterEvent=function() end,
    SetScript=function(_, _, fn) eventHandler=fn end
} end
MerchantFrame={IsShown=function() return shown end}
InCombatLockdown=function() return combat end
IsShiftKeyDown=function() return shift end
GetTime=function() return now end
GetCoinTextureString=tostring
C_Timer={After=function(_, fn) timers[#timers+1]=fn end}
C_Item={GetItemInfo=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,10 end}
C_Container={
    GetContainerNumSlots=function(bag) return bag==0 and 20 or 0 end,
    GetContainerItemInfo=function(bag,slot) if bag==0 then return bags[slot] end end,
    GetContainerItemQuestInfo=function() return {} end,
    UseContainerItem=function(bag,slot)
        assert(shown and bag==0, "must never use items outside merchant")
        calls=calls+1
        if not failSale then bags[slot]=nil end
    end
}
assert(loadfile("ScrapKeeper/ScrapKeeper.lua"))("ScrapKeeper", ns)
local function reset(count)
    bags={}; timers={}; now=0; calls=0; shift=false; combat=false; shown=true; failSale=false
    ScrapKeeperDB={enabled=true,keep={}}
    eventHandler(nil,"MERCHANT_CLOSED")
    eventHandler(nil,"ADDON_LOADED","ScrapKeeper")
    for i=1,count do bags[i]=copy(good) end
end
local function drain()
    local steps=0
    while #timers>0 do
        steps=steps+1; assert(steps<100, "timer loop must terminate")
        now=now+0.25
        table.remove(timers,1)()
    end
end
reset(15); eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==12, "12-stack cap")
reset(2); shift=true; eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==0, "shift bypass")
reset(2); ScrapKeeperDB.keep[1]=true; eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==0, "keep list integration")
reset(2); eventHandler(nil,"MERCHANT_SHOW"); shown=false
eventHandler(nil,"MERCHANT_CLOSED"); drain()
check(calls==1, "cancel after merchant close")
reset(2); failSale=true; eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==1 and bags[2]~=nil, "timeout does not retry")
reset(2); eventHandler(nil,"MERCHANT_SHOW"); combat=true; drain()
check(calls==1, "combat cancellation")
reset(2); SlashCmdList.SCRAPKEEPER("preview")
check(calls==0, "preview never sells")
reset(2); eventHandler(nil,"MERCHANT_SHOW"); SlashCmdList.SCRAPKEEPER("off"); drain()
check(calls==1, "disable cancels timers")
reset(2); eventHandler(nil,"MERCHANT_SHOW"); bags[1].quality=4; drain()
check(calls==1, "changed slot revalidated")
reset(2); eventHandler(nil,"MERCHANT_SHOW"); eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==2, "duplicate event does not duplicate session")
reset(15); eventHandler(nil,"MERCHANT_SHOW"); drain()
eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==12, "duplicate show after completion preserves visit cap")
reset(2); shift=true; eventHandler(nil,"MERCHANT_SHOW")
shift=false; eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==0, "duplicate show preserves shift bypass")
reset(2); failSale=true; eventHandler(nil,"MERCHANT_SHOW"); drain()
eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==1, "duplicate show cannot retry timed out sale")
reset(15); eventHandler(nil,"MERCHANT_SHOW"); drain()
eventHandler(nil,"MERCHANT_CLOSED"); eventHandler(nil,"MERCHANT_SHOW"); drain()
check(calls==15, "closing and reopening permits a new visit")
print(("PASS: %d assertions"):format(passed))
