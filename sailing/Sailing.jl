using Makie
using Colors
using LinearAlgebra

## Settings

Lx = 720
Ly = 720
res = (Lx, Ly)

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
    mag::Float64
    ang::Float64
    v::Vector{Float64}
    function Wind(strength::Float64, ang::Float64)
        return new(strength, mod(ang, 2pi), strength*[cos(ang), sin(ang)])
    end
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
Sail1 = Entity([0.15, 0.], 0., sz_s, RGB(1., 1., 1.))
Gs = Group("Sail", sz_s, rectangle, Sail1)
Fs = Node([0., 0.])

sz_b = [0.075, 0.05]
Boat1 = Entity(Sail1.pos, pi/3, sz_b, RGB(0.6470, 0.1647, 0.1647))
Gb = Group("Boat", sz_b, rectangle, Boat1)
Fb = Node([0., 0.])

B = Node(Board([Gs, Gb], copy(background)))
V = Node(View(s, res, [0., 0.], 3.))

Wind1 = Node(Wind(0.1, 0.))

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
    #=
    buttons = s.events.keyboardbuttons[]

    fps_cur = get_fps(T[], t)
    # Chain observable flag for fps_cur minimum?
    if fps_cur > 2. # Very low FPS messes up physics, so skip frames with low FPS
        it[] = it[] + 1
        V[].fps = fps_alpha * fps_cur + (1-fps_alpha) * V[].fps

        ## Start Controls
        # TODO: add support for multiple simultaneous key presses
        #   for multi-press: try ispressed(buttons, <tuple/vector of buttons>)
        bq = ispressed(buttons, Keyboard.q)
        be = ispressed(buttons, Keyboard.e)
        ba = ispressed(buttons, Keyboard.a)
        bd = ispressed(buttons, Keyboard.d)
        bspace = ispressed(buttons, Keyboard.space)

        Gs[].entities[1].dang = (be - bq) * sail_turn_speed + (bd - ba) * boat_turn_speed
        Gb[].entities[1].dang = (bd - ba) * boat_turn_speed
        sail_down = 1 - bspace
        ## End Controls

        ## Start Physics
        Gs[].entities[1].ang = mod(Gs[].entities[1].ang, 2pi)
        Gb[].entities[1].ang = mod(Gb[].entities[1].ang, 2pi)
        Wind1[].ang = mod(Wind1[].ang, 2pi)

        ph_s = Gs[].entities[1].ang
        ph_b = Gb[].entities[1].ang
        ph_w = Wind1[].ang

        u_s = uvec(ph_s) # why are these unit vector y components negated?
        u_b = uvec(ph_b)

        v_b = Gb[].entities[1].dpos
        v_wr = Wind1[].v - v_b

        Gs[].entities[1].pos = Gb[].entities[1].pos

        # Check sign - does not match paper work

        u_b2 = v_b/norm(v_b, 2)
        if any(isnan.(u_b2))
            u_b2 = u_b
        end
        Fd = 0.5 * Cd * v_b'v_b * -u_b2

        w1 = 1 + sgnrt(sin(ph_s), sail_p)
        w2 = 1 - sgnrt(sin(ph_s), sail_p)

        Fs[] = [0, 0]# v_wr + (norm(v_wr, 2)/2)*(w1*rot(-pi/2)*u_s + w2*rot(pi/2)*u_s)
        Fb[] = [0, 0]# sail_down * proj(Fs[], u_b) + Fd

        #Gb[].entities[1].dpos = [0, 0]#proj(Gb[].entities[1].dpos + Fb[] / fps_cur, u_b)
        #Gs[].entities[1].dpos = [0, 0]#Gb[].entities[1].dpos
        ## End Physics

        #if verbose
        #    println("vb = ", v_b, ", vwr = ", v_wr, ", fps_cur = ", fps_cur)
        #end
        #GameEntities.evolve!(Gb[], fps_cur)
        #GameEntities.evolve!(Gs[], fps_cur)
        #GameEntities.evolve!(Gb[], 1/30)
        #GameEntities.evolve!(Gs[], 1/30)
        =#
        # Boundary Conditions
        #B[].groups[1].entities[1].pos = [0, 0] #mod.(Gb[].entities[1].pos, 1.)
        #B[].groups[2].entities[1].pos = [0, 0] #mod.(Gs[].entities[1].pos, 1.)

        GameBoard.draw_entity!(B[], V[])
    #end
    V[].image
end

GameBoard.display!(V[], Frame)
