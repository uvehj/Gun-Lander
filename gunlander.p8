pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--debug/config variables
debug = false
shotspeed = 3
gravity = 4
fps = 30
reset_progress = 0
--global variables
total_levels = 2
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
    ship.w = 6
    ship.s = 0
    ship.sx = 0
    ship.sy = 0
    ship.ac = 0
    ship.crashed = 0
    ship.thrusters = {0,0}
    load_level(0,false)
    init_background()
end
--------------------
--level management--
--------------------
--build_level should only be called from load_level()
function build_level(lvlnum,startx,starty,endx,endy,lgravity,shipstart,ammo,messages)
    --init level parameters
    level.number = lvlnum
    level.startx = startx
    level.starty = starty
    level.endx = endx
    level.endy = endy
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
--draw sprite correctly, o.x and o.y are position (in pixels) on the map
--draws relative to the camera position
--o.s is the sprite of the object
function draw_object(o)
    spr(o.s,o.x - camx,o.y+9-camy)
end
function draw_ship()
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
    draw_arrow()
    draw_thrusters()
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
        spr(13,ship.x,9)
    elseif ship.y > (camy+119) then
        spr(13,ship.x,120,1,1,false,true)
    elseif ship.x < (camx-ship.w) then
        spr(15,0,ship.y,1,1,false,false)
    elseif ship.x > (camx+128) then
        spr(15,120,ship.y,1,1,true,false)
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
    print("a game by uvehj",2,116,0)
    print("github.com/uvehj/gun-lander",2,122,0)
    if menustate == 1 then
        rectfill(30,86,94,94,8)
        rectfill(31,87,93,93,7)
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
    elseif level.state == -1 then
        print("nice landing",42,62,8)
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
    elseif menustate == 1 then
        if (btnp(5) or btnp(4)) then
            menustate = 0
            load_level(menuselectlevel,false)
        elseif btnp(0) and menuselectlevel > 1 then
            menuselectlevel -= 1
        elseif btnp(1) and menuselectlevel < unlocked_levels then
            menuselectlevel += 1
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
            local contact_points = {{((ship.x+2)/8)+level.startx,((ship.y+ship.h-1)/8)+level.starty},{((ship.x+ship.w-3)/8)+level.startx,((ship.y+ship.h-1)/8)+level.starty}}
            for p in all(contact_points) do
                if fget(mget(p[1],p[2]),4) != true then
                    level.state = max(level.state, 1)
                end
            end
            if level.state == 0 then
                if #level.enemylist !=0 and level.numenemy != 0 then 
                    level.state = 3
                else
                    level.state = -1
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
    elseif (btnp(1)) then
        x = 50
        ship.thrusters[1] = 16
    end
    --y acceleration
    if (btnp(4)) then
        if (level.ammo[1] and level.ammo[3] > 0) or level.ammo[1] == false then
            level.ammo[3] -= 1
            y = -80
            spawn_bullet(ship)
            ship.ac = 6
        end
    end
    update_speed_move(ship, x, y)
    ship.sx = ship.sx * (1-(0.2/fps)) --drag
    ship.sx = max(min(ship.sx,4),-4)  --control ludicrous speeds
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
    movex(o,o.sx)
    movey(o,o.sy)
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
    local contact_points = {{((o.x)/8)+level.startx,((o.y)/8)+level.starty},{((o.x+o.w-1)/8)+level.startx,(o.y/8)+level.starty},{((o.x)/8)+level.startx,((o.y+o.h-1)/8)+level.starty},{((o.x+o.w-1)/8)+level.startx,((o.y+o.h-1)/8)+level.starty}}
    --enemy buildings
    enemycrash = 0
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),2) and pos[1] >= level.startx and pos[1] <= level.endx and pos[2] >= level.starty and pos[2] <= level.endy then
            mset(pos[1],pos[2],5)
            level.numenemy -= 1
            enemycrash = 1
        end
    end
    if enemycrash != 0 then
        return 3
    end
    --walls
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),0) and pos[1] >= level.startx and pos[1] <= level.endx and pos[2] >= level.starty and pos[2] <= level.endy then
            return 1
        end
    end
    --friendly buildings
    for pos in all(contact_points) do
        if fget(mget(pos[1],pos[2]),1) and pos[1] >= level.startx and pos[1] <= level.endx and pos[2] >= level.starty and pos[2] <= level.endy then
            return 2
        end
    end
    return 0
