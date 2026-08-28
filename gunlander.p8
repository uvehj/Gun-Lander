pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
--debug/config variables
debug = false
shotspeed = 3
gravity = 4
fps = 30
reset_progress = 0
--global variables
total_levels = 40
unlocked_levels = 0
ship = {}
level = {}
zones = {
    {startLevel = 1, basecolor=7, accentColor= 8, theme=32},
    {startLevel = 18, basecolor=6, accentColor= 2, theme=0},
    {startLevel = 31, basecolor=13, accentColor= 3, theme=50}
}
bullets = {}
background = {}
backgroundcount = 0 --state of the background for animation
backc = 1
camx = 0
camy = 0
menustate = 0
menuselectlevel = 1
crash_speed = 3
--------------------
---initialization---
--------------------
function _init()
    cls()
    cartdata("uvehj_gun_lander_v1")
    unlocked_levels = max(unlocked_levels, dget(0))
    if reset_progress != 0 then
        unlocked_levels = 1
        dset(0,unlocked_levels)
    end
    ship.h = 8
    ship.ho = ship.h --for reference unchanged ship height
    ship.w = 6
    ship.s = 0
    ship.sx = 0
    ship.sy = 0
    ship.ac = 0
    ship.crashed = 0
    ship.thrusters = {0,0}
    remove_map_assists()
    load_level(0,false, true) --main menu
    init_background()
end
function remove_map_assists()
    local x = 0
    while x < 128 do
        local y = 0
        while y < 64 do
            if fget(mget(x,y),7) then
                mset(x,y,0)
            end
            y = y + 1
        end
        x = x + 1
    end
end
--------------------
--level management--
--------------------
--build_level should only be called from load_level()
function build_level(lvlnum,startx,starty,endx,endy,camoffset,lgravity,shipstart,ammo,messages)
    --init level parameters
    level.number = lvlnum
    level.startx = startx
    level.starty = starty
    level.endx = endx
    level.endy = endy
    level.camoffset = {camoffset[1],camoffset[2]}
    if lgravity == 0 then
        level.gravity = gravity/2
    elseif lgravity == 2 then
        level.gravity = gravity*1.5
    else
        level.gravity = gravity
    end
    level.messages = messages
    level.w = level.endx - level.startx + 1
    level.h = level.endy - level.starty + 1
    level.ammo = {ammo[1],ammo[2],ammo[2]}
    level.state = 0
    --init ship
    ship.crashed = 0
    ship.x = 8*(shipstart[1]-level.startx)
    ship.y = 8*(shipstart[2]-level.starty)
    ship.sx = 0
    ship.sy = 0
    ship.thrusters = {0,0}
end
--creates a list of enemy buildings to restore them when the level is over
function create_enemy_list()
    level.enemylist = {}
    local x = level.startx
    while x <= level.endx do
        local y = level.starty
        while y <= level.endy do
            if fget(mget(x,y),2) then
                add(level.enemylist,{x,y,mget(x,y)})
            end
            y += 1
        end
        x += 1
    end
    level.numenemy = #level.enemylist
end
--restores destroyed enemies to the map sheet, also restores ammo and enemy counters
function restore_level()
    bullets = {}
    level.ammo[3] = level.ammo[2]
    level.numenemy = #level.enemylist
    for tile in all(level.enemylist) do
        mset(tile[1],tile[2],tile[3])
    end
end
-------------------
-------draw--------
-------------------
function _draw()
    cls()
    draw_background()
    if level.number > 0 then
        draw_map()
        foreach(bullets, draw_object)
        draw_ship()
        if level.state != 0 then
            draw_message()
        end
        draw_header()
    elseif level.number == 0 then
        draw_title()
    end
end

function changePalForLevel()
    if(level.number > 0) then
        currentzone = nil
        for key,value in pairs(zones) 
        do
            if value.startLevel <= level.number then
                currentzone=value
            end
        end
        if currentzone ~= nil then
            pal(14, currentzone.basecolor)
            pal(8, currentzone.accentColor)
        end
    end
end
--draw sprite correctly, o.x and o.y are position (in pixels) on the map
--draws relative to the camera position
--o.s is the sprite of the object
function draw_object(o)
    spr(o.s,o.x - camx,o.y+9-camy)
end
function draw_ship()
    if ship.sy >= crash_speed then
        pal(7,8)
    elseif flr((min(ship.sy,crash_speed)*7)/crash_speed) > 3 then
        pal(7,9)
    end
    if ship.ac >= 5 then --two frames of squash
        sspr(0,0,6,8,ship.x - camx,ship.y+9-camy,6,6)
        ship.h = 6 --update hitbox
    elseif ship.ac < 4 and ship.ac > 0 then --four frames of stretch
        sspr(0,0,6,8,ship.x - camx,ship.y+9-camy,6,10)
        ship.h = 10
    else --normal sprite in the middle as a bridge, rest of situations
        sspr(0,0,6,8,ship.x - camx,ship.y+9-camy,6,8)
        ship.h = 8
    end
    if ship.ac > 0 then --reset animation counter
        ship.ac -= 1 * (30/fps) --should be fps agnostic, untested on values other than 30
    end
    pal()
    draw_arrow()
    draw_thrusters()
    draw_gauges()
end
function draw_thrusters()
    local sprite = flr(rnd(2))
    local spriteheight = 3-min(sprite,1)
    if ship.thrusters[1] > 0 then
        sspr(12*8,8+sprite,3,3,ship.x-camx-3,ship.y+3+9-camy,3,3,false,false)
        ship.thrusters[1] -= 1
    end
    sprite = flr(rnd(2))
    spriteheight = 3-min(sprite,1)
    if ship.thrusters[2] > 0 then
        sspr(12*8+3,8+sprite,3,3,ship.x+ship.w-camx,ship.y+3+9-camy,3,3,false,false)
        ship.thrusters[2] -= 1
    end
