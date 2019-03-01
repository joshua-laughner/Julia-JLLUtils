module JLLUnits

using Unitful;

using ..JLLExceptions; # provides @msgexc
@msgexc UnitParsingError;

# The unit aliases dictionary defines aliases for existing Unitful units that
# might be written differently in ICARTT files. The key should be the Unitful
# abbreviation string, and the value must be a tuple of alternate aliases that
# that unit may go by in the ICARTT files. It must be a tuple, even if there is
# only one alias. Note that the aliases will be matched in order of decreasing
# length, no matter what order they are listed in.
const unit_aliases = Dict{String, AbstractArray{AbstractString,1}}();

# Treat "unitless" and "none" slightly differently: "unitless" implies that it
# is a physical quantity that has no dimensionality; while "none" implies that
# it is not a physical quantity, e.g. an index of some sort.
@unit(unitless, "unitless", unitless, Quantity(1, Unitful.NoUnits), false);
@unit(none, "no_units", none, Quantity(1, Unitful.NoUnits), false);
# mach numbers are technically unitless b/c the represent the speed of the craft
# relative to the speed of sound _in that medium_ so they do not map to an
# absolute speed
@unit(mach, "mach", MachNumber, Quantity(1, Unitful.NoUnits), false);

# units relating to amount of matter
@unit(molec, "molec.", molec, Quantity(1/Unitful.Na.val, Unitful.mol), false); # can't use // because Na is a float
@unit(DU, "DU", DobsonUnit, Quantity(0.4462, Unitful.mmol), false);

# the UnitfulMoles package was not working on 5 Dec 2018, so I'm defining
# mixing ratios here
@unit(ppm, "ppm", parts_per_million, Quantity(1, Unitful.μmol / Unitful.mol), false);
@unit(ppmv, "ppmv", parts_per_million_volume, Quantity(1, Unitful.μL / Unitful.L), false);
@unit(ppb, "ppb", parts_per_billion, Quantity(1, Unitful.nmol / Unitful.mol), false);
@unit(ppbv, "ppb", parts_per_billion_volume, Quantity(1, Unitful.nL / Unitful.L), false);
@unit(ppt, "ppt", parts_per_trillion, Quantity(1, Unitful.pmol / Unitful.mol), false);
@unit(pptv, "pptv", parts_per_trillion_volume, Quantity(1, Unitful.pL / Unitful.L), false);

# time units
@unit(days, "days", days, Quantity(24, Unitful.hr), false);

# volume units
@unit(std_m, "std m", m_at_stp, Quantity(1, Unitful.m), false);

# Recommended by http://ajkeller34.github.io/Unitful.jl/stable/extending/
# if a package gets precompiled

const localunits = Unitful.basefactors
function __init__()
    merge!(Unitful.basefactors, localunits)
    Unitful.register(JLLUnits)

    # this part will initialize the units aliases dict
    merge!(unit_aliases, _read_alias_config(joinpath(@__DIR__, "common_data", "standard_unit_aliases.txt")));
end

function list_default_unit_aliases()
    for (key,val) in unit_aliases
        println("\"$key\" will be substituted for: \"$(join(val, "\", \""))\"");
    end
end

# TODO: replace references to ICARTT code

"""
    parse_unit_string(ustr; aliases_dict=nothing)

Given a string describing a unit or combination of units, convert it into a
Unitful.Units instance. This uses `sanitize_raw_unit_strings` to preformat the
string into a format that Unitful is more likely to understand.

`aliases_dict` is passed through to `sanitize_raw_unit_strings`.
"""
function parse_unit_string(ustr; aliases_dict=nothing)
    # Since I could not find a version of the Unitful @u_str macro that was a
    # function, I'm replicating the internals of @u_str here
    if aliases_dict == nothing
        ustr = sanitize_raw_unit_strings(ustr);
    else
        ustr = sanitize_raw_unit_strings(ustr, aliases_dict)
    end
    # The way the @u_str macro works in Unitful is that, given an expression or
    # symbol, tries to replace each symbol (whether standalone or in the expression)
    # with a Units instance. Then the final expression is automatically evaluated
    # by the macro before returning, so e.g. "m * s^-1" becomes:
    #   FreeUnit(m) / FreeUnit(s)
    # which gets evaluated to
    #   FreeUnit(m / s)
    # When reading from a file, I don't think there's any way to replicate that
    # without doing a run-time eval. This should be safe, as Unitful.replace_value
    # will error if a symbol is not recognized, and replaces all symbols with the
    # apporpriate Unitful.FreeUnit instances.
    try
        expr = Unitful.replace_value(Meta.parse(ustr));
        return eval(expr); # do not need the `esc` call since not returning from macro
    catch err
        # Since ICARTT files are ASCII encoded, the "micro" prefix will be represent
        # most often by a "u", but we can't just replace "u" with "μ" in all cases,
        # that would break e.g. "unitless". The only way I can figure out that doesn't
        # involve manually entering _every_ unit with the prefix "μ" that we want
        # to handle is to try the parsing and, if it fails because a symbol starting
        # with "u" isn't recognized, replace that with "μ" and try again.
        if ~(:msg in fieldnames(typeof(err)))
            # if no message, then not the right error
            rethrow(err);
        end
        m = match(r"(?<=Symbol )u[a-zA-Z]+", err.msg);
        if m === nothing
            rethrow(err);
        else
            orig_str = ustr
            new_str = replace(ustr, Regex("$(m.match)") => SubstitutionString("μ" * m.match[2:end]), count=1);
            try
                return parse_unit_string(new_str);
            catch err2
                msg = "Tried replacing 'u' prefix with 'μ' ($orig_str -> $new_str) but this failed: $(err2)";
                throw(UnitParsingError(msg));
            end
        end
    end
