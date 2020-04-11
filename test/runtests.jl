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

    invalid_config = Dict{String,Any}(
        "invalid" => Dict{String,Any}(
            "type" => "UnknownModule.UnknownLogger"
        )
    )
    @test_throws ErrorException LogCompose.logger(invalid_config, "invalid")
    @test_throws ErrorException LogCompose.logcompose(String, invalid_config, invalid_config)

    try
        rm(simple_logfile; force=true)
    catch ex
        # ignore (occasionally fails with resource busy exception on Windows, because logger has not been gc'd yet)
    end
end

test()
