local animation = require "lib/animation";

local test = nil;

function love.load()
    test = animation.loadAnimation("test");
end

function love.update(dt)
    if test ~= nil then
        test = animation.updateAnimation(test, dt);
    end
end

function love.draw()
    local frame = test["frame"];
    love.graphics.draw(test["frames"][frame], 1, 1, 0, 0.5, 0.5);
end