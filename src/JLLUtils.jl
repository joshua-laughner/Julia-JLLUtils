module JLLUtils

include("exceptions.jl");
include("units.jl");
include("stats.jl");
include("arrays.jl");
include("datemath.jl");
include("plotting.jl");

import .JLLUnits: parse_unit_string, strip_units;
import .JLLStats: normalize_to, normalize_to!;
import .JLLPlots: plotas, plotas!;

export parse_unit_string, strip_units, normalize_to, normalize_to!, plotas, plotas!;

end # module
