# LogCompose

[![Build Status](https://travis-ci.org/tanmaykm/LogCompose.jl.png)](https://travis-ci.org/tanmaykm/LogCompose.jl) 
[![Coverage Status](https://coveralls.io/repos/github/tanmaykm/LogCompose.jl/badge.svg?branch=master)](https://coveralls.io/github/tanmaykm/LogCompose.jl?branch=master)

Provides a way to specify hierarchical logging configuration in a file.

Configuration file is in the form of a TOML file. Configuration sections are named,
with each section specifying a logger type and parameters needed for its construction.
Sections inherit parameter values from preceeding sectiona and can override them as well.
Loggers can be constructed by providing the name of a section.

### Example configuration

```toml
[file]
type = "LogRoller.RollingLogger"
min_level = "Info"
nfiles = 5

[syslog]
type = "SyslogLogging.SyslogLogger"
facility = "user"

[file.testapp1]
filename = "/tmp/testapp1.log"

[file.testapp2]
filename = "/tmp/testapp2.log"
min_level = "Debug"     # overrides min_level to Debug for testapp2
nfiles = 10             # overrides nfiles to 10 for testapp2

[syslog.testapp1]
identity = "testapp1"
facility = "daemon"     # facility set to daemon instead of default user

[syslog.testapp2]
identity = "testapp2"

[testapp1]
type = "LoggingExtras.TeeLogger"
destinations = ["file.testapp1", "syslog.testapp1"]

[testapp2]
type = "LoggingExtras.TeeLogger"
destinations = ["file.testapp2", "syslog.testapp2"]
```

### Example usage

```julia
julia> using LogCompose, Logging, LogRoller, SyslogLogging, LoggingExtras

julia> logger1 = LogCompose.logger("testconfig.toml", "testapp1");

julia> typeof(logger1)
TeeLogger{Tuple{RollingLogger,SyslogLogger}}

julia> logger2 = LogCompose.logger("testconfig.toml", "testapp2");

julia> typeof(logger2)
TeeLogger{Tuple{RollingLogger,SyslogLogger}}

julia> first(logger1.loggers).stream.filename
"/tmp/testapp1.log"

julia> first(logger2.loggers).stream.filename
"/tmp/testapp2.log"

julia> first(logger2.loggers).stream.nfiles
10

julia> with_logger(logger1) do
           @info("hello from app1")
       end

shell> cat /tmp/testapp1.log
┌ Info: 2020-04-02T12:03:03.588: hello from app1
└ @ Main REPL[13]:2

julia> with_logger(logger2) do
           @info("hello from app2")
       end

shell> cat /tmp/testapp2.log
┌ Info: 2020-04-02T12:04:13.156: hello from app2
└ @ Main REPL[15]:2

```

### Loggers Supported

LogCompose supports the following types of loggers at the moment:

- Logging.SimpleLogger
- LoggingExtras.TeeLogger
- LogRoller.RollingLogger
- LogRoler.RollingFileWriterTee
- SyslogLogging.SyslogLogger

### Plugging in other Loggers

Support for a new logger can be added by providing an implementation of `LogCompose.logcompose` for the target logger type.
This can be done in user code or in a package other than LogCompose. The implementation needs to be of the following form:

```julia
function LogCompose.logcompose(::Type{MyLoggerType},
        config::Dict{String,Any},           # config: the entire logging configuration file
        logger_config::Dict{String,Any})    # logger_config: configuration relevant for the
                                            #      section specified to `LogCompose.logger`
                                            #      with the hierarchy flattened out
    # provides support for MyLoggerType in LogCompose
end
```

