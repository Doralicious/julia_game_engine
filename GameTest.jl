using Makie
using Colors
using LinearAlgebra

Lx = 720
Ly = 720

frame_delay = 0
fps_alpha = 0.1

#background = Array{RGB{Float64}}(undef, Lx, Ly)
background = [ 0.4*RGB(1-i/Lx, 1-j/Ly, (i+j)/(Lx+Ly)) for i = 1:Lx, j = 1:Ly ]

s = Scene(raw = true, camera = cam2d!, resolution = (Lx, Ly))
B = Node(Board(s, (Lx, Ly), 0.0, copy(background)))

pos_list = [[0.25, 0.5], [0.5653, 0.3]]
ang_list = [0.1, pi/6]
color_list = [RGB(1., 1., 0.), RGB(0., 1., 1.)]
D0 = 0.04
entity_size = [D0, 2*D0]
circle(r, size) = r[1]^2 + r[2]^2 <= (size[1]/2)^2
diamond(r, size) = abs(r[1]) + abs(r[2]) <= size[1]/2
rectangle(r, size) = (abs(r[1]) < size[1]/2) & (abs(r[2]) < size[2]/2)

G = Node(Group("1", entity_size, rectangle, pos_list, ang_list, color_list))
G2 = Node(Group("2", entity_size .* 1.5, diamond, [[0.2, 0.1]], [pi/9], [RGB(1., 1., 1.)]))

T = Node([0.0, 0.0])
function get_fps(T, t)
    T[1] = T[2]
    T[2] = t
    dt = T[2]-T[1]
    return 1/dt
end

the_time = Node(time())
t0 = time()
last_open = false
@async while true
    global last_open
    the_time[] = time() - t0
    last_open && !isopen(B[].scene) && break
    last_open = isopen(B[].scene)
    sleep(frame_delay)
end

on(s.events.mousebuttons) do mb
    r_mouse = [s.events.mouseposition[][1]/Lx, s.events.mouseposition[][2]/Ly]
    if ispressed(mb, Mouse.left)
        println(r_mouse)
    end
end

it = Node(0)
Frame = lift(the_time) do t
    GameBoard.clear!(B[])

    it[] = it[] + 1
    fps_cur = get_fps(T[], t)
    if fps_cur > 5 # Very low FPS messes up physics, so skip frames with low FPS
        B[].fps = fps_alpha * fps_cur + (1-fps_alpha) * B[].fps

        ## Start Physics
        G[].entities[1].dpos = [0.03 * cos(it[]/10), -0.05 * sin(it[]/(10*pi))]
        G[].entities[2].dpos = [0.00, 0.04] * cos(it[]/7)
        G[].entities[1].dang = pi * cos(it[]/5) * rand()
        G[].entities[2].dang = pi/12
        ## End Physics

        GameEntities.evolve!(G[], fps_cur)
        GameBoard.draw_entity!(B[], [G[], G2[]])
    end
    B[].image
end

GameBoard.display!(B[], Frame)
