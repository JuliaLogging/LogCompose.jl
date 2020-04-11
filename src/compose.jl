using Logging

name_parts(loggername) = split(loggername, '.')

function configuration(configfile::String; section::String="")
    config = Pkg.TOML.parsefile(configfile)
    isempty(section) ? config : get_section(config, [section])
end

function get_section(config::Dict{String,Any}, path::Vector)
    isempty(path) && (return config)

    top = get(config, first(path)) do
        Dict{String,Any}()
    end

    (length(path) > 1) ? get_section(top, path[2:end]) : top
end

function flatten(config::Dict{String,Any}, path::Vector)
    result = Dict{String,Any}()
    for depth in 1:length(path)
        merge!(result, get_section(config, path[1:depth]))
    end
    result
end

function get_type(s::String, topmodule::Module=@__MODULE__)
    try
        T = topmodule
        for t in split(s, ".")
            T = Base.eval(T, Symbol(t))
        end
        return T
    catch ex
        nextmodule = parentmodule(topmodule)
        if nextmodule == topmodule
            error("Could not resolve logger $s. Ensure that the required logging packages are imported!")
        else
            return get_type(s, nextmodule)
        end
    end
end

function get_type(s::String, modules::Vector{Module})
    L = length(modules)
    for idx in 1:L
        try
            return get_type(s, modules[idx])
        catch ex
            (idx == L) && rethrow(ex)
        end
    end
end

logger(configfile::String, loggername::String; section::String="") = logger(configuration(configfile; section=section), name_parts(loggername))
logger(config::Dict{String,Any}, loggername::String) = logger(config, name_parts(loggername))
function logger(config::Dict{String,Any}, loggername::Vector)
    loggercfg = flatten(config, loggername)
    loggertypestr = loggercfg["type"]
    loggertopmodule = Base.eval(Main, Symbol(get(loggercfg, "topmodule", "Main")))
    modules = collect(Set([Main, loggertopmodule, @__MODULE__]))
    loggertype = get_type(loggertypestr, modules)

    logcompose(loggertype, config, loggercfg)
end

logcompose(::Type{T}, config::Dict{String,Any}, logger_config::Dict{String,Any}) where {T} = error("logcompose not implemented for type $T")

log_min_level(logger_config::Dict{String,Any}, default::String="Info") = getproperty(Logging, Symbol(get(logger_config, "min_level", default)))
