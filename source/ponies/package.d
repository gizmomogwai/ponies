/++ Ponies main module.
 +
 + <img src="images/dependencies.svg" />
 +
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 +/
module ponies;

public import ponies.packageversion;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.functional;
import std.range;
import std.regex;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;

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
    import unit_threaded;

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

    auto pm = removePlusMinusPrefix(plusMinusRegex);

    auto r = regex(pm.text);
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
    auto h = voteByPlusMinusRegex(pony.to!string, pattern);
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
    import unit_threaded;

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
    return ponies.readyToRun.filter!(a => a.selected(what));
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
    import unit_threaded;

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
    import std.process;
    import std.string : replace;

    auto res = ["git", "remote", "get-url", "origin"].execute;
    auto pattern = "github.com:(?P<user>.*)/(?P<project>.*)";
    auto match = matchFirst(res.output, regex(pattern, "m"));
    if (match)
    {
        return UserAndProject(match["user"], match["project"].replace(".git", ""));
    }
    else
    {
        return UserAndProject(cast(string) null, cast(string) null);
    }
}
