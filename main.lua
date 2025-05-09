-- Game Constants
local PLAYER_SCALE = 4
local ZOMBIE_SCALE = 4
local GROUND_Y = 550
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600

-- Game State Management
local gameState = {
    current = "start", -- start playing deathscreen
    wave = 1,
    zombiesPerWave = 5,
    zombiesSpawned = 0,
    spawnInterval = 1,
    paused = false
}

local sounds = {
    shoot = nil,     
    zombieHit = nil,    
    zombieDeath = nil,
    playerHurt = nil,  
    playerDeath = nil,
    gameMusic = nil,    
    deathScreenMusic = nil,
    zombieWalk = nil    
}

-- Death Screen Assets
local deathScreen = {
    ripImage = nil,
    credits = {
        "Developed by: Amir Shakibafar",
        " ",
        "Music by: Alireza Dalir",
        " ",
        "Voice Actors: Mohammad Moeini, Mohammad Reza Ghasemi"
    }
}

-- Player Properties
local player = {
    x = WINDOW_WIDTH / 2,
    y = GROUND_Y,
    lives = 3,
    width = 0,
    height = 0,
    direction = "right",
    scale = PLAYER_SCALE,
    isDead = false,
    isHurt = false,
    hurtFrame = 1,
    hurtTimer = 0,
    deathFrame = 1,
    deathTimer = 0,
    idleFrame = 1,
    hurtQuads = {},
    deathQuads = {},
    idleQuads = {}
}

-- Zombie Properties
local zombies = {}
local zombieAnim = {
    emerging = {
        frame = 1,
        timer = 0,
        speed = 0.1,
        quads = {}
    },
    walking = {
        frame = 1,
        timer = 0,
        speed = 0.1,
        quads = {}
    }
}

-- Bullets and Sprites
local bullets = {}
local sprites = {
    player = {
        idle = nil,
        hurt = nil,
        death = nil
    },
    zombie = {
        born = nil,
        walk = nil
    }
}

local ui = {
    font = nil,
    waveText = { x = 20, y = 20 },
    healthText = { x = WINDOW_WIDTH - 200, y = 20 }
}

function love.load()
    love.window.setTitle("Zombie Shooter")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    loadSounds()
    loadSprites()
    loadDeathScreenAssets()
    initializePlayer()
    initializeUI()
    
    gameState.spawnTimer = 0
    gameState.zombiesSpawned = 0
    
    if sounds.gameMusic then
        sounds.gameMusic:setLooping(true)
        sounds.gameMusic:play()
    end
end

function loadSounds()
    sounds.shoot = love.audio.newSource("shoot.ogg", "static")
    sounds.zombieHit = love.audio.newSource("zombie_hit.ogg", "static")
    sounds.zombieDeath = love.audio.newSource("zombie_death.ogg", "static")
    sounds.playerHurt = love.audio.newSource("player_hurt.ogg", "static")
    sounds.playerDeath = love.audio.newSource("player_death3.ogg", "static")
    sounds.gameMusic = love.audio.newSource("game_music.ogg", "stream")
    sounds.deathScreenMusic = love.audio.newSource("deathMusic.ogg", "stream")

    sounds.waveSounds = {
        love.audio.newSource("wave1.ogg", "static"),
        love.audio.newSource("wave2.ogg", "static"),
        love.audio.newSource("wave3.ogg", "static"),
        love.audio.newSource("wave4.ogg", "static"),
        love.audio.newSource("wave5.ogg", "static"),
        love.audio.newSource("wave6.ogg", "static"),
        love.audio.newSource("wave7.ogg", "static")
    }
end


function loadDeathScreenAssets()
    deathScreen.ripImage = love.graphics.newImage("rip.png")
end

