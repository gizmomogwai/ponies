/++ Ponies main module.
 +
 + <img src="images/dependencies.svg" />
 +
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 +/
module ponies;

import argparse : ArgumentGroup, NamedArgument, Command, SubCommands, Default,
    Parse, Action, PreValidation, Validation, ansiStylingArgument, Description;
import std.algorithm : filter, map, fold, canFind;
import std.conv : to;
import std.exception : ifThrown;
import std.experimental.logger : info;
import std.process : execute;
import std.range : array;
import std.regex : Regex, regex, match, matchFirst;
import std.stdio : writeln, readln;
import std.string : split, format, strip, join, replace;
import std.sumtype : SumType;
import std.traits : EnumMembers;
import std.typecons : tuple, Tuple;
import std.file : readText, write, exists;

private:
version (unittest)
{
    import unit_threaded;
}
public
{
    // Commandline parsing
    @(Command("version").Description("Show version."))
    struct Version
    {
    }

    @(Command("doctor").Description("Check if ponies are happy."))
    struct Doctor
    {
    }

    @(Command("list").Description("List all ponies and their current state."))
    struct List
    {
        What what = What.all;
    }

    @(Command("run").Description("Run ponies."))
    struct Run
    {
    }

    struct Arguments
    {
        @ArgumentGroup("Common arguments")
        {
            @(NamedArgument.Description("Verbose output."))
            bool verbose;

            @(NamedArgument.Description("Comma separated list of +- regexes."))
            string set = "+.*";

            @NamedArgument auto color = ansiStylingArgument;
        }
        @SubCommands SumType!(Default!Version, Doctor, List, Run) subcommand;
    }
}
enum Vote
{
    up,
    down,
    dontCare
}

auto removePlusMinusPrefix(string s)
{
    auto negate = false;
    if (s[0] == '-')
    {
        negate = true;
        s = s[1 .. $];
    }
    else if (s[0] == '+')
    {
        s = s[1 .. $];
    }
    return tuple!("negative", "text")(negate, s);
}

@("check remove plusminusprefix") unittest
{
    "-test".removePlusMinusPrefix.shouldEqual(tuple(true, "test"));
    "test".removePlusMinusPrefix.shouldEqual(tuple(false, "test"));
    "+test".removePlusMinusPrefix.shouldEqual(tuple(false, "test"));
}

auto voteByPlusMinusRegex(string pony, string plusMinusRegex)
{
    if (plusMinusRegex.length == 0)
    {
        return Vote.dontCare;
    }

    const pm = plusMinusRegex.removePlusMinusPrefix();

    auto r = pm.text.regex;
    if (pony.match(r))
    {
        if (pm.negative)
        {
            return Vote.down;
        }
        else
        {
            return Vote.up;
        }
    }
    else
    {
        return Vote.dontCare;
    }
}

bool vote(P)(P pony, bool old, string pattern)
{
    const h = voteByPlusMinusRegex(pony.to!string, pattern);
    switch (h)
    {
    case Vote.up:
        return true;
    case Vote.down:
        return false;
    default:
        return old;
    }
}

bool selected(P)(P pony, string set)
{
    // dfmt off
    return set
        .split(",")
        .fold!((result, pattern) => pony.vote(result, pattern))
        (true);
    // dfmt on
}

@("select a pony") unittest
{
    "test".selected(".*").shouldBeTrue;
    "test".selected("-.*").shouldBeFalse;
    "test".selected("test1,+es").shouldBeTrue;
    "test".selected("test1,-es").shouldBeFalse;
    "test".selected(".*,-test").shouldBeFalse;
    "test".selected("-.*,+test").shouldBeTrue;
    "a.dlang.pony".selected(".*dlang.*").shouldBeTrue;
    "a.dlang.pony".selected("-.*dlang.*").shouldBeFalse;
    "a.dlang.pony".selected("-travis").shouldBeTrue;
}

auto applicablePonies(P)(P ponies)
{
    return ponies.filter!(a => a.applicable).array;
}

public auto selectedPonies(P)(P ponies, string set)
{
    return ponies.filter!(a => a.selected(set)).array;
}

public enum What
{
    all,
    applicable,
}

public auto select(T)(T ponies, What what)
{
    switch (what)
    {
    case What.all:
        return ponies;
    case What.applicable:
        return ponies.applicablePonies;
    default:
        throw new Exception("nyi");
    }
}

auto possibleValues(E)() if (is(E == enum))
{
    return [EnumMembers!E].map!("a.to!string").join(", ");
}

public T askFor(T)() if (is(T == enum))
{
    writeln("Please enter %s [%s]: ".format(T.stringof, possibleValues!T));
    auto line = readln.strip;
    return line.to!T;
}

/// Ponies can return one of these values when running check on a project
public enum CheckStatus
{
    todo,
    done,
    dont_know
}

/// Chain a CheckStatus with a simple bool
public CheckStatus and(CheckStatus checkStatus, bool check)
{
    if (!check)
    {
        return CheckStatus.todo;
    }
    return checkStatus;
}

@("bool to checkstatus") unittest
{
    true.to!CheckStatus.shouldEqual(CheckStatus.done);
    false.to!CheckStatus.shouldEqual(CheckStatus.todo);
}

public abstract class Pony
{
    struct EnsureStringInFile
    {
        string file;
        string lines;
    }

    EnsureStringInFile[] ensureStringsInFiles;
    this()
    {
        this([]);
    }

    this(EnsureStringInFile[] ensureStringsInFiles)
    {
        this.ensureStringsInFiles = ensureStringsInFiles;
    }

    public abstract string name();
    public abstract bool applicable()
    {
        return true;
    }

    public CheckStatus check()
    {
        foreach (ensureStringInFile; ensureStringsInFiles)
        {
            if (!ensureStringInFile.file.readText.ifThrown("").canFind(ensureStringInFile.lines))
            {
                return CheckStatus.todo;
            }
        }
        return CheckStatus.done;
    }

    public string[] doctor()
    {
        string[] result = [];
        foreach (ensureStringInFile; ensureStringsInFiles)
        {
            if (!ensureStringInFile.file.exists)
            {
                result ~= "Please add %s to project".format(ensureStringInFile.file);
            }
        }
        return result;
    }

    public void run()
    {
        foreach (ensureStringInFile; ensureStringsInFiles)
        {
            changeFile(ensureStringInFile);
        }

    }

    protected string logTag()
    {
        return this.classinfo.name;
    }

    protected void changeFile(EnsureStringInFile ensureStringInFile)
    {
        changeFile(ensureStringInFile.file, (content) {
            if (!content.canFind(ensureStringInFile.lines))
            {
                content ~= ensureStringInFile.lines;
            }
            return content;
        });
    }

    protected void changeFile(string filename, string delegate(string) change)
    {
        const oldContent = filename.readText.ifThrown("");
        const newContent = change(oldContent.dup);
        if (newContent != oldContent)
        {
            "%s:Writing new %s".format(logTag, filename).info;
            filename.write(newContent);
            ["git", "add", filename].execute;
        }
    }
}

public alias UserAndProject = Tuple!(string, "user", string, "project");
public UserAndProject userAndProject;
public auto getUserAndProject()
{
    auto res = ["git", "remote", "get-url", "origin"].execute;
    auto pattern = "github.com:(?P<user>.*)/(?P<project>.*)";
    auto match = res.output.matchFirst(regex(pattern, "m"));
    if (match)
    {
        return UserAndProject(match["user"], match["project"].replace(".git", ""));
    }
    else
    {
        return UserAndProject(cast(string) null, cast(string) null);
    }
}