end

"""
    strip_units(data::Number)
    strip_units(data::AbstractArray)
    strip_units(data::Number, final_units::Unitful.Units)
    strip_units(data::AbstractArray, final_units::Unitful.Units)

Remove units from an array of Unitful Quantities. Returns an array of just
the underlying values. Optionally, provide a unit to convert the values to 
before returning:

    julia> using Unitful;  # provide the u_str macro
    julia> using JLLUnits;
    julia> x = [1., 2., 3.]u"m";
    julia> strip_units(x)
    3-element Array{Float64,1}:
    1.0
    2.0
    3.0

    julia> strip_units(x, u"cm")  # convert the values in x to centimeters before returning
    3-element Array{Float64,1}:
    100.0
    200.0
    300.0

 This also works with scalar numbers:
 
    julia> strip_units(1.0u"m")
    1.0

    julia> strip_units(1.0u"m", u"cm")
    100.0
"""
function strip_units(data::Number)
    return data.val;
end

function strip_units(data::Number, final_units::Unitful.Units)
    return Unitful.uconvert(final_units, data).val;
end

function strip_units(data::AbstractArray)
    conv(x) = x.val;
    return _strip_units_helper(data, conv);
end #strip_units(data)

function strip_units(data::AbstractArray, final_units::Unitful.Units)
    conv(x) = Unitful.uconvert(final_units, x).val;
    return _strip_units_helper(data, conv);
end #strip_units(data, final_units)

function _strip_units_helper(data::AbstractArray, conv)
    # the two forms of strip_units must be separate b/c if I try to 
    # conditionally change how `conv` works, it always gets overwritten
    # by the last one created, i.e.
    #
    # if final_units == nothing
    #   conv(x) = x.val
    # else
    #   conv(x) = uconvert(final_units, x).val
    # end
    #
    # always defines conv() as the second form.
    return_array = Array{typeof(data[1].val), ndims(data)}(undef, size(data)...);
    for i = 1:length(data)
        return_array[i] = conv(data[i]);
    end

    return return_array
end # _strip_units_helper

"""
    sanitize_raw_unit_strings(ustr)
    sanitize_raw_unit_strings(ustr, aliases_dict=nothing)

Preprocesses a unit string (`ustr`) read in from ICARTT files into a form that
can be understood by Unitful. Does several things:

    1. Replaces any substrings defined by `unit_aliases` with their key value.
       This helps standardize the units used.
    2. Replaces blank space between an alphanumeric character and a letter with
       a "*" e.g. "m s-1" becomes "m * s-1"
    3. Inserts a "^" between units and their exponents; specifically, if a letter
       is followed immediately by a number, +, or -, a "^" is inserted.

The second, two argument form, allows you to specify the dictionary of aliases
to use.
"""
function sanitize_raw_unit_strings(ustr::AbstractString)
    return sanitize_raw_unit_strings(ustr, unit_aliases);
end