end
function draw_gauges()
    local gauge_value
    if level.ammo[1] == true then
        gauge_value = ((level.ammo[3]/level.ammo[2])*ship.ho)
        if gauge_value > 0 then
            gauge_value -= 1
            rectfill(ship.x+ship.w+1-camx,ship.y+9-camy,ship.x+ship.w+1-camx,ship.y+gauge_value+9-camy,12)
        end
    end
    if #level.enemylist > 0 then
        gauge_value = ((level.numenemy/#level.enemylist)*ship.ho)
        if gauge_value > 0 then
            gauge_value -= 1
            rectfill(ship.x-2-camx,ship.y+9-camy,ship.x-2-camx,ship.y+gauge_value+9-camy,9)
        end
    end
end
function draw_arrow()
    if ship.y < (camy-ship.h) and ship.x < (camx-ship.w) then
        spr(14,0,9,1,1,false,false)
    elseif ship.y < (camy-ship.h) and ship.x > (camx+128) then
        spr(14,120,9,1,1,true,false)
    elseif ship.y > (camy+119) and ship.x < (camx-ship.w) then
        spr(14,0,120,1,1,false,true)
    elseif ship.y > (camy+119) and ship.x > (camx+128) then
        spr(14,120,120,1,1,true,true)
    elseif ship.y < (camy-ship.h) then
        spr(13,ship.x-camx,9)
    elseif ship.y > (camy+119) then
        spr(13,ship.x-camx,120,1,1,false,true)
    elseif ship.x < (camx-ship.w) then
        spr(15,0,ship.y+9-camy,1,1,false,false)
    elseif ship.x > (camx+128) then
        spr(15,120,ship.y+9-camy,1,1,true,false)
    end
end
--draw map relative to the camera position
--the first 8 pixels on the top of the screen are for the ui
function draw_map()
    changePalForLevel()
    map(level.startx,level.starty,0 - camx,9 - camy,level.w,level.h)
    pal()
end
---background---
function draw_background()
    local tile = 1
    backgroundcount += 1
    --every 2 seconds a different set of stars twinkles
    if backgroundcount > fps*2 then
        reset_twinkling_stars()
    end
    local palchange = 7
    -- 2 seconds are divided in 5 parts 1/5light grey - 2/5 dark grey - 3/5 black - 4/5 dark gray - 5/5 light gray
    if backgroundcount <= (fps*2)/5 or backgroundcount >= (fps*8)/5 then
        palchange = 6
    elseif backgroundcount <= (fps*4)/5 or backgroundcount >= (fps*6)/5 then
        palchange = 5
    else
        palchange = 0
    end
    local x = 0
    while x < 16 do
        local y = 0
        while y < 15 do
            --if there is twinkling, palet changes
            if background[tile][2] == true then
                pal(7,palchange)
            else
                pal()
            end
            spr(background[tile][1],x*8,(y*8)+9)
            y += 1
            tile += 1
        end
        x += 1
    end
    pal() --to not affect any other element
    --close celestial bodies
    changePalForLevel()
    circfill(100,level.h*8-camy-30,30,8)
    circ(64,level.h*8-camy+210,242,7)
    circfill(64,level.h*8-camy+210,230,7)
    pal()
    --level messages
    if #level.messages > 0 then
        for m in all(level.messages) do
            local str = m[1]
            rectfill((m[2]*8)-camx-(level.startx*8),(m[3]*8)-camy+9-(level.starty*8),(m[2]*8)+(#str*4)-camx-(level.startx*8),(m[3]*8)+6-camy+9-(level.starty*8),0)
            print(m[1],(m[2]*8)+1-camx-(level.startx*8),(m[3]*8)+1-camy+9-(level.starty*8),7)
        end
    end
end
--initializes a random starry sky
function init_background()
    background = {}
    local i = 0
    local tile = {}
    local sprite = 0
    while i < 240 do
        --star sprites are all between 16 and 26. 27 is a blank sprite
        sprite = min(flr(rnd(32)+16),27)
        tile = {sprite,false}
        add(background,tile)
        i += 1
    end
    reset_twinkling_stars()
end
--picks a random set of stars to twinkle
function reset_twinkling_stars()
    backgroundcount = 0
    for t in all(background) do
        if t[1] != 204 then
            if flr(rnd(6)) == 1 then
                t[2] = true
            else
                t[2] = false
            end
        end
    end
end
---ui---
function draw_title()
    --title art
    spr(64, 30, 30, 8, 4)
    spr(72, 30, 62, 8, 2)
    --credits and site
    print("a game by uvehj",2,110,0)
    print("sounds by ian edward",2,116,0)
    print("github.com/uvehj/gun-lander",20,122,0)
    if menustate == 1 then
        --rectfill(30,86,94,94,8)
        --rectfill(31,87,93,93,7)
        rectfill(30,86,94,94,7)
        titlemessage = "start lvl\139"..tostr(menuselectlevel).."\145"
        print(titlemessage,64-((#titlemessage+3)*4/2),88,8)
    end
end
--draw restart/next level message
function draw_message()
    changePalForLevel()
    rectfill(22,60,107,78,7)
    rect(22,60,107,78,8)
    if level.state == 2 then
        print("don't hit friendlies!",24,62,8)
    elseif level.state == 1 then
        print("you crashed!",42,62,8)
    elseif level.state == 3 then
        print("some enemies remain",24,62,8)
    elseif level.state == 4 then
        print("lost forever in space",24,62,8)
    elseif level.state == 5 then
        print("too fast to land",24,62,8)
    elseif level.state == 6 then
        print("missed landing pad",24,62,8)
    elseif level.state == -1 then
        print("nice landing!",42,62,8)
    end
    if level.state > 0 then --fail states
        print("press \151 to restart",28,72,8)
    else                    --win states
        print("\151 start next level",28,72,8)
    end
    pal()
end
--header with counters
function draw_header()
    rectfill(0,0,8*16,8,1)
    --level number
    print("lvl",2,2,7)
    --enemy counter
    print(level.number,14,2,7)
    if #level.enemylist > 0 then
        print(level.numenemy,43,2,7)
        print("\138",43+(#tostr(level.numenemy)*4),2,7)

    end
    --ammo counter
    if level.ammo[1] == true then
        print(level.ammo[3],86,2,7)
        print("\134",86+(#tostr(level.ammo[3])*4),2,7)
    end
    --gravity
    spr(8,122,1)
    if level.gravity >= gravity then
        spr(8,122,3)
        if level.gravity > gravity then
        spr(8,122,5)
        end
    end
    --speed
    if flr((min(ship.sy,crash_speed)*7)/crash_speed) > 0 then
        sspr(13*8,2*8,flr((min(ship.sy,crash_speed)*7)/crash_speed),8,113,0)
    end
end
------------------
------update------
------------------
function _update()
    if level.number > 0 then
        if level.state == 0 then
            if debug == true then
                update_ship_debug()
            else
                update_ship()
            end
        update_bullets()
        end
        check_end()
    elseif level.number == -1 then
        update_credits()
    elseif level.number == 0 then
        update_menu()
    end
    update_camera()
end
function update_menu()
    if menustate == 0 and (btnp(5) or btnp(4)) then
        menustate = 1
        --ian wip
        sfx(56,3) --play menu beep on ch.3
    elseif menustate == 1 then
        if (btnp(5) or btnp(4)) then
            menustate = 0
            --ian wip
            sfx(56,3) --play menu beep on ch.3
            load_level(menuselectlevel,false, true) --load level from menu
        elseif btnp(0) and menuselectlevel > 1 then
            menuselectlevel -= 1
            --ian wip
            sfx(56,3) --play menu beep on ch.3
        elseif btnp(1) and menuselectlevel < unlocked_levels then
            menuselectlevel += 1
            --ian wip
            sfx(56,3) --play menu beep on ch.3
        end
    end
end
function check_end()
    --level is failed, button press will restart it
    if level.state != 0 then
        if (btnp(5)) then
            restore_level()
            if level.state > 0 then --fail, restart
                load_level(level.number,true, false)
            elseif level.state < 0 then --success
                if level.number < total_levels then --next level
                    unlocked_levels = max(unlocked_levels,level.number+1)
                    dset(0,unlocked_levels)
                    load_level(level.number+1,false, false)
                else --credits
                    load_level(-1,false, true)
                end
            end
        end
    else
        --check if the ship has landed on the landing pad or not
        if ship.crashed != 0 then
            local contact_points = {{flr(((ship.x+2)/8)+level.startx),flr(((ship.y+ship.h-1)/8)+level.starty)},{flr(((ship.x+ship.w-3)/8)+level.startx),flr(((ship.y+ship.h-1)/8)+level.starty)}}
            local top_points = {{flr(((ship.x)/8)+level.startx),flr(((ship.y)/8)+level.starty)},{flr(((ship.x+ship.w-1)/8)+level.startx),flr((ship.y/8)+level.starty)}}
            for p in all(contact_points) do
                if fget(mget(p[1],p[2]),4) != true then
                    --it is a crash if: lands on a building, lands too hard or lands sideways (hits a wall with the side of the ship)
                    if fget(mget(p[1],p[2]),1) == true or fget(mget(p[1],p[2]),2) == true or ship.sy >= crash_speed then
                        level.state = max(level.state, 1)
                        sfx(61,3) --play ship crash sfx on ch.3
                    else
                        for p2 in all(top_points) do
                            --if any of the top points is making contact, it is a sideways crash
                            if fget(mget(p[1],p[2]),0) != true then
                                level.state = max(level.state, 1)
                                sfx(61,3) --play ship crash sfx on ch.3
                            end
                        end
                    end
                    --if it is not a crash but it's not on the landing pad, it's a game over
                    if level.state == 0 then
                        level.state = 6
                        sfx(58,3) --play fail sfx on ch.3
                    end
                end
            end
            if level.state == 0 then
                if ship.sy >= crash_speed then
                    level.state = 5
                    sfx(61,3) --play ship crash sfx on ch.3
                elseif #level.enemylist !=0 and level.numenemy != 0 then
                    level.state = 3
                    --ian wip
                    sfx(58,3) --play fail sfx on ch.3
                else
                    level.state = -1
                    --ian wip
                    sfx(57,3) --play success sfx on ch.3
                end
            end
        end
    end
end
function update_credits()
    if (btnp(5) or btnp(4)) then
        load_level(0,true, true) --back to main menu
    end
end
function update_camera()
    --update camera x axis to center ship
    camx = ship.x+(ship.w/2)-64
    --update camera so it doesn't go beyond the borders
    --in case of a level that is too narrow, the camera will adjust to the left border and show black past the right one
    --if the camera hits the right border adjust to not go further
    if (camx+64)>((level.w*8)-64) then
        camx = (level.w*8) - 128
    end
    --if the camera goes beyond the left border adjust it to starts at the left edge
    if camx < 0 then
        camx = 0
    end
    --same as with cam x
    camy = ship.y+(ship.h/2)-64
    if (camy+60)>((level.h*8)-60) then
        camy = (level.h*8) - 119
    end
    if camy < 0 then
        camy = 0
    end
    camx += level.camoffset[1] * 8
    camy += level.camoffset[2] * 8
end
function update_ship_debug()
    if (btnp(0)) then
        movex(ship,-4)
    end
    if (btnp(1)) then
        movex(ship,4)
    end
    if (btnp(2)) then
        movey(ship,-4)
    end
    if (btnp(3)) then
        movey(ship,4)
    end
    if (btnp(4)) then
        if (level.ammo[1] and level.ammo[3] > 0) or level.ammo[1] == false then
            level.ammo[3] -= 1
            spawn_bullet(ship)
        end
    end
end
function update_ship()
    local x = 0
    local y = level.gravity
    --x acceleration
    if (btnp(0)) then
        x = -50
        ship.thrusters[2] = 16
        --ian wip
        sfx(55,3) --play thruster sfx on ch.3
    elseif (btnp(1)) then
        x = 50
        ship.thrusters[1] = 16
        --ian wip
        sfx(55,3) --play thruster sfx on ch.3
    end
    --y acceleration
    if (btnp(4)) then
        if (level.ammo[1] and level.ammo[3] > 0) or level.ammo[1] == false then
            level.ammo[3] -= 1
            y = -80
            spawn_bullet(ship)
            ship.ac = 6
            --ian wip
            sfx(60,2) --play bullet sfx on ch.2
        end
    end
    update_speed_move(ship, x, y)
    ship.sx = ship.sx * (1-(0.2/fps)) --drag
    ship.sx = max(min(ship.sx,4),-4)  --control ludicrous speeds
    if abs(ship.x-camx) > 1000 or abs(ship.y-camy) > 1000 then
        level.state = 4
        --ian wip
        sfx(58,3) --play fail sfx on ch.3
    end
end
--s is the ship object that spawns the bullet
function spawn_bullet(s)
    local b = {}
    b.h = 2
    b.w = 4
    b.s = 1
    b.x = s.x + (s.w/2) - (b.w/2)
    b.y = s.y + (s.h/2)
    b.sx = 0
    b.sy = shotspeed
    b.crashed = 0
    add(bullets,b)
    return b
end
function update_bullets()
    for b in all (bullets) do
        update_speed_move(b, 0, gravity)
        if b.crashed != 0 then
            if b.crashed == 2 then --destroyed friendly building
                level.state = 2
                --ian wip
                sfx(58,3) --play fail sfx on ch.3
            end
            del(bullets,b)
        elseif b.y > ((level.h+16)*8) then
            del(bullets,b)
        end
    end
end
-----------------
----movement-----
-----------------
function update_speed_move(o,x,y)
    if x > 0 or x < 0 then
        o.sx = o.sx + (x/fps)
    end
    if y > 0 or y < 0 then
        o.sy = o.sy + (y/fps)
    end
    movex(o,o.sx*(30/fps))
    movey(o,o.sy*(30/fps))
end
--distance in pixels, slow but accurate (should be fine with so few moving objects)
function movex(o, distance)
    while (distance <= -1 or distance >= 1) and o.crashed == 0 do
        if distance >= 1 then
            distance -= 1
            o.x += 1
        end
        if distance <= -1 then
            distance += 1
            o.x -=1
        end
        if is_wall_collision(o) != 0 then
            o.crashed = 1
        end
    end
end
--same as movex
function movey(o, distance)
    --while the object hasn't crashed into a wall, check for every pixel of movement
    while (distance <= -1 or distance >= 1) and o.crashed == 0 do
        if distance >= 1 then
            distance -= 1
            o.y += 1
        end
        if distance <= -1 then
            distance += 1
            o.y -=1
        end
        o.crashed = is_wall_collision(o)
    end
end
function is_wall_collision(o)
    --top left, top right, bottom left, bottom right
    local contact_points = {{flr(((o.x)/8)+level.startx),flr(((o.y)/8)+level.starty)},{flr(((o.x+o.w-1)/8)+level.startx),flr((o.y/8)+level.starty)},{flr(((o.x)/8)+level.startx),flr(((o.y+o.h-1)/8)+level.starty)},{flr(((o.x+o.w-1)/8)+level.startx),flr(((o.y+o.h-1)/8)+level.starty)}}
    --enemy buildings
    enemycrash = 0
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),2) and pos[1] >= level.startx and pos[1] < level.endx+1 and pos[2] >= level.starty and pos[2] <= level.endy then
            if fget(mget(pos[1],pos[2]-1),3) then
                mset(pos[1],pos[2],3)
            else
                mset(pos[1],pos[2],2)
            end
            level.numenemy -= 1
            enemycrash = 1
            --ian wip
            sfx(63,2) --play enemy destroyed sfx on ch.3
        end
    end
    if enemycrash != 0 then
        return 3
    end
    --walls
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),0) and pos[1] >= level.startx and pos[1] < level.endx+1 and pos[2] >= level.starty and pos[2] <= level.endy then
            return 1
        end
    end
    --friendly buildings
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),1) and pos[1] >= level.startx and pos[1] < level.endx+1 and pos[2] >= level.starty and pos[2] <= level.endy then
            return 2
        end
    end
    return 0
end

function gameplaymusic(l, restart, restartMusic) --play gameplay music, if not already playing
    if(l > 0) then
        currentzone = nil
        for key,value in pairs(zones) 
        do
            if value.startLevel <= l then
                currentzone=value
            end
        end
        if currentzone ~= nil then
            if( restart == false and (restartMusic or l == currentzone.startLevel)) then
                music(currentzone.theme,0,7) --play gameplay music, reserve ch.0-2
            end
        end
    end
end

--level info--
--build_level(lvlnum,startx,starty,endx,endy,camoffset{x,y},lgravity,shipstart{x,y},ammo{is limited,number},restart,messages)
--l is level number, r is level restart (true of false), restartMusic forces the music to start from the beginning
--start and end coordinates are as displayed by the map tab
function load_level(l, restart, restartMusic)
    --level -
    if l > 0 then --gameplay beep and song
        sfx(56,3) --play menu beep sfx on ch.3
        gameplaymusic(l, restart, restartMusic) --call gameplaymusic function
    elseif l == 0 then
        music(24,0,7) --play main menu music, reserve ch.0-2
    elseif l == -1 then
        music(16,0,7) --play credits music, reserve ch.0-2
    end
    --level build
    if l == 0 then
        build_level(l,0,0,15,14,{0,0},1,{0,0},{false,0},{{"houston, we have a gun",2,8.2}})
    elseif l == -1 then
        build_level(l,0,0,15,14,{0,0},1,{0,0},{false,0},{{"thanks for playing!",3,3}, {"game design, programing",2,7}, {"& visuals",10,8}, {"uvehj",6,9}, {"sounds & music",4,11}, {"ian edward",5,12}})
    elseif l == 1 then
        build_level(l,0,0,10,10,{0,0},0,{2,1},{false,0},{{"land here",5,8}})
    elseif l == 2 then
        build_level(l,10,0,15,10,{-3,0},0,{12,9},{false,0},{{"up here!",12,2},{"\142shoot!",11,9}})
    elseif l == 3 then
        build_level(l,10,0,15,10,{-3,0},2,{12,9},{false,0},{{"beware gravity ;)",11,9}})
    elseif l == 4 then
        build_level(l,10,3,15,10,{-1,0},1,{12,11},{false,0},{{"do a blind landing",11,6}, {"no ceiling here",16,3}})
    elseif l == 5 then
        build_level(l,29,0,40,13,{-2,0},0,{31,8},{true,2},{{"keep an eye on your ammo",30,3}})
    elseif l == 6 then
        build_level(l,21,0,40,13,{0,-1},1,{22,5},{false,0},{{"don't shoot us",24,9}})
    elseif l == 7 then
        build_level(l,16,0,40,13,{0,-1},1,{22,5},{false,0},{{"destroy the enemy",17,8}})
    elseif l == 8 then
        build_level(l,16,0,40,13,{0,-1},1,{22,5},{true,15},{{"a bit harder ;)",22,4}})
    elseif l == 9 then
        build_level(l,100,48,127,55,{0,-7},1,{101,43},{false,0},{{"our blessed homeworld",101,42}, {"their barbarous void",117,42}, {"our glorious",101,46}, {"planet council",101,47},{"their wicked",122,46}, {"star-lord",123,47}, {"our great",105,48}, {"spaceport",105,49}, {"our noble",107,50}, {"space-born",107,51}, {"our brave",109,52}, {"spacefarers",109,53}, {"their primitive",118,48}, {"workshop",121,49}, {"their backward",116,50}, {"xenos",120,51}, {"their brutish",115,52}, {"spacepirates",115,53}})
    elseif l == 10 then
        build_level(l,41,0,66,10,{0,0},1,{43,4},{false,0},{{"into the cave",46,5}})
    elseif l == 11 then
        build_level(l,10,29,29,41,{0,-6},2,{11,34},{false,0},{{"mountain climb",15,27}})
    elseif l == 12 then
        build_level(l,08,22,29,32,{0,-4},2,{27,26},{false,0},{{"up! up!",23,31}})
    elseif l == 13 then
        build_level(l,10,14,29,40,{0,0},2,{11,36},{false,0},{{"over here",20,35}})
    elseif l == 14 then
        build_level(l,30,14,41,26,{-2,-2},1,{40,16},{true,55},{{"dig dig dig",33,14}})
    elseif l == 15 then
        build_level(l,0,32,3,36,{-6,-8},1,{0,30},{true,7},{{"??",2,30}})
    elseif l == 16 then
        build_level(l,3,32,7,36,{-5,-8},1,{9,31},{true,7},{{"beware the",4,29},{"chimaeras",5,30}})
    elseif l == 17 then
        build_level(l,0,37,7,41,{-2,-8},1,{9,38},{true,14},{{"beware friendly fire",0,35}})
    elseif l == 18 then
        build_level(l,2,12,5,31,{-6,0},1,{3,11},{false,0},{{"easy",3,13}})
    elseif l == 19 then
        build_level(l,2,12,5,31,{-6,0},2,{3,11},{false,0},{{"faster",3,13}})
    elseif l == 20 then
        build_level(l,1,12,6,31,{-5,0},1,{3,11},{false,0},{{"harder",3,13}})
    elseif l == 21 then
        build_level(l,1,12,6,31,{-5,0},2,{3,11},{false,0},{{"not so easy",3,13}})
    elseif l == 22 then
        build_level(l,0,12,7,31,{-4,0},1,{3,11},{false,0},{{"precision",3,13}})
    elseif l == 23 then
        build_level(l,30,27,41,41,{0,0},1,{44,29},{false,0},{{"entrance hidden by enemy bases",30,30},{"air vent",32,36},{"fan",33,39},{"landing",37,37},{"pad",39,38}})
    elseif l == 24 then
        build_level(l,56,41,65,55,{0,0},1,{64,50},{false,0},{{"dive",58,52}})
    elseif l == 25 then
        build_level(l,42,41,55,55,{-2,0},1,{44,50},{false,0},{{"dive",47,52},{"again",52,52}})
    elseif l == 26 then
        build_level(l,42,33,65,47,{0,0},1,{42,33},{false,0},{{"jump",46,35}})
    elseif l == 27 then
        build_level(l,103,16,127,25,{0,-5},2,{107,17},{false,0},{})
    elseif l == 28 then
        build_level(l,103,7,122,25,{0,0},2,{107,17},{false,0},{{"round 'n round",105,13}})
    elseif l == 29 then
        build_level(l,120,0,127,25,{-5,0},0,{120,1},{false,0},{{"down",121,2},{"the",123,3},{"rabbit",121,4},{"hole",123,5}})
    elseif l == 30 then
        build_level(l,103,0,127,16,{0,0},2,{105,3},{false,0},{{"back again",105,13}})
    elseif l == 31 then
        build_level(l,105,26,124,47,{0,0},1,{124,39},{false,0},{})
    elseif l == 32 then
        build_level(l,91,26,127,46,{0,0},1,{92,41},{false,0},{})
    elseif l == 33 then
        build_level(l,42,25,61,30,{0,-9},1,{44,25},{false,0},{{"mind the gap",48,22}})
    elseif l == 34 then
        build_level(l,42,22,61,30,{0,-6},1,{44,25},{false,0},{{"tighter",48,25}})
    elseif l == 35 then
        build_level(l,42,22,61,32,{0,-4},1,{44,25},{false,0},{{"one step at a time",45,25}})
    elseif l == 36 then
        build_level(l,42,11,61,32,{0,0},1,{57,26},{false,0},{{"up and around",48,25}})
    elseif l == 37 then
        build_level(l,42,14,61,32,{0,0},1,{57,26},{false,0},{{"again?",53,25}, {"no landing pad?",49,14}})
    elseif l == 38 then
        build_level(l,77,5,102,19,{0,0},0,{77,10},{false,0},{{"landy gun",79,11}})
    elseif l == 39 then
        build_level(l,77,10,99,24,{0,0},0,{83,15},{false,0},{})
    elseif l == 40 then
        build_level(l,77,0,99,23,{0,0},0,{88,2},{false,0},{{"seek",87,05},{"and",88,06},{"destroy",87,07}})
    end
    --new level initializations
    if restart == false then
        init_background()
        create_enemy_list()
    end
end

__gfx__
0cccc00008800000000000000505550588888888888888888888888888888888700070007c7cc7cc00011000000000a9a999999a00c00000cccc000000c00000
cc77cc008778000000000000055505558eeeeeeeeeeeeeeeee8eeee88eeee8e807070000c70000c701111110000a9999a9777a9a0ccc0000ccc000000cc00000
cccccc008778000000000000655055508eeeeeeeeee8eeeeeee8eee88eee8ee800700000c0700c0711cccc11a9999999a9777a9accccc000cc000000ccc00000
001100000880000006606000550550508ee8eeeeeeee8eeeeeeee8e88eeeeee800000000c007c007cccccccc99999999a999999a00000000c00000000cc00000
0cccc0000000000005565060555555058e8eeeeeeeee8eeeeeeeeee88eeeeee800000000700c700cccccc77c97979999a9777a9a000000000000000000c00000
c0660c000000000065055656550505558eeeeeeee88eeeeeeeeee8e88888eee80000000070c0070ccc77c77c99799779a9777a9a000000000000000000000000
c0660c000000000055050555055555558eeeeeeeeeeeeeeeeee88ee88eee8ee8000000007c00007ccc77cccc97979779a999999a000000000000000000000000
700007000000000050550050055500558888888888888888888888888888888800000000c777ccc7cc77cccc99999779a999999a000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005000050087778887cccccccc000a0000
00000000000000000000000000000070000000000000007000000000000000000000000000070000000000000000000000660000780000787c0007c0aaaaaaaa
000000000000000000070000000000000000000000000000000000000000000000000000007070000000000000000000560065007080070807c07c00a999999a
0000000000700000007070000000000000000000000000000007000000000000000000000007000000000000000000005000050070087008007cc000a977779a
0000070000000000000700000000000000000000000000000000000000000000000007000000000000000000000000000666650080078007eeeeeeeea977779a
0000707000000000000000000700000000000000000000000000000000000000000000000000000000000700000000000000000080700807eeeeeeeea999999a
0000070000000070000000000000000000070000000000000000000007000000000000700000000000000000000000000566500087000087eeeeeeeea977779a
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005000050078887778eeeeeeeea977779a
8888888888888888888888888eeeeeeeeeeeeeeeeeeeeee81cccccc10001100007777700077777000cc000008888888888888888000000007575575500000000
8eeeeeeeeeeeeeeeeeeeeee88eeeeeeee88eeeeeeeee88e81c7cc7c1011cc110777c7770777c7770c7cc0000877b9778877bb778000000805700005700000000
8eeee8eee8eeeeeeeeeeeee88ee8eeeeeeeeeeeeeeeeeee81c7cc7c11cccccc17c77c77077c7c770cccc000087b7797887b77b78000009805070050700000000
8eeeeeeee88eeeeeeeeeeee88e8eeeeeeeee8eeeeee8eee81cccccc11cc77cc177c77c707c777c70777700008b7777988b7777b8000099805007500700000000
8ee8eeeee8eee8eeeee8eee88e8eee8eeee8eeeeeeee8ee81c7cc7c11c7777c17c77c770777c7770cccc00008b77779889777798000999807005700500000000
8eee8eeeeeeee88eeeee8ee88eeee8eeeee8eeeee8eeeee81c7cc7c11c7777c1777c777077c7c7700cc0000087b7797887977978007999807050070500000000
8eeeeeeeeeeeeeeee88eeee88eeeeeeeeeeeeeeeeeeeeee81cccccc11cc77cc1077777000777770000000000877b977887799778077999807500007500000000
8eeeeeeeeeeeeeeeeeeeeee88888888888888888888888881cccccc11cccccc10000000000000000000000008888888888888888777999805777555700000000
8eeeeeeeeeeeeeeeeeeeeee8888888888eeeeee88eeeeee800000000000000000000000000000000000000000000000000000000000000000000000000000000
888eeeeeeee88eeeeeeee8e88eeeeee88eeeeee88eeeeee800000000000000000000000000000000000000000000000000000000000000000000000000000000
8ee8eeeeeeee88eeeeee8ee88eeeeee88e8eeee88e8eeee800000000000000000000000000000000000000000000000000000000000000000000000000000000
8eeee8eeeeeeeeeeeeeeeee88e88eee88ee8eee88e8eeee800000000000000000000000000000000000000000000000000000000000000000000000000000000
8eeeeeeeeeeeeeeeeeeeeee88ee8eee88eeeeee88eeeee8800000000000000000000000000000000000000000000000000000000000000000000000000000000
8eeee8eee88eeeeee888eee88eeee8e88eeeeee88eee88e800000000000000000000000000000000000000000000000000000000000000000000000000000000
8ee88eeeeeeee8eeeeee8ee88eeeeee88ee888e88eeeeee800000000000000000000000000000000000000000000000000000000000000000000000000000000
8eeeeeeeeeeeeeeeeeeeeee88eeeeee88eeeeee88888888800000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888888888888888888888888888888888888777777877777777777877777777778777877777787777777777877777777778
87777777777777777777787777777778777777777787777777777777787777788777777877777877777877777777778777877777787777777777877777777778
87777777777777777777787777777778777777777787777777777777787777788777777877777877777877777777778777877777787777778888877777778888
87777777777777777777787777777778777777777787777777777777787777788777777877777877777877777777778777877777787777777777877777777778
87777777777777777777787777777778777777777787777777777777787777788777777888888887777877777777778777877777787777777777877787777778
87777777777777777777787777777778777777777787777777777777787777788777777777777787777877787777778777877777787777777777877787777778
87777777777777777777787777777778777777777787777777777777787777788777777777777787777877787777778777877777787777777777877787777778
87777777777777777777787777777778777777777787777777777777787777788777777777777787777877787777778777877777787777777777877787777778
87777777777777777777787777777778777777777787777777777777787777788777777777777787777877787777778777777777787777777777877787777778
87777777777777777777787777777778777777777787777777777777787777788777777777777787777877787777778777777777787777777777877787777778
87777777777888888888887777777778777777777787777777777777787777788777777777777787777877787777778777777777787777777777877787777778
87777777777877777777787777777778777777777787777787777777787777788888888888888888888888888888888888888888888888888888888888888888
87777777777877777777787777777778777777777787777787777777787777780000000000000000000000000000000000000000000000000000000000000000
87777777777877777777787777777778777777777787777787777777787777780000000000000000000000000000000000000000000000000000000000000000
87777777777877777777787777778888888777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777877777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777877777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
87777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888888888888888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787777777777877777777778777777777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787777777777877777777778777777777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787777777777877777777778777777777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787778777777877777777778777777777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787778777777877777777778777877777780000000000000000000000000000000000000000000000000000000000000000
87777778777788877778777777877787778777777877777777778777877777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777877787778777777877777777778777877777780000000000000000000000000000000000000000000000000000000000000000
87777778777777777778777777777787778777777877777788888777877777780000000000000000000000000000000000000000000000000000000000000000
0000f10000000000e1e1d1d1d1d1031313131323d1d1d1d1d1d1d1d1e2e222000000000000000212122213121212131213121312131213121213131313130000
000000000000000000000000000000000000000000000000000000d10000b06200b000a00000c000a0c0000000000000000000000000000000000000000000d1
0000c00000f100001352000000000313131313230000000000000000e2e223000000000000000313132300000033000040122200004012e1e1e11260000033d1
d10000000000000000000000000000000000000000000000000000d10000405050505050505050505060000000000000000000000072000000000000000000d1
0000620000c00000520000d10000031313131323000000000000000003e213220000000000021313132300000043000000032300000003131313230000004300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000007200007262000000000000000000d1
00006200b062a000d100000000000313131313230000000000f100f1031313230000000002131313132300000043000000032300000003131313230000004300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000a06200a06262a00000000000000000d1
4050509050505060d100000000000313131313230000000000c0b0c0031313230000000032424242422300000043000000032300000003131313230000f14300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d100000000000040505050505050600000000000909090
000000f100000000d10000000000031313131313e1e1e112121212121313e2e2e2e2000000000000004300000043f1000003230000000313131323b000c04300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000000000000000000000000000000000d1
000000c0f1000000d100000000000313131313131313131313131313131313230000000000000000004300000043c0f10003230000b003131313131212122300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000000000000000000000000000000000d1
00f1f1c062720000d100000000000313131313131313131313131313131313237200000090900000904300000043c0c0b0031312121213131313131313132300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000000000000000000000000000000000d1
b0c062626262a000d1d1d1d1d1d1031313131313131313131313131313131323e200000090909090904300000003121212131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d100000000000000000000000000d1000000000000000000000000000000000000000000d1
90905050505050600000000000000000000000000000000000000000000013131212121212121212122300000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d1d1000000000000000000000000f100000000000000000000000000000000f100000000d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d100000000000072000000000000c0b0b00000000000000000f10000f10000c0f10000d1d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d1000000000000620000000000000212220000000000000000c0b0b0c0b0b0c0c0000000d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d1000000007200620000b000720003132300000072007200004050505050505060000000d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d10000a0a062a062a0a033a062a0031323a0b0a062a06200000000000000000000000000d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003131313131313131313131313131313132300
d10000000000000000000000000000000000000000000000000000d1d1d14050505050505042505050424242505050505060d1d1d1d1d1d1d1d1d1d1d1d1d1d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1d1d1031313131313131313131313131313131323d1
d10000000000000000000000000000000000000000000000000000d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1909090d1d1d1d1d1d1d1d1d1d1d1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000003424242421313131313131342424242132300
d10000000000000000000000000000000000000000000000000000000000000000000000d1d172d1d1d1d1d1d1d1d1d1d1d1000000d1d1d1d1d1d1d1d1d1d1f1
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000000342424242132300000000032300
d10000000000000000000000000000000000000000000000000000000000000000000000d100627200000000000000000000000000000000000000000000f1c0
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000004300000000032300000000032300
d10000000000000000000000000000000000000000000000000000000000000000000000d100626200000000000000000000000000000000000000000000c0c0
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000004300000000032300000000032300
d10000000000000000000000000000000000000000000000000000000000000000000000121212220072000000000000000000000000000000000000f1000212
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000004300000000032300000000032300
d10000000000000000000000000000000000000000000000000000000000000000000000131313230062000000000000000000000000000000000000c0000313
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000004300000000032300000000032300
d1000000000000000000000000000000000000000000000000000000000000000000000013131313121222a0a0000000000000000000000000b0b00212121313
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1000043000000b04300000000032300000000032300
d100000000000000000000000000000000000000000000000000000000000000000000001313131313131312122200a0000000000000b0000212121313131313
000000000000000000000000000000000000000000000000000000000000000000000000000000000000d1d1d153d1d1d14052d1d1909032529090d1d13252d1
d1000000000000000000000000000000000000000000000000000000000000000000000013131313131313131313e1e1e1e1e1e1e1e1e1e11313131313131313
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000007070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000070000
00000000000000000070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000707000
00000000000000000007000000000000000000000000000000600000000000000000000000000000000000000007000000000000000000000000000000070000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000700000070000000000000
00000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000088888888888888888888888888888888888888888888888888888888888888880000000000000000000000000000000000
00000000000000700000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000007000070000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000700000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777888888888887777777778777777777787777777777777787777780000000000000000000000000000000000
00000000000000000000000000000087777777777877777777787777777778777777777787777787777777787777780000000000000000000000000000000000
00000000000700000000000000000087777777777877777777787777777778777777777787777787777777787777780000000000000000000000000000000000
00000000007070000000000000000087777777777877777777787777777778777777777787777787777777787777780000000000000000000000000000000000
00000000000700000000000000000087777777777877777777787777778888888777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777877777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777877777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000000000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000070000000000000000000000000000
00000000000000000000000000000087777777777777777777787777777777777777777787777787777777777777780000707000000000000007000000000000
00000000000000000000000000000088888888888888888888888888888888888888888888888888888888888888880000070000000000000000000000000000
00000000000000000000000000000087777778777777777778777777877787777777777877777777778777777777780000000000000000000000000000000000
00000000000000000000000000000087777778777777777778777777877787777777777877777777778777777777780000000000000000000000000007000000
00000000000000000000000000000087777778777777777778777777877787777777777877777777778777777777780000000000000000000000000000000000
00000000000000000000000000000087777778777777777778777777877787778777777877777777778777777777780000000000000000000000000000000000
00000000000000000000000000000087777778777777777778777777877787778777777877777777778777877777780000000000000000000000000000000000
00000000000000000000000000000087777778777788877778777777877787778777777877777777778777877777780000000000000000000000000000000000
00000000000000000000000000000087777778777777777778777777877787778777777877777777778777877777780888888888887000000000000000000000
00000000000000000000000000000087777778777777777778777777777787778777777877777788888777877777788888888888888888000000000000000000
00000000000000000000000000000087777778777777777778777777777787778777777877777777778777777777788888888888888888880000000000000000
00000000000000000000000000000087777778777778777778777777777787778777777877777777778777777777788888888888888888888880000000000000
00000000000000000000000000000087777778777778777778777777777787778777777877777788888777777788888888888888888888888888000000000000
00000000000000000000000000000087777778777778777778777777777787778777777877777777778777777777788888888888888888888888880000000000
00000060000000000000000000000087777778888888877778777777777787778777777877777777778777877777788888888888888888888888888000000000
00000000000000000000000000000087777777777777877778777877777787778777777877777777778777877777788888888888888888888888888800000000
00000000000000000000000000000087777777777777877778777877777787778777777877777777778777877777788888888888888888888888888880000000
00000000000000000000000000000087777777777777877778777877777787778777777877777777778777877777788888888888888888888888888888000700
00000000000000000000000000000087777777777777877778777877777787777777777877777777778777877777788888888888888888888888888888800000
00000000000000000000000000000087777777777777877778777877777787777777777877777777778777877777788888888888888888888888888888880070
00000000000000000000000000000087777777777777877778777877777787777777777877777777778777877777788888888888888888888888888888888000
00000000000000000000000000000088888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088888888888888888888800
00070000000000000707007707070077077700770770000000000707077700000707077707070777000007770000007707070770088888888888888888888880
00707000000000000707070707070700007007070707000000000707070000000707070707070700000007070000070007070707088888888888888888888888
00070000000000000777070707070777007007070707000000000707077000000777077707070770000007770000070007070707088888888888888888888888
00000000000000000707070707070007007007070707007000000777070000000707070707770700000007070000070707070707088888888888888888888888
00000000000000000707077000770770007007700707070000000777077700000707070700700777000007070000077700770707088888888888888888888888
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088888888888888888888888
00000000000000000000000000000000000000000000000000000000000000000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000000000000000000000000000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000007000000000000000000000000000888888888888888888888888888888888888888888888888888888888
00070000000000000000000000000000000000000070700000000000007000000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000007000000000000000000000000008888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000000000000000000000000000000008888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000000000000000000000000700000008888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000000000007777777777777777777777777777777888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000777777777770000000000000000000008888888888777777777778888888888888888888888888888888888888
00000000000000000000000000000077777777000000000000000000000000000007008888888888888888888887777777788888888888888888888888888888
00000000000000000000000777777700000000000000000000000000000000000070708888888888888888888888888888877777778888888888888888888888
00000000000000000077777000000000000000000070000000000000000000000007008888888888888888888888888888888888887777788888888888888888
00000000000007777700000000000000000000000000000000000000000000000000008888888888888888888888888888888888888888877777888888888888
00000000077770000000000000000000000000000000000000000000000000000000008888888888888888888888888888888888888888888888777788888888
00000777700000000000000000000000000000000000007000000000000000000000008888888888888888888888888888888888888888888888888877778888
07777000000000000000000000000000000000000000000000000000000000000000000888888888888888888888888888888888888888888888888888887777
70000000000000000000000000000000000000000000000000000000000000000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000060000000000000000000000000000000700000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000606000000000000000000000000000007070000000000888888888888888888888888888888888888888888888888888888888
00000000000000000000000000060000000000000000000007777777777777777777777777777777888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000777777777777777777777777777777777777777777777777777778888888888888888888888888888888888888
00000000000000000000000000000007777777777777777777777777777777777777777777777777777777777777777777888888888888888888888888888888
00000000000000000000000007777777777777777777777777777777777777777777777777777777777777777777777777777777888888888888888888888888
00000000000000000007777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777888888888888888888
00000000000000077777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777788888888888880
00000000007777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777888888800
00000077777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777788800
00077777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777700
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77000777777007000700070007777700070707777707070707000707070007777777777777777777777777777777777777777777777777777777777777777777
77070777770777070700070777777707070707777707070707077707077077777777777777777777777777777777777777777777777777777777777777777777
77000777770777000707070077777700770007777707070707007700077077777777777777777777777777777777777777777777777777777777777777777777
77070777770707070707070777777707077707777707070007077707077077777777777777777777777777777777777777777777777777777777777777777777
77070777770007070707070007777700070007777770077077000707070077777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77700700070007070707070007777770077007000777070707070700070707000777077007070700777777077700070077007700070007777777777777777777
77077770777077070707070707777707770707000770770707070707770707707770770777070707077777077707070707070707770707777777777777777777
77077770777077000707070077777707770707070770770707070700770007707770770777070707070007077700070707070700770077777777777777777777
77070770777077070707070707777707770707070770770707000707770707707770770707070707077777077707070707070707770707777777777777777777
77000700077077070770070007707770070077070707777007707700070707007707770007700707077777000707070707000700070707777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777

__gff__
0000080801010101011102040400000000000000000000000000000000801104010101010101020200000010100001000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d00000000000000303131312424242424242424242424242431000000000000000000001d1d1d1d1d1d1d1d20221d1d1d20221d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d
1d001d000000000000001d000000001d00000000001d000000000000001d000000000000000000001d1d00000000000000302424250000000000000000000000000030000000000000000000001d000000000000003032000000303200000000000000001d001d1d000000000000000000000000000000001d0000000000001d
1d0000000000000000001d000000001d0000000000000000000000000000000000000000000000001d1d00000000000020250000000000000000000000000000000030000000000000000000001d00000000000000303200000030320000000000000b001d001d1d00000000000000000000000000000000000000000000001d
1d0000000000000000001d090909091d0000000000000000000000000000000000000000000000001d1d00000000000425000000280000000000000000000000000030000000000000000000001d00000000000000303200001e313200000000002021221d001d1d00000000000000000000000000000000000000000000001d
1d0000002800000000001d000000001d2200000000000000000000000000000000000000000000001d1d00000000000000000000000000000000000000000000000030000000000000000000001d00000b000000003032000000303200002021052424251d001d1d00000000000000001f00000000000000000000000000001d
202122000000000000001d000000001d3200000000000000000000000000280000000000201e1e1e1d1d00000000000000000000000000200505060000000000002031000000000000000000001d001d202200000030320000003032000030320000000000001d1d00000000000000000c00000000000000000000000000001d
232431220028000000001d000000001d3200000000000000000000000000000000000000303131321d1d00000000000000000000000000340000000000000000003031000000000000000000001d0000303200000030320000002325000030320000000000001d1d00000000000000000c0b1f000000000000000000000b001d
1d0023312200000000001d000000001d320000000000000000000000000000000000000030313131321d00000000000000000000000000340000000000000000003031000000000000000000001d0000303200000030320000000000000030320000000000001d1d00000000000000200505052200000000000000000020221d
1d0000233200000000001d000000001d320000000000000000000000000000000000000030313131321d00000000000405220000000000340000000000000000003031000000000000000000001d0000303200000030320000000000000030320000000000001d1d000000000020052500000023060000000000000000303122
1d00000030211e1e1e221d000000001d320000001f00000000000000000000000000000030313131321d00000000000000232200000000340000000000000000203131000000000000000000001d0000232500000030320000000000000023250000000000001d1d000000002025000000000000003300000000000000233132
1d1d1d1d2324242424251d1d1d1d1d1d320000000c00000000000027000000000000002031313131321d1d1d1d1d1d1d1d1d2305050505241e1e1e0505050505242424000000000000000000001d0000000000000030310600002022000000000000000000001d1d000020052500000000000000002305220000000000003032
000000000000001d000000000000001d32000b000c000000000a00260a000000000000303131313132001d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d0000000000000000000000000000001d0000000000000030320000003032000000000000000000001d1d002025000000000000000000000000232200000000002325
000000000000001d000000000000001d31212121220000002021212122000000000000303131313132001d0000000000000000000000000000000000001d0000000000000000000000000000001d0000000000000030320000003032000000000000000000001d1d0035000000000000270a0000000000002322000000000000
002700000000001d000000000000001d24242424251d1d1d23242424251d1d1d1d1d1d232424242425001d0000000000000009090900000000000000001d0000000000000000000000000000001d000421220b0000303200000b3032000020210600000000001d1d330000000000000026202200000000000023060000000000
00260b00000000001d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d0000000000000000000000000000000000001d0000000000000000000000000000001d000030310600003032000004313200003032000700000909091d340000000000002021313122000000000000000000000000
05050600000000001d0000000000000000000000000000000000000000301d000000000000000000001d1d0000000000000000000000000000000000001d0000000000000000000000000000001d000030320000002325000000303200003032000000001d001d2132001e1e1e00203131313132000000000000000000000000
00000000000000001d0000000000000000000000000000000000000000301d00000000001f0000001d1d1d0000000000000000000000000000000000001d0000000000000000000000000000001d000030320000000000000000303200003032000000001d001d31312124242405313131313131220000000000000000000000
00000000000027001d0000000000000000000000000000000000000000301d00001f1f000c001f00001d1d00000000000000000000000000001f0000001d0000000000000000000000000000001d000030320000000000000000303200003032000000001d001d31312500000000233131313131250000000000000000000000
00000000000b260b1d0000000000000000002700000000000000000000301d001f0c0c1f0c1f0c00001d1d00000000000000000000000000000c0000001d0000000000000000000000000000001d000030320000000000000000303200003032000000001d001d3132000000000000232424242500000000000000000000001f
00000000000405061d00000000000000002726000000000000000000003020220c0c0c0c0c0c0c0000331d00000000000000000000000b000b0c0000001d0000000000000000000000000000001d0000303200000020220000002325000023251d0000001d001d3131220000000000000000000000000000000007000000000c
00000000000000001d00000000000000002626270000000000000000003030320c0c0c0c0c0c0c0020321d000000202121212121212121212121212121210000000000000000000000000000001d000b303200000030320000000000000000001f0000001d001d31313122000000000000000000000000002006000000002022
00270000000000001d000000000000002e2e2e2e0a0000000000000000303031220c0c0c0c0c0c2031321d000020313131313131313131313131313131310000000000000000000000000000001d000431321f000030320000000000000000000c001f001d001d31313131220000000000000000000000003500000000203132
0b260b00000000001d1d1d1d1d1d1d04222e2e2e2e1d1d1d1d1d1d1d1d303031320c0c0c0c0c203131321d00002e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e0000000000000000000000000000001d000030320c000b30320000000000000000000c0b0c0b1d001d313131313122000000001f0000000020060000000004242425
05050600000000001d0000000000000030212122000000000000000000303031320c0c0c0c0c303131321d000000000000000000000000000000000000300000000000000000000000000000001d1d1d23240505052425000000202200000000040505061d001d313131313132000000000c1f00000034000000000000000000
00000000000000001d00000000000000303131312106001f0b0000002031303131220c0c0c20313131321d000000000000000000000000000000000000300000000000000000000000000000001d1d1d1d1d1d1d1d1d1d09090424251d1d1d1d1d1d1d1d1d1d1d3131313131312122000b0c0c00002025000000000000000000
00000000000027001d0000000000000030313131322e2e2e2e0000003031303131320c0c2031313131321d00000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000031313131313131312121212121213200000000000000000909
00000000000b260b1d0000000000000023242424252e2e2e000000003031303131311e1e313131313132220000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000001d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d
00000000000405061d001d00000000002e2e2e2e2e2e2e0000001d002e311d1d1d1d1d1d1d1d1d1d1d1d320000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000001d000000000000000000000000001d0000000000000000000000000000000000000000001d
00000000000000001d00000000000000002e2e2e2e000000000000002e2e1d000000000000000000001d320000000000270000002700000000000000003000000000000000000000000000000000000000000000000000000000001d000000000000000000000000001d0000000000000000000000000000000000000000001d
00270000000000001d000000000000002021212121220000000000002e2e1d0000000000000000001d1d320000000a0026000a0026000a0000000000003000000000000000000000000000000000000000000000000000000000001d000000000000000000000000001d0000000000000000000000000000000000000000001d
0b260b00000000001d001d000000002031313131312500000000000030311d000000000000000000001d320000002e002e002e002e002e0000001e1e1e3100000000000000000000000000000000000000000000000000000000001d000000270000000000000000001d0000000000000000000000000000000000000000001d
05050609090909091d001d000000203131313131250000000000000030311d1f1f1f1f1f1f1f0000001d32000000330b330b330b330b330b00203131313100000000000000000000000000000000000000000000000000000000001d000000260000000000001f00001f0000000000000000000000000000000000000000001d
__sfx__
370e00000b0730b0450b0450b0450b0730b0450b045107750b0730b0450b0450b0450b0730b0451c7450b0450b0730b0450b0450b0450b0730b045177450b0450b0730b0450b0450b0450b0730b0450b04517745
4b0e00003f605016053f6253e61538600336053f625326053f605016053f6253f605386003f6153f625326053f605016053f6253e61538600006053f6253f6053f605016053f6253f60538600006053f6253f615
ad0e0000344053440534405123353040512335133353040533405334053340533405304051f3351d4051d405304052e405324052d405143051c335304052e40533405334051e3052e4051c3351e3350840508405
6f0e0000344053440534405123353040512335133353040533405334053340533405304051f3351d4051d405304052e405324052d405143051c335304052e40533405334051e3052e4051c3351e3350840508405
010a00003f6003e6003b600376002f6002860023600156000c6010360100601226011a601126010b601026012e60129601256011f6011a601156010f601096010060100601006010060100601006010060100601
010700002370423704237042370423700237002370023700247042470424704247040070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010700000060000601006010060100601006010060100601006010060100601006010060100601006010060100601006010060100601006010060105601096000b60010600126001a60020600296003060000000
011400000900000700007000070009000007000070000700090000070000700007000900000700007000070009000007000070000700090000070000700007000900000700007000070009000007000070000700
1d14000018742187421874218742187421874218742187421874218742187421874218742187421a7421b7421b7421b7421b7421b7421b7421b7421d7421f7421f7421f7421f7421f74222742227421f74214742
1d1400001474214742147421474214742147421474214742147421474214742147421474214742147421d7421d7421d7421d7421d7421d7421d7421d7421b7421b7421b7421b7421b7421b7421b7421b7421d742
1d1400001d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421d7421b7421b7421b7421b7421b7421b7421b7421b7421d7421d7421d7421d7421d7421d7421d7421d7421f742
1d1400001f7421f7421f7421f7421f7421f7421f7421f7421f7421f7421f7421f7421f7421b7421b7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a7421a742
011400000907300765007650076509073007650076500765090730076500765007650907300765007650076509073007650076500765090730076500765007650907300765007650076509073007650076500765
011400000907308765087650876509073087650876508765090730876508765087650907308765087650876509073087650876508765090730876508765087650907308765087650876509073087650876508765
011400000907305765057650576509073057650576505765090730576505765057650907305765057650576509073057650576505765090730576505765057650907305765057650576509073057650576505765
011400000907307765077650776509073077650776507765090730776507765077650907307765077650776509073077650776507765090730776507765077650907307765077650776509073077650776507765
031400003f6053f6153f6253f615386353f6153f6253f615326053f6153f6253f615386353f6153f6253f615346053f6153f6253f615386353f6153f6253f615117003f6153f6253f615386353f6153f6253f615
1d14000024722247222472224722247222472224722247222472224722247222472224722247222672227722277222772227722277222772227722297222b7222b7222b7222b7222b7222e7222e7222b72220722
1d140000207222072220722207222072220722207222072220722207222072220722207222072220722297222972229722297222972229722297222972227722277222772227722277222772227722277221d722
1d1400001d7221d7221d7221d7221d7221d7221d7221d7221d7221d7221d7221d7221d7221d7221d722277222772227722277222772227722277222772229722297222972229722297222972229722297222b722
1d1400002b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222c7222c7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b7222b722
1b1400003b6213662131621296211f62113621006010060100601006010670105701017010070100701007010070100701007010070100701007010070110741117411374115741187411a7411c7412074123741
2f1400001b7321b7321b7321b7321b7321b7321b7321b7321b7321b7321b7321b7321b7321b7321d7321f7321f7321f7321f7321f7321f7321f73220732227322273222732227322273227732277322573218732
2d14000018732187321873218732187321873218732187321873218732187321873218732187321873220732207322073220732207322073220732207321f7321f7321f7321f7321f7321f7321f7321f73218732
2d1400001873218732187321873218732187321873218732187321873218732187321873218732187322073220732207322073220732207322073220732227322273222732227322273222732227322273224732
2d1400002473224732247322473224732247322473224732247322473224732247322473220732207321f7321f7321f7322b7221f7322b7221f7321f7322b7221f7321f7322b7221f7322b7221f7321f7321f732
1d1400001474214742147421474214742147421474214742147421474214742147421474214742147421d7421d7421d7421d7421d7421d7421d7421d7421b7421b7421b7421b7421b7421b7421b7421b74211742
1d1400001174211742117421174211742117421174211742117421174211742117421174211742117421b7421b7421b7421b7421b7421b7421b7421b7421d7421d7421d7421d7421d7421d7421d7421d7421f742
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31160000130551505516055180551a0551b0551e0551f05522055210551f0551b0551a055180551605515055130551505516055180551a0551b0551e0551f05522055210551f0551b0551a055180551605515055
2d1600000757207572075720757507572075720757507572075720757207572075750557205572055720357203572035750357203575035720357203575035720357203572035720357502572025720257200571
451600000057200572005720057500572005720057500572005720057200572005750057200572005720a5710a5720a5720a5720a5720a5720a5720a5720a5720957209572095720957209572095720957209572
25160000070733f6003e0153e015070733d0053c0153c015070733e0053e0153e015070733c0153c0003c015070733e0053e0153e015070733d0053c0153c015070733e0053e0153e015070733c0153c0003c015
131600003f6253f6043f6143f6203f6153f6043f6143f6213f615000003f6143f6203f615000003f6143f6213f615000003f6113f6203f615000003f6143f6213f615000003f6143f6203f615000003f6143f621
010f00000c0730000000000000002263500000000000c0000c000000000c07300000226350000000000000000c073000000000000000226352d600000000c0000c000000000c07300000226350c0730000000000
970f00003f6153f6003f615000003f6153f6003f615000003f6153f6153f6153f6003f6153f6003f6153f6153f6153f6003f6153f6003f6153f6153f6153f6003f6153f6003f6153f6003f6153f6003f6153f615
530f00000b300013000433504300043000433508300043350030000300033351033500300003000e335003000e3350e3000030000300043350433500300043350030000300003350030000300043350030005335
810f000023530195301c5301f530205322053220532205320050000500005000050023500195001c5001f50023500195001c5001f500005000050000500005000050000500005000050023500195001c5001f500
010f000023545195451c5451f5452054520545205002054520500005001e5451e5451e545195001c5451f5001c545195001c5001f5001a5451a5451a5001a5450050000500195451a500235001a5451c5001c545
010f00000c0000000000000000002263500000000000c0000c000000000c00000000226350000000000000000c000000000000000000226352d600000000c0000c000000000c00000000226350c0000000000000
010f00000c0730000000000000002263500000000000c0000c000000000c07300000226350000000000000000c000000000000000000236002d600000000c0000c000000000c00000000236350c0530c07300000
010f18000f0733e6053e6050f0733e6053e6050f0733e6050b0430f0730b0030b0030f0733e6053e6050f0733e6053e6050f0733e6050b0430f0730b0000b0000000300003000030000300003000030000300003
010f18000f0733e6053e6050f0733e6053e6050f0733e6050b0430f0730b0030b0030f0733e6053e6050f0733e6053e6050f0733e6050b0430f0730b0430b0430000000000000000000000000000000000000000
011000000f0003e6003e6000f0003e6003e6000f0003e6000b0000f0000b0000b0000f0003e6003e6000f0003e6003e6000f0003e6000b0000f0000b0000b0000000000000000000000000000000000000000000
110f18000604006040060450604006040060450604006040060450604006040090400604006040060450604006040060450404004040040450404004040050400000500005000050000500005000050000500005
110f18000b0400b0400b0450b0400b0400b0450b0400b0400b0450b0400b0400e0400b0400b0400b0450b0400b0400b04509040090400904509045090450a0400000000000000000000000000000000000000000
0d0f18001e0252102523025210251e025210251e025240251e0251c0251e025210251e0251c025250251e0251c025230251e025210251c025190251c025210250000500005000050000500005000050000500005
150f18001e0252102523025210251e025210251e025240251e0251c0251e025210251e0251c025250251e0251c025230251e025210251c025190251c025210252400000000000000000000000000000000000000
090f18003f6033f6033f603216233f6033f6033f6033f6033f603216233f6033f6033f6033f6033f603216233f6033f6033f6033f60322603216233f6033f6033560300603006030060300603006030060300603
081000002a6003060035600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000296142e610356150000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0600000c6600c6600c6600c66005600056000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800002f07500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
3d0b000032055370753c0000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
3912000028052280521b0511005110052100521005210002110001100011000110001100011000110001100011000110001100000002000020000200002000020000200002000020000200002000020000200002
0b0600003c6213c6213c6213c6213c6213c6013c6013c601000000000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001
07100000241432d1030a1032710300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103
331000003b6713667131671296711f671136710060100601000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000
070e000000600006000060000600006000060000600006000060000600006000060000600006000060001600056200562006620086200a6200d6200f6201262014621186211c62121621266212c6213162137621
230600003f651356512d6511e65111651056011660109601006000160000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
__music__
01 0041427d
00 00404344
00 00424344
00 00424144
00 00014140
00 00014140
00 00014140
00 00014140
00 00010244
00 00010244
00 00010244
00 0001027e
00 00010344
00 00010344
00 00010344
02 00010344
01 0c081044
00 0d1a1044
00 0e1b1044
00 0f0b1015
00 0c081016
00 0d091017
00 0e0a1018
02 0f0b1019
01 20232463
00 20232163
00 20232261
00 20232162
02 20232261
00 60636262
00 60626463
02 60626463
01 25266768
00 25266768
00 25262769
00 25262769
00 25262769
00 2a262769
00 25262728
00 25262728
00 25262728
00 2b262728
00 25262729
00 25262729
00 25262729
00 2a262729
00 25262729
00 25262729
00 25262729
02 2a262729
01 2c2f7373
00 2d2f7373
00 2d307344
00 2d307344
00 2c2f3173
00 2d2f3173
00 2d303144
00 2d303144
00 2c2f3332
00 2d2f3332
00 2d303332
00 2c303332
00 2c2f3373
02 2d2f3334

