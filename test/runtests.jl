using LogCompose, Test, Logging

function test()
    config = joinpath(@__DIR__, "testapp.toml")
    simple_logfile = "simple.log"
    rm(simple_logfile; force=true)

    let logger = LogCompose.logger(config, "simple"; section="loggers")
        with_logger(logger) do
            @info("testsimple")
        end
        flush(logger.stream)

        log_file_contents = readlines(simple_logfile)
        @test findfirst("testsimple", log_file_contents[1]) !== nothing
    end

    let pipe = Pipe()
        Base.link_pipe!(pipe)
        writer = Base.pipe_writer(pipe)
        redirect_stdout(writer) do
            let logger = LogCompose.logger(config, "console"; section="loggers")
                with_logger(logger) do
                    @info("testconsole")
                end
                flush(logger.stream)
            end
        end
        close(writer)
        log_file_contents = readlines(Base.pipe_reader(pipe))
        @test findfirst("testconsole", log_file_contents[1]) !== nothing
        close(pipe)
    end

    let logger = LogCompose.logger(config, "null"; section="loggers")
        with_logger(logger) do
            @info("testnull")
        end
    end

    rm(simple_logfile; force=true)
end

test()
