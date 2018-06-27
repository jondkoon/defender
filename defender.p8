pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
screen_width = 128
half_screen_width = screen_width / 2
screen_height = 128
ship_height = 7
screen_vertical_margin = screen_height / 2
max_y = screen_height + screen_vertical_margin
min_y = -screen_vertical_margin

s = {}
s.ship = 1
s.tail_blast_counter = 0
start_x = 10
start_y = 60
x = start_x
y = start_y
baseline_dy = 0.5
dy = baseline_dy
start_dx = 0.5
dx = start_dx
max_dx = 3
ddy = 0.15
ddx = 0.4
decel = 0.5
ship_nose_offset = 3

stars = {}
for i = 0, 50 + rnd(50) do
	local s = { 
		x = -half_screen_width + rnd(screen_width * 2),
		y = -start_y + rnd(screen_width + (start_y * 2))
	}
	add(stars, s)
end

function update_stars()
	local x_start = cam.x
	local x_end = x_start + screen_width
	for s in all(stars) do
		if (s.x < x_start - half_screen_width) then
			s.x = x_end + rnd(half_screen_width)
			s.y = -start_y + rnd(screen_width + (start_y * 2))
		elseif (s.x > x_end + half_screen_width) then
			s.x = x_start - rnd(half_screen_width)
			s.y = -start_y + rnd(screen_width + (start_y * 2))
		end
	end
end

function draw_stars()
	for s in all(stars) do
		line(s.x, s.y, s.x + min(2, dx), s.y, 7)
	end
end

shots = {}
function make_shot(x,y,dx)
	local shot = {}
	shot.x = x
	shot.y = y
	shot.dx = max(abs(dx) + 5, 3)
	if (dx < 0) then
		shot.dx *= -1
	end
	shot.length = 5 + rnd(10)
	add(shots,shot)
end

function draw_shots()
	for shot in all(shots) do
		line(shot.x, shot.y, shot.x+shot.length, shot.y, 10)
	end
end

function update_shots()
	for shot in all(shots) do
		if ((shot.x > cam.x + screen_width) or (shot.x < cam.x)) then
			del(shots,shot)
		end
		shot.x += shot.dx
	end
end

cam = {}
cam.x = start_x
cam.y = start_y
cam.dx = 1
function update_cam()
	local desired_x = x - start_x
	if (dx < 0) then
		desired_x = x - screen_width + (start_x * 2)
	end

	local diff = cam.x - desired_x

	if (abs(diff) <= abs(dx)) then
		cam.x = desired_x
	elseif (diff < 0) then
		cam.x += cam.dx
	else
		cam.x -= cam.dx
	end

	if (cam.x != desired_x) then
		cam.dx = min(cam.dx + 1, abs(dx) + 2)
	else
		cam.dx = 1
	end

	desired_y = y-start_y
	if (desired_y < min_y) then
		cam.y = min_y
	elseif(desired_y > max_y - screen_height) then
		cam.y = max_y - screen_height
	else
		cam.y = desired_y
	end

end

function set_cam()
	local x_offset = flr(dx * 2)
	camera(cam.x - x_offset(), cam.y)
end

