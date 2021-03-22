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
        return new(scene, res, Inf, pos, zoom, zeros(RGB{Float64}, res))
    end
end

function clear!(B::Board, V::View)
    V.image = copy(B.background)
end

function draw_entity!(B::Board, V::View, G::Group)
    Lmax = maximum(V.res)
    for i = 1:G.n
        E = G.entities[i]
        bounds_board = E.bounds
        bounds_view = [V.pos] .- bounds_board
        bounds_view_scaled = V.zoom * bounds_view
        bounds_px_f = V.res./2 .* (bounds_view_scaled .- [[1, 1], [1, 1]])
        bounds_px = [-Int64.(ceil.(bounds_px_f[1])), -Int64.(ceil.(bounds_px_f[2]))]
        # Get all Board pixel coordinates within E's bounding box (bounding box size accounts for rotation)
        Ix = clamp(bounds_px[1][1], 1, V.res[1]):1:clamp(bounds_px[2][1], 1, V.res[1])
        Iy = clamp(bounds_px[1][2], 1, V.res[2]):1:clamp(bounds_px[2][2], 1, V.res[2])
        #println("bounds_px = ", bounds_px, ", Ix = ", Ix)
        for ix in Ix
            # Convert to 0 to 1 units and translate to be relative to E's center
            # (Isn't ix already relative to E's center?)
            x_view = 1/V.zoom * (2*ix/V.res[1] - 1)
            for iy in Iy
                # Convert to 0 to 1 units and translate to be relative to E's center
                # (Isn't ix already relative to E's center?)
                y_view = 1/V.zoom * (2*iy/V.res[2] - 1)
                # Rotate to match E's angle
                r_rot = rotate(E.ang)*[x_view, y_view]
                #=println("r_px = ", [ix, iy],
                    ", r_view = ", round.([x_view, y_view], digits = 3),
                    ", bounds_px = ", bounds_px)=#
                if G.shape(r_rot, G.size)
                    V.image[ix, iy] = E.color
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