function sanitize_raw_unit_strings(ustr::AbstractString, aliases_dict::AbstractDict)
    #print("Sanitizing '$ustr', ")
    # The first one is the most complicated because we need to look for any of
    # the aliases defined in the unit_aliases dictionary, but they need to match
    # a whole word, or be prefixed. That makes this a bit of a mess. We require
    # either:
    #   A) the string to substitute (S) is preceeded by a start of the string, or
    #   B) S is preceeded by a whitspace character, or
    #   C) S is preceeded by one of the defined metric prefixes, which is itself
    #       preceeded by a start-of-string or whitespace
    # and
    #   D) S is followed by a non-letter character, or an end-of-string

    # This is the first step, we need to construct a look-ahead pattern that matches
    # on start-of-string (\A), whitespace (\s), or one of the prefixes preceeded
    # by a start-of-string or whitespace.
    #
    # The joins will correctly put the | and either \A or \s in front of each
    # prefix except the first one, so the first "\\A" adds it for the first prefix
    # and the "|\\s" adds it for the first prefix of the second group. We shouldn't
    # need to explicitly include \A and \s without a prefix because the prefixdict
    # includes an empty string for no prefix.
    #
    # This part relies heavily on ICARTT files being ASCII encoded; it's not compatible
    # with Unicode encodings. This has to happen first in case we want to treat
    # a string with spaces, e.g. "std m" specially.
    prefixes = "\\A" * join(values(Unitful.prefixdict), "|\\A") * "|\\s" * join(values(Unitful.prefixdict), "|\\s")
    for (key, val) in pairs(aliases_dict)
        # Force the aliases to be searched in order of decreasing length (longest
        # first); this ensures that if a shorter alias is a subset of a longer one
        # that the entirety of the longer one gets matched. E.g. if searching
        # for "deg" or "degrees" and "deg" came up first, it would replace only
        # the first three letters of "degrees" with the proper ° symbol, i.e. we'd
        # get "°rees", which wouldn't match any known unit.\
        # Also there's no `sort` method for tuples, so we have to convert to a
        # temporary array
        sorted_aliases = sort([val...], by=length, rev=true)
        aliases = join(val, "|");
        sub = SubstitutionString(key)
        # Look for any of the aliases preceeded by any of the metric prefixes and
        # either the start-of-string or whitespace, and succeeded by any non-letter
        # character or an end-of-string
        re = Regex("(?<=$(prefixes))($(aliases))(?=[^a-zA-Z]|\\Z)");
        #println("sub = $sub, re = $re")
        ustr = replace(ustr, re => sub)
    end

    # Replace any spaces between a letter/number and letter with *, so e.g.
    # m s-1 -> m * s-1 and m2 s-1 -> m2 * s-1. User groups to keep the last
    # character of the preceeding unit and first letter of the succeeding unit
    # in the result
    ustr = replace(ustr, r"([a-zA-Z0-9])\s+([a-zA-Z])" => s"\1 * \2")

    # Insert a caret between units and their exponents. Assumes units will never
    # contain digits. Gets the last non-digit character of the unit as group 1
    # and the exponent which is the numbers and optionally a leading + or - as
    # group 2, and insert the ^ between them. Right now, there cannot be spaces
    # between the unit and exponent.
    ustr = replace(ustr, r"([a-zA-Z])([+\-]?\d+)" => s"\1^\2")

    #println(" result: '$ustr'")
    return ustr
end

"""
    _read_alias_config(config_file; verbose=0)

Read a unit alias configuration file `config_file`. Returns the aliases as a
dictionary where the key is the string to replace with and the values are arrays
of strings to replace.

`verbose` sets the level of logging, change to > 0 to increase logging or < 0 to
suppress warning messages.

See `ReadICARTT.read_icartt_file` for information about the formatting of the
configuration file.
"""
function _read_alias_config(config_file; verbose=0)
    alias_dict = Dict{String,Array}();
    return _read_alias_config!(alias_dict, config_file; verbose=verbose);
end

"""
    _read_alias_config!(alias_dict, config_file; verbose=0)

Reads the unit alias configuration file, placing the results into `alias_dict`.
The modified `alias_dict` is also returned. Values in `alias_dict` may be added
to or overwritten depending on the configuration file.

`verbose` sets the level of logging, change to > 0 to increase logging or < 0 to
suppress warning messages.

See `ReadICARTT.read_icartt_file` for information about the formatting of the
configuration file.
"""
function _read_alias_config!(alias_dict, config_file; verbose=0)
    # the config file needs to be formatted as
    #  Unitful abbrev: alias1, alias2, ... [:{append,replace}]
    open(config_file, "r") do io
        for (ln,line) in enumerate(eachline(io))
            line_chunks = split(line, ":");
            unit = strip(line_chunks[1]);
            aliases = [strip(a) for a in split(line_chunks[2], ",")];
            op_mode = length(line_chunks) > 2 ? lowercase(strip(line_chunks[3])) : "append";

            if op_mode == "replace"
                if unit in keys(alias_dict) && verbose >= 0
                    old_aliases = join(alias_dict[unit], ", ");
                    new_aliases = join(aliases, ", ");
                    @warn "Replacing existing aliases for unit \"$unit\" ($old_aliases) with
                     those defined on line $ln of $config_file ($new_aliases)"
                end
                alias_dict[unit] = aliases;
            elseif op_mode == "append"
                if !(unit in keys(alias_dict))
                    alias_dict[unit] = aliases;
                else
                    append!(alias_dict[unit], aliases);
                end
            end
        end
    end
    return alias_dict;
end

end
