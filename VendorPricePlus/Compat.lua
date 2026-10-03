-- VendorPricePlus client/API compatibility layer
--
-- Keep differences between WoW client API surfaces here so feature code can
-- remain client-agnostic. Prefer capability detection over project IDs.

VendorPricePlus = VendorPricePlus or {}
local VP = VendorPricePlus

VP.Compat = VP.Compat or {}
local Compat = VP.Compat

function Compat.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(item)
    end

    if GetItemInfo then
        return GetItemInfo(item)
    end
end

function Compat.GetContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        return C_Container.GetContainerItemInfo(bag, slot)
    end

    if GetContainerItemInfo then
        local texture, stackCount, locked, quality, readable, lootable, itemLink,
              isFiltered, noValue, itemID, isBound = GetContainerItemInfo(bag, slot)

        if texture then
            return {
                iconFileID = texture,
                stackCount = stackCount,
                isLocked = locked,
                quality = quality,
                isReadable = readable,
                hasLoot = lootable,
                hyperlink = itemLink,
                isFiltered = isFiltered,
                hasNoValue = noValue,
                itemID = itemID,
                isBound = isBound,
            }
        end
    end
end

function Compat.IsAddOnLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(addonName)
    end

    return false
end

-- WoW Forever currently reports the Mainline project ID, so do not use
-- WOW_PROJECT_ID alone to distinguish it from Retail. Its interface generation
-- is 16000-series (currently 16001), while Retail is not.
function Compat.IsForever()
    local interfaceVersion = select(4, GetBuildInfo())
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
        and type(interfaceVersion) == "number"
        and interfaceVersion >= 16000
        and interfaceVersion < 17000
end

-- Secret values (Classic 1.15.9, TBC 2.5.6, Mists 5.5.4, Forever, Retail 12.0)
-- can be stored and passed through addon code, but tainted code cannot
-- compare or do arithmetic on them. issecretvalue/canaccessvalue are the
-- supported checks. Older clients do not define them; every number is usable.
function Compat.CanAccessValue(value)
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        return ok and allowed and true or false
    end

    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and not secret
    end

    return value ~= nil
end

function Compat.CanAccessNumber(value)
    return type(value) == "number" and Compat.CanAccessValue(value)
end

-- Bag totals are not part of the action-count secret. includeUses matches
-- GetActionCount() for charged items (healthstones and similar); potions
-- still return the number of items in the bags.
function Compat.GetItemCount(item)
    if not Compat.CanAccessValue(item) then
        return nil
    end
    if item == nil then
        return nil
    end

    local itemInfo = item
    if type(item) == "string" then
        local id = item:match("item:(%d+)")
        if id then
            itemInfo = tonumber(id)
        end
    end

    local getter = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(getter) ~= "function" then
        return nil
    end

    local ok, count = pcall(getter, itemInfo, false, true)
    if ok then
        return count
    end
end

-- Action-bar counts from GetActionCount() are secret in combat. For an item
-- action that secret is the usable inventory count, so recover it from
-- GetItemCount(). Any other secret count (one bag slot, one mail stack) must
-- not be replaced with the bag total; callers then show the unit price only.
function Compat.ResolveStackCount(count, item, recoverFromInventory)
    if Compat.CanAccessNumber(count) then
        return count
    end

    if recoverFromInventory then
        local bagCount = Compat.GetItemCount(item)
        if Compat.CanAccessNumber(bagCount) then
            return bagCount
        end
    end

    return 1
end
