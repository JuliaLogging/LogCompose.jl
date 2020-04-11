module Connectors

using Logging
using ..LogCompose
import ..LogCompose: logcompose, log_min_level, log_assumed_level

#--------------------------------------------------------------------
# The connectors for individual logger implementations should ideally
# be in their own packages. Here we implement connectors only for the
# loggers in the stdlib Logging package.
#--------------------------------------------------------------------

logcompose(::Type{Logging.NullLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any}) = Logging.NullLogger()

function logcompose(::Type{T}, config::Dict{String,Any}, logger_config::Dict{String,Any}) where {T <: Union{Logging.SimpleLogger, Logging.ConsoleLogger}}
    level = log_min_level(logger_config, "Info")

    streamname = strip(get(logger_config, "stream", "stdout"))
    @assert !isempty(streamname)

    stream = streamname == "stdout" ? stdout :
             streamname == "stderr" ? stderr :
             open(streamname, "a+")

    T(stream, level)
end

end # module Connectors
