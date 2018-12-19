module JLLArrays

import ..JLLExceptions: InputException

"""
    move_dim(A, dim)

Permute A so that dimension `dim` is first:

```jldoctest
julia> A = zeros((4,3,2));
julia> A2 = move_dim(A, 2);
julia> size(A2)
(3, 4, 2)
```

    move_dim(A, dim, pos)

Permute A so that dimension `dim` ends up at position `pos`:

```jldoctest
julia> A = zeros((4,3,2));
julia> A2 = move_dim(A, 2, 3);
(4, 2, 3)
```

By default the returned array is a view into `A` (this saves memory but means
changes to values in one will affect the other). This can be changed by setting
the keyword `isview = false`:

```jldoctest
julia> A = zeros((4,3,2));
julia> Aview = move_dim(A, 2, isview=true);
julia> Acopy = move_dim(A, 2, isview=false);
julia> A[1] = 100;
julia> A[1] == Aview[1]
true

julia> A[1] == Acopy[1]
false
```
"""
function move_dim(A, dim, pos=1; isview=true)
    perm_vec = _compute_perm_vec(A, dim, pos);
    if isview
        return PermutedDimsArray(A, perm_vec);
    else
        return permutedims(A, perm_vec);
    end
end

"""
    _compute_perm_vec(A, dim, pos)

Helper function that computes the permutation vector to move `dim` to `pos`.
"""
function _compute_perm_vec(A, dim, pos)
    if dim < 1 || dim > ndims(A)
        throw(InputException("dim must be between 1 and ndims(A)"));
    elseif pos < 1 || pos > ndims(A)
        throw(InputException("pos must be between 1 and ndims(A)"));
    end

    perm_vec = [i for i in 1:ndims(A) if i != dim];
    splice!(perm_vec, pos:(pos-1), dim);
    return perm_vec;
end


"""
    seq_mat(dims...)
    seq_mat(T::DataType, dims...)

Create a matrix (optionally of the type `T`, defaults to Float64) with the
dimensions `dims` where each element's value is its linear index.
"""
function seq_mat(dims...)
    return seq_mat(Float64, dims...);
end

function seq_mat(T::DataType, dims...)
    mat = zeros(T, dims);
    for i = 1:length(mat)
        mat[i] = i;
    end
    return mat;
end

end
