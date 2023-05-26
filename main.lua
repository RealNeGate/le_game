-- get the libcuik shit working *enough*
--
-- game project: semi top-down
--   [ ] village
--   [ ] sword
--   [ ] forest
--   [ ] go in cave
--   [ ] stab monsters
--   [ ] beat boss
--   [ ] win
cuik = require "libcuik"

local window = cuik.compile_file "window.c"
local renderer = cuik.compile[[
        #define WIN32_LEAN_AND_MEAN
        #include <windows.h>
        #include <GL/GL.h>

        void prepare(float w, float h) {
            glClearColor(1.0, 0.5, 0.1, 1.0);
            glClear(GL_COLOR_BUFFER_BIT);

            glMatrixMode(GL_PROJECTION);
            glLoadIdentity();
            glOrtho(0.0f, w, 0.0f, h, -1.0f, 1.0f);
            glMatrixMode(GL_MODELVIEW);
            glLoadIdentity();
        }

        void quad(float x, float y, float w, float h) {
            float x1 = x + w;
            float y1 = y + h;

            glBegin(GL_QUADS);
            glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
            glVertex2f(x, y),   glVertex2f(x1, y);
            glVertex2f(x1, y1), glVertex2f(x, y1);
            glEnd();
        }

    ]]

local player = { x=100, y=100, sword_t=0, angle=0 }

local wnd = window.create("Hello", 1600, 900)
while window.is_running() do
	while window.update() do
		local dt = 1 / 60

		-- player inputs
		local vx = 0
		local vy = 0
		if window.key_down(65) then vx = -1 end
		if window.key_down(68) then vx =  1 end
		if window.key_down(83) then vy = -1 end
		if window.key_down(87) then vy =  1 end

		player.x = player.x + vx*4
		player.y = player.y + vy*4

		if vx ~= 0 or vy ~= 0 then
			player.angle = math.atan2(vx, vy)
		end

		-- sword
		if window.key_down(32) and player.sword_t <= 0.0 then
			player.sword_t = 1.0
		end

		if player.sword_t > 0.0 then
			player.sword_t = player.sword_t - 4.0*dt
		end
	end

	renderer.prepare(1600.0, 900.0)

	-- draw player
	local px = player.x
	local py = player.y
	local r = 120.0
	local t = player.angle + (player.sword_t * 3.14)
	renderer.quad(px-64, py-64, 128, 128)
	renderer.quad(px-32 + math.sin(t)*r, py-32 + math.cos(t)*r, 64, 64)

	window.swap_buffers(wnd)
end
