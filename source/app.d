/++
 + Authors: Christian Koestlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

import ponies;
import ponies.dlang;
import ponies.dlang.travis;
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

void run(P)(P ponies, string what)
{
    "run".info;
    "Before running ponies".commit;
    foreach (pony; ponies.poniesToRun(what))
    {
        auto check = pony.check;
        "main:Checking %s -> %s".format(pony.name, check).info;
        if (check != CheckStatus.done)
        {
            "main:Running %s".format(pony.name).info;
            pony.run;
            "After %s".format(pony.name).commit;
        }
    }
}

void list(T)(T ponies, What what)
{
    "list args: %s".format(what).info;
    writeln("%s ponies:".format(what));
    auto table = AsciiTable(1, 1, 1, 1).add("class", "description", "applicable", "status");// dfmt off
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

        writeln(PACKAGE_VERSION);
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
    };// dfmt off
    Command rootCommand =
        Command("root", rootDelegate,
        [
            Option.boolWithName("help").withDescription("show general help"),
            Option.boolWithName("verbose").withDescription("enable verbose logging")],
            [
                Command("list", listDelegate,
                [
                    Option.boolWithName("help").withDescription("show list help"),
                    Option.withName("set").withDescription("which ponies to list").withDefault("readyToRun").allow(One!string.fromEnum!What)], []),
                Command("run", runDelegate,
                [
                    Option.boolWithName("help").withDescription("show run help"),
                    Option.withName("set").withDescription("set of ponies to run (+-set of regex on pony classes)").withDefault(".*")], []),
                Command("version", versionDelegate,
                [
                    Option.boolWithName("help").withDescription("show version help")], []),
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
        // new TravisPony,
        new LanguageTravisDlangPony,
        new CompilerTravisDlangPony,
        new NoSudoTravisDlangPony,
        new GhPagesTravisDlangPony,
        new GithubShieldPony,
        new TravisCiShieldPony,
        new CodecovShieldPony,
        new GithubPagesShieldPony,
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
