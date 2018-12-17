module JLLExceptions

export ExceptionWithMsg, @msgexc;

"""
    ExceptionWithMsg

Abstract type from which any simple custom exceptions that should just print a
simple message can derive. Any exceptions deriving from this one will have to
include a `msg` property, e.g.

```
struct NewMsgException <: ExceptionWithMsg
    msg::AbstractString;
end
```

This may also be accomplished with the `@msgexc` macro, unless you want to add
intermediate abstract types, e.g.:

```
abstract type MyCustomErrorType end;
struct MyCustomException <: MyCustomErrorType
    msg::AbstractString;
end
```

There is currently no other way to accomplish this.
"""
abstract type ExceptionWithMsg <: Exception end

"""
    @msgexc(exc_name)

Create a new exception type that is a concrete subtype of the abstract ExceptionWithMsg
type. Example:

```
julia> @msgexc MyCustomException
julia> throw(MyCustomException("Something bad happened!"))
ERROR: MyCustomException: Something bad happened!
```

This allows some level of the nice Python behavior where exceptions are created
as subclasses of one another and have the default behavior where the argument
given to the exception when creating it is the error message to display. You
can use `@msgexc` to create custom exception types that by default print whatever
message they are given and can be easily filtered for:

```
try
    fxn_will_error()
catch err
    if isa(err, MyCustomException)
        # handle the error
    else
        rethrow(err)
    end
end
```
"""
macro msgexc(exc_name)
    return :(struct $exc_name <: ExceptionWithMsg
        msg::AbstractString;
    end)
end


"""
    InputException(msg::AbstractString)

Simple exception to use when the input to a function is incorrect. Takes a
message which will be printed to the console when the error is thrown.
"""
struct InputException <: ExceptionWithMsg
    msg::AbstractString;
end

Base.showerror(io::IO, e::ExceptionWithMsg) = print(io, "$(typeof(e)): $(e.msg)")

end
