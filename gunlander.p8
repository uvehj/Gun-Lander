pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--debug/config variables
debug = false
shotspeed = 3
gravity = 4
fps = 30
reset_progress = 0
--global variables
total_levels = 14
unlocked_levels = 1
ship = {}
level = {}
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
    cartdata("uvehj_gun_lander")
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
    load_level(0,false)
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
function create_level_lists()
    level.enemylist = {}
    level.friendlist = {}
    local x = level.startx
    while x <= level.endx do
        local y = level.starty
        while y <= level.endy do
            if fget(mget(x,y),2) then
                add(level.enemylist,{x,y,mget(x,y)})
            end
            if fget(mget(x,y),5) then
                add(level.friendlist,{x,y})
                --mset(x,y,0)
            end
            y += 1
        end
        x += 1
    end
    level.numenemy = #level.enemylist
    level.numfriend = #level.friendlist
end
--restores destroyed enemies to the map sheet, also restores ammo and enemy counters
function restore_level()
    bullets = {}
    level.ammo[3] = level.ammo[2]
    level.numenemy = #level.enemylist
    level.numfriend = #level.friendlist
    for tile in all(level.enemylist) do
        mset(tile[1],tile[2],tile[3])
    end
    for pod in all(level.friendlist) do
        mset(pod[1],pod[2],42)
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
    map(level.startx,level.starty,0 - camx,9 - camy,level.w,level.h)
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
    circfill(100,level.h*8-camy-30,30,8)
    circ(64,level.h*8-camy+210,242,7)
    circfill(64,level.h*8-camy+210,230,7)
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
    --ian wip
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
        print("missed landing pad!",24,62,8)
    elseif level.state == -1 then
        print("nice landing!",42,62,8)
    end
    if level.state > 0 then --fail states
        print("press \151 to restart",28,72,8)
    else                    --win states
        print("\151 start next level",28,72,8)
    end
