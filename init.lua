-- basket_cooking/init.lua
-- Cook all stuffs inside a basket with electric furnaces
-- Copyright (c) 2025  1F616EMO
-- SPDX-License-Identifier: LGPL-2.0-or-later

local core, technic, basket, fakelib = core, technic, basket, fakelib

local basket_recipe_cache = {}
local basket_recipe_scheduled = {}

local function generate_recipe_of_basket(basket_item)
    local basket_data = basket.get_basket_from_item(basket_item)
    if not basket_data then return nil end

    local basket_inv = basket_data.items
    local new_basket_inv = fakelib.create_inventory({ main = #basket_inv })
    local time = 0

    for i = 1, #basket_inv do
        local source_stack = ItemStack(basket_inv[i])
        while not source_stack:is_empty() do
            local this_recipe = technic.get_recipe("cooking", { source_stack })
            if not this_recipe or #this_recipe.new_input > 1 then
                return nil
            end

            for _, output in ipairs(this_recipe.output) do
                if not new_basket_inv:room_for_item("main", output) then
                    return nil
                end
                new_basket_inv:add_item("main", output)
            end

            source_stack = this_recipe.new_input[1]
            time = time + this_recipe.time
        end
    end

    local new_basket = basket.get_basket_itemstack({
        description = "",
        items = new_basket_inv:get_list("main"),
    })

    return {
        time = time,
        new_input = { ItemStack() },
        output = { new_basket },
    }
end

local function get_recipe_of_basket(basket_item)
    local basket_meta = basket_item:get_meta()
    local basket_inv_string = basket_meta:get_string("inv")

    if basket_recipe_cache[basket_inv_string] then
        basket_recipe_cache[basket_inv_string][2] = os.time()
        return basket_recipe_cache[basket_inv_string][1]
    end

    if basket_recipe_scheduled[basket_inv_string] then
        return false
    end

    basket_recipe_scheduled[basket_inv_string] = true
    core.after(0, function()
        local recipe = generate_recipe_of_basket(basket_item)
        basket_recipe_cache[basket_inv_string] = { recipe, os.time() }
        basket_recipe_scheduled[basket_inv_string] = nil
    end)
    return false
end

do
    local function cleanloop()
        local now = os.time()
        for k, v in pairs(basket_recipe_cache) do
            if now - v[2] > 30 then
                basket_recipe_cache[k] = nil
            end
        end
        core.after(15, cleanloop)
    end
    core.after(5, cleanloop)
end

local old_get_recipe = technic.get_recipe

function technic.get_recipe(method, items) -- luacheck: ignore
    if method == "cooking" and #items == 1 and items[1]:get_name() == "basket:basket" then
        -- Try to run through all items in the basket and smelt all of them
        -- Fail if any cannot be smelt, otherwise sum up the time needed and construct a new basket

        local basket_item = items[1]
        local recipe = get_recipe_of_basket(basket_item)
        if recipe == false then
            return nil
        elseif recipe == nil then
            return old_get_recipe(method, items)
        else
            return recipe
        end
    end

    return old_get_recipe(method, items)
end
