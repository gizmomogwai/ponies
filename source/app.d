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
import std.conv;
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

void run(P)(P ponies)
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

enum What {
    all, readyToRun
}

void list(T)(T ponies, What what)
{
    "list args: %s".format(what).info;

    switch (what)
    {
    case What.all:
        ("All ponies: " ~ ponies.map!(a => a.toString).join("\n  ")).writeln;
        return;
    case What.readyToRun:
        ("Ready to run ponies: " ~ ponies.readyToRun.map!(a => a.toString).join("\n  ")).writeln;
        return;
    default:
        throw new Exception("unknown list option %s".format(what));
    }
}

int main(string[] args)
{
    auto androidLogger = new AndroidLogger(true, LogLevel.warning);
    sharedLog = androidLogger;

    // dfmt off
    auto ponies = [
        new ponies.dlang.DDoxPony,
        new ponies.dlang.RakeFormatPony,
        new ponies.dlang.LicenseCommentPony,
    ];

    auto rootDelegate = (Command command) {
        if (auto verbose = "verbose" in command.result.parsed) {
            if (*verbose == "true") {
                androidLogger.logLevel = LogLevel.all;
            }
        }
        "rootDelegate %s %s".format(command.result, ponies).info;
        if (command.helpNeeded) {
            writeln(command.help);
        }
    };
    auto runDelegate = (Command command) {
        "runDelegate %s %s".format(command.result, ponies).info;
        if (command.helpNeeded) {
            writeln(command.help);
        } else {
            run(ponies);
        }
    };
    auto versionDelegate = (Command command) {
        "versionDelegate %s %s".format(command.result, ponies).info;
        if (command.helpNeeded) {
            writeln(command.help);
        }
    };
    auto listDelegate = (Command command) {
        "listDelegate %s %s".format(command.result, ponies).info;
        if (command.helpNeeded) {
            writeln(command.help);
        } else {
            auto what = command.result.parsed["set"].to!What;
            writeln(what);
            list(ponies, what);
        }
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
