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
    Parse, Action, PreValidation, Validation;
import std.algorithm : filter, map, fold;
import std.conv : to;
import std.experimental.logger : info, warning;
import std.process : execute;
import std.range : array;
import std.regex : Regex, regex, match, matchFirst;
import std.stdio : writeln, readln;
import std.string : split, format, strip, join, replace;
import std.sumtype : SumType;
import std.traits : EnumMembers;
import std.typecons : tuple, Tuple;

version (unittest)
{
    import unit_threaded;
}
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
    }
    @SubCommands SumType!(Default!Version, Doctor, List, Run) subcommand;
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

bool selected(P)(P pony, string what)
{
    // dfmt off
    return what
        .split(",")
        .fold!((result, pattern) => pony.vote(result, pattern))
        (false);
    // dfmt on
}

@("select a pony") unittest
{
    "test".selected(".*").shouldBeTrue;
    "test".selected("-.*").shouldBeFalse;
    "test".selected("test1,+test").shouldBeTrue;
    "test".selected("test1,-test").shouldBeFalse;
    "test".selected(".*,-test").shouldBeFalse;
    "test".selected("-.*,+test").shouldBeTrue;
    "a.dlang.pony".selected(".*dlang.*").shouldBeTrue;
    "a.dlang.pony".selected("-.*dlang.*").shouldBeFalse;
}

auto readyToRun(P)(P ponies)
{
    return ponies.filter!(a => a.applicable).array;
}

auto poniesToRun(P)(P ponies, string what)
{
    return ponies.readyToRun.filter!(a => a.selected(what)).array;
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

auto possibleValues(E)() if (is(E == enum))
{
    return [EnumMembers!E].map!("a.to!string").join(", ");
}

T askFor(T)() if (is(T == enum))
{
    writeln("Please enter %s [%s]: ".format(T.stringof, possibleValues!T));
    auto line = readln.strip;
    return line.to!T;
}

enum CheckStatus
{
    todo,
    done,
    dont_know
}

@("bool to checkstatus") unittest
{
    true.to!CheckStatus.shouldEqual(CheckStatus.done);
    false.to!CheckStatus.shouldEqual(CheckStatus.todo);
}

abstract class Pony
{
    public abstract string name();
    public abstract bool applicable();
    public abstract CheckStatus check();
    public string[] doctor()
    {
        return [];
    }

    public abstract void run();
}

alias UserAndProject = Tuple!(string, "user", string, "project");
UserAndProject userAndProject;
auto getUserAndProject()
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