end
--header with counters
function draw_header()
    rectfill(0,0,8*16,8,1)
    --level number
    print("lvl",2,2,7)
    --enemy counter
    print(level.number,14,2,7)
    if #level.enemylist > 0 then
        print(level.numenemy,32,2,7)
        print("\138",32+(#tostr(level.numenemy)*4),2,7)

    end
    --friendly pod counter
    if #level.friendlist > 0 then
        print(level.numfriend,64,2,7)
        print("\140",64+(#tostr(level.numfriend)*4),2,7)
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
            load_level(menuselectlevel,false)
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
            if level.state > 0 then
                load_level(level.number,true)
            elseif level.state < 0 then
                if level.number < total_levels then
                    unlocked_levels = max(unlocked_levels,level.number+1)
                    dset(0,unlocked_levels)
                    load_level(level.number+1,false)
                else
                    load_level(-1,false)
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
        load_level(0,true)
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

--ian wip
function gameplaymusic() --play gameplay music, if not already playing
    if stat(24)<0 or stat(24)>15 then
        music(0,0,7) --play gameplay music, reserve ch.0-2
    end
end

--level info--
--build_level(lvlnum,startx,starty,endx,endy,camoffset{x,y},lgravity,shipstart{x,y},ammo{is limited,number},restart,messages)
--l is level number, r is level restart (true of false)
--start and end coordinates are as displayed by the map tab
function load_level(l,restart)
    --level music
    if l > 0 then --gameplay beep and song
        sfx(56,3) --play menu beep sfx on ch.3
        gameplaymusic() --call gameplaymusic function
    elseif l == 0 then
        music(24,0,7) --play main menu music, reserve ch.0-2
    elseif l == -1 then
        music(16,0,7) --play credits music, reserve ch.0-2
    end
    --level build
    if l == 0 then
        build_level(l,0,0,15,14,{0,0},1,{0,0},{false,0},{{"houston, we have a gun",2,8.2}})
    elseif l == -1 then
        build_level(l,0,0,15,14,{0,0},1,{0,0},{false,0},{{"thanks for playing!",3,6},{"more levels to come",3,9}})
    elseif l == 1 then
        build_level(l,0,0,10,10,{0,0},0,{2,1},{false,16},{{"land here",5,8}})
    elseif l == 2 then
        build_level(l,10,0,15,10,{-3,0},0,{12,9},{false,16},{{"up here!",12,2},{"\142shoot!",11,9}})
    elseif l == 3 then
        build_level(l,10,0,15,10,{-3,0},2,{12,9},{false,16},{{"beware gravity ;)",11,9}})
    elseif l == 4 then
        build_level(l,10,3,15,10,{-1,0},1,{12,11},{false,16},{{"do a blind landing",11,6}, {"no ceiling here",16,3}})
    elseif l == 5 then
        build_level(l,29,0,40,13,{-2,0},0,{31,8},{true,2},{{"keep an eye on your ammo",30,3}})
    elseif l == 6 then
        build_level(l,21,0,40,13,{0,-1},1,{22,5},{false,0},{{"don't shoot us",24,9}})
    elseif l == 7 then
        build_level(l,16,0,40,13,{0,-1},1,{22,5},{false,0},{{"destroy the enemy",17,8}})
    elseif l == 8 then
        build_level(l,16,0,40,13,{0,-1},1,{22,5},{true,15},{{"a bit harder ;)",22,4}})
    elseif l == 9 then
        build_level(l,41,0,66,10,{0,0},1,{43,4},{false,0},{{"into the cave",46,5}})
    elseif l == 10 then
        build_level(l,2,12,5,31,{-6,0},1,{3,11},{false,0},{{"easy",3,13}})
    elseif l == 11 then
        build_level(l,2,12,5,31,{-6,0},2,{3,11},{false,0},{{"faster",3,13}})
    elseif l == 12 then
        build_level(l,1,12,6,31,{-5,0},1,{3,11},{false,0},{{"harder",3,13}})
    elseif l == 13 then
        build_level(l,1,12,6,31,{-5,0},2,{3,11},{false,0},{{"not so easy",3,13}})
    elseif l == 14 then
        build_level(l,0,12,7,31,{-4,0},1,{3,11},{false,0},{{"precision",3,13}})
    end
    --new level initializations
    if restart == false then
        init_background()
        create_level_lists()
    end
end

__gfx__
0cccc00008800000000000000505550588888888888888888888888888888888700070007c7cc7cc00011000000000a9a999999a00c00000cccc000000c00000
cc77cc008778000000000000055505558777777777777777778777788777787807070000c70000c701111110000a9999a9777a9a0ccc0000ccc000000cc00000
cccccc008778000000000000655055508777777777787777777877788777877800700000c0700c0711cccc11a9999999a9777a9accccc000cc000000ccc00000
001100000880000006606000550550508778777777778777777776788777777800000000c007c007cccccccc99999999a999999a00000000c00000000cc00000
0cccc0000000000005565060555555058787777777778777777777788777777800000000700c700cccccc77c97979999a9777a9a000000000000000000c00000
c0660c00000000006505565655050555877777777887777777777878888877780000000070c0070ccc77c77c99799779a9777a9a000000000000000000000000
c0660c0000000000550505550555555587777777777777777778877887778778000000007c00007ccc77cccc97979779a999999a000000000000000000000000
700007000000000050550050055500558888888888888888888888888888888800000000c777ccc7cc77cccc99999779a999999a000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005000050087778887cccccccc000a0000
00000000000000000000000000000070000000000000007000000000000000000000000000070000000000000000000000660000780000787c0007c0aaaaaaaa
000000000000000000070000000000000000000000000000000000000000000000000000007070000000000000000000560065007080070807c07c00a999999a
0000000000700000007070000000000000000000000000000007000000000000000000000007000000000000000000005000050070087008007cc000a977779a
000007000000000000070000000000000000000000000000000000000000000000000700000000000000000000000000066665008007800777777777a977779a
000070700000000000000000070000000000000000000000000000000000000000000000000000000000070000000000000000008070080777777777a999999a
000007000000007000000000000000000007000000000000000000000700000000000070000000000000000000000000056650008700008777777777a977779a
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500005007888777877777777a977779a
8888888888888888888888888777777777777777777777781cccccc10001100007777700077777000cc000008888888888888888000000000000000000000000
8777777777777777777777788777777778877777777788781c7cc7c1011cc110777c7770777c7770c7cc0000877b9778877bb778000000800000000000000000
8777787778777777777777788778777777777777777777781c7cc7c11cccccc17c77c77077c7c770cccc000087b7797887b77b78000009800000000000000000
8777777778877777777777788787777777778777777877781cccccc11cc77cc177c77c707c777c70777700008b7777988b7777b8000099800000000000000000
8778777778777877777877788787778777787777777787781c7cc7c11c7777c17c77c770777c7770cccc00008b77779889777798000999800000000000000000
8777877777777887777787788777787777787777787777781c7cc7c11c7777c1777c777077c7c7700cc0000087b7797887977978007999800000000000000000
8777777777777777788777788777777777777777777777781cccccc11cc77cc1077777000777770000000000877b977887799778077999800000000000000000
8777777777777777777777788888888888888888888888881cccccc11cccccc10000000000000000000000008888888888888888777999800000000000000000
87777777777777777777777888888888877777788777777800000000000000000000000000000000000000000000000000000000000000000000000000000000
88877777777887777777787887777778877777788777777800000000000000000000000000000000000000000000000000000000000000000000000000000000
87787777777788777777877887777778878777788787777800000000000000000000000000000000000000000000000000000000000000000000000000000000
87777677777777777777777887887778877877788787777800000000000000000000000000000000000000000000000000000000000000000000000000000000
87777777777777777777777887787778877777788777778800000000000000000000000000000000000000000000000000000000000000000000000000000000
87777877788777777888777887777878877777788777887800000000000000000000000000000000000000000000000000000000000000000000000000000000
87788777777778777777877887777778877888788777777800000000000000000000000000000000000000000000000000000000000000000000000000000000
87777777777777777777777887777778877777788888888800000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000080801010101011102040400000000000000000000000000000000801104010101010101020200002010100000000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d0000000000000030313131242424242424242424242424243100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d001d000000000000001d000000001d00000000001d000000000000001d000000000000000000001d1d0000000000000030242425000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d0000000000000000001d000000001d0000000000000000000000000000000000000000000000001d1d0000000000002025000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d0000000000000000001d090909091d0000000000000000000000000000000000000000000000001d1d0000000000042500000028000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d0000002800000000001d000000001d22000000000000000000000000000000002a0000000000001d1d0000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
202122000000000000001d000000001d3200002a00000000002a00000000280000000000201e1e1e1d1d0000000000000000000000000020050506000000000000203100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
232431220028000000001d000000001d3200000000000000000000000000000000000000303131321d1d0000000000000000000000000034000000000000000000303100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d0023312200000000001d000000001d320000000000000000000000000000002a00000030313131321d0000000000000000000000000034000000000000000000303100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d0000233200000000001d000000001d320000000000000000000000000000000000000030313131321d0000000000040522000000000034000000000000000000303100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d00000030211e1e1e221d000000001d320000001f00000000000000000000000000000030313131321d0000000000000023220000000034000000000000000020313100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d1d1d1d2324242424251d1d1d1d1d1d320000000c00000000000027000000000000002031313131321d1d1d1d1d1d1d1d1d2305050505241e1e1e050505050524242400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000001d000000000000001d32000b000c000000000a00260a000000000000303131313132000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000001d000000000000001d31312121220000002021212122000000000000303131313132000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
002700000000001d000000000000001d24242424251d1d1d23242424251d1d1d1d1d1d232424242425000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00260b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000b260b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000040506000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0027000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b260b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000b260b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000040506000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0027000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b260b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505060909090909000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
1d1400001474214742147421474214742147421474214742147421474214742147421474214742147421d7421d7421d7421d7421d7421d7421d7421d7421b7421b7421b7421b7421b7421b7421b7421b74211742
1d1400001174211742117421174211742117421174211742117421174211742117421174211742117421b7421b7421b7421b7421b7421b7421b7421b7421d7421d7421d7421d7421d7421d7421d7421d7421f742
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
1b1400003b6213662131621296211f6211362100601006010060100601067010570101701007010070100701007010070100701007010070100701007011874118741197411b7411c7411d7411f7412074124741
001000001d7001d7001d7001d7001d7001d7001d7001d7001d7001d7001d7001d7001d7001d7001d700277002770027700277002770027700277002770029700297002970029700297002970029700297002b700
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30160000130551505516055180551a0551b0551e0551f05522055210551f0551b0551a055180551605515055130551505516055180551a0551b0551e0551f05522055210551f0551b0551a055180551605515055
2d1600000757207572075720757507572075720757507572075720757207572075750557205572055720357203572035750357203575035720357203575035720357203572035720357502572025720257200571
451600000057200572005720057500572005720057500572005720057200572005750057200572005720a5710a5720a5720a5720a5720a5720a5720a5720a5720957209572095720957209572095720957209572
25160000070733f6003e0153e015070733d0053c0153c015070733e0053e0153e015070733c0153c0003c015070733e0053e0153e015070733d0053c0153c015070733e0053e0153e015070733c0153c0003c015
131600003f6253f6043f6143f6203f6153f6043f6143f6213f615000003f6143f6203f615000003f6143f6213f615000003f6113f6203f615000003f6143f6213f615000003f6143f6203f615000003f6143f621
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00 0d091044
00 0e0a1044
00 0f0b1015
00 0c081011
00 0d091012
00 0e0a1013
02 0f0b1014
01 20232463
00 20232163
00 20232261
00 20232162
02 20232261
00 60636262
00 60626463
02 60626463

