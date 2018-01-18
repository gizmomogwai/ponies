/++
 + License: MIT
 +/

import ponies.dlang;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;
import androidlogger;
import commandline;

void commit(string message)
{
    import std.process;

    auto addCommand = ["git", "add", "-u"];
    auto res = addCommand.execute;
    "result of %s: %s".format(addCommand, res).info;
    auto commitCommand = ["git", "commit", "-m", message];
    res = commitCommand.execute;
    "result of %s: %s".format(commitCommand, res).info;
}

auto readyToRun(P)(P ponies)
{
    return ponies.filter!(a => a.applicable);
}

void run(P)(P ponies, Option[] args)
{
    "run".info;
    foreach (pony; ponies.readyToRun)
    {
        "main:Checking %s".format(pony).info;
        if (!pony.check)
        {
            "main:Commit before %s".format(pony).info;
            "Before %s".format(pony.name).commit;
            "main:Running %s".format(pony).info;
            pony.run;
            "After %s".format(pony.name).commit;
            "main:Commit after %s".format(pony).info;
        }
    }

    //return 0;
}

void list(T)(T ponies, ParseResult args)
{
    "list args: %s".format(args).info;
    /*
    auto res = commandline.parse(args[1 .. $]);
    switch (res.rest[0])
    {
    case "all":
        ("All ponies: " ~ ponies.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    case "readyToRun":
        ("Ready to run ponies: " ~ ponies.readyToRun.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    default:
        throw new Exception("unknown list option %s".format(args));
    }
    */
}

int main(string[] args)
{
    sharedLog = new AndroidLogger(true, LogLevel.all);

    // dfmt off
    auto ponies = [
        new ponies.dlang.DDoxPony,
        new ponies.dlang.RakeFormatPony,
        new ponies.dlang.LicenseCommentPony,
    ];
    auto rootDelegate = (Command command) {
        "rootDelegate %s %s".format(command.result, ponies).info;
    };
    auto runDelegate = (Command command) {
        "runDelegate %s %s".format(command.result, ponies).info;
        //run(ponies, result);
    };
    auto versionDelegate = (Command command) {
        "versionDelegate %s %s".format(command.result, ponies).info;
    };
    auto listDelegate = (Command command) {
        "listDelegate %s %s".format(command.result, ponies).info;
        //list(ponies, result);
    };

    Command rootCommand =
        Command(
            "root", rootDelegate,
            [
                Option.withName("help").withDescription("show general help"),
                Option.withName("verbose").withDescription("enable verbose logging").withDefault("false")
            ],
            [
                Command("run", runDelegate,
                        [Option.withName("help").withDescription("show run help")],
                        []
                ),
                Command("version", versionDelegate,
                        [Option.withName("help").withDescription("show version help")],
                        []
                ),
                Command("list", listDelegate,
                        [
                            Option.withName("help").withDescription("show list help"),
                            Option.withName("set").withDescription("which ponies to list (all|readyToRun)").withDefault("readyToRun")
                        ], []
                )
            ]
        );
    // dfmt on

    rootCommand.parse(args[1..$]);
    /*
    writeln("parsed: ", rootCommand.result.parsed);
    if ("help" in rootCommand.result.parsed) {
        writeln(rootCommand.help);
        return 0;
    }

    if ("help" in rootCommand.subCommand.result.parsed) {
        writeln(rootCommand.subCommand.help);
    }
    */
    rootCommand.run;

    return 1;
}
