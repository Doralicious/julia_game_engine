module GameBoard


using LinearAlgebra: norm
using Colors: RGB
using Makie: Observable, Scene, image!, center!

import Main.GameEntities: Group, Entity

export Board, View

# Utility Functions (move to other module?)
rotate(ph) = [cos(ph) -sin(ph); sin(ph) cos(ph)]

mutable struct Board
    groups::Vector{Group}
    background::Array{RGB{Float64}, 2}
    function Board(groups::Vector{Group}, background::Array{RGB{Float64}, 2})
        return new(groups, background)
    end
end

mutable struct View
    scene::Scene
    res::Tuple{Int64, Int64}
    fps::Float64
    pos::Vector{Float64}
    zoom::Float64
    image::Array{RGB{Float64}, 2}
    function View(scene::Scene, res::Tuple{Int64, Int64}, pos::Vector{Float64}, zoom::Float64)
        return new(scene, res, 30, pos, zoom, zeros(RGB{Float64}, res))
    end
end

function clear!(B::Board, V::View)
    V.image = copy(B.background)
end

function draw_entity!(B::Board, V::View, G::Group)
    L = V.res
    O = V.pos
    z = V.zoom / 2.
    Lmax = maximum(V.res)
    for i = 1:G.n
        E = G.entities[i]
        R = E.pos
        bounds_B = E.bounds
        bounds_V = [[0., 0.], [0., 0.]]
        bounds_V[1][1] = z*(bounds_B[1][1] - O[1])
        bounds_V[1][2] = z*(bounds_B[1][2] - O[2])
        bounds_V[2][1] = z*(bounds_B[2][1] - O[1])
        bounds_V[2][2] = z*(bounds_B[2][2] - O[2])
        bounds_px = [[0, 0], [0, 0]]
        bounds_px[1][1] = Int64(round(L[1]*(bounds_V[1][1] + 0.5)))
        bounds_px[1][2] = Int64(round(L[2]*(bounds_V[1][2] + 0.5)))
        bounds_px[2][1] = Int64(round(L[1]*(bounds_V[2][1] + 0.5)))
        bounds_px[2][2] = Int64(round(L[2]*(bounds_V[2][2] + 0.5)))
        # Get all Board pixel coordinates within E's bounding box (bounding box size accounts for rotation)
        Ix = clamp(bounds_px[1][1], 1, L[1]):1:clamp(bounds_px[2][1], 1, L[1])
        Iy = clamp(bounds_px[1][2], 1, L[2]):1:clamp(bounds_px[2][2], 1, L[2])
        #println(G.type_id, ": bounds_B = ", bounds_B, ", bounds_V = ", bounds_V)
        #println(G.type_id, ": bounds_px = ", bounds_px, ", Ixy = ", [[Ix[1], Iy[1]], [Ix[end], Iy[end]]])
        for ix_p in Ix
            ix_V = ix_p/L[1] - 0.5
            Ex_V = z*(R[1] - O[1])
            ix_V_L = (ix_V - Ex_V)/z
            for iy_p in Iy
                iy_V = iy_p/L[2] - 0.5
                Ey_V = z*(R[2] - O[2])
                iy_V_L = (iy_V - Ey_V)/z
                # Rotate to match E's angle
                R_L_rot = rotate(E.ang)*[ix_V_L, iy_V_L]
                #V.image[ix, iy] = E.color
                if G.shape(R_L_rot, G.size)
                    V.image[ix_p, iy_p] = E.color
                end
            end
        end
    end
end
function draw_entity!(B::Board, V::View)
    # Groups at lower indices are drawn on top
    # That is, closer to the beginning of the vector of groups = higher priority
    for i = length(B.groups):-1:1
        draw_entity!(B, V, B.groups[i])
    end
end

function draw_line!(B::Board, r1::Vector{Float64}, r2::Vector{Float64}, c::RGB{Float64})
    # TODO: make work with View type
    r1 = r1 * B.size[1]
    r2 = r2 * B.size[2]
    drh = (r2 .- r1)./norm(r2 .- r1, 2)
    lx = r1[1]:drh[1]:r2[1]
    ly = r1[2]:drh[2]:r2[2]
    Lp = Vector{Tuple{Int64, Int64}}(undef, length(lx))
    for i = 1:length(lx)
        Lp[i] = Int64.(round.((clamp(lx[i], 1, B.size[1]), clamp(ly[i], 1, B.size[2]))))
    end
    Lp = unique(push!(Lp, Int64.(round.((clamp(r2[1], 1, B.size[1]), clamp(r2[2], 1, B.size[2]))))))
    for I in Lp
        B.image[I[1], I[2]] = c
    end
end

function display!(V::View, Frame::Observable{Array{RGB{Float64}, 2}})
    image!(V.scene, Frame)[end]
    center!(V.scene)
end


end
