/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin, Christian Köstlin
 +/
import androidlogger : AndroidLogger;
import argparse : CLI;
import asciitable : AsciiTable, UnicodeParts;
import colored : bold, underlined, white, lightGray, green, red;
import packageinfo : packages;
import ponies.dlang.dub.registry;
import ponies.dlang.gitlab;
import ponies.dlang.travis;
import ponies.dlang;
import ponies.shields;
import ponies.utils;
import ponies;
import std.algorithm : fold, map, sort;
import std.array : array;
import std.conv : to;
import std.experimental.logger : sharedLog, info, LogLevel;
import std.file : exists;
import std.stdio : stderr, writeln, writefln;
import std.string : join, format, strip;
import std.sumtype : SumType, match;
import std.process : execute;

private:

void commit(string message)
{
    "main:%s".format(message).info;

    auto addCommand = ["git", "add", "-u"];
    auto res = addCommand.execute;
    "main:result of %s: %s".format(addCommand, res).info;
    auto commitCommand = ["git", "commit", "-m", message];
    res = commitCommand.execute;
    "main:result of %s: %s".format(commitCommand, res).info;
}

void run(P)(P ponies)
{
    "main:run".info;
    "main:Before running ponies".commit;
    "main:Selected ponies:\n  %s".format(ponies.map!("a.to!string").join("\n  ")).info;
    foreach (pony; ponies)
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

string colorize(string checkString)
{
    if (checkString == "done")
    {
        return checkString.green.to!string;
    }
    if (checkString == "todo")
    {
        return checkString.red.to!string;
    }
    return checkString;
}

void list(T)(T ponies, What what)
{
    writeln("%s ponies:".format(what));
    // dfmt off
    auto table = new AsciiTable(4)
        .header
            .add("class".bold)
            .add("description".bold)
            .add("applicable".bold)
            .add("status".bold);
    ponies
        .select(what)
        .fold!((table, pony) => table.row
               .add(pony.to!string)
               .add(pony.name)
               .add(pony.applicable.to!string)
               .add((pony.applicable ? pony.check.to!string : "----").colorize))(table)
        .format.parts(new UnicodeParts).headerSeparator(true).columnSeparator(true).to!string
        .writeln;
    // dfmt on
}

void doctorWithoutExceptionHandling(T)(T ponies)
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
    if (!".git".exists)
    {
        hints["Please create a git repository"] = ["general"];
    }
    if (!gitAvailable())
    {
        hints["Please install git"] = ["general"];
    }

    if (hints.length == 0)
    {
        writeln("All good");
        return;
    }

    auto table = new AsciiTable(2).header.add("by".underlined).add("what".underlined);
    foreach (hint, categories; hints)
    {
        table.row.add(categories.join("\n")).add(hint);
    }
    writeln(table.format.columnSeparator(true).rowSeparator(true).headerSeparator(true));
}

void doctor(T)(T ponies)
{
    try
    {
        doctorWithoutExceptionHandling(ponies);
    }
    catch (Exception e)
    {
        writeln("Fatal exception: ", e);
    }
}

void printVersion()
{
    // dfmt off
    auto table = packages
        .sort!("a.name < b.name")
        .fold!((table, p) => table
               .row
                   .add(p.name.white)
                   .add(p.semVer.lightGray)
                   .add(p.license.lightGray)
               .table
        )
        (new AsciiTable(3)
             .header
                 .add("Package".bold)
                 .add("Version".bold)
                 .add("License".bold).table);
    // dfmt on
    writefln("Packages:\n%s", table.format.parts(new UnicodeParts)
            .headerSeparator(true).columnSeparator(true));
}

int main_(Arguments arguments)
{
    sharedLog = new AndroidLogger(stderr, true, arguments.verbose ? LogLevel.all : LogLevel.warning);
    auto dubRegistry = new DubRegistryCache;
    // dfmt off
    auto ponies = [
        new ponies.dlang.PackageInfoPony,
        new ponies.dlang.AuthorsPony,
        new ponies.dlang.CopyrightCommentPony,
        new ponies.dlang.DDoxPony,
        new ponies.dlang.GeneratePackageDependenciesPony,
        new ponies.dlang.LicenseCommentPony,
        new ponies.dlang.dub.DdoxWithScodSkinPony,
        new ponies.dlang.dub.CompilerInfoPony,
        new ponies.dlang.dub.Lst2ErrorMessagesPony,
        new ponies.dlang.dub.registry.DubLicenseShieldPony(dubRegistry),
        new ponies.dlang.dub.registry.DubVersionShieldPony(dubRegistry),
        new ponies.dlang.dub.registry.DubWeeklyDownloadsShieldPony(dubRegistry),
        new ponies.dlang.dub.registry.CheckVersionsPony(dubRegistry),
        new ponies.dlang.gitlab.GitlabPony,
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

    arguments.subcommand.match!(
      (Version _) { printVersion; },
      (Doctor _) { ponies.selectedPonies(arguments.set).doctor(); },
      (List l) { ponies.selectedPonies(arguments.set).list(l.what); },
      (Run _) { ponies.selectedPonies(arguments.set).run(); },
    );
    // dfmt on

    return 0;
}

mixin CLI!(Arguments).main!((arguments) { return main_(arguments); });
