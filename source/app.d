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
import asciitable;
import std.array;

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
    return ponies.filter!(a => a.applicable).array;
}

void run(P)(P ponies, string what)
{
    "run".info;
    "Before running ponies".commit;
    foreach (pony; ponies.readyToRun)
    {
        if (!(what == "all" || what.canFind(pony.to!string)))
        {
            continue;
        }
        "main:Checking %s".format(pony.name).info;
        if (pony.check != CheckStatus.done)
        {
            "main:Running %s".format(pony.name).info;
            pony.run;
            "After %s".format(pony.name).commit;
        }
    }
}

enum What
{
    all,
    readyToRun
}

auto select(T)(T ponies, What what)
{
    switch (what)
    {
    case What.all:
        return ponies;
    case What.readyToRun:
        return ponies.readyToRun;
    default:
        throw new Exception("nyi");
    }
}

void list(T)(T ponies, What what)
{
    "list args: %s".format(what).info;
    writeln("%s ponies:".format(what));
    auto table = AsciiTable(1, 1, 1, 1).add("class", "description", "applicable", "status");
    // dfmt off
    ponies
        .select(what)
        .fold!((table, pony) => table.add(pony.to!string,
            pony.name, pony.applicable.to!string, pony.applicable ? pony.check.to!string : "----"))(
            table)
        .toString("    ", "  ")
        .writeln;
    // dfmt on
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
        run(ponies, command.parsed["set"]);
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
            Option.withName("help").withShortName("h").withDescription("show general help").allow(One.of("true", "false")),
            Option.withName("verbose").withShortName("v").withDescription("enable verbose logging").withDefault("false").allow(One.of("true", "false"))],
            [
                Command("list", listDelegate,
                         [
                          Option.withName("help").withShortName("h").withDescription("show list help").allow(One.of("true", "false")),
                          Option.withName("set").withShortName("s").withDescription("which ponies to list").withDefault("readyToRun").allow(One.fromEnum!What)], []),
                Command("run", runDelegate,
                        [Option.withName("help").withShortName("h").withDescription("show run help").allow(One.of("true", "false")),
                         Option.withName("set").withShortName("s").withDescription("set of ponies to run").withDefault("all").allow(Set.fromArray(["all"] ~ ponies.map!(a => a.to!string).array))], []),
                Command("version", versionDelegate,
                        [Option.withName("help").withShortName("h").withDescription("show version help").allow(One.of("true", "false"))], []),
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

    try
    {
        setupCommandline(ponies).parse(args[1 .. $]).run;
        return 0;
    }
    catch (Exception e)
    {
        e.message.writeln;
        return 1;
    }
}
