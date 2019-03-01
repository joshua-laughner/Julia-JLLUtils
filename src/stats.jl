module JLLStats

import ..JLLExceptions: InputException

export nanmean;

"""
    nanmean(x; dims=nothing, count_nans=false)

Average an array (`x`) excluding NaNs. By default, the average is calculated as
the sum of all non-NaN values in `x` divided by the number of non-NaN values in `x`.
Setting `count_nans=true` will change it to be divided by the total number of
elements in `x`, include NaNs.

If dims is given, then `x` will be averaged along that dimension. Like `sum()`,
that dimension will not be removed in the output (it will have length = 1).

While using `missing` is generally preferred in Julia to mark values that are
actually missing and not the result of an undefined operation (e.g. `0. / 0.`),
currently `missing`s are not compatible with Unitful quantities.
"""
function nanmean(x; dims=nothing, count_nans=false)
    count_nans::Bool;

    notnans = .!isnan.(x);
    if dims == nothing
        # if no dim given, average over all elements
        n = count_nans ? length(x) : sum(notnans);
        return sum(x[notnans]) / n;
    else
        # require dims is an Integer
        dims :: Integer;
        if dims < 1 || dims > ndims(x)
            throw(InputException("x must be between 1 and ndims(x)"))
        end
        # if dim given, average along that element.
        n = count_nans ? size(x, dims) : sum(notnans, dims=dims);
        # this creates an anonymous function in the do block that's passed as the
        # first argument to mapslices, which iterates over x such that if e.g. x
        # is 3D and dims=2, slices x[1,:,1], x[1,:,2], x[2,:,1], etc. are taken
        # in turn. So this function gets each slice and adds up the non-NaN
        # values.
        s = mapslices(x; dims=(dims,)) do v
            vclean = v[.!isnan.(v)];
            sum(vclean);
        end
        return s ./ n;
    end
end

"""
    combinations(options::AbstractArray{<:Any,1}...)

Given multiple 1D arrays, returns an array of arrays with 
all possible combinations of the input options. Example:

    julia> combinations([1.,2.,3.],["a","b","c"])
    9-element Array{Any,1}:
     Any[1.0, "a"]
     Any[2.0, "a"]
     Any[3.0, "a"]
     Any[1.0, "b"]
     Any[2.0, "b"]
     Any[3.0, "b"]
     Any[1.0, "c"]
     Any[2.0, "c"]
     Any[3.0, "c"]    
"""
function combinations(options::AbstractArray{<:Any,1}...)
    dims = Tuple([length(o) for o in options]);
    combos = Array{Any,1}();
    for inds in CartesianIndices(dims)
        # CartesianIndices(dims) produces an array with dimensions dims 
        # where each element gives its cartesian indices. The list 
        # comprehension essentially takes each options vector as the 
        # possible values along one dimension
        this_combo = [options[i][inds[i]] for i = 1:length(inds)];
        push!(combos, this_combo);
    end
    return combos;
end

"""
    normalize_to(data::AbstractArray{<:Integer}, range=(0.0, 1.0))
    normalize_to(data::AbstractArray{<:AbstractFloat}, range=(0.0, 1.0))
    
Return a copy of the input array, `data`, normalized to the specified range.
If `data` is an array of integers, then it is converted to floats internally.
Does not affect the original `data`.

Use the `range` keyword to specify a range to normalize to other that 0 to 1.
The value may be any object where `range[1]` returns the bottom of the range
and `range[2]` the top of it.

Examples:

    julia> x = collect(1:5)
    5-element Array{Int64,1}:
     1
     2
     3
     4
     5

    julia> normalize_to(x)
    5-element Array{Float64,1}:
     0.0 
     0.25
     0.5 
     0.75
     1.0

    julia> normalize_to(x, (50, 100))
    5-element Array{Float64,1}:
     50.0
     62.5
     75.0
     87.5
     100.0
"""
function normalize_to(data::AbstractArray{<:Integer}, range=(0.0, 1.0))
    data = convert.(Float64, data);
    return normalize_to!(data, range);
end # normalize_to(AbstractArray{<:Integer})

function normalize_to(data::AbstractArray{<:AbstractFloat}, range=(0.0, 1.0))
    data = copy(data);
    normalize_to!(data, range);
    return data;
end # normalize_to(AbstractArray{<:AbstractFloat})

"""
    normalize_to!(data::AbstractArray{<:AbstractFloat}, range=(0.0, 1.0)) 

An in-place version of `normalize_to`, this overwrites `data` with the normalized
version, but may be faster since it does not have to create a new array. Because
of that, this function requires you to give it an array containing floats. An integer
array will not be accepted, and trying to call this with an integer array will 
result in a `MethodError`.

Example:
    julia> x = collect(1.0:5.0)
    5-element Array{Float64,1}:
     1.0
     2.0
     3.0
     4.0
     5.0

    julia> normalize_to!(x);
    julia> x
    5-element Array{Float64,1}:
     0.0 
     0.25
     0.5 
     0.75
     1.0 
"""
function normalize_to!(data::AbstractArray{<:AbstractFloat}, range=(0.0, 1.0))
    # first make all values in data between 0 and 1. don't use -= to avoid 
    data .-= minimum(data);
    data ./= maximum(data);

    # Now rescale to the requested range
    range_diff = range[2] - range[1];
    data .*= range_diff;
    data .+= range[1];

end # normalize_to!

end # module