end
--level info--
--build_level(lvlnum,startx,starty,endx,endy,lgravity,shipstart{x,y},ammo{is limited,number},restart,messages)
--l is level number, r is level restart (true of false)
--start and end coordinates are as displayed by the map tab
function load_level(l,restart)
    if l == 0 then
        build_level(l,0,0,15,14,1,{0,0},{false,0},{{"houston, we have a gun",2,8.2}})
    elseif l == -1 then
        build_level(l,0,0,15,14,1,{0,0},{false,0},{{"thanks for playing!",3,6}})
    elseif l == 1 then
        build_level(l,0,0,10,10,0,{2,2},{false,16},{{"\143 move!",2,6},{"land",6,9}})
    elseif l == 2 then
        build_level(l,11,0,39,13,0,{18,8},{false,16},{{"up here!",17,3},{"\142 shoot!",14,8}})
    end
    if restart == false then
        init_background()
        create_enemy_list()
    end
end

__gfx__
0cccc000088000000cccc000777777778888888806000060877777777777777870007000cccccccc00011000000000a99009900900c00000cccc000000c00000
cc77cc0087780000cc77cc00777887777777777705606656888777777777787807070000c66c66c601111110000a9999999999990ccc0000ccc000000cc00000
cccccc0087780000cccccc007777887778777777655655508778777777778778007000006c66c66c11cccc11a999999999999799ccccc000cc000000ccc00000
0011000008800000111111007777777778877777550550508777767777777778000000007c77c77ccccccccc999999999999997900000000c00000000cc00000
0cccc00000000000c0660c0077777777787778775555550587777777777777780000000077877777ccccc77c9797999999979999000000000000000000c00000
c0660c00000000007066070078877777777778875505055587777877788877780000000077877787cc77c77c9979977999777999000000000000000000000000
c0660c00000000000000000077777877777777770555555587788777777787780000000077787777cc77cccc9797977999777999000000000000000000000000
70000700000000000000000077777777777777770555005587777777777777780000000077777777cc77cccc9999977999777999000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000500000000000000000000000000
00000000000000000000000000000070000000000000007000000000000000000000000000070000000000000000000000660000000000000000000000000000
00000000000000000007000000000000000000000000000000000000000000000000000000707000000000000000000056006500000000000000000000000000
00000000007000000070700000000000000000000000000000070000000000000000000000070000000000000000000050000500000000000000000000000000
00000700000000000007000000000000000000000000000000000000000000000000070000000000000000000000000006666500000000000000000000000000
00007070000000000000000007000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000
00000700000000700000000000000000000700000000000000000000070000000000007000000000000000000000000005665000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050000500000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
__gff__
0000000101080101011102040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000030303030303030303030303030303030303030303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000090909090000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000040909090000030000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000070000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000070000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000030404040404040404040404040404040404040404040404040404040300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000500000b1500c1500d1500e150111501215013150131501515017050160501305012050110500d0500c0500c0501505013250162501b2502625027250262500000000000000000000000000000000000000000
00100000110501705021050250501f05017050170501215015150191502515033150301502d15017150101500d1500b1500b150091500a1500c15000000000000000000000000000000000000000000000000000
00100000123501335015350193501e350223500000025350273502735025350213501c350173500d3500d350000000e3501035000000133501435018350000000000000000000000000000000000000000000000
__music__
01 00014344
00 02424344
02 00024344