function update_ship()
	if(btn(⬆️)) then
		dy = dy or -baseline_dy
		dy -= ddy
	elseif(btn(⬇️)) then
		dy = dy or baseline_dy
		dy += ddy
	else
		if (abs(dy) <= decel) then
			dy = 0
		elseif (dy <= 0) then
			dy += decel
		elseif (dy > 0) then
			dy -= decel
		end
	end
	
	if (btn(➡️) and dx < max_dx) then
		dx += ddx
	elseif (btn(⬅️) and dx > -max_dx) then
		dx -= ddx
	end
	
	y += dy
	x += dx
	
	if (y > max_y - ship_height) then
		dy = max(-3, dy * -1)
		y = max_y - ship_height
	elseif (y < min_y) then
		dy = min(3, dy * -1)
		y = min_y
	end
	
	if (dy <= -1.5) then
		s.ship = 3
	elseif (dy <= -1) then
		s.ship = 2
	elseif (dy >= 1.5) then
		s.ship = 5
	elseif (dy >= 1) then
		s.ship = 4
	else
		s.ship = 1
	end

	if (dx < 0) then
		s.ship += 5
	end
	
	if (abs(dx) > 0) then
		local sprite_start = 17
		if (dx < 0) then
			sprite_start = 33
		end
		local sprite_end = sprite_start + 8
		s.tail = min(sprite_end, sprite_start + (2 * flr(((abs(dx) - start_dx) / 0.4))))
		if (s.tail == sprite_end) then
			if (s.tail_blast_counter == 0 and flr(rnd(10)) == 1) then
				s.tail_blast_counter = 5
			elseif (s.tail_blast_counter > 0) then
				s.tail_blast_counter -= 1
				s.tail = sprite_end + 2
			end
		end
	else
		s.tail = nil
	end

	if (btn(🅾️)) then
		if (shot_delay == 0) then
			shot_delay = 8
			make_shot(x, y+ship_nose_offset, dx)
		else
			shot_delay -= 1
		end
	else
		shot_delay = 0
	end
end

function draw_ship()
	if (s.tail) then
		local tail_offset = -8
		if (dx < 0) then
			tail_offset = 8
		end
		spr(s.tail, x+tail_offset, y)
	end
	spr(s.ship, x, y)
end

function _update60()
	update_ship()
	update_stars()
	update_shots()
	update_cam()
end

function _draw()
	cls(1)
	set_cam()
	draw_stars()
	draw_shots()
	draw_ship()
end
__gfx__
00000000066600000000000000000000000000000000000000006660000000000000000000000000000000000000000000000000000000000000000000000000
00000000066660000666600000000000066660000000000000066660000666600000000000066660000000000000000000000000000000000000000000000000
00700700555556607775566077755000066666600000000006655555066557770005577706666660000000000000000000000000000000000000000000000000
00077000777555555555555556666665555555555666666555555777555555555666666555555555566666650000000000000000000000000000000000000000
00077000555556600666666000000000777556607775500006655555066666600000000006655777000557770000000000000000000000000000000000000000
00700700066660000666600000000000066660000000000000066660000666600000000000066660000000000000000000000000000000000000000000000000
00000000066600000000000000000000000000000000000000006660000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000006660000000000000000000000000000
00000000000000000666600000000000066660000000000006666000000000000666600000000000066660000000000006666000000000000000000000000000
00000000000000005555566000000009555556600000009a555556600000009a555556600000009a55555660000009a755555660000000000000000000000000
0000000000000009775555550000009777555555000009a777555555000099a777555555000009a77755555500099a7777555555000000000000000000000000
00000000000000005555566000000009555556600000009a555556600000009a555556600000009a55555660000009a755555660000000000000000000000000
00000000000000000666600000000000066660000000000006666000000000000666600000000000066660000000000006666000000000000000000000000000
00000000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000006660000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006660000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000000000000000000000000000000000
00066660000000000006666000000000000666600000000000066660000000000006666000000000000666600000000000000000000000000000000000000000
0665555500000000066555559000000006655555a900000006655555a900000006655555a9000000066555557a90000000000000000000000000000000000000
55555577900000005555557779000000555555777a900000555555777a990000555555777a9000005555557777a9900000000000000000000000000000000000
0665555500000000066555559000000006655555a900000006655555a900000006655555a9000000066555557a90000000000000000000000000000000000000
00066660000000000006666000000000000666600000000000066660000000000006666000000000000666600000000000000000000000000000000000000000
00006660000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dd000000550000001100000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dddd00005555000011110000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dd88ddd055aa55501122111011cc111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd88d00055aa50001122100011cc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dd88d00055aa50001122100011cc10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dd88ddd055aa55501122111011cc111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00dddd00005555000011110000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dd000000550000001100000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ddd00000aaa0000022200000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dddd0000aaaa000022220000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dd222220aa55555022111110cc11111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222888555558881111188811111888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0dd222220aa55555022111110cc11111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dddd0000aaaa000022220000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ddd00000aaa0000022200000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77755555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
