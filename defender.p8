pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

screen_width = 128
half_screen_width = screen_width / 2
scene_width = screen_width * 10

screen_height = 128
scene_height = screen_height + (screen_height / 2)
screen_vertical_margin = (scene_height - screen_height) / 2
max_y = screen_height + screen_vertical_margin
min_y = -screen_vertical_margin

start_x = flr(screen_width / 3)
start_y = 60
baseline_dy = 0.5
ship_max_dy = 5
start_dx = 0.5
ship_ddy = 0.15
ship_ddx = 0.3
ship_decel = 0.5
ship_nose_offset = 3
ship_height = 7
ship_width = 8

objects = {}

sound_on = true
stop = false
_sfx = sfx
function sfx(id)
	if (sound_on) then
		_sfx(id)
	end
end

function draw_hit_box(o)
	rect(o.x, o.y, o.x + o.width, o.y + o.height, 11)
end

function white_pal()
	for i = 0, 15 do
		pal(i, 7)
	end
end

function test_collision(a, b)
	return (
		a.x < b.x + b.width and
		a.x + a.width > b.x and
		a.y < b.y + b.height and
		a.y + a.height > b.y
	)
end

ships = {}
function make_ship(options)
	local ship = {
		x = options.x,
		y = options.y,
		width = ship_width,
		height = ship_height,
		max_hp = options.hp,
		max_dx = options.max_dx,
		hp = options.hp,
		shot_color = options.shot_color,
		indicator_color = options.indicator_color,
		is_player_ship = options.is_player_ship,
		control = options.control,
		pal = options.pal,
		tail_blast_counter = 0,
		shot_delay = 0,
		dx = options.dx,
		dy = 0,
		go_right = function(self)
				self.dx = min(self.dx + ship_ddx, self.max_dx)
		end,
		go_left = function(self)
				self.dx = max(self.dx - ship_ddx, -self.max_dx)
		end,
		go_up = function(self)
				self.dy = self.dy or -baseline_dy
				self.dy = max(self.dy - ship_ddy, -ship_max_dy)
		end,
		go_down = function(self)
				self.dy = self.dy or baseline_dy
				self.dy = min(self.dy + ship_ddy, ship_max_dy)
		end,
		fire = function(self)
			if (self.shot_delay == 0) then
				self.shot_delay = 8
				self.fired = true
			else
				self.shot_delay -= 1
			end
		end,
		destroy = function(self)
			make_explosion(self.x + self.width / 2, self.y + self.height / 2)
			del(ships, self)
			del(objects, self)
		end,
		check_hit = function(self, object)
			self.hit = test_collision(self, object)
			if (self.hit) then
				self.hp -= 1
			end

			if (self.hp == 0 ) then
				self:destroy()
			end

			return self.hit
		end,
		decel_y = function(self)
			if (abs(self.dy) <= ship_decel) then
				self.dy = 0
			elseif (self.dy <= 0) then
				self.dy += ship_decel
			elseif (self.dy > 0) then
				self.dy -= ship_decel
			end
		end,
		update = function(self)
			self:control()
			self.y += self.dy
			self.x += self.dx
			
			if (self.y > max_y - ship_height) then
				self.dy = max(-3, self.dy * -1)
				self.y = max_y - ship_height
			elseif (self.y < min_y) then
				self.dy = min(3, self.dy * -1)
				self.y = min_y
			end
			if (self.fired) then
				make_shot({
					x = self.x + (self.dx >= 0 and ship_width or 0),
					y = self.y+ship_nose_offset,
					dx = self.dx,
					color = self.shot_color,
					from_player = self.is_player_ship
				})
				self.fired = false
			end
		end,
		draw = function(self)
			local ship_sprite, tail_sprite
			if (abs(self.dy) <= 1) then
				ship_sprite = 1
			elseif (abs(self.dy) <= 1.5) then
				ship_sprite = 2
			else
				ship_sprite = 3
			end
			
			if (abs(self.dx) > 0) then
				local sprite_start = 17
				local sprite_end = sprite_start + 8
				tail_sprite = min(sprite_end, sprite_start + (2 * flr(((abs(self.dx) - start_dx) / 0.4))))
				if (tail_sprite == sprite_end) then
					if (self.tail_blast_counter == 0 and flr(rnd(10)) == 1) then
						self.tail_blast_counter = 5
					elseif (self.tail_blast_counter > 0) then
						self.tail_blast_counter -= 1
						tail_sprite = sprite_end + 2
					end
				end
			end

			local flip_x = self.dx < 0
			local flip_y = self.dy > 0
			local y_offset = flip_y and -1 or 0
			if (self.hit) then
				if (self.is_player_ship) then
					sfx(2)
					cam:shake()
				else
					sfx(1)
				end
				white_pal()
				self.hit = false
			elseif (self.pal) then
				self:pal()
			end
			spr(ship_sprite, self.x, self.y + y_offset, 1, 1, flip_x, flip_y)
			pal()

			if (tail_sprite) then
				local tail_offset = -8
				if (self.dx < 0) then
					tail_offset = 8
				end
				spr(tail_sprite, self.x+tail_offset, self.y+y_offset, 1, 1, flip_x, flip_y)
			end

			local hp_offset = -2
			local hp_ratio = self.hp / self.max_hp
			local hp_full_width = self.width - 1
			local hp_scaled_width = hp_full_width * hp_ratio
			local hp_color = 3 -- green
			if (hp_ratio <= 0.5) then
				hp_color = 8 -- red
			elseif (hp_ratio < 1) then
				hp_color = 10 -- yellow
			end
			line(self.x, self.y + hp_offset, self.x + hp_scaled_width, self.y + hp_offset, hp_color)
			-- print(self.hp, self.x, self.y - 8)
		end
	}
	add(ships, ship)
	add(objects, ship)
	return ship
