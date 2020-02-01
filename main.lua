local controls = {
    game = {
        a = {hold = function(dt) move(dt, -1) end},
        d = {hold = function(dt) move(dt, 1) end},
        space = {down = function(dt) jump(true) end, up = function(dt) jump(false) end}
    },
    cutscene = {
        escape = skip_cutscene
    },
    menu = {
        
    }
}

local player = {
    maxSpeed = {x = 5, y = 10},
    acceleration = 0.2,
    jumpVelocity = 2,
    jumpTime = 10,
    doubleJumpVelocity = 1.5,
    doubleJumpTime = 5,

    x = 0,
    y = 0,
    speed = {x = 0, y = 0},
    isGrounded = true,

    get_rect = function(self)
        return {self.x - 10, self.y, self.x + 10, self.y + 30}
    end
}

local game = {
    baseGravity = 1,
    jumpGravity = 0.5,
    
    gravity = baseGravity,
    mode = "game",
    scene = {
        name = nil, -- name of the scene
        collision = nil, -- the collision rectangles
        background = nil, -- background image
        foreground = nil, -- foreground image
        objects = nil -- table containing moving/interactible objects
    }
}

local animation = require "lib/animation";

local test = nil;

function rects_collide(rect1, rect2)
    return not (rect1[1] < rect2.[3] && rect1[3] > rect2[1] &&
    rect1[2] < rect2[4] && rect1[4] > rect2[2]) 
end

function move(dt, dir)
    player.speed.x + dir
end

function jump(start)
    if start and player.isGrounded then
        player.speed.y = player.speed.y - player.jumpVelocity
        game.gravity = game.jumpGravity
    else
        game.gravity = game.baseGravity
    end
end

function love.load()
    test = animation.loadAnimation("test");
end

function love.update(dt)
    for key, actions in pairs(controls[game.scene]) do
        if actions.hold ~= nil and love.keyboard.isDown(key) then
            action(dt)
        end
    end

    player.speed.y = player.speed.y + game.gravity

    player.x = player.x + player.speed.x
    player.y = player.y + player.speed.y
    local playerRect = player:get_rect()
    for i, rect in pairs(game.scene.collision) do
        if rects_collide(rect, playerRect) then
            
        end

    if test ~= nil then
        test = animation.updateAnimation(test, dt);
    end
end

function love.draw()
    local frame = test["frame"];
    love.graphics.draw(test["frames"][frame], 1, 1, 0, 0.5, 0.5);
end

function love.keypressed(key)
end

function love.keyreleased(key)
end
