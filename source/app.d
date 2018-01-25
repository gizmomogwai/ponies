/++
 + Authors: Christian Koestlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

import ponies;
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

    "main:%s".format(message).info;

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
    "Before running ponies".commit;
    foreach (pony; ponies.readyToRun)
    {
        "main:Checking %s".format(pony.name).info;
        if (!pony.check)
        {
            "main:Running %s".format(pony.name).info;
            pony.run;
            "After %s".format(pony.name).commit;
        }
    }

    //return 0;
}

enum What
{
    all,
    readyToRun
}

void list(T)(T ponies, What what)
{
    import std.array;
    import std.range;

    "list args: %s".format(what).info;

    auto pony2string = (Pony pony) {
        return "%s - %s (applicable=%s)".format(pony, pony.name, pony.applicable);
    };

    switch (what)
    {
    case What.all:
        ("All ponies: " ~ ponies.map!(pony2string).join("\n  ")).writeln;
        return;
    case What.readyToRun:
        ("Ready to run ponies: " ~ ponies.readyToRun.map!(pony2string)
                .join("\n  ")).writeln;
        return;
    default:
        throw new Exception("unknown list option %s".format(what));
    }
}

auto setupCommandline(P)(P ponies)
{
    bool delegate(Command) rootDelegate = (Command command) {
        if (command.helpNeeded)
        {
            writeln(command.help);
            return false;
        }
        if (auto verbose = "verbose" in command.parsed)
        {
            auto androidLog = new AndroidLogger(true, (*verbose == "true")
                    ? LogLevel.all : LogLevel.warning);
            sharedLog = androidLog;
        }
        return true;
    };
    auto runDelegate = (Command command) {
        if (command.helpNeeded)
        {
            writeln(command.help);
            return false;
        }
        run(ponies);
        return true;
    };
    bool delegate(Command) versionDelegate = (Command command) {
        if (command.helpNeeded)
        {
            writeln(command.help);
            return false;
        }
        import ponies.packageversion;

        writeln(packageVersion);
        return true;
    };
    auto listDelegate = (Command command) {
        if (command.helpNeeded)
        {
            writeln(command.help);
            return false;
        }
        list(ponies, command.parsed["set"].to!What);
        return true;
    };

    // dfmt off
    Command rootCommand =
        Command("root", rootDelegate,
        [
            Option.withName("help").withShortName("h").withDescription("show general help"),
            Option.withName("verbose").withShortName("v").withDescription("enable verbose logging").withDefault("false")],
            [
                Command("list", listDelegate,
                         [
                          Option.withName("help").withShortName("h").withDescription("show list help"),
                          Option.withName("set").withShortName("s").withDescription("which ponies to list (all|readyToRun)").withDefault("readyToRun")], []),
                Command("run", runDelegate,
                        [Option.withName("help").withShortName("h").withDescription("show run help")], []),
                Command("version", versionDelegate,
                        [Option.withName("help").withShortName("h").withDescription("show version help")], []),
             ]);
    // dfmt on

    return rootCommand;
}

int main(string[] args)
{
    // dfmt off
    auto ponies = [
        new DDoxPony,
        new AuthorsPony,
        new LicenseCommentPony,
        new CopyrightCommentPony,
        new TravisPony,
        new GithubPagesShieldPony,
        new TravisCiShieldPony,
        new GithubShieldPony,
        new CodecovShieldPony,
        new AddPackageVersionPony,
        new FormatSourcesPony,
    ];
    // dfmt on

    setupCommandline(ponies).parse(args[1 .. $]).run;

    return 0;
}
