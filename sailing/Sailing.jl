using Makie
using Colors
using LinearAlgebra

## Settings

Lx = 720
Ly = 720
res = (Lx, Ly)

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

mutable struct Wind
    fcn::Function
    a::Float64
    v::Vector{Float64}
    mag::Float64
    ang::Float64
    function Wind(fcn::Function, a::Float64, r::Vector{Float64})
        v = fcn(r, a)
        mag = norm(v, 2)
        ang = atan(v[2]/v[1])
        return new(fcn, a, v, mag, ang)
    end
    #=
    function Wind(fcn::Function, strength::Float64, ang::Float64)
        return new(fcn, strength*[cos(ang), sin(ang)], strength, mod(ang, 2pi), )
    end=#
end
function update!(W::Wind, r::Vector{Float64})
    W.v = W.fcn(r, W.a)
    W.mag = norm(W.v, 2)
    W.ang = atan(W.v[2]/W.v[1])
end

function solar_wind(r, a, r0 = [0., 0.])
    R = r - r0
    Rm = norm(R, 2)
    Rh = R/Rm
    return a/Rm^2 * Rh
end

sail_turn_speed = pi/3
boat_turn_speed = pi/3

Cd = 0.5 # Drag coefficient

sail_p = 14.


## Initializations

#background = Array{RGB{Float64}}(undef, Lx, Ly)
background = [ 0.4*RGB(1-i/Lx, 1-j/Ly, (i+j)/(Lx+Ly)) for i = 1:Lx, j = 1:Ly ]

s = Scene(raw = true, camera = cam2d!, resolution = (Lx, Ly))

sz_s = [0.01, 0.075]
Sail1 = Entity([0.15, 0.], pi/2, sz_s, RGB(1., 1., 1.))
Gs0 = Group("Sail", sz_s, rectangle, Sail1)
Fs = Node([0., 0.])

sz_b = [0.075, 0.05]
Boat1 = Entity(Sail1.pos, 0., sz_b, RGB(0.6470, 0.1647, 0.1647))
Gb0 = Group("Boat", sz_b, rectangle, Boat1)
Fb = Node([0., 0.])

n_r = 130
sz_r = [0.05, 0.05]
pos_r = rand_2vecs_square(n_r, [[-1., -1.], [1, 1.]])
ang_r = zeros(Float64, n_r)
c_r = RGB(0.55, 0.55, 0.55) .* ones(n_r)
Gr0 = Group("Rock", sz_r, circle, pos_r, ang_r, c_r)

Wind1 = Node(Wind(solar_wind, 0.02, Sail1.pos))

sz_i = [0.05, 0.01]
c_i_low = RGB(0., 0.5, 1.)
c_i_high = RGB(1., 0., 0.)
ang_i = -Wind1[].ang
pos_i = Sail1.pos + sz_i[1]/2 .* [cos(ang_i), sin(ang_i)]
Indicator = Entity(Sail1.pos, Wind1[].ang, sz_i, c_i_high)
Gi0 = Group("Indicator", copy(sz_i), rectangle, Indicator)

B = Node(Board([Gi0, Gs0, Gb0, Gr0], copy(background)))
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

        Gi = B[].groups[1]
        Gs = B[].groups[2]
        Gb = B[].groups[3]

        ## Start Controls
        # TODO: add support for multiple simultaneous key presses
        #   for multi-press: try ispressed(buttons, <tuple/vector of buttons>)
        bq = ispressed(buttons, Keyboard.q)
        be = ispressed(buttons, Keyboard.e)
        ba = ispressed(buttons, Keyboard.a)
        bd = ispressed(buttons, Keyboard.d)
        bspace = ispressed(buttons, Keyboard.space)

        Gs.entities[1].dang = (be - bq) * sail_turn_speed + (bd - ba) * boat_turn_speed
        Gb.entities[1].dang = (bd - ba) * boat_turn_speed
        sail_down = 1 - bspace
        ## End Controls

        ## Start Physics
        update!(Wind1[], Gs.entities[1].pos)

        Gs.entities[1].ang = mod(Gs.entities[1].ang, 2pi)
        Gb.entities[1].ang = mod(Gb.entities[1].ang, 2pi)
        Wind1[].ang = mod(Wind1[].ang, 2pi)

        ph_s = Gs.entities[1].ang
        ph_b = Gb.entities[1].ang
        ph_w = Wind1[].ang

        u_s = uvec(ph_s) # why are these unit vector y components negated?
        u_b = uvec(ph_b)

        v_b = Gb.entities[1].dpos
        v_wr = Wind1[].v - v_b

        Gs.entities[1].pos = Gb.entities[1].pos

        # Check sign - does not match paper work

        u_b2 = v_b/norm(v_b, 2)
        if any(isnan.(u_b2))
            u_b2 = u_b
        end
        Fd = 0.5 * Cd * v_b'v_b * -u_b2

        w1 = 1 + sgnrt(sin(ph_s), sail_p)
        w2 = 1 - sgnrt(sin(ph_s), sail_p)

        Fs[] = v_wr + (norm(v_wr, 2)/2)*(w1*rot(-pi/2)*u_s + w2*rot(pi/2)*u_s)
        Fb[] = sail_down * proj(Fs[], u_b) + Fd

        Gb.entities[1].dpos = u_b/10#proj(Gb.entities[1].dpos + Fb[] / fps_cur, u_b)
        Gs.entities[1].dpos = Gb.entities[1].dpos
        Gi.entities[1].dpos = Gb.entities[1].dpos

        l_max = 3.
        l_min = 0.3
        l_a = 10.
        m_w  = l_a*Wind1[].mag
        Gi.size[1] = sz_i[1]*min(l_a*Wind1[].mag + l_min, l_max)
        Gi.entities[1].ang = -ph_w
        Gi.entities[1].pos = Gs.entities[1].pos + Gi.size[1]/2 .* sign(Gs.entities[1].pos[1]) .* [cos(ph_w), sin(ph_w)]
        Gi.entities[1].color = (c_i_low * (l_max - m_w) + c_i_high * (l_min + m_w))/(l_max - l_min)
        ## End Physics

        if verbose
            println("vb = ", v_b, ", rb = ", Gb.entities[1].pos, ", fps_cur = ", round(fps_cur, digits = 1))
        end
        GameEntities.evolve!(Gb, fps_cur)
        GameEntities.evolve!(Gs, fps_cur)
        GameEntities.evolve!(Gi, fps_cur)

        # Boundary Conditions
        Gs.entities[1].pos = mod.(Gs.entities[1].pos .+ 1., 2.) .- 1.
        Gb.entities[1].pos = mod.(Gb.entities[1].pos .+ 1., 2.) .- 1.

        # Move View
        V[].pos = Gs.entities[1].pos

        B[].groups[1] = Gi
        B[].groups[2] = Gs
        B[].groups[3] = Gb

        GameBoard.draw_entity!(B[], V[])
    end
    V[].image
end

GameBoard.display!(V[], Frame)
