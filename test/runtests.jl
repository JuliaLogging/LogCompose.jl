using LogCompose, Test, Logging, LoggingExtras

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
                    @info("testconsole2", a=[111,222,333])
                end
                flush(logger.stream)
            end
        end
        close(writer)
        log_file_contents = String(read(Base.pipe_reader(pipe)))
        @test findfirst("testconsole", log_file_contents) !== nothing
        @test findfirst("testconsole2", log_file_contents) !== nothing
        # setting displaysize limits output
        @test findfirst("111", log_file_contents) === nothing
        # ANSI color codes were enabled
        @test findfirst("\e", log_file_contents) !== nothing
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

    file1 = "testapp1.log"
    file2 = "testapp2.log"
    rm(file1; force=true)
    rm(file2; force=true)

    let logger = LogCompose.logger(config, "file1"; section="loggers")
        with_logger(logger) do
            @info("testfile1")
        end
    end

    let logger = LogCompose.logger(config, "file2"; section="loggers")
        with_logger(logger) do
            @info("testfile2")
        end
    end

    let logger = LogCompose.logger(config, "tee"; section="loggers")
        with_logger(logger) do
            @info("testtee")
        end
    end

    @test isfile(file1)
    @test isfile(file2)

    log_file_contents = readlines(file1)
    @test findfirst("testfile1", log_file_contents[1]) !== nothing
    @test findfirst("testtee", log_file_contents[3]) !== nothing

    log_file_contents = readlines(file2)
    @test findfirst("testfile2", log_file_contents[1]) !== nothing
    @test findfirst("testtee", log_file_contents[3]) !== nothing

    try
        rm(simple_logfile; force=true)
        rm(file1; force=true)
        rm(file2; force=true)
    catch ex
        # ignore (occasionally fails with resource busy exception on Windows, because logger has not been gc'd yet)
    end
end

test()