end

player_ship = make_ship({
	x = start_x,
	y = start_y,
	dx = start_dx,
	max_dx = 3,
	hp = 10,
	shot_color = 10,
	indicator_color = 11,
	is_player_ship = true,
	control = function(self)
		if(btn(⬆️)) then
			self:go_up()
		elseif(btn(⬇️)) then
			self:go_down()
		else
			self:decel_y()
		end
		
		if (btn(➡️)) then
			self:go_right()
		elseif (btn(⬅️)) then
			self:go_left()
		end

		if (btn(🅾️)) then
			self:fire()
		end
	end
})

function make_bad_ship()
	local bad_ship = make_ship({ 
		x = rnd(scene_width),
		y = rnd(max_y),
		dx = start_dx,
		max_dx = 2,
		hp = 3,
		shot_color = 8,
		indicator_color = 8,
		pal = function(self)
			pal(5,2)
			pal(7,8)
			pal(6,13)
		end,
		control = function(self)
			local desired_y = (player_ship.y + player_ship.dy)
			local y_diff = (self.y + self.dy) - desired_y
			if(abs(y_diff) <= 5) then
				self:decel_y()
			elseif (y_diff > 0) then
				self:go_up()
			else
				self:go_down()
			end

			local desired_x = (player_ship.x + player_ship.dx) - 20
			local x_diff = (self.x + self.dx) - desired_x
			if(x_diff > 10) then
				self:go_left()
			elseif (x_diff < -10) then
				self:go_right()
			end

			if (rnd(1) > 0.5) then
				self:fire()
			end
		end	
	})
end

for i = 0, 5 do
	make_bad_ship()
end


function make_explosion(x, y)
	local make_particle = function(x, y)
		local particle_colors = { 6, 7, 9, 10 }
		local particle = {
			x = x - 4 + flr(rnd(8)),
			y = y - 4 + flr(rnd(8)),
			width = 5 + flr(rnd(8)),
			color = particle_colors[1 + flr(rnd(count(particle_colors)))],
			counter = 10 + flr(rnd(10)),
			dx = flr(rnd(3)) - 1.5,
			dy = flr(rnd(3)) - 1.5,
			dwidth = flr(rnd(3)) - 1.5,
			update = function(self)
				self.x += self.dx
				self.y += self.dy
				self.width += self.dwidth
				self.counter -= 1
				if (self.counter <= 0) then
					del(objects, self)
				end
			end,
			draw = function(self)
				circfill(self.x, self.y, self.width / 2, self.color)
			end
		}
		add(objects, particle)
	end
	for i = 0, 10 do
		make_particle(x, y)
	end
end

for i = 0, 50 + rnd(50) do
	local star = {
		x = -half_screen_width + rnd(screen_width * 2),
		y = -start_y + rnd(screen_width + (start_y * 2)),
		width = 1,
		update = function(self)
			local x_start = cam.x
			local x_end = x_start + screen_width
			if (self.x < x_start - half_screen_width) then
				self.x = x_end + rnd(half_screen_width)
				self.y = -start_y + rnd(screen_width + (start_y * 2))
			elseif (self.x > x_end + half_screen_width) then
				self.x = x_start - rnd(half_screen_width)
				self.y = -start_y + rnd(screen_width + (start_y * 2))
			end
			self.width = min(2, player_ship.dx)
		end,
		draw = function(self)
			line(self.x, self.y, self.x + self.width, self.y, 7)
		end
	}
	add(objects, star)
end

shots = {}
function make_shot(options)
	sfx(0)
	local width = 5 + rnd(10)
	local shot = {
		new = true,
		from_player = options.from_player,
		color = options.color,
		x = options.dx < 0 and options.x - width or options.x,
		y = options.y,
		dx = options.dx < 0 and options.dx - 5 or options.dx + 5,
		width = width,
		height = 1,
		remove = function(self)
			del(shots,self)
			del(objects,self)
		end,
		update = function(self)
			if (self.new) then
				self.new = false
				return
			end

			if ((self.x > cam.x + screen_width + half_screen_width) or (self.x < cam.x - half_screen_width)) then
				self:remove()
			else
				self.x += self.dx
			end
		end,
		draw = function(self)
			line(self.x, self.y, self.x+self.width, self.y, self.color)
		end
	}
	add(shots, shot)
	add(objects, shot)
