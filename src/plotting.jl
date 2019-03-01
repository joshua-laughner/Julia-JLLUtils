module JLLPlots

import Plots;
import Unitful;

import ..JLLArrays

export plotas;

"""
    plotas(y; yunit=missing, kwargs...)
    plotas(x, y; unit=missing, xunit=missing, yunit=missing, xlabel="", ylabel="", kwargs...)

Plots quantities y or x and y, which should be arrays of Unitful.Quantities, in
either their native units if `unit`, `xunit`, and `yunit` are not given, or converted
to those units before plotting. `unit` is applied to both x and y, `xunit` and
`yunit` override it for x and y, respectively. `unit`, `xunit`, and `yunit` must
be Unitful.Units values. For example:

    using Unitful;
    using JLLUtils;

    x = (1:10)u"m";
    y = (1000:1000:10000)u"m";

    plotas(x,y) # plots x and y in meters, their native unit
    plotas(x,y; unit=u"km") # plots both x and y in kilometers
    plotas(x,y; unit=u"km", xunit=u"m") # plots x in meters, y in kilometers
    plotas(x,y; yunit=u"km") # also plots x in meters, y in kilometers

The unit will be given in parentheses in the axis label. If you pass a string to
the `xlabel` or `ylabel` keywords, that string will be printed before the unit.
For example,

    plotas(x,y; yunit=u"km", xlabel="Distance", ylabel="Altitude")

would print "Distance (m)" as the x-axis label and "Altitude (km)" as the y-axis
label.

If only y is given, then x is created as a sequential array the same size as y.
Any extra keyword arguments are passed through to Plots.plot.

NOTE: the units of x and y are not saved anywhere, so if you later use `plot!`
to add more series, it is your resposibility to make sure that the new series
are the same units.
"""
function plotas(y; yunit=missing, kwargs...)
    x = JLLArrays.seq_mat(size(y)...);
    plotas(x, y; yunit=yunit, kwargs...)
end

function plotas(x, y; unit=missing, xunit=missing, yunit=missing, xlabel="", ylabel="", kwargs...)
    x, y = _convert_xy(x, y; unit=unit, xunit=xunit, yunit=yunit);

    xlabel *= " ($(Unitful.unit(x[1])))";
    ylabel *= " ($(Unitful.unit(y[1])))";

    return Plots.plot(Unitful.ustrip(x), Unitful.ustrip(y); xlabel=xlabel, ylabel=ylabel, kwargs...);
end

function plotas!(x, y; unit=missing, xunit=missing, yunit=missing, kwargs...)
    x, y = _convert_xy(x, y; unit=unit, xunit=xunit, yunit=yunit);
    return Plots.plot!(Unitful.ustrip(x), Unitful.ustrip(y); kwargs...)
end

function _convert_xy(x, y; unit, xunit, yunit)
    xunit = ismissing(xunit) ? unit : xunit;
    yunit = ismissing(yunit) ? unit : yunit;

    x = !ismissing(xunit) ? Unitful.uconvert.(xunit, x) : x;
    y = !ismissing(yunit) ? Unitful.uconvert.(yunit, y) : y;
    return x, y
end

end #module
