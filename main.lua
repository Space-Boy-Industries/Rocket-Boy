local bump = require "lib/bump";
json = require "lib/json";
local animation = require "lib/animation";

local drawHitboxes = true

local game = {
    baseGravity = 0.4,
    jumpGravity = 0.2,
    
    gravity = nil,
    mode = "game",
    bumpWorld = nil,
    currentSong = {
        fp = nil, -- file path of the song
        source = nil, -- the Source object
    }, 
    scene = {
        meta = {
            name = nil, -- name of the scene
            start = {x = 0, y = 0}, -- player starting position
            song = nil -- file path of music for this scene
        },
        collision = nil, -- the collision rectangles
        background = nil, -- background image
        foreground = nil, -- foreground image
        objects = nil, -- table containing moving/interactible objects
        scale = 0.3
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
    maxSpeed = {x = 4, y = 10},
    slidingSpeed = {up = 5, down = 2},
    groundAcceleration = 0.4,
    airAcceleration = 0.2,
    groundDeceleration = 0.5,
    airDeceleration = 0.1,
    jumpVelocity = 5,
    doubleJumpVelocity = 4,
    wallJumpAngle = {x = 0.6, y = 0.7},
    slidingGracePeriod = 10,
    scale = 0.4,

    width = 0,
    height = 0,
    position = {x = 320, y = 100},
    speed = {x = 0, y = 0},
    moving = false,
    isGrounded = true,
    doubleJump = true,
    slidingTime = 0,
    slidingSide = 0,

    get_rect = function(self)
        return {self.position.x, self.position.y, self.position.x + self.width, self.position.y + self.height}
    end,
}

local noWallSlide = {
    ["1-0"] = {["3"] = true}
}

function move(dt, dir)
    local accelConstant = player.isGrounded and player.groundAcceleration or player.airAcceleration
    player.speed.x = player.speed.x + dir * accelConstant, player.maxSpeed.x
    player.moving = true;
end

function jump()
    if player.isGrounded then
        player.speed.y = 0 - player.jumpVelocity
        game.gravity = game.jumpGravity
    elseif player.slidingTime > 0 then
        player.speed.y = 0 - player.jumpVelocity * player.wallJumpAngle.y
        player.speed.x = player.slidingSide * player.jumpVelocity * player.wallJumpAngle.x
        game.gravity = game.jumpGravity
    elseif player.doubleJump then
        player.speed.y = 0 - player.doubleJumpVelocity
        player.doubleJump = false
        game.gravity = game.jumpGravity
    end
end

function loadScene(name)
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
    game.currentSong.fp = game.scene.meta.song
    game.currentSong.source = love.audio.newSource("assets/sound/music/" .. game.currentSong.fp, "stream")
    game.currentSong.source:setLooping(true)
    game.currentSong.source:play()
end

function initPlayer()
    player["animation"] = animation.createAnimationController("player");
    player.animation.state = "idle";
    player.width = player.animation.meta.width * player.scale;
    player.height = player.animation.meta.width * player.scale;
end

function love.load()
    game.gravity = game.baseGravity
    initPlayer();
    loadScene("1-0");
end

function love.update(dt)

    for key, actions in pairs(controls[game.mode]) do
        if actions.hold ~= nil and love.keyboard.isDown(key) then
            actions.hold(dt)
        end
    end

    player.speed.y = player.speed.y + game.gravity

    if math.abs(player.speed.x) > player.maxSpeed.x then
        player.speed.x = player.maxSpeed.x * (player.speed.x > 0 and 1 or -1)
    end
    if player.slidingTime >= player.slidingGracePeriod - 1 then
        if player.speed.y > player.slidingSpeed.down then
            player.speed.y = player.slidingSpeed.down
        elseif player.speed.y < 0 - player.slidingSpeed.up then
            player.speed.y = 0 - player.slidingSpeed.up
        end
    else
        if math.abs(player.speed.y) > player.maxSpeed.y then
            player.speed.y = player.maxSpeed.y * (player.speed.y > 0 and 1 or -1)
        end
    end

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
    for i = 1, len do
        local col = cols[i]
        if col.normal.y == -1 then
            player.isGrounded = true
            player.doubleJump = true
        end
        
        if col.normal.x ~= 0 then
            player.speed.x = 0
            if noWallSlide[game.scene.name] and noWallSlide[game.scene.name][col.other] then
                player.slidingSide = col.normal.x
                player.slidingTime = player.slidingGracePeriod
            end
        end
        if col.normal.y ~= 0 then
            player.speed.y = 0
        end
    end

    if player.isGrounded then
        player.sliding = false
    end

    if player.slidingTime > 0 then
        player.slidingTime = player.slidingTime - 1
    end

    if player.isGrounded then
        if player.moving then
            if player.speed.x > 0 then
                player.animation.state = "walkright";
            else
                player.animation.state = "walkleft";
            end
        else
            player.animation.state = "idle";
        end
    else
        if player.speed.y > 0 then
            player.animation.state = "fall";
        else
            if player.doubleJump then
                player.animation.state = "jump";
            else
                player.animation.state = "doublejump";
            end
        end
    end

    animation.updateController(player["animation"], dt);

    player.moving = false
end

function love.draw()
    love.graphics.setColor(255,255, 255);
    love.graphics.draw(game.scene.background, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
    love.graphics.draw(game.scene.foreground, 1, 1, 0, game.scene.meta.scale, game.scene.meta.scale);
    love.graphics.draw(animation.getControllerSprite(player.animation), player.position.x, player.position.y, 0, player.scale, player.scale);
    love.graphics.setColor(255, 0, 0)
    if drawHitboxes then
        local pRect = player:get_rect()
        love.graphics.rectangle("line", pRect[1], pRect[2], pRect[3]-pRect[1], pRect[4]-pRect[2])
        for i, rect in ipairs(game.scene.collision) do
            love.graphics.rectangle("line", rect[1] * game.scene.meta.scale, rect[2] * game.scene.meta.scale, (rect[3] * game.scene.meta.scale)-(rect[1] * game.scene.meta.scale), (rect[4] * game.scene.meta.scale)-(rect[2] * game.scene.meta.scale))
            love.graphics.print(i + 1, (rect[1] + 4) * game.scene.meta.scale, (rect[2] + 2) * game.scene.meta.scale )
        end
    end
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
