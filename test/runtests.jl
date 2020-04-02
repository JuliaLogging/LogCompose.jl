using LogCompose, Test, Logging, LogRoller, SyslogLogging, LoggingExtras

function test()
    config = joinpath(@__DIR__, "testapp.toml")
    default_logfile = "/tmp/default.log"
    rotated_logfile = "/tmp/testapp.log"
    rm(rotated_logfile; force=true)
    rm(default_logfile; force=true)

    let logger = LogCompose.logger(config, "default"; section="loggers")
        with_logger(logger) do
            @info("testdefault")
        end
        @test isfile(default_logfile)
        close(logger.stream)
    end

    let logger = LogCompose.logger(config, "file.testapp"; section="loggers")
        with_logger(logger) do
            @info("testroller")
        end
        @test isfile(rotated_logfile)
    end

    let logger = LogCompose.logger(config, "syslog.testapp"; section="loggers")
        with_logger(logger) do
            @info("testsyslog")
        end
    end

    let logger = LogCompose.logger(config, "testapp"; section="loggers")
        with_logger(logger) do
            @info("testtee")
        end
    end

    log_file_contents = readlines(default_logfile)
    @test findfirst("testdefault", log_file_contents[1]) !== nothing

    log_file_contents = readlines(rotated_logfile)
    @test findfirst("testroller", log_file_contents[1]) !== nothing
    @test findfirst("testtee", log_file_contents[3]) !== nothing
end

test()
