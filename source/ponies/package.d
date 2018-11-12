/++ Ponies main module.
 +
 + <img src="images/dependencies.svg" />
 +
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright © 2018, Christian Köstlin
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

class ShieldPony : Pony
{
    protected UserAndProject userAndProject;
    this()
    {
        userAndProject = getUserAndProject;
    }

    override bool applicable()
    {
        return exists("readme.org") && userAndProject.user != null && userAndProject.project != null;
    }

    override CheckStatus check()
    {
        return readText("readme.org").canFind(shield.strip).to!CheckStatus;
    }

    override string[] doctor()
    {
        if (!exists("readme.org"))
        {
            return ["Please add readme.org"];
        }
        return [];
    }

    abstract string shield();

    override void run()
    {
        "Please resort your readme.org to put the shield to the right place".warning;
        append("readme.org", shield);
    }
}

class GithubShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a link to github in readme.org";
    }

    override string shield()
    {
        return "[[https://github.com/%1$s/%2$s][https://img.shields.io/github/tag/%1$s/%2$s.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }
}

class CodecovShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a link to codecov in readme.org";
    }

    override string shield()
    {
        return "[[https://codecov.io/gh/%1$s/%2$s][https://img.shields.io/codecov/c/github/%1$s/%2$s/master.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }
}

class TravisCiShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a travis ci shield in readme.org";
    }

    override string shield()
    {
        return "[[https://travis-ci.org/%1$s/%2$s][https://img.shields.io/travis/%1$s/%2$s/master.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }
}

class GithubPagesShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a documentation shield in readme.org";
    }

    override string shield()
    {
        return "[[https://%s.github.io/%s][https://img.shields.io/readthedocs/pip.svg?style=flat-square]]\n".format(
                userAndProject.user, userAndProject.project);
    }
}

bool mightBeEmacs()
{
    return exists("Cask");
}

class MelpaShieldPony : ShieldPony
{
    protected UserAndProject userAndProject;

    this()
    {
        userAndProject = getUserAndProject;
    }

    override string name()
    {
        return "Setup a melpa shield in readme.org";
    }

    override bool applicable()
    {
        return super.applicable() && mightBeEmacs;
    }

    override string shield()
    {
        return "[[https://melpa.org/#/%1$s][https://melpa.org/packages/%1$s-badge.svg]]".format(
                userAndProject.project);
    }
}
