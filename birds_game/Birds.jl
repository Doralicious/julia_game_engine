module Birds


using LinearAlgebra: norm

import Main.GameEntities: AbstractEntity, Entity, Group

export Bird, Plant

BIRD_SIZE = 0.05
LEAF_SIZE = 0.05
BIRD_COLOR = :blue
LEAF_COLOR = :green
GROWTH_RATE = 0.05
HUNGER_RATE = 0.05
FEED_RANGE = Inf
BIRD_SPEED = 0.02
BIRD_VEL_MATCH = 0.1
CIRCLE(r, size) = norm(r) <= size[1]
function TRIANGLE(r, size)
    al = 2*pi/3
    b = size[1]
    xm = b*cos(al)
    xM = b
    ym = b*sin(al)
    yM = -ym
    y1 = yM - yM * (r[1] - xm) / (xM - xm)
    y2 = -yM + yM * (r[1] - xm) / (xM - xm)
    r[2] > y1 & r[1] > xm & r[2] < y2
end
ROTATE(ph) = [cos(ph) -sin(ph); sin(ph) cos(ph)]


mutable struct Bird <: AbstractEntity
    pos::Vector{Float64}
    dpos::Vector{Float64}
    ang::Float64
    dang::Float64
    bounds::Vector{Vector{Float64}}
    color::RGB{Float64}
    hunger::Float64
    function Bird(pos::Vector{Float64})
        bounds = [pos - BIRD_SIZE/2, pos + BIRD_SIZE/2] # [[xmin, ymin], [xmax, ymax]]
        return new(pos, [0., 0.], 0., 0., bounds, BIRD_COLOR, 0.)
    end
end

mutable struct Flock <: AbstractGroup
    # Flocks are not necessarily contiguous groups of Birds;
    #   a Flock is just a grouping of Bird entities
    type_id::String
    n::Int64
    size::Float64
    shape::Function
    entities::Vector{AbstractEntity}
    function Flock(pos_list::Vector{Vector{Float64}},
        ang_list::Vector{Float64}, color_list::Vector{RGB{Float64}})
        n = length(pos_list)
        size = BIRD_SIZE
        shape = CIRCLE
        G = new(0, size, shape, Bird[])
        for i = 1:n
            add!(G, Bird(pos_list[i]))
        end
        return G
    end
    function Flock(bird_list::Vector{Bird})
        n = length(bird_list)
        size = BIRD_SIZE
        shape = CIRCLE
        G = new(0, size, shape, Bird[])
        for i = 1:n
            add!(G, bird_list[i])
        end
        return G
    end
end

mutable struct Leaf <: AbstractEntity
    pos::Vector{Float64}
    dpos::Vector{Float64}
    ang::Float64
    dang::Float64
    bounds::Vector{Vector{Float64}}
    color::RGB{Float64}
    growth::Float64
    function Leaf(pos::Vector{Float64}, ang::Float64)
        bounds = [pos - LEAF_SIZE/2, pos + LEAF_SIZE/2] # [[xmin, ymin], [xmax, ymax]]
        return new(pos, [0., 0.], ang, 0., bounds, LEAF_COLOR, 0.)
    end
end

mutable struct Plant <: AbstractGroup
    # Plants are not necessarily contiguous groups of Leaves;
    #   a Plant is just a grouping of Leaf entities
    n::Int64
    size::Float64
    shape::Function
    entities::Vector{AbstractEntity}
    function Plant(pos_list::Vector{Vector{Float64}},
        ang_list::Vector{Float64}, color_list::Vector{RGB{Float64}})
        n = length(pos_list)
        size = LEAF_SIZE
        shape = TRIANGLE
        G = new(0, size, shape, Leaf[])
        for i = 1:n
            add!(G, Leaf(pos_list[i], ang_list[i]))
        end
        return G
    end
    function Plant(leaf_list::Vector{Leaf})
        n = length(leaf_list)
        size = LEAF_SIZE
        shape = TRIANGLE
        G = new(0, size, shape, Leaf[])
        for i = 1:n
            add!(G, leaf_list[i])
        end
        return G
    end
    function Plant()
        size = LEAF_SIZE
        shape = TRIANGLE
        G = new(0, size, shape, Leaf[])
    end
end

function add!(G::Group, E::AbstractEntity)
    G.n = G.n + 1
    push!(G.entities, E)
end

function remove!(G::Group, i::Int64)
    G.n = G.n - 1
    deleteat!(G.entities, i)
end

function closest_leaf(P::Plant, pos::Vector{Float64}, radius::Float64)
    # Returns the closest Leaf of P within radius of pos
    # If there is no such Leaf in P, returns an empty Leaf
    dmin = Inf
    imin = 0
    for i = 1:P.n
        r = P.entities[i].pos - pos
        if abs(r[1]) <= radius & abs(r[2]) <= radius
            d = norm(r, 2)
            if d < radius & d < dmin
                dmin = d
                imin = i
            end
        end
    end
    if imin = 0
        return (Leaf[], 0)
    else
        return (P.entities[imin], imin)
    end
end

function closest_bird(F::Flock, pos)
    dmin = Inf
    imin = 0
    for i = 1:F.n
        r = F.entities[i].pos - pos
        d = norm(r, 2)
        if d < radius & d < dmin
            dmin = d
            imin = i
        end
    end
    if imin = 0
        return (Bird[], 0)
    else
        return (F.entities[imin], imin, dmin)
    end
end

function neighbor_leaves(P::Plant, pos::Vector{Float64})
    Ln = Plant()
    for i = 1:P.n
        r = P.entities[i].pos - pos
        d = norm(r, 2)
        if d < PLANT_SIZE + 10^-4 # adding epsilon to account for small errors
            add!(Ln, P.entities[i])
        end
    end
    neighbors = [false, false, false]
    for i = 1:Ln.n
        Li = Ln.entities[i]
        r = Ln.entities[i] - pos
        ri = ROTATE(Li.ang) * r # currently, ang should be 0 for all plants
        if ri[1] > 0
            neighbors[1] = true
        elseif ri[2] > 0
            neighbors[2] = true
        else
            neighbors[3] = true
        end
    end
    return neighbors
end

function eat!(B::Bird, P::Plant, i::Int64)
    B.hunger = 0.
    remove!(P, i)
end

function evolve!(F::Flock, P::Plant, fps)
    for i = 1:F.n
        B = F.entities[i]
        # TODO: add behavior for following other birds and for finding/getting food
        if B.hunger >= 1. # Hungry
            (Lc, ic) = closest_leaf(P, B.pos, FEED_RANGE)
            r = Lc.pos - B.pos
            d = norm(r, 2)
            u = r/d
            if d < 0.01
                eat!(B, P, ic)
            end
            B.dpos = BIRD_SPEED * u
        else              # Not Hungry
            (Bc, ic, d) = closest_bird(F, B.pos)
            if d < 0.05
                v = Bc.dpos - B.dpos
                B.dpos = B.dpos + BIRD_VEL_MATCH * v
            else
                r = Bc.pos - B.pos
                d = norm(r, 2)
                u = r/d
                B.dpos = BIRD_SPEED * u
            end
        end
        B.hunger = B.hunger + HUNGER_RATE / fps
        B.pos = B.pos + B.dpos / fps
        B.bounds = [B.pos - F.size/2, B.pos + F.size/2] # [[xmin, ymin], [xmax, ymax]]
    end
    for i = 1:P.n
        L = P.entities[i]
        if L.growth >= 1.
            neighbors = neighbor_plants(P, L.pos)
            # TODO: grow new leaves based on neighbor pattern
        end
    end
end

end
