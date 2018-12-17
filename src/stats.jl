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

end
