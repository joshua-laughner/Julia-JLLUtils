module JLLDateTime

import Dates;

"""
    unix2datetime(unix_timestamp)

Convert a Unix timestamp (seconds since midnight, Jan 1 1970) into a DateTime.
"""
function unix2datetime(unix_timestamp)
    return Dates.DateTime(1970, 1, 1) + Dates.Second(unix_timestamp);
end

end # JLLDateTime