
"""
    abstract type Transformable
This is a bit of a weird name, but all scenes and plots are transformable,
so that's what they all have in common. This might be better expressed as traits.
"""
abstract type Transformable end

abstract type AbstractPlot <: Transformable end
abstract type AbstractScene <: Transformable end
abstract type AbstractScreen <: AbstractDisplay end

const SceneLike = Union{AbstractScene, AbstractScene}

"""
Main structure for holding attributes, for theming plots etc!
Will turn all values into observables, so that they can be updated.
"""
struct Attributes
    attributes::Dict{Symbol, Observable{Any}}

    Attributes(dict::Dict{Symbol, Observable{Any}}) = new(dict)

    function Attributes(@nospecialize(iterable_of_pairs))
        result = Dict{Symbol, Observable{Any}}()
        for (k::Symbol, v) in iterable_of_pairs
            if v isa NamedTuple
                result[k] = Attributes(v)
            else
                obs = Observable{Any}(to_value(v))
                if v isa Observables.AbstractObservable
                    on(x-> obs[] = x, v)
                end
                result[k] = obs
            end
        end
        return new(result)
    end

end

mutable struct PlotObject <: AbstractPlot
    type::Any
    transformation::Transformable

    # Unprocessed arguments directly from the user command e.g. `plot(args...; kw...)``
    kw::Dict{Symbol, Any}
    args::Vector{Any}
    converted::NTuple{N, Observable} where N
    # Converted and processed arguments
    attributes::Attributes

    plots::Vector{PlotObject}
    parent::Union{AbstractScene, PlotObject}

    function PlotObject(type, transformation, kw, args)
        return new(type, transformation, kw, args, (), Attributes(), PlotObject[])
    end

end

function Base.getproperty(x::PlotObject, key::Symbol)
    if hasfield(typeof(x), key)
        getfield(x, key)
    else
        getindex(x, key)
    end
end

function Base.setproperty!(x::PlotObject, key::Symbol, value)
    if hasfield(typeof(x), key)
        setfield!(x, key, value)
    else
        setindex!(x, value, key)
    end
end

repr_arg(x) = repr(x)

function Base.show(io::IO, plot::PlotObject)
    args = join(map(x-> repr_arg(to_value(x)), plot.args), ", ")
    if isempty(plot.kw)
        kw = ""
    else
        kw = "; " * join(map(((k,v),)-> "$k=$(repr_arg(to_value(v)))", collect(plot.kw)), ", ")
    end
    func = replace(lowercase(string(plot.type)), "makiecore." => "") * "!"
    print(io, func, "(", args, kw, ")")
end

Base.parent(x::AbstractPlot) = x.parent

struct TypedPlot{P <: AbstractPlot} <: AbstractPlot
    plot::PlotObject
end

TypedPlot(plot::PlotObject) = TypedPlot{plot.type}(plot)

Base.getproperty(@nospecialize(plot::TypedPlot), key::Symbol) = getproperty(getfield(plot, :plot), key)
Base.getindex(@nospecialize(plot::TypedPlot), key::Integer) = getindex(getfield(plot, :plot), key)
Base.getindex(@nospecialize(plot::TypedPlot), key::Symbol) = getindex(getfield(plot, :plot), key)
Base.setproperty!(@nospecialize(plot::TypedPlot), key::Symbol, @nospecialize(value)) = setproperty!(getfield(plot, :plot), key, value)
Base.setindex!(@nospecialize(plot::TypedPlot), @nospecialize(value), key::Symbol) = setindex!(getfield(plot, :plot), value, key)


struct Key{K} end
macro key_str(arg)
    :(Key{$(QuoteNode(Symbol(arg)))})
end
Base.broadcastable(x::Key) = (x,)

"""
Type to indicate that an attribute will get calculated automatically
"""
struct Automatic end

"""
Singleton instance to indicate that an attribute will get calculated automatically
"""
const automatic = Automatic()

abstract type Unit{T} <: Number end

"""
Unit in pixels on screen.
This one is a bit tricky, since it refers to a static attribute (pixels on screen don't change)
but since every visual is attached to a camera, the exact scale might change.
So in the end, this is just relative to some normed camera - the value on screen, depending on the camera,
will not actually sit on those pixels. Only camera that guarantees the correct mapping is the
`:pixel` camera type.
"""
struct Pixel{T} <: Unit{T}
    value::T
end

const px = Pixel(1)

"""
    Billboard([angle::Real])
    Billboard([angles::Vector{<: Real}])

Billboard attribute to always have a primitive face the camera.
Can be used for rotation.
"""
struct Billboard{T <: Union{Float32, Vector{Float32}}}
    rotation::T
end
Billboard() = Billboard(0f0)
Billboard(angle::Real) = Billboard(Float32(angle))
Billboard(angles::Vector) = Billboard(Float32.(angles))
