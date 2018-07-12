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

start_x = flr(screen_width / 4)
start_y = 60
baseline_dy = 0.5
ship_max_dy = 3
start_dx = 0.5
ship_ddy = 0.1
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
		white_pal_counter = 0,
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
		remove = function(self)
			del(ships, self)
			del(objects, self)		
		end,
		destroy = function(self)
			make_explosion(self.x + self.width / 2, self.y + self.height / 2)
			self:remove()
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
				tail_sprite = min(sprite_end, sprite_start + (2 * flr((abs(self.dx) * (self.max_dx)))))
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
				self.hit = false
				self.white_pal_counter = 2
			end

			if (self.white_pal_counter > 0) then
				self.white_pal_counter -= 1
				white_pal()
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
	max_dx = 2,
	hp = 20,
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

function make_bad_ship(player_ship)
	local bad_ship = make_ship({ 
		x = rnd(scene_width),
		y = rnd(max_y),
		dx = start_dx,
		max_dx = 1,
		hp = 3,
		shot_color = 8,
		indicator_color = 8,
		pal = function(self)
			pal(5,2)
			pal(7,8)
			pal(6,13)
		end,
		control = function(self)
			if (abs(self.x - player_ship.x) > screen_width) then
				return
			end

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

function make_explosion(x, y)
	cam:shake()
	sfx(3)
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

function add_stars()
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

			if (not cam:in_view_x(self.x)) then
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
	x = start_x,
	y = start_y,
	dx = 0,
	dy = 0,
	max_x = scene_width - screen_width,
	min_x = 0,
	shake_counter = 0,
	shake = function(self)
		self.shake_counter = 10
	end,
	follow = function(self, following, follow_offset)
		self.following = following
		self.follow_offset = follow_offset
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
	update_shake = function(self)
		if (self.shake_counter > 0) then
			self.shake_counter -= 1
			self.shake_x  = rnd(3)
			self.shake_y  = rnd(3)
		else
			self.shake_x  = 0
			self.shake_y  = 0
		end
	end,
	update_follow = function(self)
		if (not self.following) then
			return
		end
		local desired_x = self.following.x - self.follow_offset
		if (self.following.dx < 0) then
			desired_x = self.following.x - screen_width + self.follow_offset + self.following.width
		end

		local diff = self.x - desired_x

		if (abs(diff) <= 3) then
			self.x = desired_x
		else
			self.dx = min(self.dx + 1, abs(self.following.dx) + 2)
			if (diff < 0) then
				self.x += self.dx
			else
				self.x -= self.dx
			end
		end

		desired_y = self.following.y-start_y
		self.y = desired_y
	end,
	update = function(self)
		self:update_shake()
		self:update_follow()

		if (self.y < min_y) then
			self.y = min_y
		elseif(self.y > max_y - screen_height) then
			self.y = max_y - screen_height
		end

		self:update_screen_wrap()
	end,
	x_offset = function(self)
		return self.following and flr(self.following.dx * 2) or 0
	end,
	set = function(self)
		camera(self.x - self:x_offset() + self.shake_x, self.y + self.shake_y)
	end
}

mini_map_width = 128
local mini_map = {
	x = 0,
	y = 0,
	width = mini_map_width,
	height = (mini_map_width * scene_height) / scene_width,
	draw = function(self)
		rectfill(self.x, self.y, self.x + self.width, self.y + self.height, 0)

		for ship in all(ships) do
			local ship_x = ship.x * (self.width / scene_width)
			local ship_y = (abs(min_y)  + ship.y ) * (self.height / scene_height)
			pset(self.x + ship_x, self.y + ship_y, ship.indicator_color)
		end
	end
}

local title = {
	x = 18,
	y = 8,
	width = 11 * 8,
	height = 5 * 8,
	draw = function(self)
		spr(181, self.x, self.y, self.width / 8, self.height / 8)
	end
}

game_scene = {
	init = function(self)
		cam.x = player_ship.x - start_x
		cam:follow(player_ship, start_x)
		add_stars()
		for i = 0, 8 do
			-- make_bad_ship(player_ship)
		end
	end,
	update = function(self)
		check_hits()
		for object in all(objects) do
			object:update()
		end
		cam:update()
	end,
	draw = function(self)
		cls(1)
		camera()
		mini_map:draw()
		cam:set()
		for object in all(objects) do
			object:draw()
		end
	end
}

function _init()
	game_scene:init()
end

function _update60()
	if (stop) then
		return
	end

	game_scene:update()
end

function _draw()
	if (stop) then
		return
	end

	game_scene:draw()
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
00000000000000000000000000000000000000000000888880000000888888888800000000008880888888888800000088888888888888008888888888800000
00000000000000000000000000000000000000000000222220000000222222222200000000082220222222222288000022222222222222002222222222288000
00000000000000000000000000000000000000000000222220000000222222222280000000822220222222222222800022222222222222002222222222222800
00000000000000000000000000000000000000000000222220000000222220222228000000222200222220022222280022222000000000002222200022222200
00000000000000000000000000000000000000000000222220000000222220022222000008222000222220002222220022222000000000002222200002222200
00000000000000000000000000000000000000000000222220000000222220022222800082220000222220000222220022222000000000002222200002222200
00000000000000000000000000000000000000000000222220000000222220002222280022220000222220000222220022222000000000002222200002222200
00000000000000000000000000000000000000000000222220000000222220000222220822200000222220008222220022222888888000002222200082222200
00000000000000000000000000000000000000000000222228888888222220000022228222000000222220082222200022222222222000002222288822222000
00000000000000000000000000000000000000000000222222222222222220000022222222000000222228822222200022222222222000002222222222220000
00000000000000000000000000000000000000000000222222222222222220000002222220000000222222222222000022222000000000002222222222800000
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222000000000002222202222280000
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222000000000002222202222220000
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222000000000002222200222228000
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222000000000002222200022222800
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222000000000002222200002222280
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222888888880002222200002222220
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222222222228002222200000222228
00000000000000000000000000000000000000000000222220000000222220000000222200000000222220000000000022222222222222002222200000022222
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000888800000000088800000000888888888800000088888000000000008880000888000000000000
00000000000000000000000000000000000000000000000000222280000000022200000088222222222280000022222000000000082220008222000000000000
00000000000000000000000000000000000000000000000000222220000000022200000822222000222228800022222800000000022200002222800000000000
00000000000000000000000000000000000000000000000000222228000000022200008222220000002222280002222200000000822200082222200000000000
00000000000000000000000000000000000000000000000000222222800000022200082222200000000222220002222280000000222000022222280000000000
00000000000000000000000000000000000000000000000000222222280000022200022222000000000222228000222220000008222000022222220000000000
00000000000000000000000000000000000000000000000000222222228000022200022222000000000022222000222228000002222000822222228000000000
00000000000000000000000000000000000000000000000000222022222800022200822222000000000022222000022222000002220000222022222000000000
00000000000000000000000000000000000000000000000000222022222280022200222222000000000022222000022222000082220008222022222800000000
00000000000000000000000000000000000000000000000000222002222228022200222220000000000022222000002222800022200002220002222200000000
00000000000000000000000000000000000000000000000000222000222222822200222228000000000022222000002222200822200082220002222280000000
00000000000000000000000000000000000000000000000000222000022222222200222222000000000022222000000222280222000022228888222220000000
00000000000000000000000000000000000000000000000000222000002222222200022222000000000022222000000222228222000822222222222220000000
00000000000000000000000000000000000000000000000000222000000222222200022222000000000822222000000222222220000222200000022228000000
00000000000000000000000000000000000000000000000000222000000022222200022222800000000222220000000022222220008222000000022222000000
00000000000000000000000000000000000000000000000000222000000002222200002222200000008222220000000022222220002222000000002222800000
00000000000000000000000000000000000000000000000000222000000002222200000222288000082222200000000002222200082220000000002222200000
00000000000000000000000000000000000000000000000000222000000000222200000022222888822222000000000002222200022220000000000222280000
00000000000000000000000000000000000000000000000000222000000000022200000002222222222200000000000000222000022200000000000222220000
00000000000000000000000000000000000000000000000000000000000000002200000000002222220000000000000000222000000000000000000000000000
__sfx__
01100000330233e002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011400001c44300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030020300203002030000300000
011400001c4731c445004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403
010500002d6622d6622d6622c6622a652256521f652176520b6220360200602006020060200602006020060200602006020060200602006020060200602006020060200602006020060200602006020000200002
