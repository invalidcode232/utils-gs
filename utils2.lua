--[[
    Utils
    Commonly used utilities for GameSense LUA API

    Author: invalidcode#7810
]]--

-- Dependencies
local vector = require 'vector'

local found, ref = pcall(require, 'gamesense/ref_lib')
if not found then
    error('ref_lib not found')
end

local found, csgo_weapons = pcall(require, 'gamesense/csgo_weapons')
if not found then
    error('csgo_weapons not found')
end

local utils = { }

utils.enums = { }
utils.misc = { }
utils.entity = { }
utils.renderer = { }

-- List of throwable classnames
local THROWABLES = {
    'CMolotovGrenade',
    'CHEGrenade',
    'CFlashbang',
    'CDecoyGrenade',
    'CSmokeGrenade',
    'CIncendiaryGrenade',
}

-- Player state strings for get_pstate
utils.enums.PLAYER_STATES = {
    ['Standing'] = 'stand',
    ['Crouching'] = 'crouch',
    ['Slowwalk'] = 'slow',
    ['Air'] = 'air',
    ['Moving'] = 'move',
}

utils.enums.HITBOX = {
    ['Generic'] = 0,
    ['Head'] = 1,
    ['Chest'] = 2,
    ['Stomach'] = 3,
    ['Pelvis'] = 4,
    ['Left Arm'] = 5,
    ['Right Arm'] = 6,
    ['Left Leg'] = 7,
    ['Right Leg'] = 8,
}

---Checks if a value is in a table
---@param t void
---@param index number
---@return boolean, number
utils.misc.contains = function (t, index)
    for i, v in pairs(t) do
        if v == index then
            return true, i
        end
    end
    return false, -1
end

---Converts a table to a vector
---@param table table
---@return Vector
utils.misc.vectorize = function (table)
    return vector(table[1], table[2], table[3])
end

---Gets eye position
---@param ent number
---@return Vector
function utils.entity.eye_pos(ent)
    return ent == entity.get_local_player(ent) and utils.misc.vectorize({ client.eye_position() }) or utils.misc.vectorize({ entity.hitbox_position(ent, utils.enums.HITBOX.Head) })
end

---Extrapolates player position
---@param ent number
---@param ticks number
---@return Vector
utils.entity.extrapolate = function (ent, ticks)
    local m_vecVelocity = utils.misc.vectorize({ entity.get_prop(ent, 'm_vecVelocity') })
    local extrapolated_pos = m_vecVelocity

    for i = 0, ticks do
        extrapolated_pos = extrapolated_pos + (m_vecVelocity * globals.tickinterval())
    end

    return extrapolated_pos
end

---Gets distance between two entities
---@param ent1 number
---@param ent2 number
---@return number
utils.entity.ent_dist = function (ent1, ent2)
    local pos1 = utils.misc.vectorize({ entity.get_origin(ent1) })
    local pos2 = utils.misc.vectorize({ entity.get_origin(ent2) })

    return pos1:dist(pos2)
end

---Gets predicted bullet damage
---@param shooter number
---@param victim number
---@param hb number
---@param ticks number
---@return number
utils.entity.get_damage = function (shooter, victim, hb, ticks)
    local eye_pos = utils.entity.eye_pos(ent1)

    if ticks then
        eye_pos = utils.entity.extrapolate(ent1, ticks)
    end

    local hitbox_pos = utils.misc.vectorize({ entity.hitbox_position(ent2, hb) })

    local _, damage = client.trace_bullet(ent1, eye_pos.x, eye_pos.y, eye_pos.z, hitbox_pos.x, hitbox_pos.y, hitbox_pos.z)

    return damage
end

---Checks if an entity is crouching
---@param ent number
---@return boolean
utils.entity.is_crouching = function (ent)
    local flags = entity.get_prop(ent, 'm_fFlags')

    return bit.band(flags, 4) == 4
end

---Check if an entity is in air
---@param ent number
---@return boolean
utils.entity.is_in_air = function (ent)
    local flags = entity.get_prop(ent, 'm_fFlags')

    return bit.band(flags, 1) ~= 1
end

---Gets an entity's velocity
---@param ent number
---@return number
utils.entity.get_velocity = function (ent)
    local vel = utils.misc.vectorize({ entity.get_prop(ent, 'm_vecVelocity') })

    return math.sqrt(vel.x^2 + vel.y^2)
end

---Gets an entity's current movement state
---@param ent number
---@return string
utils.entity.get_pstate = function (ent)
    local velocity = utils.entity.get_velocity(ent)

    local state = 'stand'

    if utils.entity.is_crouching(ent) then
        state = utils.enums.PLAYER_STATES['Crouching']
    elseif utils.entity.is_in_air(ent) then
        state = utils.enums.PLAYER_STATES['Air']
    elseif velocity > 0.1 then
        state = utils.enums.PLAYER_STATES['Moving']
    elseif (ui.get(ref.antiaim_other.slow_motion[1]) and ui.get(ref.antiaim_other.slow_motion[2])) then
        state = utils.enums.PLAYER_STATES['Slowwalk']
    else
        state = utils.enums.PLAYER_STATES['Standing']
    end
end

---Check if a weapon is a throwable
---@param ent number
---@return boolean
utils.entity.is_throwable = function (ent)
    local classname = entity.get_classname(ent)

    return utils.misc.contains(THROWABLES, classname)
end

---Get maximum player speed
---@param ent number
---@param wpn number
---@return number
utils.entity.get_max_speed = function (ent, wpn)
    if not entity.is_alive(ent) or wpn == nil then
        return nil
    end

    local data = csgo_weapons(wpn)

    if not data then
        return nil
    end

    local m_bScoped = entity.get_prop(ent, 'm_bIsScoped') == 1
    local m_zoomLevel = entity.get_prop(wpn, 'm_zoomLevel') or 0
    local m_bResumeZoom = entity.get_prop(ent, 'm_bResumeZoom') == 1

    if m_bScoped and m_zoomLevel > 0 and not m_bResumeZoom then
        return data.max_player_speed_alt
    end

    return data.max_player_speed
end

---Renders a multicolored string
---@param x number
---@param y number
---@param flags string
---@param centered boolean
---@param spacing number
---@param data table
---@return void
utils.renderer.multicolored_text = function (x, y, flags, centered, spacing, data)
    local total_width = 0

    if centered then
        for _, v in pairs(data) do
            local text_width = renderer.measure_text(flags, v.text)
            total_width = total_width + text_width + spacing
        end
    end

    local used_width = 0

    for _, v in pairs(data) do
        local text = v.text
        local clr = v.clr

        local text_width = renderer.measure_text(flags, text)
        local cur_x = centered and (x - total_width / 2 + used_width) or x + used_width

        renderer.text(cur_x, y, clr[1], clr[2], clr[3], clr[4], flags, nil, text)

        used_width = used_width + text_width + spacing
    end
end

---Animates from 0 to 1 to 0
---@param speed number
---@return number
utils.renderer.anim = function (speed)
    return math.sin(math.abs(-math.pi + (globals.curtime() * speed) % (math.pi * 2)))
end

---Sets the visibility of all the elements in a table
---@param table table
---@param visible boolean
---@return void
utils.misc.table_visible = function (table, visible)
    for k in pairs(table) do
        local reference = table[k]
        if type(reference) == 'table' then
            for j in pairs(reference) do
                ui.set_visible(reference[j], visible)
            end
        else
            ui.set_visible(reference, visible)
        end
    end
end

return utils
