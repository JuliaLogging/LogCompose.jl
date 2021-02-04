module Connectors

using Logging
using ..LogCompose
import ..LogCompose: logcompose, log_min_level

#--------------------------------------------------------------------
# The connectors for individual logger implementations should ideally
# be in their own packages. Here we implement connectors only for the
# loggers in the stdlib Logging package.
#--------------------------------------------------------------------

logcompose(::Type{Logging.NullLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any}) = Logging.NullLogger()

function logcompose(::Type{Logging.SimpleLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    level = log_min_level(logger_config, "Info")

    streamname = strip(get(logger_config, "stream", "stdout"))
    @assert !isempty(streamname)

    stream = streamname == "stdout" ? stdout :
             streamname == "stderr" ? stderr :
             open(streamname, "a+")

    Logging.SimpleLogger(stream, level)
end

function logcompose(::Type{Logging.ConsoleLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    level = log_min_level(logger_config, "Info")

    streamname = strip(get(logger_config, "stream", "stdout"))
    @assert !isempty(streamname)

    stream = streamname == "stdout" ? stdout :
             streamname == "stderr" ? stderr :
             open(streamname, "a+")

    color = get(logger_config, "color", nothing)
    color === nothing || (stream = IOContext(stream, :color=>color))

    displaysize = get(logger_config, "displaysize", nothing)
    if displaysize !== nothing
        if !(displaysize isa AbstractVector) || length(displaysize) != 2
            error("Expected [height,width] but got displaysize=$displaysize")
        end
        stream = IOContext(stream, :displaysize=>Tuple(convert(Vector{Int},displaysize)))
    end

    show_limited = get(logger_config, "show_limited", true)
    color isa Bool || error("Expected boolean but got show_limited=$show_limited")

    Logging.ConsoleLogger(stream, level; show_limited=show_limited)
end

end # module Connectors