function loadSprites()
    sprites.player.idle = love.graphics.newImage("m_idle.png")
    sprites.player.hurt = love.graphics.newImage("m_sick.png")
    sprites.player.death = love.graphics.newImage("m_dead.png")

    player.deathQuads = createQuads(sprites.player.death, 7)
    player.hurtQuads = createQuads(sprites.player.hurt, 5)
    player.idleQuads = createQuads(sprites.player.idle, 4)

    sprites.zombie.born = love.graphics.newImage("z_born.png")
    sprites.zombie.walk = love.graphics.newImage("z_walk.png")

    zombieAnim.emerging.quads = createQuads(sprites.zombie.born, 6)
    zombieAnim.walking.quads = createQuads(sprites.zombie.walk, 6)

    player.width = sprites.player.idle:getWidth() * PLAYER_SCALE
    player.height = sprites.player.idle:getHeight() * PLAYER_SCALE
end

function initializeUI()
    ui.font = love.graphics.newFont(40)
    love.graphics.setFont(ui.font)
end

function initializePlayer()
    player.x = WINDOW_WIDTH/2
    player.y = GROUND_Y - player.height/2
end

function createQuads(img, frameCount)
    local quads = {}
    local w = img:getWidth() / frameCount
    local h = img:getHeight()
    for i=0, frameCount-1 do
        table.insert(quads, love.graphics.newQuad(i*w, 0, w, h, img:getDimensions()))
    end
    return quads
end

function checkWaveCompletion()
    if #zombies == 0 and gameState.zombiesSpawned >= gameState.zombiesPerWave then
        -- if gameState.wave <= 7 then
        --     sounds.waveSounds[gameState.wave]:play()
        -- end
        nextWave()
    end
end

function love.update(dt)
    if gameState.current == "playing" and not gameState.paused then
        updateZombies(dt)
        updateBullets(dt)
        updateSpawning(dt)
        checkCollisions()
        updateAnimations(dt)
        checkWaveCompletion()
    end

    updatePlayerState(dt)
end

function updateSpawning(dt)
    gameState.spawnTimer = gameState.spawnTimer + dt
    if gameState.spawnTimer >= gameState.spawnInterval and
       gameState.zombiesSpawned < gameState.zombiesPerWave then
        spawnZombie()
        gameState.spawnTimer = 0
        gameState.zombiesSpawned = gameState.zombiesSpawned + 1
    end
end

