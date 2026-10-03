-- Stand-in for the combat secret-number rules. WoW raises on arithmetic
-- against a real secret; here a number listed in `secrets` is treated as secret
-- so the addon must not use it as a stack size.
local secrets = {}

local function reset_secret_api()
    canaccessvalue = nil
    issecretvalue = nil
    for key in pairs(secrets) do
        secrets[key] = nil
    end
end

local function mark_secret(value)
    secrets[value] = true
end

-- Load the addon against a tiny Classic-like environment.
hooksecurefunc = function() end
SetTooltipMoney = function() end
SELL_PRICE = "Sell Price"
GetBuildInfo = function()
    return "", "", "", 11509
end
GameTooltip = {}
floor = math.floor
COPPER_PER_SILVER = 100
SILVER_PER_GOLD = 100
NORMAL_FONT_COLOR = {
    r = 1, g = 1, b = 1,
    WrapTextInColorCode = function(_, text)
        return text
    end,
}

dofile("VendorPricePlus/Compat.lua")
dofile("VendorPricePlus/VendorPricePlus.lua")

local Compat = VendorPricePlus.Compat
local VP = VendorPricePlus

local function fail(message)
    error(message, 2)
end

local function expect(actual, expected, message)
    if actual ~= expected then
        fail((message or "assertion failed") ..
            "\n  expected: " .. tostring(expected) ..
            "\n  actual:   " .. tostring(actual))
    end
end

local item_calls

local function install_item_api(bag_count)
    item_calls = 0
    GetItemInfo = function()
        return "Lesser Mana Potion", "link", nil, nil, nil, nil, nil, nil, nil, nil, 30
    end
    C_Item = {
        GetItemCount = function(item_info, include_bank, include_uses)
            item_calls = item_calls + 1
            if include_bank ~= false or include_uses ~= true then
                fail("GetItemCount must ignore the bank and include charges")
            end
            if item_info ~= 3385 then
                fail("expected item id 3385, got " .. tostring(item_info))
            end
            return bag_count
        end,
    }
end

local function tooltip()
    local lines = {}
    return {
        lines = lines,
        AddDoubleLine = function(_, left, right)
            lines[#lines + 1] = { left = left, right = right }
        end,
        Show = function() end,
    }, lines
end

local potion_link = "|cnIQ1:|Hitem:3385::::::::16:1486:::::::::|h[Lesser Mana Potion]|h|r"

local function use_issecretvalue()
    canaccessvalue = nil
    issecretvalue = function(value)
        return secrets[value] == true
    end
end

-- Older clients have no secret API. Plain counts pass through unchanged.
reset_secret_api()
install_item_api(99)
expect(Compat.ResolveStackCount(4, 3385, true), 4, "plain action count")
expect(item_calls, 0, "plain count must not query the bags")
expect(Compat.ResolveStackCount(nil, 3385, false), 1, "missing count")
expect(Compat.CanAccessNumber(0), true, "zero is a real count")

-- The reported failure: GetActionCount() is secret, the bag total is not.
use_issecretvalue()
install_item_api(20)
mark_secret(99)
expect(Compat.ResolveStackCount(99, 3385, true), 20, "recover bag count")
expect(item_calls, 1, "action bar recovery queries GetItemCount once")
expect(Compat.ResolveStackCount(99, potion_link, true), 20, "item link recovery")
expect(Compat.ResolveStackCount(99, 3385, false), 1, "bag slot must not use the bag total")
expect(item_calls, 2, "non-action secret count does not query the bags")

-- Both APIs secret: show a single item rather than throwing.
install_item_api(20)
mark_secret(20)
expect(Compat.ResolveStackCount(99, 3385, true), 1, "secret bag count falls back to one")

-- canaccessvalue is authoritative, including when the check itself errors.
reset_secret_api()
canaccessvalue = function(value)
    if secrets[value] then
        error("blocked")
    end
    return true
end
issecretvalue = function()
    fail("issecretvalue should not run when canaccessvalue exists")
end
mark_secret(99)
install_item_api(7)
expect(Compat.ResolveStackCount(99, 3385, true), 7, "erroring secret check still recovers")

-- SetPrice must multiply the recovered count, never the secret sentinel.
use_issecretvalue()
install_item_api(20)
mark_secret(99)
local tt, lines = tooltip()
VP:SetPrice(tt, true, "SetAction", 99, 3385)
expect(#lines, 2, "stack tooltip has unit and total lines")
expect(lines[1].left, "Vendor", "unit label")
expect(lines[1].right, "30 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", "unit price")
expect(lines[2].left, "Vendor |cff88ccffx20|r", "recovered stack label")
expect(lines[2].right,
    "6 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t",
    "20 * 30 copper")

-- Same potion link from the combat tooltip, with no item id argument.
install_item_api(20)
lines = {}
tt = {
    lines = lines,
    GetItem = function()
        return "Lesser Mana Potion", potion_link
    end,
    AddDoubleLine = function(_, left, right)
        lines[#lines + 1] = { left = left, right = right }
    end,
    Show = function() end,
}
VP:SetPrice(tt, true, "SetAction", 99, nil)
expect(lines[2].left, "Vendor |cff88ccffx20|r", "tooltip link recovers the stack")

-- Out of combat, the action count wins over a different bag total.
reset_secret_api()
install_item_api(99)
tt, lines = tooltip()
VP:SetPrice(tt, true, "SetAction", 4, 3385)
expect(item_calls, 0, "readable action count skips GetItemCount")
expect(lines[2].left, "Vendor |cff88ccffx4|r", "uses the action count")

-- A secret bag-slot count must not throw and must not become the bag total.
use_issecretvalue()
install_item_api(20)
mark_secret(99)
tt, lines = tooltip()
VP:SetPrice(tt, true, "SetBagItem", 99, 3385)
expect(item_calls, 0, "bag tooltip does not replace a slot count")
expect(#lines, 1, "secret slot count keeps the unit price only")
expect(lines[1].right, "30 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", "unit price survived")

-- The multiply in SetPrice stays after the secret-count resolution.
local source_file = assert(io.open("VendorPricePlus/VendorPricePlus.lua", "r"))
local source = source_file:read("*a")
source_file:close()
local set_price_at = assert(source:find("function VP:SetPrice", 1, true))
local resolve_at = assert(source:find("ResolveStackCount", set_price_at, true))
local multiply_at = assert(source:find("sellPrice * count", set_price_at, true))
if resolve_at > multiply_at then
    fail("SetPrice multiplies the count before resolving secret values")
end

print("secret count tests passed")
