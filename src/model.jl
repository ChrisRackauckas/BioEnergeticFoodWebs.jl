using Sundials
#=using DataFrames=#
#=using Gadfly=#

include("utils.jl")
include("ode.jl")

A = omnivory

# TODO comment
p = Dict{Symbol,Any}(
    :Z              => 1.25,
    :vertebrates    => falses(size(A)[1]),
    :a_vertebrate   => 0.88,
    :a_invertebrate => 0.314,
    :a_producer     => 1.0,
    :m_producer     => 1.0,
    :y_vertebrate   => 8.0,
    :y_invertebrate => 4.0,
    :e_herbivore    => 0.85,
    :e_carnivore    => 0.45,
    :h              => 1.0,
    :Γ              => 0.5,
    :c              => 0.0,
    :r => 1.0,
    :K => 1.0
    )

# begin code

# Setup some objects
S = size(A)[1]
F = zeros(Float64, size(A))
consumption = zeros(Float64, size(A))
efficiency = zeros(Float64, size(A))
w = zeros(S)
M = zeros(S)
a = zeros(S)
x = zeros(S)
y = zeros(S)

# Identify producers
is_producer = vec(sum(A, 2) .== 0)
producers_richness = sum(is_producer)
is_herbivore = falses(S)

# Identify herbivores
# Herbivores consume producers
for consumer in 1:S
    if ! is_producer[consumer]
        for resource in 1:S
            if is_producer[resource]
                if A[consumer, resource] == 1
                    is_herbivore[consumer] = true
                end
            end
        end
    end
end

# Measure generality and extract the vector of 1/n
generality = vec(sum(A, 2))
w = map(x -> x > 0 ? 1/x : 0, generality)

# Get the body mass
M = p[:Z].^(trophic_rank(A).-1)

# Scaling constraints based on organism type
a[p[:vertebrates]] = p[:a_vertebrate]
a[!p[:vertebrates]] = p[:a_invertebrate]
a[is_producer] = p[:a_producer]

# Metabolic rate
body_size_relative = M ./ p[:m_producer]
body_size_scaled = body_size_relative.^-0.25
x = (a ./ p[:a_producer]) .* body_size_scaled

# Assimilation efficiency
y = zeros(S)
y[p[:vertebrates]] = p[:y_vertebrate]
y[!p[:vertebrates]] = p[:y_invertebrate]

# Efficiency matrix
for consumer in 1:S
    for resource in 1:S
        if A[consumer, resource] == 1
            if is_producer[resource]
                efficiency[consumer, resource] = p[:e_herbivore]
            else 
                efficiency[consumer, resource] = p[:e_carnivore]
            end
        end
    end
end


p[:w] = w
p[:efficiency] = efficiency
p[:y] = y
p[:x] = x
p[:a]= a
p[:is_herbivore] = is_herbivore
p[:is_producer] = is_producer


# Done!

biomass = rand(S)
derivative = zeros(Float64, S)
start = 0
stop = 200
steps = 100
t = collect(linspace(start, stop, stop * steps))
f(t, y, ydot) = dBdt(t, y, ydot, p)
data = Sundials.cvode(f, biomass, t)

using Gadfly
p1 = plot(x=t, y=data[:,1], Geom.line)
p2 = plot(x=t, y=data[:,2], Geom.line)
p3 = plot(x=t, y=data[:,3], Geom.line)
p4 = plot(x=t, y=data[:,1]+data[:,2]+data[:,3], Geom.line)

draw(PNG("a.png", 30cm, 20cm), vstack(hstack(p1, p2), hstack(p3, p4)))