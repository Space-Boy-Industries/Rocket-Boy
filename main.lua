local bump = require "lib/bump";
json = require "lib/json";
local animation = require "lib/animation";
local testAnimation = nil;

local game = {
    baseGravity = 0.4,
    jumpGravity = 0.2,
    
    gravity = nil,
    mode = "game",
    bumpWorld = nil,
    scene = {
        name = nil, -- name of the scene
        collision = {}, -- the collision rectangles
        background = nil, -- background image
        foreground = nil, -- foreground image
        objects = nil, -- table containing moving/interactible objects
        scale = 0.3;
    }
}

local controls = {
    game = {
        a = {hold = function(dt) 
            move(dt, -1);
        end},
        d = {hold = function(dt) move(dt, 1) end},
        space = {down = function() jump() end, up = function() game.gravity = game.baseGravity end}
    },
    cutscene = {
        escape = skip_cutscene
    },
    menu = {
        
    }
}

local player = {
    maxSpeed = {x = 4, y = 7},
    groundAcceleration = 0.4,
    airAcceleration = 0.2,
    groundDeceleration = 0.5,
    airDeceleration = 0.1,
    jumpVelocity = 5,
    doubleJumpVelocity = 4,

    position = {x = 320, y = 100},
    speed = {x = 0, y = 0},
    moving = false,
    isGrounded = true,
    doubleJump = true,
    sliding = false,

    get_rect = function(self)
        return {self.position.x, self.position.y, self.position.x + 20, self.position.y + 30}
    end
}

-- returns true if rect1 and rect2 collide
function rects_collide(rect1, rect2)
    return not (rect1[1] > rect2[3] or rect1[3] < rect2[1] or rect1[2] > rect2[4] or rect1[4] < rect2[2]) 
end

-- tells you how to adjust position of rect1 to stop colliding with rect2
function resolve_collision(rect1, rect2)
    local dists = {rect2[1] - rect1[3], rect2[3] - rect1[1], rect2[2] - rect1[4], rect2[4] - rect1[2]}
    local shortest = nil
    local adjust = nil
    for i, dist in ipairs(dists) do
        if shortest == nil or math.abs(dist) < shortest then
            shortest = math.abs(dist)
            adjust = {i < 3 and "x" or "y", dist}
        end
    end

    return adjust[1], adjust[2]
end

function move(dt, dir)
    local accelConstant = player.isGrounded and player.groundAcceleration or player.airAcceleration
    player.speed.x = player.speed.x + dir * accelConstant, player.maxSpeed.x
        if math.abs(player.speed.x) > player.maxSpeed.x then
            player.speed.x = player.maxSpeed.x * (player.speed.x > 0 and 1 or -1)
        end
    player.moving = true
end

function jump()
    if player.isGrounded then
        player.speed.y = 0 - player.jumpVelocity
        game.gravity = game.jumpGravity
    elseif player.doubleJump then
        player.speed.y = 0 - player.doubleJumpVelocity
        player.doubleJump = false
        game.gravity = game.jumpGravity
    end
end

function loadScene(name)
    -- TODO: load level data into game.scene
    local rawMeta = love.filesystem.read("assets/scenes/" .. name .. "/meta.json");
    local rawCollisions = love.filesystem.read("assets/scenes/" .. name .. "/collision.json");
    local rawObjects = love.filesystem.read("assets/scenes/" .. name .. "/object.json");
    game.scene["meta"] = json.decode(rawMeta);
    game.scene["collision"] = json.decode(rawCollisions);
    game.scene["objects"] = json.decode(rawObjects);
    game.scene["background"] = love.graphics.newImage("assets/scenes/" .. name .. "/background.png")
    game.scene["foreground"] = love.graphics.newImage("assets/scenes/" .. name .. "/foreground.png")
    game.bumpWorld = bump.newWorld()
    player.position.x = game.scene.meta.start.x * game.scene.meta.scale;
    player.position.y = game.scene.meta.start.y * game.scene.meta.scale;
    pRect = player:get_rect()
    game.bumpWorld:add("player", pRect[1], pRect[2], pRect[3]-pRect[1], pRect[4]-pRect[2])
    for i, rect in ipairs(game.scene.collision) do
        game.bumpWorld:add(i .. "", rect[1] * game.scene.meta.scale, rect[2] * game.scene.meta.scale, (rect[3] * game.scene.meta.scale)-(rect[1] * game.scene.meta.scale), (rect[4] * game.scene.meta.scale)-(rect[2] * game.scene.meta.scale))
    end
end

function love.load()
    game.gravity = game.baseGravity
    loadScene("test")
    testAnimation = animation.createAnimationController("player");
end

function love.update(dt)
    for key, actions in pairs(controls[game.mode]) do
        if actions.hold ~= nil and love.keyboard.isDown(key) then
            actions.hold(dt)
        end
    end

    player.speed.y = player.speed.y + game.gravity

    player.position.x = player.position.x + player.speed.x * dt * 100
    player.position.y = player.position.y + player.speed.y * dt * 100

    if player.speed.y > 0 then 
        game.gravity = game.baseGravity
    end

    if not player.moving then
        local decelConstant = player.isGrounded and player.groundDeceleration or player.airDeceleration
        player.speed.x = player.speed.x + decelConstant * (player.speed.x > 0 and -1 or 1)
        if math.abs(player.speed.x) < decelConstant * 1.5 then
            player.speed.x = 0
        end
    end

    local actualX, actualY, cols, len = game.bumpWorld:move("player", player.position.x, player.position.y)

    player.position.x = actualX
    player.position.y = actualY

    player.isGrounded = false
    player.sliding = false
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then
            player.isGrounded = true
            player.doubleJump = true
        end
        
        if col.normal.x ~= 0 then
            player.speed.x = 0
            player.sliding = true
        end
        if col.normal.y ~= 0 then
            player.speed.y = 0
        end
    end

    player.sliding = player.sliding and not player.isGrounded
    player.moving = false

    animation.updateController(testAnimation, dt);
end

function love.draw()
    for i, rect in ipairs(game.scene.collision) do
        love.graphics.rectangle("fill", rect[1], rect[2], rect[3]-rect[1], rect[4]-rect[2])
    end

    love.graphics.draw(game.scene.background, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
    love.graphics.draw(game.scene.foreground, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
    local pRect = player:get_rect()
    love.graphics.rectangle("fill", pRect[1], pRect[2], pRect[3]-pRect[1], pRect[4]-pRect[2])
    love.graphics.print("", 0, 0)
end

function love.keypressed(key)
    local actions = controls[game.mode][key]
    if actions ~= nil and actions.down ~= nil then
        actions.down()
    end
end

function love.keyreleased(key)
    local actions = controls[game.mode][key]
    if actions ~= nil and actions.up ~= nil then
        actions.up()
    end
end
