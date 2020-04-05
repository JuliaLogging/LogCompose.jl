module Connectors

using ..LogCompose
import ..LogCompose: logcompose, log_min_level, log_assumed_level

using Logging, LogRoller, SyslogLogging, LoggingExtras, Sockets

#--------------------------------------------------------------------
# The connectors for individual logger implementations should ideally
# be in their own packages.
#--------------------------------------------------------------------

function logcompose(::Type{Logging.SimpleLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    level = log_min_level(logger_config, "Info")

    streamname = strip(get(logger_config, "stream", "stdout"))
    @assert !isempty(streamname)

    stream = streamname == "stdout" ? stdout :
             streamname == "stderr" ? stderr :
             open(streamname, "w+")

    Logging.SimpleLogger(stream, level)
end

const sysloglck = ReentrantLock()
function logcompose(::Type{SyslogLogging.SyslogLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    ident = logger_config["identity"]
    level = log_min_level(logger_config, "Info")

    kwargs = Dict{Symbol,Any}()

    kwargs[:facility] = Symbol(get(logger_config, "facility", "user"))

    if get(logger_config, "lock", false)
        kwargs[:lck] = sysloglck
    end

    server_type = get(logger_config, "server_type", "local")
    if (server_type == "tcp") || (server_type == "udp")
        kwargs[:tcp] = (server_type == "tcp")
        if haskey(logger_config, "server_host")
            kwargs[:host] = logger_config["server_host"]
        end
        if haskey(logger_config, "server_port")
            kwargs[:port] = logger_config["server_port"]
        end
    end
    SyslogLogging.SyslogLogger(ident, level; kwargs...)
end

function logcompose(::Type{LogRoller.RollingLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    filename = String(strip(logger_config["filename"]))
    @assert !isempty(filename)

    level = log_min_level(logger_config, "Info")
    sizelimit = get(logger_config, "sizelimit", 10240000)
    nfiles = get(logger_config, "nfiles", 5)
    timestamp_identifier = Symbol(get(logger_config, "timestamp_identifier", "time"))

    LogRoller.RollingLogger(filename, sizelimit, nfiles, level; timestamp_identifier=timestamp_identifier)
end

function logcompose(::typeof(LogRoller.RollingFileWriterTee), config::Dict{String,Any}, logger_config::Dict{String,Any})
    filename = String(strip(logger_config["filename"]))
    @assert !isempty(filename)

    level = log_assumed_level(logger_config, "Info")
    sizelimit = get(logger_config, "sizelimit", 10240000)
    nfiles = get(logger_config, "nfiles", 5)
    destination_name = logger_config["destination"]
    destination = LogCompose.logger(config, destination_name)
    LogRoller.RollingFileWriterTee(filename, sizelimit, nfiles, destination, level)
end

function logcompose(::Type{LoggingExtras.TeeLogger}, config::Dict{String,Any}, logger_config::Dict{String,Any})
    destinations = [LogCompose.logger(config, dest) for dest in logger_config["destinations"]]
    LoggingExtras.TeeLogger(destinations...)
end

end # module Connectors
