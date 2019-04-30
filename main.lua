io.stdout:setvbuf('no')
if arg[#arg] == "-debug" then require("mobdebug").start() end

love.graphics.setDefaultFilter("nearest")

-- Images Tiles loading (On charge toute les images qui serviront à l'affichage des tuiles des niveaux)
local imgTiles = {}
imgTiles["1"] = love.graphics.newImage("images/tile1.png")
imgTiles["2"] = love.graphics.newImage("images/tile2.png")
imgTiles["3"] = love.graphics.newImage("images/tile3.png")
imgTiles["4"] = love.graphics.newImage("images/tile4.png")
imgTiles["5"] = love.graphics.newImage("images/tile5.png")
imgTiles["="] = love.graphics.newImage("images/tile=.png")
imgTiles["["] = love.graphics.newImage("images/tile[.png")
imgTiles["]"] = love.graphics.newImage("images/tile].png")
imgTiles["H"] = love.graphics.newImage("images/tileH.png")
imgTiles["#"] = love.graphics.newImage("images/tile#.png")
imgTiles["g"] = love.graphics.newImage("images/tileg.png")
imgTiles[">"] = love.graphics.newImage("images/tile-arrow-right.png")
imgTiles["<"] = love.graphics.newImage("images/tile-arrow-left.png")

-- Map and levels
local map = {}
local level = {}
local currentLevel = 0
local lstSprites = {}
local player = nil

local TILESIZE = 16
local GRAVITY = 450

-- Globals
local bJumpReady

-- Collision detection function;
-- Returns true if two boxes overlap, false if they don't;
-- x1,y1 are the top-left coords of the first box, while w1,h1 are its width and height;
-- x2,y2,w2 & h2 are the same, but for the second box.
-- FROM https://love2d.org/wiki/BoundingBox.lua 
function CheckCollision(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

local levels = {
    "The beginning",
    "Welcome in hell"
  }

function ChargeNiveau(pNum)
  if pNum > #levels then
    print("There is no level "..pNum)
    return
  end
  currentLevel = pNum
  map = {}
  local filename = "levels/level"..tostring(pNum)..".txt"
  -- (love.filesystem.lines() permet de parcourir les lignes d'un fichier en .txt par exemple)
  for line in love.filesystem.lines(filename) do  -- Parcours de toutes les lignes du fichier text (line renvoie la 1ere ligne du fichier)
    map[#map + 1] = line                          -- On stock toute les lignes du fichier dans la table "map" (à la fin de la boucle, "map" sera remplit)
  end
  -- Look for the sprites in the map
  lstSprites = {}
  level = {}                  -- Table qui contiendra les informations utiles au niveau (
  level.charStart = {}        -- Table qui va contenir les informations sur le positionnement du caractère (ex: "P" ), dans le niveau
  level.charStart.col = 0     -- Variable qui va contenir les informations sur le positionnement x du caractère (ex: "P" ) 
  level.charStart.lig = 0     -- Variable qui va contenir les informations sur le positionnement y du caractère (ex: "P" )
  level.coins = 0             -- Variable qui gèrera les piéces de notre niveau (compteur)
  for l=1,#map do        -- Parcours de toute les lignes de la map
    for c=1,#map[1] do   -- Parcours de toutes les colonnes de la map
      local char = string.sub(map[l],c,c)  -- Récuperation dans char, de chaque caractères tours après tours (string.sub permet de découper une chaine de caractère)
      if char == "P" then          -- Si on trouve un "P" dans le parcours de la map alors...
        level.charStart.col = c  -- on récupère sa coordonnée en x
        level.charStart.lig = l  -- on récupère sa coordonnée en y
        player = CreatePlayer(c,l) -- on créé notre player grâce à la fonction CreatePlayer(c,l)
      elseif char == "c" then      -- Sinon si on trouve un "c" alors...
        CreateCoin(c,l)            -- on créé une pièce
        level.coins = level.coins + 1  -- compteur de pièce (ex: si 5 x "c" dans map alors level.coins vaudra 5 à la fin de la boucle)
      elseif char == "D" then          -- Si on trouve un "D" alors...
        CreateDoor(c,l)                -- on créé une porte
      elseif char == "@" then          -- Si on trouve un "@" alors...
        CreatePNJ(c,l)                 -- on créé un PNJ
      end
    end
  end
--  CreatePlayer(level.charStart.col,level.charStart.lig)
end

-- Fonction de changement de niveau
function NextLevel()
  currentLevel = currentLevel + 1
  if currentLevel > #levels then
    currentLevel = 1
    print("TODO: Victory screen, all level completed")
  end
  ChargeNiveau(currentLevel)
end

-- Vérification si la tuile est solide ou pas en fonction de pID passé en paramètre
function isSolid(pID)
  if pID == "0" then return false end  -- La tuile 0 est une tuile vide (noire)
  if pID == "1" then return true end  -- "1" = tuile du bas
  if pID == "5" then return true end  -- "5" = tuile de décor gauche
  if pID == "4" then return true end  -- "4" = tuile de décor droit
  if pID == "=" then return true end  -- "=" = tuile de centre
  if pID == "[" then return true end  -- "[" = tuile de fin de bordure gauche
  if pID == "]" then return true end  -- "]" = tuile de fin de bordure droite
  return false
end
-- Vérification on peut sauter à travers ou non de la tuile
function isJumpThrough(pID)
  if pID == "g" then return true end  -- "g" est une tuile green 
  return false
end
-- Vérification si la tuile est une échelle
function isLadder(pID)
  if pID == "H" then return true end  -- "H" = tuile échelle (avant l'arrivée)
  if pID == "#" then return true end  -- "#" = tuile échelle de case d'arrivée
  return false
end
-- Pour définir si on affiche ou pas (ici si on affiche ou pas les flèches qui encadrent les ennemis)
function isInvisible(pID)
  --if pID == ">" or pID == "<" then return true end
  return false
end

function CreateSprite(pType, pX, pY)
  local mySprite = {}
  
  mySprite.x = pX            -- Propriété pour une position en pixels (x)
  mySprite.y = pY            -- Propriété pour une position en pixels (y)
  mySprite.vx = 0            -- Propriété de vélocité x
  mySprite.vy = 0            -- Propriété de vélocité y
  mySprite.gravity = 0       -- Propriété de gravité, pour désactiver/réactiver et d'empêcher le personnage de chuter quand il est sur une échelle!
  mySprite.isJumping = false -- Propriété de saut, pour faire la distinction entre le saut et la chute naturelle.
  mySprite.type = pType      -- Propriété de type (pour faire la différence entre le personnage principal, les ennemis, les objets… (type))       
  mySprite.standing = false  -- Propriété un booléen pour savoir si le sprite est posé sur le décor ou si il chute (standing)
  mySprite.flip = false      -- Propriété qui permettra de savoir si le sprite est tourné vers la gauche ou pas
  
  mySprite.currentAnimation = ""  -- Propriété qui déterminera l'actuelle animation en cours (qui va contenir soit une chaîne vide, soit "run", soit "idle"...)
  mySprite.frame = 0              -- Propriété frame pour gérer une future animation (frame)
  mySprite.animationSpeed = 1/8   -- Propriété qui détermine la vitesse d'animation des sprites
  mySprite.animationTimer = mySprite.animationSpeed
  mySprite.animations = {}  -- Création d'une table qui recevra les animations
  mySprite.images = {}      -- Création d'une table qui recevra les images des animations
  
  -- Fonction qui charge les images de l'animation du sprite 
  mySprite.AddImages = function(psDir, plstImages)-- Paramètres: psDir= un répertoire(ex: images/player), plstImages= table contenant la liste des images (ex idle1)
    for k,v in pairs(plstImages) do
      local fileName = psDir.."/"..v..".png"
      mySprite.images[v] = love.graphics.newImage(fileName)
    end
  end
  -- Fonction qui charge les animations
  mySprite.AddAnimation = function(psDir, psName, plstImages)  -- Paramètres: psDir= un répertoire, psName= le nom de l'animation, plstImages= table contenant la liste des images)
    mySprite.AddImages(psDir, plstImages)
    mySprite.animations[psName] = plstImages
  end
  -- Fonction qui initialise currentAnimation, et sa frame
  mySprite.PlayAnimation = function(psName)
    if mySprite.currentAnimation ~= psName then
      mySprite.currentAnimation = psName
      mySprite.frame = 1
    end
  end
    
  table.insert(lstSprites, mySprite)
  
  return mySprite
end

-- Creation du sprite JOUEUR
function CreatePlayer(pCol, pLig)
  local myPlayer = CreateSprite("player", (pCol-1) * TILESIZE, (pLig-1) * TILESIZE)
  myPlayer.gravity = GRAVITY
  myPlayer.AddAnimation("images/player", "idle", { "idle1", "idle2", "idle3", "idle4" })
  myPlayer.AddAnimation("images/player", "run", { "run1", "run2", "run3", "run4", "run5", "run6", "run7", "run8", "run9", "run10" })
  myPlayer.AddAnimation("images/player", "climb", { "climb1", "climb2" })
  myPlayer.AddAnimation("images/player", "climb_idle", { "climb1" })
  myPlayer.PlayAnimation("idle")
  bJumpReady = true
  return myPlayer
end

-- Création du sprite PIECE
function CreateCoin(pCol, pLig)
  local myCoin = CreateSprite("coin", (pCol-1) * TILESIZE, (pLig-1) * TILESIZE)
  myCoin.AddAnimation("images/coin", "idle", { "coin1", "coin2", "coin3", "coin4" })
  myCoin.PlayAnimation("idle")
end

-- Création du sprite PORTE
function CreateDoor(pCol, pLig)
  local myDoor = CreateSprite("door", (pCol-1) * TILESIZE, (pLig-1) * TILESIZE)
  myDoor.AddAnimation("images/door", "close", { "door-close" })
  myDoor.AddAnimation("images/door", "open", { "door-open" })
  myDoor.PlayAnimation("close")
end

-- Creation du sprite PNJ
function CreatePNJ(pCol, pLig)
  local myPNJ = CreateSprite("PNJ", (pCol-1) * TILESIZE, (pLig-1) * TILESIZE)
  myPNJ.AddAnimation("images/pnj", "walk", { "walk0", "walk1", "walk2", "walk3", "walk4", "walk5" })
  myPNJ.PlayAnimation("walk")
  myPNJ.direction = "right"
  myPNJ.CheckInternalCollision = collidePNJ
end


function OpenDoor()
  for nSprite=#lstSprites,1,-1 do
    local sprite = lstSprites[nSprite]
    if sprite.type == "door" then
      sprite.PlayAnimation("open")
    end
  end
end

function InitGame(pNiveau)
  ChargeNiveau(pNiveau)
end

function love.load()
  love.window.setMode(1200,900)
  love.window.setTitle("Mini platformer (c) Gamecodeur 2017")
  InitGame(1)                                                     -- Ici on peut changer de niveau
end

function AlignOnLine(pSprite)
  local lig = math.floor((pSprite.y + TILESIZE/2) / TILESIZE) + 1
  pSprite.y = (lig-1)*TILESIZE
end

function AlignOnColumn(pSprite)
  local col = math.floor((pSprite.x + TILESIZE/2) / TILESIZE) + 1
  pSprite.x = (col-1)*TILESIZE
end
-- Fonction
function updatePNJ(pSprite, dt)
  if pSprite.direction == "right" then
    pSprite.vx = 25
  elseif pSprite.direction == "left" then
    pSprite.vx = -25
  end
end

function collidePNJ(pSprite, dt)
  -- Tile under the player
  local idUnder = getTileAt(pSprite.x + TILESIZE/2, pSprite.y + TILESIZE)
  local idOverlap = getTileAt(pSprite.x + TILESIZE/2, pSprite.y + TILESIZE-1)
  
  pSprite.vx = 0
  local isCollide = false
  
  if idOverlap == ">" then
    pSprite.direction = "right"
    pSprite.flip = false
    pSprite.x = pSprite.x + 2
    isCollide = true
  elseif idOverlap == "<" then
    pSprite.direction = "left"
    pSprite.flip = true
    pSprite.x = pSprite.x - 2
    isCollide = true
  end
    
  return isCollide
end

function updatePlayer(pPlayer, dt)
  -- Locals for Physics
  local accel = 400
  local friction = 150
  local maxSpeed = 100
  local jumpSpeed = -200
  
  -- Tile under the player
  local idUnder = getTileAt(pPlayer.x + TILESIZE/2, pPlayer.y + TILESIZE)     -- idUnder stock la position de la tuile qui est sous les pied (ici de pPlayer)
  local idOverlap = getTileAt(pPlayer.x + TILESIZE/2, pPlayer.y + TILESIZE-1) -- idOverlap stock la position de la tuile ou on se trouve (ici de pPlayer)
  
  -- Stop Jump?
  if pPlayer.isJumping and (CollideBelow(pPlayer) or isLadder(idUnder)) then
    pPlayer.isJumping = false
  end
  -- Friction
  if pPlayer.vx > 0 then
    pPlayer.vx = pPlayer.vx - friction * dt
    if pPlayer.vx < 0 then pPlayer.vx = 0 end
  end
  if pPlayer.vx < 0 then
    pPlayer.vx = pPlayer.vx + friction * dt
    if pPlayer.vx > 0 then pPlayer.vx = 0 end
  end
  local newAnimation = "idle"
  -- Keyboard
  if love.keyboard.isDown("right") then
    pPlayer.vx = pPlayer.vx + accel*dt
    if pPlayer.vx > maxSpeed then pPlayer.vx = maxSpeed end
    pPlayer.flip = false
    newAnimation = "run"
  end
  if love.keyboard.isDown("left") then
    pPlayer.vx = pPlayer.vx - accel*dt
    if pPlayer.vx < -maxSpeed then pPlayer.vx = -maxSpeed end
    pPlayer.flip = true
    newAnimation = "run"
  end
  -- Check if the player overlap a ladder
  local isOnLadder = isLadder(idUnder) or isLadder(idOverlap)
  if isLadder(idOverlap) == false and isLadder(idUnder) then
    pPlayer.standing = true
  end
  -- Jump
  if love.keyboard.isDown("up") and pPlayer.standing and bJumpReady and isLadder(idOverlap) == false then
    pPlayer.isJumping = true
    pPlayer.gravity = GRAVITY
    pPlayer.vy = jumpSpeed
    pPlayer.standing = false
    bJumpReady = false
  end
  -- Climb
  if isOnLadder and pPlayer.isJumping == false then
    pPlayer.gravity = 0
    pPlayer.vy = 0
    bJumpReady = false
  end
  if isLadder(idUnder) and isLadder(idOverlap) then
    newAnimation = "climb_idle"
  end
  if love.keyboard.isDown("up") and isOnLadder == true and pPlayer.isJumping == false then
    pPlayer.vy = -50
    newAnimation = "climb"
  end
  if love.keyboard.isDown("down") and isOnLadder == true then
    pPlayer.vy = 50
    newAnimation = "climb"
  end
  -- Not climbing
  if isOnLadder == false and pPlayer.gravity == 0 and pPlayer.isJumping == false then
    pPlayer.gravity = GRAVITY
  end
  -- Ready for next jump
  if love.keyboard.isDown("up") == false and bJumpReady == false and pPlayer.standing == true then
    bJumpReady = true
  end
  pPlayer.PlayAnimation(newAnimation)
end

-- Déctecter quelle tuile se trouve à une position en pixel (retourne un caractère, qui si on l'analyse permet de savoir quelle tuile il s'agit) 
function getTileAt(pX, pY)  -- la fonction reçoit en paramètre une position en pixel et retourne le caractères de la map se trouvant à cette position
  
  local col = math.floor(pX / TILESIZE) + 1  -- col stock le calcul qui définit sur quelle colonne se trouve la coordonnée x (on sait qu'un tuile fait 16 x 16 px)
  local lig = math.floor(pY / TILESIZE) + 1  -- lig stock le calcul qui définit sur quelle ligne se trouve la coordonnée y (math.floor renvoie l'entier inférieur ou égal)
  if col > 0 and col <= #map[1] and lig > 0 and lig <= #map then  -- Si les coordonnées calculée (col et lig) sont bien dans les limites de la map alors...
    local id = string.sub(map[lig],col,col)  -- on stock dans id le caractère de la map se trouvant à cette position
    return id                                -- et on retourne le caractère de la map se trouvant à cette position
  end
  return 0                                   -- Sinon elle renvoie 0 (un vide de 16 x 16 px)
  
end
-- Collision du sprite sur 2 points à sa droite
function CollideRight(pSprite)
  local id1 = getTileAt(pSprite.x + TILESIZE, pSprite.y + 3)
  local id2 = getTileAt(pSprite.x + TILESIZE, pSprite.y + TILESIZE - 2)
  if isSolid(id1) or isSolid(id2) then return true end
  return false
end
-- Collision du sprite sur 2 points à sa gauche
function CollideLeft(pSprite)
  local id1 = getTileAt(pSprite.x-1, pSprite.y + 3)
  local id2 = getTileAt(pSprite.x-1, pSprite.y + TILESIZE - 2)
  if isSolid(id1) or isSolid(id2) then return true end
  return false
end
-- Collision sur points en dessous du sprite
function CollideBelow(pSprite)
  local id1 = getTileAt(pSprite.x + 1, pSprite.y + TILESIZE)
  local id2 = getTileAt(pSprite.x + TILESIZE-2, pSprite.y + TILESIZE)
  if isSolid(id1) or isSolid(id2) then return true end
  if isJumpThrough(id1) or isJumpThrough(id2) then  -- On détecte si la tuile sous les pieds du personnage est "JumpThrough"
    local lig = math.floor((pSprite.y + TILESIZE/2) / TILESIZE) + 1  -- Si c'est le cas, on calcule sur quelle ligne de la map se trouve le personnage (en se basant sur son centre : sa position y + TILESIZE/2)
    local yLine = (lig-1)*TILESIZE
    local distance = pSprite.y - yLine -- On calcule ensuite à quelle distance, en pixel, le personnage se trouve de cette ligne (= nombre de pixels entre les pieds du perso et le haut de la ligne)
    if distance >= 0 and distance < 10 then -- Si la distance est entre 0 et 10 pixels, on considère qu'il y a collision !
      return true
    end
  end
  return false
end
-- Collision sur 2 points en haut du sprite
function CollideAbove(pSprite)
  local id1 = getTileAt(pSprite.x + 1, pSprite.y-1)
  local id2 = getTileAt(pSprite.x + TILESIZE-2, pSprite.y-1)
  if isSolid(id1) or isSolid(id2) then return true end
  return false
end

function updateSprite(pSprite, dt)
  -- Locals for Collisions
  local oldX = pSprite.x
  local oldY = pSprite.y

  -- Animation
  if pSprite.currentAnimation ~= "" then                  -- Si on a une animation en cours alors...
    pSprite.animationTimer = pSprite.animationTimer - dt  -- on baisse le timer en cours avec le delta time (temps écoulé depuis la frame précédente)
    if pSprite.animationTimer <= 0 then                   -- Si le timer arrive à 0 alors...
      pSprite.frame = pSprite.frame + 1                   -- on passe à la frame suivante
      pSprite.animationTimer = pSprite.animationSpeed     -- et on réinitialise le timer
      if pSprite.frame > #pSprite.animations[pSprite.currentAnimation] then   -- Si la frame dépasse le nombre de frame de l'animation alors...
        pSprite.frame = 1  -- On revient à la frame 1           
      end
    end
  end

  -- Evolution du sprite en fonction de son type
  if pSprite.type == "player" then
    updatePlayer(pSprite, dt)
  elseif pSprite.type == "PNJ" then
    updatePNJ(pSprite, dt)
  end
  
  
  -- PRINCIPE DE DETECTION DE COLISION EN CONTINU (CCD)
  -- Calculate the movement steps
  local distanceX = pSprite.vx * dt  -- distanceX = vélocité x * dt du sprite (ce qui va donner un nb de pixel à parcourir, et donc la destination du sprite en pixel)
  local distanceY = pSprite.vy * dt  -- distanceY = vélocité y* dt du sprite (ce qui va donner un nb de pixel à parcourir, et donc la destination du sprite en pixel)
  
  -- On cape la distanceX et Y à la moitié de la taille d'une tuile (dans le but d'être sûr que le test d'aprés soit effectué à chaque tuile)
  if distanceX > TILESIZE/2 then  -- Si distanceX (nb de pixel à parcourir) est supérieur à la moitié d'une tuile alors ...
    distanceX = TILESIZE/2        -- on remet distanceX à la taille d'une demi tuile
  end  
  if distanceY > TILESIZE/2 then  -- Si distanceY (nb de pixel à parcourir) est supérieur à la moitié d'une tuile alors...
    distanceY = TILESIZE/2        -- on remet distanceY à la taille d'une demi tuile
  end
    
  -- Collision detection using simple and not optimized CCD
  
  -- Obtenir le dernier résultat de collision interne
  local collide = false --pSprite.collide

  -- Test CDD sur la droite
  local destX = pSprite.x + distanceX   -- On crée une variable destX qui représente la destination x du sprite
  if distanceX > 0 and collide == false then  -- Si la destination x du sprite est supérieur à 0
    while pSprite.x < destX do
      collide = CollideRight(pSprite)
      if collide == false and pSprite.CheckInternalCollision ~= nil then
        collide = pSprite.CheckInternalCollision(pSprite, dt)
      end
      if collide == true then
        pSprite.vx = 0
        break   -- On sort de la boucle while (optimisation)
      else
        pSprite.x = pSprite.x + 0.05
      end
    end
  -- Test CDD sur la gauche
  elseif distanceX < 0 and collide == false then
    while pSprite.x > destX do
      collide = CollideLeft(pSprite)
      if collide == false and pSprite.CheckInternalCollision ~= nil then
        collide = pSprite.CheckInternalCollision(pSprite, dt)
      end
      if collide == true then
        pSprite.vx = 0
        break
      else
        pSprite.x = pSprite.x - 0.05
      end
    end
  end
  
  -- Test CDD vers le haut
  local destY = pSprite.y + distanceY
  -- Above (go up)
  if distanceY < 0 then
    while pSprite.y > destY do
      collide = CollideAbove(pSprite)
      if collide == false and pSprite.CheckInternalCollision ~= nil then
        collide = pSprite.CheckInternalCollision(pSprite, dt)
      end
      if collide == true then
        pSprite.vy = 0
        break
      else
        pSprite.y = pSprite.y - 0.05
      end
    end
  end
  collide = false
  -- Below (go down)
  -- Test CDD vers le bas
  if pSprite.standing == true or pSprite.vy > 0 then
    collide = CollideBelow(pSprite)
    if collide then
      pSprite.standing = true
      pSprite.vy = 0
      AlignOnLine(pSprite)
    else
      if pSprite.gravity ~= 0 then
        pSprite.standing = false
      end
    end
  end
  if distanceY > 0 then
    while pSprite.y < destY do
      collide = CollideBelow(pSprite)
      if collide == false and pSprite.CheckInternalCollision ~= nil then
        collide = pSprite.CheckInternalCollision(pSprite, dt)
      end
      if collide == true then
        pSprite.standing = true
        pSprite.vy = 0
        break
      else
        pSprite.y = pSprite.y + 0.05
      end
    end
  end
    
  collide = false
  -- Sprite falling
  if pSprite.standing == false then
    pSprite.vy = pSprite.vy + pSprite.gravity * dt
  end
end

function love.update(dt)

  -- Check collision with the player
  for nSprite=#lstSprites,1,-1 do         -- Parcours de la liste des sprites
    local sprite = lstSprites[nSprite]
    updateSprite(sprite, dt)              -- Appel de la fonction updateSprite
    if sprite.type ~= "player" then    -- Si le sprite n'est pas le player, c'est donc un autre sprite alors...
      -- On check si les rectangles des 2 sprites se superposent
      if CheckCollision(player.x, player.y, TILESIZE, TILESIZE, sprite.x, sprite.y, TILESIZE, TILESIZE) then
        if sprite.type == "coin" then         -- Et si il y a collision entre le player et une pièce alors...
          table.remove(lstSprites, nSprite)   -- On retire la pièce de la table des sprites
          level.coins = level.coins - 1       -- et on retire une piéce du compteur
          if level.coins == 0 then            -- si le compteur arrive à 0 alors...
            -- Open door!
            OpenDoor()                        -- La porte s'ouvre
          end
        elseif sprite.type == "door" then     -- Sinon si il y a collision entre le player et la porte alors... 
          if level.coins == 0 then            -- et si le compteur de piece = 0 alors...
            NextLevel()                       -- on passe au niveau suivant
          end
        elseif sprite.type == "PNJ" then      -- Sinon si il y a collision entre le player et PNJ alors...
          print("YOU ARE DEAD")               -- notif dans la console
        end
      end
    end
  end  
end
-- PRINCIPE D'AFFICHAGE MIROIR D'UN SPRITE
-- Fonction Dessine le sprite en obtenant, depuis la liste des images de l'animation courante du sprite, la bonne image à afficher
function drawSprite(pSprite)
  local imgName = pSprite.animations[pSprite.currentAnimation][pSprite.frame]  -- Nom de l'image de la frame
  local img = pSprite.images[imgName]  -- à partir de imgName, on va chercher l'image correspondante
  local halfw = img:getWidth()  / 2    -- Calcul du moitié de l'origine en x (dans le but d'inverser l'image, effet miroir)
  local halfh = img:getHeight() / 2    -- Calcul du moitié de l'origine en y (dans le but d'inverser l'image, effet miroir)
  local flipCoef = 1
  if pSprite.flip then flipCoef = -1 end  -- si l'image est "flippée" horizontalement. Si oui, elle initialise une variable flipCoef à -1, sinon c'est 1
  love.graphics.draw(                     -- Elle affiche l'image à une position ajustée de la moitié de sa taille car maintenant l'origine de l'affichage n'est plus son coin supérieur gauche, sinon l'effet miroir ne fonctionnerait pas
    img, -- Image
    pSprite.x + halfw, -- horizontal position
    pSprite.y + halfh, -- vertical position
    0, -- rotation (none = 0)
    1* flipCoef , -- horizontal scale      -- c'est le "flipCoef" qui détermine le sens d'affichage de l'animation
    1, -- vertical scale (normal size = 1)
    halfw, halfh -- horizontal and vertical offset
    )
end

function love.draw()
  love.graphics.scale(3,3)  -- Mise à l'échelle x 3
  
  -- Affichage du notre map via une double boucle
  for l=1,#map do       -- parcours de toute les ligne de map (de 1 à 18 ici)
    for c=1,#map[1] do  -- parcours de toutes les colonnes de map indice 1 (pour savoir combien il y a de colonne soit 25 ici)
      -- string.sub() est une fonction qui permet de découper une chaîne de caractère (pour en récupérer une partie):  
      -- En paramètre: La chaîne qu'on veut découper, le caractère de départ de la coupe de la chaîne, et le caractère d'arrivée de la coupe de la chaîne.
      local char = string.sub(map[l],c,c)  -- char va stocker le caractére de notre "découpe" (puisqu'en paramètre on passe le même caractère de départ et d'arrivée) 
      if tonumber(char) ~= 0 and isInvisible(char) == false then  -- Si char est différent de "0" et qui le caractère n'est pas invisible alors...
        if imgTiles[char] ~= nil then  -- Et si la tuile n'est nul alors...
          love.graphics.draw(imgTiles[char],(c-1)*TILESIZE,(l-1)*TILESIZE)  -- On déssine la tuile
        end
      end
    end
  end
  -- Affichage de tout les sprites
  for nSprite=#lstSprites,1,-1 do
    local sprite = lstSprites[nSprite]
    drawSprite(sprite)
  end
  love.graphics.print("Level "..currentLevel..": "..levels[currentLevel], 5, (TILESIZE * 18) - 3)
end