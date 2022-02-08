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
local PLAYER_STATES = {
    ['Standing'] = 'stand',
    ['Crouching'] = 'crouch',
    ['Slowwalk'] = 'slow',
    ['Air'] = 'air',
    ['Moving'] = 'move',
}

local utils = {}

---contains
---@param t void
---@param index number
function utils:contains(t, index)
    for i, v in pairs(t) do
        if v == index then
            return true, i
        end
    end
    return false, -1
end

utils.HITBOX = {
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

---vectorize
---@param table table
---@return Vector
function utils:vectorize(table)
    return vector(table[1], table[2], table[3])
end

---eye_pos
---@param ent number
---@return Vector
function utils:eye_pos(ent)
    return ent == entity.get_local_player(ent) and self:vectorize({ client.eye_position() }) or self:vectorize({ entity.hitbox_position(ent, self.HITBOX.Head) })
end

---extrapolate
---@param ent1 number
---@param ent2 number
---@param hb number
---@return Vector
function utils:extrapolate(ent, ticks)
    local m_vecVelocity = self:vectorize({ entity.get_prop(ent, 'm_vecVelocity') })
    local extrapolated_pos = m_vecVelocity

    for i = 0, ticks do
        extrapolated_pos = extrapolated_pos + (m_vecVelocity * globals.tickinterval())
    end

    return extrapolated_pos
end

---@param ent1 number
---@param ent2 number
---@return number
function utils:ent_dist(ent1, ent2)
    local pos1 = { entity.get_origin(ent1) }
    pos1 = vector(pos1[1], pos1[2], pos1[3])

    local pos2 = { entity.get_origin(ent2) }
    pos2 = vector(pos2[1], pos2[2], pos2[3])

    return pos1:dist(pos2)
end

---get_damage
---@param shooter number
---@param victim number
---@param hb number
---@return number
function utils:get_damage(shooter, victim, hb, ticks)
    local eye_pos = self:eye_pos(ent1)

    if ticks then
        eye_pos = self:extrapolate(ent1, ticks)
    end

    local hitbox_pos = self:vectorize({ entity.hitbox_position(ent2, hb) })

    local _, damage = client.trace_bullet(ent1, eye_pos.x, eye_pos.y, eye_pos.z, hitbox_pos.x, hitbox_pos.y, hitbox_pos.z)

    return damage
end

---is_crouching
---@param ent number
---@return boolean
function utils:is_crouching(ent)
    local flags = entity.get_prop(ent, 'm_fFlags')

    return bit.band(flags, 4) == 4
end

---is_in_air
---@param ent number
---@return boolean
function utils:is_in_air(ent)
    local flags = entity.get_prop(ent, 'm_fFlags')

    return bit.band(flags, 1) ~= 1
end

---get_velocity
---@param ent number
---@return number
function utils:get_velocity(ent)
    local vel = entity.get_prop(ent, 'm_vecVelocity')

    return math.sqrt(vel[1]^2 + vel[2]^2)
end

---get_pstate
---@param ent number
---@return string
function utils:get_pstate(ent)
    local velocity = self:get_velocity(ent)

    local state = 'stand'

    if self:is_crouching(ent) then
        state = PLAYER_STATES['Crouching']
    elseif self:is_in_air(ent) then
        state = PLAYER_STATES['Air']
    elseif velocity > 0.1 then
        state = PLAYER_STATES['Moving']
    elseif (ui.get(ref.antiaim_other.slow_motion[1]) and ui.get(ref.antiaim_other.slow_motion[2])) then
        state = PLAYER_STATES['Slowwalk']
    else
        state = PLAYER_STATES['Standing']
    end
end

---is_throwable
---@param ent number
---@return boolean
function utils:is_throwable(ent)
    local classname = entity.get_classname(ent)

    return self:contains(THROWABLES, classname)
end

---get_max_speed
---@param ent number
---@param wpn number
---@return number
function utils:get_max_speed(ent, wpn)
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

---multicolored_text
---@param x number
---@param y number
---@param flags string
---@param centered boolean
---@param spacing number
---@param data table
---@return void
function utils:multicolored_text(x, y, flags, centered, spacing, data)
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

return utils
