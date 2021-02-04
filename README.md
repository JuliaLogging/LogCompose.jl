# LogCompose

[![Build Status](https://github.com/tanmaykm/LogCompose.jl/workflows/CI/badge.svg)](https://github.com/tanmaykm/LogCompose.jl/actions?query=workflow%3ACI+branch%3Amaster)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/tanmaykm/LogCompose.jl?branch=master&svg=true)](https://ci.appveyor.com/project/tanmaykm/logroller-jl/branch/master)
[![codecov.io](http://codecov.io/github/tanmaykm/LogCompose.jl/coverage.svg?branch=master)](http://codecov.io/github/tanmaykm/LogCompose.jl?branch=master)

Provides a way to specify hierarchical logging configuration in a file.

Configuration file is in the form of a TOML file. Configuration sections are named,
with each section specifying a logger type and parameters needed for its construction.
Sections inherit parameter values from preceeding sections and can override them as well.
Loggers can be constructed by providing the name of a section.

[Here](example.toml) is what a configuration that allows logging to several types of loggers may look like.

## Plugging in a Logger

Support for a logger can be added by providing an implementation of `LogCompose.logcompose` for the target logger type.
The implementation needs to be of the following form:

```julia
function LogCompose.logcompose(::Type{MyLoggerType},
        config::Dict{String,Any},           # config: the entire logging configuration file
        logger_config::Dict{String,Any})    # logger_config: configuration relevant for the
                                            #      section specified to `LogCompose.logger`
                                            #      with the hierarchy flattened out
    # provides support for MyLoggerType in LogCompose
end
```

For complete examples, refer to any of the existing implementations listed below.

## Loggers Supported

LogCompose has in-built support for the loggers provided in the stdlib logging package.
They are listed below with example configuration sections illustrating parameters they accept.

- Logging.SimpleLogger
    ```
    [loggers.simple]
    type = "Logging.SimpleLogger"
    # min_level = "Debug"             # Debug, Info (default) or Error
    stream = "simple.log"             # file to log to
    ```
- Logging.ConsoleLogger
    ```
    [loggers.console]
    type = "Logging.ConsoleLogger"
    # min_level = "Debug"             # Debug, Info (default) or Error
    stream = "stdout"                 # stdout (default), stderr or a filepath
    ```
- Logging.NullLogger
    ```
    [loggers.null]
    type = "Logging.NullLogger"
    ```

There are external packages that provide support for a few other types of loggers as well:

- LoggingExtras: [LoggingExtrasCompose.jl](https://github.com/tanmaykm/LoggingExtrasCompose.jl)
- LogRoller: [LogRollerCompose.jl](https://github.com/tanmaykm/LogRollerCompose.jl)
- SyslogLogging: [SyslogLoggingCompose.jl](https://github.com/tanmaykm/SyslogLoggingCompose.jl)

For loggers supplied by external packages, LogCompose looks for the logger implementation type
(the one mentioned in `type` configuration attribute) in the `Main` module by default. But if
your code imports the external loggers within your module instead of the Main module, then the
module name where the logger type can be found must be specified in the (otherwise optional)
`topmodule` configuration parameter. E.g.:

```
[loggers.rollinglog]
type = "LogRoller.RollingFileLogger"
topmodule = "MyModule"
...
```

## Examples

Here is an example configuration using multiple logger types, from different logging packages.

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

And below is a snippet of Julia code that make use of this configuration:

```julia
julia> using LogCompose, Logging

julia> using LogRoller, LogRollerCompose

julia> using SyslogLogging, SyslogLoggingCompose

julia> using LoggingExtras, LoggingExtrasCompose

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
