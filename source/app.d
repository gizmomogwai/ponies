/++
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

import androidlogger;
import asciitable;
import colored;
import commandline;
import ponies.dlang.dub.registry;
import ponies.dlang.travis;
import ponies.dlang;
import ponies.shields;
import ponies.utils;
import ponies;
import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.stdio;
import std.string;

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
            pony.name.commit;
        }
    }
}

void list(T)(T ponies, What what)
{
    "list args: %s".format(what).info;
    writeln("%s ponies:".format(what));
    auto table = new AsciiTable(4).header.add("class".bold)
        .add("description".bold).add("applicable".bold).add("status".bold);
    // dfmt off
    ponies
        .select(what)
        .fold!((table, pony) => table.row.add(pony.to!string).add(pony.name).add(pony.applicable.to!string).add(pony.applicable ? pony.check.to!string : "----"))(table)
        .table.format.parts(new UnicodeParts).headerSeparator(true).columnSeparator(true).to!string
        .writeln;
    // dfmt on
}

void doctor(T)(T ponies)
{
    string[][string] hints;
    foreach (pony; ponies)
    {
        foreach (hint; pony.doctor)
        {
            auto h = pony.to!string;
            if (hint !in hints)
            {
                hints[hint] = [];
            }
            hints[hint] ~= h;
        }
    }
    import std.file;

    if (!exists(".git"))
    {
        hints["Please create a git repository"] = ["general"];
    }
    if (!gitAvailable())
    {
        hints["Please install git"] = ["general"];
    }

    foreach (k, v; hints)
    {
        "%s:\n    %s".format(k, v.join("\n    ")).writeln;
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
            auto androidLog = new AndroidLogger(stderr, true,
                    (*verbose == "true") ? LogLevel.all : LogLevel.warning);
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

        import packageversion;

        // dfmt off
        auto table = packageversion
            .getPackages
            .sort!("a.name < b.name")
            .fold!((table, p) => table.row.add(p.name.white).add(p.semVer.lightGray).add(p.license.lightGray).table)
            (new AsciiTable(3).header.add("Package".bold).add("Version".bold).add("License".bold).table);
        // dfmt on
        writeln("Packages:\n", table.format.parts(new UnicodeParts)
                .headerSeparator(true).columnSeparator(true).to!string);
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
    auto doctorDelegate = (Command command) {
        if (command.helpNeeded)
        {
            writeln(command.help);
            return false;
        }
        doctor(ponies);
        return true;
    };
    // dfmt off
    Command rootCommand =
        Command("root", rootDelegate,
        [
            Option.boolWithName("help").withDescription("show general help"),
            Option.boolWithName("verbose").withDescription("enable verbose logging")],
            [
                Command("doctor", doctorDelegate,
                [
                    Option.boolWithName("help").withDescription("show doctor help"),
                ]),
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
    auto dubRegistry = new DubRegistryCache;
    writeln(dubRegistry.includes("colored"));
    // new TravisPony,
    // dfmt off
    auto ponies = [
        new ponies.dlang.AddPackageVersionPony,
        new ponies.dlang.AuthorsPony,
        new ponies.dlang.CopyrightCommentPony,
        new ponies.dlang.DDoxPony,
        new ponies.dlang.GeneratePackageDependenciesPony,
        new ponies.dlang.LicenseCommentPony,
        new ponies.dlang.dub.registry.DubLicenseShieldPony,
        new ponies.dlang.dub.registry.DubVersionShieldPony,
        new ponies.dlang.dub.registry.DubWeeklyDownloadsShieldPony,
        new ponies.dlang.travis.CompilerTravisDlangPony,
        new ponies.dlang.travis.GhPagesTravisDlangPony,
        new ponies.dlang.travis.LanguageTravisDlangPony,
        new ponies.dlang.travis.NoSudoTravisDlangPony,
        new ponies.shields.CodecovShieldPony,
        new ponies.shields.GithubPagesShieldPony,
        new ponies.shields.GithubShieldPony,
        new ponies.shields.MelpaShieldPony,
        new ponies.shields.TravisCiShieldPony,
        new ponies.dlang.FormatSourcesPony,
    ].sort!((v1, v2) => v1.to!string < v2.to!string).array;
    // dfmt on

    try
    {
        setupCommandline(ponies).parse(args[1 .. $]).run;
        return 0;
    }
    catch (Exception e)
    {
        e.message.writeln;
        e.to!string.writeln;
        return 1;
    }
}
