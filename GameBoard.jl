module GameBoard


using LinearAlgebra: norm
using Colors: RGB
using Makie: Observable, Scene, image!, center!

import Main.GameEntities: Group, Entity

export Board, draw

# Utility Functions (move to other module?)
rotate(ph) = [cos(ph) -sin(ph); sin(ph) cos(ph)]

mutable struct Board
    scene::Scene
    size::Tuple{Int64, Int64}
    fps::Float64
    background::Array{RGB{Float64}, 2}
    image::Array{RGB{Float64}, 2}
    function Board(scene::Scene, size::Tuple{Int64, Int64}, fps::Float64,
                   background::Array{RGB{Float64}, 2})
        return new(scene, size, fps, background, copy(background))
    end
end

function clear!(B::Board)
    B.image = copy(B.background)
end

function draw_entity!(B::Board, G::Group)
    Lmax = maximum(B.size)
    for i = 1:G.n
        E = G.entities[i]
        bounds_scaled = Lmax * E.bounds
        # Get all Board pixel coordinates within E's bounding box (bounding box size accounts for rotation)
        Ix = Int64.(floor.(clamp(bounds_scaled[1][1], 1, B.size[1]):1:clamp(bounds_scaled[2][1], 1, B.size[1])))
        Iy = Int64.(floor.(clamp(bounds_scaled[1][2], 1, B.size[2]):1:clamp(bounds_scaled[2][2], 1, B.size[2])))
        for ix in Ix
            # Convert to 0 to 1 units and translate to be relative to E's center
            # (Isn't ix already relative to E's center?)
            x_t = ix/Lmax - E.pos[1]
            for iy in Iy
                # Convert to 0 to 1 units and translate to be relative to E's center
                # (Isn't ix already relative to E's center?)
                y_t = iy/Lmax - E.pos[2]
                # Rotate to match E's angle
                r_rel = rotate(E.ang)*[x_t, y_t]
                if G.shape(r_rel, G.size)
                    B.image[ix, iy] = E.color
                end
            end
        end
    end
end
function draw_entity!(B::Board, VG::Vector{Group})
    # Groups at lower indices are drawn on top
    # That is, closer to the beginning of the vector of groups = higher priority
    for i = length(VG):-1:1
        draw_entity!(B, VG[i])
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

function display!(B::Board, Frame::Observable{Array{RGB{Float64}, 2}})
    image!(B.scene, Frame)[end]
    center!(B.scene)
end


end