end

function check_hits()
	for shot in all(shots) do
		for ship in all(ships) do
			if (ship.is_player_ship != shot.from_player and ship:check_hit(shot)) then
				shot:remove()
			end
		end
	end
end

cam = {
	x = player_ship.x - start_x,
	y = start_y,
	dx = 1,
	max_x = scene_width - screen_width,
	min_x = 0,
	shake_counter = 0,
	shake = function(self)
		self.shake_counter = 10
	end,
	in_view_x = function(self, x)
		return x >= self.x and x <= self.x + screen_width
	end,
	update_screen_wrap = function(self)
		if (self.x > self.max_x) then
			self.x = self.x  - self.max_x
		elseif (self.x < self.min_x) then
			self.x = self.x + self.max_x
		end
		for o in all(objects) do
			if (self:in_view_x(o.x - self.max_x) or self:in_view_x(o.x + o.width - self.max_x)) then
				o.x = o.x - self.max_x
			end
			if (self:in_view_x(o.x + self.max_x) or self:in_view_x(o.x + o.width + self.max_x)) then
				o.x = o.x + self.max_x
			end
		end
	end,
	update = function(self)
		if (self.shake_counter > 0) then
			self.shake_counter -= 1
			self.shake_x  = rnd(3)
			self.shake_y  = rnd(3)
		else
			self.shake_x  = 0
			self.shake_y  = 0
		end

		local desired_x = player_ship.x - start_x
		if (player_ship.dx < 0) then
			desired_x = player_ship.x - screen_width + start_x + ship_width
		end

		local diff = self.x - desired_x

		if (abs(diff) <= abs(player_ship.dx)) then
			self.x = desired_x
		elseif (diff < 0) then
			self.x += self.dx
		else
			self.x -= self.dx
		end

		if (self.x != desired_x) then
			self.dx = min(self.dx + 1, abs(player_ship.dx) + 2)
		else
			self.dx = 1
		end

		desired_y = player_ship.y-start_y
		if (desired_y < min_y) then
			self.y = min_y
		elseif(desired_y > max_y - screen_height) then
			self.y = max_y - screen_height
		else
			self.y = desired_y
		end

		self:update_screen_wrap()
	end,
	x_offset = function(self)
		return flr(player_ship.dx * 2)
	end,
	set = function(self)
		camera(self.x - self:x_offset() + self.shake_x, self.y + self.shake_y)
	end
}

local x_printer = {
	x = 1,
	y = 1,
	width = 1,
	update = function(self)
		self.x = player_ship.x
		self.y = player_ship.y - 8
	end,
	draw = function(self)
		print(player_ship.x, self.x, self.y)
	end
}
-- add(objects, x_printer)

mini_map_width = 128
local mini_map = {
	width = mini_map_width,
	height = (mini_map_width * scene_height) / scene_width,
	draw = function(self)
		local x = cam.x - cam:x_offset()
		local y = cam.y
		rectfill(x, y, x + self.width, y + self.height, 0)

		for ship in all(ships) do
			local ship_x = ship.x * (self.width / scene_width)
			local ship_y = (abs(min_y)  + ship.y ) * (self.height / scene_height)
			pset(x + ship_x, y + ship_y, ship.indicator_color)
		end
	end
}

function _update60()
	if (stop) then
		return
	end

	check_hits()
	for object in all(objects) do
		object:update()
	end
	cam:update()
end

function _draw()
	if (stop) then
		return
	end

	cls(1)
	cam:set()
	mini_map:draw()
	for object in all(objects) do
		object:draw()
	end
end
__gfx__
00000000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066660000666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700555556607775566077755000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000777555555555555556666665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000555556600666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700066660000666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000006660000000000000000000000000000
00000000000000000666600000000000066660000000000006666000000000000666600000000000066660000000000006666000000000000000000000000000
00000000000000005555566000000009555556600000009a555556600000009a555556600000009a55555660000009a755555660000000000000000000000000
0000000000000009775555550000009777555555000009a777555555000099a777555555000009a77755555500099a7777555555000000000000000000000000
00000000000000005555566000000009555556600000009a555556600000009a555556600000009a55555660000009a755555660000000000000000000000000
00000000000000000666600000000000066660000000000006666000000000000666600000000000066660000000000006666000000000000000000000000000
00000000000000000666000000000000066600000000000006660000000000000666000000000000066600000000000006660000000000000000000000000000
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
__sfx__
01100000330233e002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011400001c44300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030000300000
011400001c4731c445004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403
