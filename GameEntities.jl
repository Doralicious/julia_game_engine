module GameEntities


using Colors: RGB

export AbstractEntity, AbstractGroup, Entity, Group

abstract type AbstractEntity end
abstract type AbstractGroup end

mutable struct Entity <: AbstractEntity
    pos::Vector{Float64}
    dpos::Vector{Float64}
    ang::Float64
    dang::Float64
    bounds::Vector{Vector{Float64}}
    color::RGB{Float64}
    function Entity(pos::Vector{Float64}, ang::Float64, size::Vector{Float64}, color::RGB{Float64})
        box_size = [abs(size[2]*sin(ang)) + abs(size[1]*cos(ang)), abs(size[1]*sin(ang)) + abs(size[2]*cos(ang))]
        bounds = [pos - box_size/2, pos + box_size/2] # [[xmin, ymin], [xmax, ymax]]
        return new(pos, [0., 0.], ang, 0., bounds, color)
    end
end

mutable struct Group <: AbstractGroup
    type_id::String
    n::Int64
    size::Vector{Float64}
    shape::Function
    entities::Vector{Entity}
    function Group(type_id::String, size::Vector{Float64}, shape, pos_list::Vector{Vector{Float64}},
        ang_list::Vector{Float64}, color_list::Vector{RGB{Float64}})
        G = new(type_id, 0, size, shape, Entity[])
        for i = 1:length(pos_list)
            add!(G, Entity(pos_list[i], ang_list[i], size, color_list[i]))
        end
        return G
    end
    function Group(type_id::String, size::Vector{Float64}, shape, entity_list::Vector{Entity})
        G = new(type_id, 0, size, shape, Entity[])
        for i = 1:length(entity_list)
            add!(G, entity_list[i])
        end
        return G
    end
    function Group(type_id::String, size::Vector{Float64}, shape, entity::Entity)
        G = new(type_id, 0, size, shape, Entity[])
        add!(G, entity)
        return G
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

function evolve!(G::Group, fps::Float64)
    # Q: mod angles by 2pi?
    for i = 1:G.n
        G.entities[i].pos = G.entities[i].pos + G.entities[i].dpos / fps
        G.entities[i].ang = G.entities[i].ang + G.entities[i].dang / fps
        box_size = [abs(G.size[2]*sin(G.entities[i].ang)) + abs(G.size[1]*cos(G.entities[i].ang)),
                    abs(G.size[1]*sin(G.entities[i].ang)) + abs(G.size[2]*cos(G.entities[i].ang))]
        G.entities[i].bounds = [G.entities[i].pos - box_size/2, G.entities[i].pos + box_size/2] # [[xmin, ymin], [xmax, ymax]]
    end
end


end
