using Makie
using Colors
using LinearAlgebra

## Settings

Lx = 1080
Ly = 1080
res = (Lx, Ly)

board_size = (2., 2.)

zoom = 1.5

frame_delay = 0
fps_alpha = 0.1

verbose = true


## General Constants

uvec(ph) = [cos(ph), -sin(ph)]
# [cos(ph), sin(ph)] is normal
# -sin(ph) needed here for some reason
# does the Board coord system have y backwards?
rot(ph) = [cos(ph) -sin(ph); sin(ph) cos(ph)]
ang(r) = atan(r[2]/r[1])
proj(u, v) = u'v * (v/norm(v,2)) # projects u onto v

sgnrt(x, p) = sign(x)*abs(x)^(1/p)

circle(r, size) = r[1]^2 + r[2]^2 <= (size[1]/2)^2
rectangle(r, size) = (abs(r[1]) < size[1]/2) & (abs(r[2]) < size[2]/2)

function rand_2vecs_square(n, bounds)
    V = Vector{Vector{Float64}}(undef, n)
    range = [bounds[2][1] - bounds[1][1], bounds[2][2] - bounds[1][2]]
    for i = 1:n
        V[i] = rand(Float64, 2) .* range .+ bounds[1]
    end
    return V
end
#=
mutable struct View
    pos::Vector{Float64}
    zoom::Float64
    bounds::Vector{Float64}
    background::Array{RGB{Float64}, 2}
    function View(pos::Vector{Float64}, zoom::Float64, background::Array{RGB{Float64}, 2})
        bounds = [pos - zoom/2, pos + zoom/2]
        return new(pos, zoom, bounds, background)
    end
end
=#


## Game-Specific Constants

move_speed = 0.2
player_width = 0.05


## Initializations

#background = Array{RGB{Float64}}(undef, Lx, Ly)
background = [ 0.4*RGB(1-i/Lx, 1-j/Ly, (i+j)/(Lx+Ly)) for i = 1:Lx, j = 1:Ly ]

s = Scene(raw = true, camera = cam2d!, resolution = (Lx, Ly))

sz_p = [player_width, player_width]
player = Entity([0.25, 0.], pi/2, sz_p, RGB(0., 1., 1.))
Gp0 = Group("player", sz_p, circle, player)

n_r = 130
sz_r = [0.05, 0.05]
pos_r = rand_2vecs_square(n_r, [.- board_size./2, board_size./2])
ang_r = zeros(Float64, n_r)
c_r = RGB(0.55, 0.55, 0.55) .* ones(n_r)
Gr0 = Group("Rock", sz_r, circle, pos_r, ang_r, c_r)

B = Node(Board(board_size, [Gp0, Gr0], copy(background)))
V = Node(View(s, res, [0., 0.], zoom))

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
    last_open && !isopen(V[].scene) && break
    last_open = isopen(V[].scene)
    sleep(frame_delay)
end


## Animation

on(s.events.mousebuttons) do mb
    r_mouse = [s.events.mouseposition[][1]/Lx, s.events.mouseposition[][2]/Ly]

    if ispressed(mb, Mouse.left)
        println(r_mouse)
    end
end

it = Node(0)
Frame = lift(the_time) do t
    GameBoard.clear!(B[], V[])

    it[] = it[] + 1

    fps_cur = get_fps(T[], t)

    buttons = s.events.keyboardbuttons[]

    # Chain observable flag for fps_cur minimum?
    if fps_cur > 0. # Very low FPS messes up physics, so skip frames with low FPS
        it[] = it[] + 1
        V[].fps = fps_alpha * fps_cur + (1-fps_alpha) * V[].fps

        Gp = B[].groups[1]
        Gr = B[].groups[2]

        ## Start Controls
        # TODO: add support for multiple simultaneous key presses
        #   for multi-press: try ispressed(buttons, <tuple/vector of buttons>)
        bw = ispressed(buttons, Keyboard.w)
        ba = ispressed(buttons, Keyboard.a)
        bs = ispressed(buttons, Keyboard.s)
        bd = ispressed(buttons, Keyboard.d)

        dpos = [bd - ba, bw - bs]
        Gp.entities[1].dpos = if norm(dpos, 2) >= 10^-2
            move_speed*dpos/norm(dpos, 2)
        else
            [0., 0.]
        end
        ## End Controls

        ## Start Physics
        ## End Physics

        GameEntities.evolve!(Gp, fps_cur)

        # Boundary Conditions
        #Gp.entities[1].pos[1] = mod(Gp.entities[1].pos[1] + B[].size[1]/2, B[].size[1]) - B[].size[1]/2
        #Gp.entities[1].pos[2] = mod(Gp.entities[1].pos[2] + B[].size[2]/2, B[].size[2]) - B[].size[2]/2

        # Move View
        V[].pos = Gp.entities[1].pos

        B[].groups[1] = Gp
        B[].groups[2] = Gr

        GameBoard.draw_entity!(B[], V[])

        if verbose
            println("fps = ", round(V[].fps, digits = 1))
        end
    end
    V[].image
end

GameBoard.display!(V[], Frame)
