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

verbose = false


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

player_speed = 0.2
zombie_speed = 0.15

player_width = 0.02
zombie_width = 0.02
rock_width = 0.05

n_z = 10
n_r = 130

## Initializations

#background = Array{RGB{Float64}}(undef, Lx, Ly)
background = [ 0.4*RGB(1-i/Lx, 1-j/Ly, (i+j)/(Lx+Ly)) for i = 1:Lx, j = 1:Ly ]

s = Scene(raw = true, camera = cam2d!, resolution = (Lx, Ly))

sz_p = [player_width, player_width]
player = Entity([0.25, 0.], pi/2, sz_p, RGB(0., 1., 1.))
Gp0 = Group("player", sz_p, circle, player)

sz_z = [zombie_width, zombie_width]
pos_z = rand_2vecs_square(n_z, [.- board_size./2, board_size./2])
ang_z = zeros(Float64, n_z)
c_z = RGB(1., 0., 0.) .* ones(n_z)
Gz0 = Group("zombie", sz_z, circle, pos_z, ang_z, c_z)

sz_r = [rock_width, rock_width]
pos_r = rand_2vecs_square(n_r, [.- board_size./2, board_size./2])
ang_r = zeros(Float64, n_r)
c_r = RGB(0.55, 0.55, 0.55) .* ones(n_r)
Gr0 = Group("rock", sz_r, circle, pos_r, ang_r, c_r)

B = Node(Board(board_size, [Gp0, Gz0, Gr0], copy(background)))
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
    if fps_cur > 2. # Very low FPS messes up physics, so skip frames with low FPS
        it[] = it[] + 1
        V[].fps = fps_alpha * fps_cur + (1-fps_alpha) * V[].fps

        Gp = B[].groups[1]
        Gz = B[].groups[2]
        Gr = B[].groups[3]

        P = Gp.entities[1]

        ## Start Controls
        bw = ispressed(buttons, Keyboard.w)
        ba = ispressed(buttons, Keyboard.a)
        bs = ispressed(buttons, Keyboard.s)
        bd = ispressed(buttons, Keyboard.d)
        bspace = ispressed(buttons, Keyboard.space)

        dpos = [bd - ba, bw - bs]
        P.dpos = if norm(dpos, 2) >= 10^-2
            player_speed * dpos/norm(dpos, 2)
        else
            [0., 0.]
        end

        zombie_dir = -2*bspace + 1
        ## End Controls

        ## Start Physics
        for Z in Gz.entities
            dr_pz = P.pos - Z.pos
            Z.dpos = if norm(dr_pz, 2) >= 10^-2
                zombie_dir * zombie_speed * dr_pz/norm(dr_pz, 2)
            else
                [0., 0.]
            end
        end
        ## End Physics

        GameEntities.evolve!(Gp, fps_cur)
        GameEntities.evolve!(Gz, fps_cur)

        # Boundary Conditions
        #Gp.entities[1].pos[1] = mod(Gp.entities[1].pos[1] + B[].size[1]/2, B[].size[1]) - B[].size[1]/2
        #Gp.entities[1].pos[2] = mod(Gp.entities[1].pos[2] + B[].size[2]/2, B[].size[2]) - B[].size[2]/2

        # Move View
        V[].pos = P.pos

        B[].groups[1] = Gp
        B[].groups[2] = Gz
        B[].groups[3] = Gr

        GameBoard.draw_entity!(B[], V[])

        if verbose
            println("fps = ", round(V[].fps, digits = 1))
        end
    end
    V[].image
end

GameBoard.display!(V[], Frame)
