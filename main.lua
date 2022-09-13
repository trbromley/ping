-- From here: https://github.com/Ulydev/push
local push = require "push"
require "class"

boxThickness = 4

leftBorder = 4
rightBorder = 4
topBorder = 30
bottomBorder = 10

width = 400
height = 210

paddleHeight = boxThickness
paddleWidth = 20
paddleSpeed = 100

puckSize = 6
speedMultiplier = 1.03
puckInitialSpeed = 70

scoreSize = 25
fontSize = 20
titleSize = 50

timer = 0

gameWidth = width + leftBorder + rightBorder + 2 * boxThickness
gameHeight = height + topBorder + bottomBorder + 2 * boxThickness

textHeight = topBorder + boxThickness + height / 6

menuState = 1
maxScore = 5

local windowWidth, windowHeight = love.window.getDesktopDimensions()
windowWidth = 0.7 * windowWidth
windowHeight = 0.7 * windowHeight

Box = class()


function Box:init(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height

    self.startX = x
    self.startY = y
end

function Box:draw()
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
end


function Box:reset()
    self.x = self.startX
    self.y = self.startY
end


MovableBoxX = Box:extend()

function MovableBoxX:init(x, y, width, height, minX, maxX, speedX, buttonLeft, buttonRight)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.minX = minX
    self.maxX = maxX
    self.speedX = speedX

    self.startX = x
    self.startY = y

    self.buttonLeft = buttonLeft
    self.buttonRight = buttonRight
end


function MovableBoxX:update(dt)
    if (self == rightPaddle or self == rightPaddleUpper) and menuState == 1 then
        if puck.y < rightPaddleUpper.y and puck.x > gameWidth / 2 and math.abs(puck.x - (self.x + self.width / 2)) < 100 then
            if puck.x < (self.x + self.width / 2) then
                targetX = puck.x - 10
            else
                targetX = puck.x + 10
            end
        else
            targetX = estimateX(puck) - rightPaddle.width / 2
        end

        targetX = targetX + overshoot

        if math.abs(targetX - self.x) > 5 then
            if targetX < self.x then
                self.x = self.x - self.speedX * dt
            else
                self.x = self.x + self.speedX * dt
            end
        end
    else
        if love.keyboard.isDown(self.buttonLeft) then
            self.x = self.x - self.speedX * dt
        end
            if love.keyboard.isDown(self.buttonRight) then
            self.x = self.x + self.speedX * dt
        end
    end
    if self.x < self.minX then
        self.x = self.minX
    end
    if self.x > self.maxX then
        self.x = self.maxX
    end
end


MovingBox = Box:extend()

function MovingBox:init(x, y, width, height, minX, maxX, minY, maxY, speedX, speedY, avoid)
    self.x = x
    self.y = y
    self.width = width
    self.height = height

    self.minX = minX
    self.maxX = maxX
    self.minY = minY
    self.maxY = maxY

    directionX = math.random(0, 1) == 1 and 1 or -1
    directionY = math.random(0, 1) == 1 and 1 or -1

    self.startSpeedX = speedX
    self.startSpeedY = speedY

    self.speedX = speedX * directionX
    self.speedY = speedY * directionY

    self.startX = x
    self.startY = y

    self.avoid = avoid
end


function MovingBox:reset()
    self.x = self.startX
    self.y = self.startY

    directionX = math.random(0, 1) == 1 and 1 or -1
    directionY = math.random(0, 1) == 1 and 1 or -1

    self.speedX = self.startSpeedX * directionX
    self.speedY = self.startSpeedY * directionY
end


function solve(x1, x2, y1, y2, u1, u2, v1, v2)
    res = ((x2 - x1) * v2 - u2 * (y2 - y1)) / (u1 * v2 - u2 * v1)
    if res < 0 then
        return 2 -- only [0, 1] is valid
    end
    return res
end


function whereCollided(x1, y1, u1, v1, obj2)
    optimalRoot = 2
    optimalRootIndex = -1

    -- Left side
    x2 = obj2.x
    y2 = obj2.y

    u2 = 0
    v2 = obj2.height

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 1
    end

    -- Top side
    x2 = obj2.x
    y2 = obj2.y

    u2 = obj2.width
    v2 = 0

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 2
    end

    -- Right side
    x2 = obj2.x + obj2.width
    y2 = obj2.y

    u2 = 0
    v2 = obj2.height

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 3
    end

    -- Bottom side
    x2 = obj2.x
    y2 = obj2.y + obj2.height

    u2 = obj2.width
    v2 = 0

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 4
    end

    return optimalRootIndex, optimalRoot
end


function estimateX(puck)
    if gameState == "ready" or gameState == "score1" or gameState == "score2" or gameState == "begin" or gameState == "win1" or "gameState" == "win2" then
        return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2
    end

    x1 = puck.x
    y1 = puck.y

    u1 = puck.speedX
    v1 = puck.speedY

    x1, y1, u1, v1, indx = findCrossover(x1, y1, u1, v1)

    if x1 == -1000 then
        return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2
    end

    if indx == 5 then
        if x1 < midBox.x then
            return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2
        end
        return x1
    end

    keepGoing = true
    ctr = 1
    ctrMax = 3

    while keepGoing do
        x1, y1, u1, v1, indx = findCrossover(x1, y1, u1, v1)

        if indx == 5 or x1 == -1000 then
            keepGoing = False
        end
        ctr = ctr + 1

        if ctr > ctrMax then
            keepGoing = false
        end
    end

    if x1 == -1000 then
        return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2
    end

    if indx == 5 then
        if x1 < midBox.x then
            return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2
        end
        return x1
    end
    return gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2

end

--uncertainty = 1

function findCrossover(x1, y1, u1, v1)
    optimalRoot = 2
    optimalRootIndex = -1

    --r1 = (math.random() - 0.5) / uncertainty + 1
    --r2 = (math.random() - 0.5) / uncertainty + 1
    r1 = 1
    r2 = 1

    u1Original = u1 * r1
    v1Original = v1 * r2

    -- 1000 just makes the diff vector bigger, giving it a chance to cross the bounding edges
    u1 = 1000 * u1 * r1
    v1 = 1000 * v1 * r2

    -- Left side
    x2 = leftBox.x
    y2 = leftBox.y

    u2 = 0
    v2 = leftBox.height

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 1
    end

    -- Top side
    x2 = topBox.x
    y2 = topBox.y

    u2 = topBox.width
    v2 = 0

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 2
    end

    -- Right side
    x2 = rightBox.x
    y2 = rightBox.y

    u2 = 0
    v2 = rightBox.height

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 3
    end

    -- Middle
    x2 = midBox.x
    y2 = midBox.y

    u2 = 0
    v2 = midBox.height

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 4
    end

    -- Bottom
    x2 = leftBox.x
    y2 = leftBox.y + leftBox.height

    u2 = topBox.width
    v2 = 0

    rootA = solve(x1, x2, y1, y2, u1, u2, v1, v2)
    rootB = solve(x2, x1, y2, y1, u2, u1, v2, v1)

    if rootA <= 1 and rootB <= 1 and rootA < optimalRoot then
        optimalRoot = rootA
        optimalRootIndex = 5
    end

    if optimalRootIndex == -1 then
        return -1000, -1, -1, -1, -1
    end

    newx1 = x1 + optimalRoot * u1
    newy1 = y1 + optimalRoot * v1

    if optimalRootIndex == 1 or optimalRootIndex == 3 or optimalRootIndex == 4 then
        newu1 = - u1Original * speedMultiplier
        newv1 = v1Original
    end
    if optimalRootIndex == 2 or optimalRootIndex == 5 then
        newu1 = u1Original
        newv1 = - v1Original * speedMultiplier
    end

    if optimalRootIndex == 1 then
        newx1 = leftBox.x + leftBox.width + 1
    end

    if optimalRootIndex == 3 then
        newx1 = rightBox.x - puck.width - 1
    end

    if optimalRootIndex == 4 then
        if x1 < midBox.x then
            newx1 = midBox.x - puck.width - 1
        else
            newx1 = midBox.x + midBox.width + 1
        end
    end

    if optimalRootIndex == 2 then
        newy1 = topBox.y + topBox.height + 1
    end

    return newx1, newy1, newu1, newv1, optimalRootIndex
end


function identifyAlignment(xBefore, yBefore, obj1, obj2)
    -- assume obj2 is static and xBefore and yBefore correspond to obj1
    -- https://math.stackexchange.com/questions/406864/intersection-of-two-lines-in-vector-form

    optimalRootOut = 2
    optimalRootOutIndex = -1
    whichVertex = -1

    -- top-left corner
    x1 = xBefore
    y1 = yBefore

    u1 = obj1.x - xBefore
    v1 = obj1.y - yBefore

    indx, val = whereCollided(x1, y1, u1, v1, obj2)
    if val < optimalRootOut then
        optimalRootOut = val
        optimalRootOutIndex = indx
        whichVertex = 1
    end

    -- top-right corner
    x1 = xBefore + obj1.width
    y1 = yBefore

    u1 = obj1.x - xBefore
    v1 = obj1.y - yBefore

    indx, val = whereCollided(x1, y1, u1, v1, obj2)
    if val < optimalRootOut then
        optimalRootOut = val
        optimalRootOutIndex = indx
        whichVertex = 2
    end

    -- bottom-right corner
    x1 = xBefore + obj1.width
    y1 = yBefore + obj1.height

    u1 = obj1.x - xBefore
    v1 = obj1.y - yBefore

    indx, val = whereCollided(x1, y1, u1, v1, obj2)
    if val < optimalRootOut then
        optimalRootOut = val
        optimalRootOutIndex = indx
        whichVertex = 3
    end

    -- bottom-left corner
    x1 = xBefore
    y1 = yBefore + obj1.height

    u1 = obj1.x - xBefore
    v1 = obj1.y - yBefore

    indx, val = whereCollided(x1, y1, u1, v1, obj2)
    if val < optimalRootOut then
        optimalRootOut = val
        optimalRootOutIndex = indx
        whichVertex = 4
    end

    return optimalRootOutIndex, whichVertex
end


function MovingBox:update(dt)
    xBefore = self.x
    yBefore = self.y
    self.x = self.x + self.speedX * dt
    self.y = self.y + self.speedY * dt

    for i, object in ipairs(self.avoid) do
        objAlignment, whichVertex = identifyAlignment(xBefore, yBefore, self, object)

        -- side collision
        if objAlignment == 1 or objAlignment == 3 then
            if object ~= midBox then
                sounds["paddle"]:play()
            else
                sounds["sides"]:play()
            end

            self.speedX = -1 * speedMultiplier * self.speedX

            if object.buttonLeft == nil then
                keydownLeft = false
            else
                keydownLeft = love.keyboard.isDown(object.buttonLeft)
            end

            if object.buttonRight == nil then
                keydownRight = false
            else
                keydownRight = love.keyboard.isDown(object.buttonRight)
            end

            if object.speedX ~= nil and math.abs(self.speedX) < math.abs(object.speedX) then
                if keydownLeft or keydownRight then
                    self.speedX = self.speedX > 0 and math.abs(object.speedX) or -math.abs(object.speedX)
                end
            end

            if objAlignment == 1 then
                -- right of puck hit
                if keydownLeft then
                    self.x = object.x - self.width - 1 - dt * object.speedX
                else
                    self.x = object.x - self.width - 1
                end
            else
                -- left of puck hit
                if keydownRight then
                    self.x = object.x + object.width + 1 + dt * object.speedX
                else
                    self.x = object.x + object.width + 1
                end
            end
        end

        -- top/bottom collision
        if objAlignment == 2 or objAlignment == 4 then
            if object ~= midBox then
                sounds["paddle"]:play()
            else
                sounds["sides"]:play()
            end

            self.speedY = -1 * speedMultiplier * self.speedY
            self.speedX = 1 * speedMultiplier * self.speedX

            if objAlignment == 4 then
                -- top of puck hit
                self.y = object.y + object.height + 1
            else
                -- bottom of puck hit
                self.y = object.y - self.height - 1
            end
        end
    end

    if self.x < self.minX then
        sounds["sides"]:play()
        self.x = self.minX
        self.speedX = -1 * speedMultiplier * self.speedX
        --self.speedY = 1 * speedMultiplier * self.speedY
    end
    if self.x > self.maxX then
        sounds["sides"]:play()
        self.x = self.maxX
        self.speedX = -1 * speedMultiplier * self.speedX
        --self.speedY = 1 * speedMultiplier * self.speedY
    end

    if self.y < self.minY then
        sounds["sides"]:play()
        self.y = self.minY
        --self.speedX = 1 * speedMultiplier * self.speedX
        self.speedY = -1 * speedMultiplier * self.speedY
    end
    if self.y > self.maxY then
        sounds["sides"]:play()
        self.y = self.maxY
        --self.speedX = 1 * speedMultiplier * self.speedX
        self.speedY = -1 * speedMultiplier * self.speedY
    end
end
hintShown = false

function love.draw()
    push:start()

    love.graphics.clear(40/255, 45/255, 52/255, 255/255)
    leftBox:draw()
    rightBox:draw()
    topBox:draw()

    if gameState == "menu" then
        hintShown = false
        love.graphics.setFont(titleFont)
        love.graphics.printf("Ping", leftBorder + boxThickness, textHeight, width, "center")
        love.graphics.setFont(Font)

        leftPaddle:reset()
        leftPaddleUpper:reset()
        rightPaddle:reset()
        rightPaddleUpper:reset()

        if menuState == 1 then
            setHighlight()
            love.graphics.printf("Single Player", leftBorder + boxThickness, gameHeight / 2, width, "center")
            setWhite()
        else
            love.graphics.printf("Single Player", leftBorder + boxThickness, gameHeight / 2, width, "center")
        end

        if menuState == 2 then
            setHighlight()
            love.graphics.printf("Two Player", leftBorder + boxThickness, gameHeight / 2 + 1 * fontSize, width, "center")
            setWhite()
        else
            love.graphics.printf("Two Player", leftBorder + boxThickness, gameHeight / 2 + 1 * fontSize, width, "center")
        end

        if menuState == 3 then
            setHighlight()
            love.graphics.printf("Exit", leftBorder + boxThickness, gameHeight / 2 + 2 * fontSize, width, "center")
            setWhite()
        else
            love.graphics.printf("Exit", leftBorder + boxThickness, gameHeight / 2 + 2 * fontSize, width, "center")
        end

        push:finish()
        return
    end

    if gameState == "score1" then
        puck:reset()
        love.graphics.printf("Player 1 scores!", leftBorder + boxThickness, textHeight, width, "center")
    end

    if gameState == "score2" then
        puck:reset()
        love.graphics.printf("Player 2 scores!", leftBorder + boxThickness, textHeight, width, "center")
    end

    if gameState == "win1" then
        puck:reset()
        love.graphics.printf("Player 1 wins!", leftBorder + boxThickness, textHeight, width, "center")
    end

    if gameState == "win2" then
        puck:reset()
        love.graphics.printf("Player 2 wins!", leftBorder + boxThickness, textHeight, width, "center")
    end

    if gameState == "ready" or gameState == "begin" then
        love.graphics.printf("Press Enter to serve!", leftBorder + boxThickness, textHeight, width, "center")
        if not hintShown then
            love.graphics.printf(string.format("First to %d wins", maxScore), leftBorder + boxThickness, 115, width, "center")
            love.graphics.printf("Press A and D", leftBorder + boxThickness, height, (width - boxThickness) / 2, "center")

            if menuState == 2 then
                love.graphics.printf("Press left and right", leftBorder + boxThickness + width / 2, height, (width - boxThickness) / 2, "center")
            end
        end
        if gameState == "ready" and love.keyboard.isDown("return") then
            gameState = "start"
            hintShown = true
        end
    end

    midBox:draw()
    leftPaddle:draw()
    rightPaddle:draw()
    leftPaddleUpper:draw()
    rightPaddleUpper:draw()
    puck:draw()

    love.graphics.setFont(scoreFont)
    love.graphics.printf(player1Score, leftBorder + boxThickness, (topBorder - scoreSize) / 2, width / 2, "center")
    love.graphics.printf(player2Score, leftBorder + boxThickness + width / 2, (topBorder - scoreSize) / 2, width / 2, "center")
    love.graphics.setFont(Font)

    push:finish()
end


function setWhite() love.graphics.setColor(1, 1, 1) end
function setHighlight() love.graphics.setColor(0.5, 0.5, 0.5) end


function love.keypressed(key)
    if key == "escape" and gameState ~= "menu" then
        sounds['menu']:play()
        gameState = "menu"
        puck:reset()
        menuState = 1
        player1Score = 0
        player2Score = 0
    end

    if gameState == "menu" then
        if key == "down" or key == "s" then
            if menuState < 3 then
                menuState = menuState + 1
                sounds['menu']:play()
            end
        end

        if key == "up" or key == "w" then
            if menuState > 1 then
                menuState = menuState - 1
                sounds['menu']:play()
            end
        end

        if key == "return" then
            if menuState == 1 or menuState == 2 then
                gameState = "begin"
                sounds['menu']:play()
            end
            if menuState == 3 then
                love.event.quit()
            end
        end
    end
end


function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, {fullscreen = false, resizable = true, vsync = true})
    math.randomseed(os.time())
    love.window.setTitle('Ping')
    pingImage = love.image.newImageData("imgs/ping.png")
    love.window.setIcon(pingImage)
    setWhite()

    sounds = {
        ['lose'] = love.audio.newSource('sounds/lose.wav', 'static'),
        ['menu'] = love.audio.newSource('sounds/menu.wav', 'static'),
        ['paddle'] = love.audio.newSource('sounds/paddle.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['score_bad'] = love.audio.newSource('sounds/score_bad.wav', 'static'),
        ['sides'] = love.audio.newSource('sounds/sides.wav', 'static'),
        ['win'] = love.audio.newSource('sounds/win.wav', 'static'),
    }

    Font = love.graphics.newFont('VT323/VT323-Regular.ttf', fontSize, "mono")
    scoreFont = love.graphics.newFont('VT323/VT323-Regular.ttf', scoreSize, "mono")
    titleFont = love.graphics.newFont('VT323/VT323-Regular.ttf', titleSize, "mono")
    love.graphics.setFont(Font)

    gameState = 'menu'
    player1Score = 0
    player2Score = 0

    leftBox = Box(leftBorder, topBorder + boxThickness, boxThickness, height)
    rightBox = Box(gameWidth - rightBorder - boxThickness, topBorder + boxThickness, boxThickness, height)
    topBox = Box(leftBorder, topBorder, width + 2 * boxThickness, boxThickness)
    midBox = Box((gameWidth - boxThickness) / 2, topBorder + boxThickness + 2 * height / 3, boxThickness, height / 3)

    leftPaddle = MovableBoxX(width / 4 - paddleWidth / 2 + leftBorder + boxThickness, height + topBorder + boxThickness, paddleWidth, paddleHeight, leftBorder, leftBorder + boxThickness + width / 2 - paddleWidth, paddleSpeed, "a", 'd')
    rightPaddle = MovableBoxX(gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2, height + topBorder + boxThickness, paddleWidth, paddleHeight, leftBorder + boxThickness + width / 2, leftBorder + boxThickness + width - paddleWidth + boxThickness, paddleSpeed, "left", 'right')

    leftPaddleUpper = MovableBoxX(width / 4 - paddleWidth / 2 + leftBorder + boxThickness, height / 2 + topBorder + boxThickness, paddleWidth, paddleHeight, leftBorder, leftBorder + boxThickness + width / 2 - paddleWidth, paddleSpeed, "a", 'd')
    rightPaddleUpper = MovableBoxX(gameWidth - rightBorder - boxThickness - width / 4 - paddleWidth / 2, height / 2 + topBorder + boxThickness, paddleWidth, paddleHeight, leftBorder + boxThickness + width / 2, leftBorder + boxThickness + width - paddleWidth + boxThickness, paddleSpeed, "left", 'right')

    puck = MovingBox((gameWidth - puckSize) / 2, (height - puckSize) / 3 + topBorder + boxThickness, puckSize, puckSize, leftBorder + boxThickness, gameWidth - rightBorder - boxThickness - puckSize, topBorder + boxThickness, gameHeight + 40, puckInitialSpeed, puckInitialSpeed, {midBox, leftPaddle, leftPaddleUpper, rightPaddle, rightPaddleUpper})

end


function love.resize(w, h)
  return push:resize(w, h)
end

difficultyTimer = 0
overshoot = 10
sign = 1


function love.update(dt)
    difficultyTimer = difficultyTimer + dt

    if difficultyTimer > 5 then
        overshoot = sign * math.random() * paddleWidth
        sign = sign * -1
        difficultyTimer = 0
    end

    leftPaddle:update(dt)
    rightPaddle:update(dt)

    leftPaddleUpper:update(dt)
    rightPaddleUpper:update(dt)
    if gameState == "begin" then
    timer = timer + dt

    if timer > 0.5 then
    gameState = "ready"
    timer = 0
    end
    end

    if gameState == "win1" or gameState == "win2" then
    timer = timer + dt
    menuState = 1

    if love.keyboard.isDown("escape") then
    sounds['menu']:play()
    gameState = "menu"
    timer = 0
    end
    if timer > 2 then
    gameState = "menu"
    timer = 0
    end

    if gameState == "menu" then
    player1Score = 0
    player2Score = 0
    end
    end

    if gameState == "score1" or gameState == "score2" then
    if love.keyboard.isDown("return") then
    gameState = "start"
    end
    timer = timer + dt
    if timer > 1 then
    gameState = "ready"
    timer = 0
    end
    end

    if gameState == "start" then
    puck:update(dt)

    if puck.y > gameHeight then
    if puck.x > gameWidth / 2 then
    player1Score = player1Score + 1

    if player1Score >= maxScore then
    sounds["win"]:play()
    gameState = "win1"
    else
    sounds["score"]:play()
    gameState = "score1"
    end
    else
    player2Score = player2Score + 1

    if player2Score >= maxScore then
    if menuState == 1 then
    sounds["lose"]:play()
    else
    sounds["win"]:play()
    end
    gameState = "win2"
    else
    if menuState == 1 then
    sounds["score_bad"]:play()
    else
    sounds["score"]:play()
    end
    gameState = "score2"
    end
    end
    end
    end
    end