function updateAnimations(dt)
    zombieAnim.emerging.timer = zombieAnim.emerging.timer + dt
    if zombieAnim.emerging.timer >= zombieAnim.emerging.speed then
        zombieAnim.emerging.timer = 0
        zombieAnim.emerging.frame = (zombieAnim.emerging.frame % #zombieAnim.emerging.quads) + 1
    end

    zombieAnim.walking.timer = zombieAnim.walking.timer + dt
    if zombieAnim.walking.timer >= zombieAnim.walking.speed then
        zombieAnim.walking.timer = 0
        zombieAnim.walking.frame = (zombieAnim.walking.frame % #zombieAnim.walking.quads) + 1
    end
end

function updatePlayerState(dt)
    if player.isDead then
        player.deathTimer = player.deathTimer + dt
        if player.deathTimer >= 0.1 then
            player.deathTimer = 0
            if player.deathFrame < 7 then
                player.deathFrame = player.deathFrame + 1
            else
                gameState.current = "deathscreen"
                if sounds.gameMusic then
                    sounds.gameMusic:stop()
                end
                if sounds.deathScreenMusic then
                    sounds.deathScreenMusic:setLooping(true)
                    sounds.deathScreenMusic:play()
                end
            end
        end
    elseif player.isHurt then
        player.hurtTimer = player.hurtTimer + dt
        if player.hurtTimer >= 0.1 then
            player.hurtTimer = 0
            if player.hurtFrame < 5 then
                player.hurtFrame = player.hurtFrame + 1
            else
                player.isHurt = false
            end
        end
    end
end

function love.draw()
    drawGameWorld()
    drawUI()
    drawGameStates()
end

function drawGameWorld() 
    drawGround()
    drawPlayer()
    drawZombies()
    drawBullets()
end

function drawGround()
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 0, GROUND_Y - 100, WINDOW_WIDTH, 200)
    love.graphics.setColor(1, 1, 1)
end

function drawUI()
    love.graphics.print("Wave: " .. gameState.wave, ui.waveText.x, ui.waveText.y)
    love.graphics.print("Health: " .. player.lives, ui.healthText.x, ui.healthText.y)
end

function drawGameStates()
    if gameState.current == "start" then
        love.graphics.printf("Press Space to Start Wave " .. gameState.wave, 0, WINDOW_HEIGHT/2 - 20, WINDOW_WIDTH, "center")
    elseif gameState.paused then
        love.graphics.printf("Game Paused - Press P to Resume", 0, WINDOW_HEIGHT/2 - 20, WINDOW_WIDTH, "center")
    elseif gameState.current == "deathscreen" then
        drawDeathScreen()
    end
end

function drawDeathScreen()
    local deathScreenFont = love.graphics.newFont(24)
    love.graphics.setFont(deathScreenFont)

    if deathScreen.ripImage then
        local ripWidth = deathScreen.ripImage:getWidth()
        local ripHeight = deathScreen.ripImage:getHeight()
        love.graphics.draw(deathScreen.ripImage, WINDOW_WIDTH/2 - ripWidth/2, WINDOW_HEIGHT/4 - ripHeight/2)
    end
    love.graphics.printf("RIP", 0, WINDOW_HEIGHT/4 + 50, WINDOW_WIDTH, "center")

    local creditY = WINDOW_HEIGHT/4 + 100
    for i, credit in ipairs(deathScreen.credits) do
        love.graphics.printf(credit, 0, creditY, WINDOW_WIDTH, "center")
        creditY = creditY + 30
    end

    love.graphics.setFont(ui.font)
end

function drawPlayer()
    -- ox and oy are pivot points
    local img, quad, ox, oy

    if player.isDead then
        img = sprites.player.death
        quad = player.deathQuads[player.deathFrame]
        ox = img:getWidth() / (7 * 2)
        oy = img:getHeight() / 2
    elseif player.isHurt then
        img = sprites.player.hurt
        quad = player.hurtQuads[player.hurtFrame]
        ox = img:getWidth() / (5 * 2)
        oy = img:getHeight() / 2
    else
        img = sprites.player.idle
        quad = nil
        ox = img:getWidth() / 2
        oy = img:getHeight() / 2
    end

    local scaleX = player.scale
    if player.direction == "left" then
        scaleX = -player.scale
    end

    if quad then
        love.graphics.draw(img, quad, player.x, player.y, 0, scaleX, player.scale, ox, oy)
    else
        love.graphics.draw(img, player.x, player.y, 0, scaleX, player.scale, ox, oy)
    end
end

function drawZombies()
    for _, z in ipairs(zombies) do
        local scaleX = (z.side == "right") and -1 or 1

        if z.state == "emerging" then
            local quad = zombieAnim.emerging.quads[z.emergingFrame]
            love.graphics.draw(
                sprites.zombie.born, 
                quad, 
                z.x, 
                z.y, 
                0, 
                scaleX * ZOMBIE_SCALE,
                ZOMBIE_SCALE, 
                sprites.zombie.born:getWidth() / 12, 
                sprites.zombie.born:getHeight() / 2
            )
        elseif z.state == "walking" then
            local quad = zombieAnim.walking.quads[z.walkingFrame]
            love.graphics.draw(
                sprites.zombie.walk, 
                quad, 
                z.x, 
                z.y, 
                0, 
                scaleX * ZOMBIE_SCALE,
                ZOMBIE_SCALE, 
                sprites.zombie.walk:getWidth() / 12, 
                sprites.zombie.walk:getHeight() / 2
            )
        end

        local healthWidth = 40 * (z.health / z.maxHealth)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", z.x - 20, z.y - 50, healthWidth, 5)
        love.graphics.setColor(1, 1, 1)
    end
end

function drawBullets()
    for _, b in ipairs(bullets) do
        -- draw posx posy width height
        love.graphics.rectangle("fill", b.x - 2, b.y - 2, 4, 4)
    end
end

function love.keypressed(key)
    if (key == "escape" or key == "p") and gameState.current == "playing" then
        gameState.paused = not gameState.paused
    elseif key == "r" and gameState.current == "deathscreen" then
        resetGame()
    elseif gameState.current == "start" and key == "space" then
        startWave()
    elseif gameState.current == "playing" and (key == "left" or key == "right") then
        player.direction = key
        shoot()
    end
end

function spawnZombie()
    local side = math.random(2) == 1 and "left" or "right"
    local x
    -- spawn just inside screen
    if side == "left" then
        x = 50  
    else
        x = WINDOW_WIDTH - 50
    end

    local health = 2 + gameState.wave
    local zombie = {
        x = x,
        y = GROUND_Y - 40,
        speed = 100 + gameState.wave * 10,
        side = side,
        health = health,
        maxHealth = health,
        state = "emerging",
        emergingFrame = 1,
        walkingFrame = 1
    }
    table.insert(zombies, zombie)
end

function updateZombies(dt)
    for i = #zombies, 1, -1 do
        -- question why from last to first?
        local z = zombies[i]

        if z.state == "emerging" then
            zombieAnim.emerging.timer = zombieAnim.emerging.timer + dt
            if zombieAnim.emerging.timer >= zombieAnim.emerging.speed then
                zombieAnim.emerging.timer = 0
                z.emergingFrame = z.emergingFrame + 1
                if z.emergingFrame > 6 then
                    z.state = "walking"
                end
            end
        elseif z.state == "walking" then
            zombieAnim.walking.timer = zombieAnim.walking.timer + dt
            if zombieAnim.walking.timer >= zombieAnim.walking.speed then
                zombieAnim.walking.timer = 0
                z.walkingFrame = (z.walkingFrame % 6) + 1
            end

            -- move based on direction
            if z.side == "left" then
                z.x = z.x + z.speed * dt  
            else
                z.x = z.x - z.speed * dt 
            end

            -- if a zombie is near the player, trigger a hit
            if math.abs(z.x - player.x) < 30 and not player.isDead then
                playerHit()
                table.remove(zombies, i)
            end
        end
    end
end

function updateBullets(dt)
    -- question why from last to first?
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + (b.speed * b.dir) * dt
        if b.x < 0 or b.x > WINDOW_WIDTH then
            table.remove(bullets, i)
        end
    end
end

function checkCollisions()
    for bi = #bullets, 1, -1 do
        local b = bullets[bi]
        for zi = #zombies, 1, -1 do
            local z = zombies[zi]
            -- then we can trigger a hit
            if math.abs(b.x - z.x) < 20 then
                z.health = z.health - 1
                table.remove(bullets, bi)
                if z.health <= 0 then
                    zombieDeath()
                    table.remove(zombies, zi)
                end
                -- why brake?
                break
            end
        end
    end
end

function shoot()
    local bullet = {
        x = player.x,
        y = player.y,
        speed = 500,
        dir = player.direction == "left" and -1 or 1
    }
    table.insert(bullets, bullet)
    shootBullet()
end

function playerHit()
    player.lives = player.lives - 1
    player.isHurt = true
    player.hurtFrame = 1
    player.hurtTimer = 0
    
    if player.lives <= 0 then
        playerDeath()
        player.isDead = true
        player.deathFrame = 1
    else
        playerHurt()
    end
end

function startWave()
    gameState.current = "playing"
    gameState.zombiesSpawned = 0
end

function nextWave()
    gameState.wave = gameState.wave + 1
    gameState.zombiesPerWave = gameState.zombiesPerWave + 2
    gameState.spawnInterval = math.max(0.5, gameState.spawnInterval - 0.1)
    gameState.current = "start"
    gameState.zombiesSpawned = 0
    gameState.spawnTimer = 0
end

function resetGame()
    player.lives = 3
    player.isDead = false
    player.isHurt = false
    zombies = {}
    bullets = {}
    gameState.wave = 1
    gameState.zombiesPerWave = 5
    gameState.current = "start"
    initializePlayer()

    -- go back to game sounds
    if sounds.deathScreenMusic then
        sounds.deathScreenMusic:stop()
    end
    if sounds.gameMusic then
        sounds.gameMusic:play()
    end
end

function shootBullet()
    if sounds.shoot then sounds.shoot:play() end
end

function zombieDeath()
    if sounds.zombieDeath then sounds.zombieDeath:play() end
end

function playerHurt()
    if sounds.playerHurt then sounds.playerHurt:play() end
end

function playerDeath()
    if sounds.playerDeath then sounds.playerDeath:play() end
end