/++
 + Authors: Christian Koestlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

module ponies;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.functional;
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

auto string2selector(string s)
{
    if (s.length == 0)
    {
        return (string p) { return Vote.dontCare; }.toDelegate;
    }

    bool negate = false;
    if (s[0] == '-')
    {
        negate = true;
        s = s[1 .. $];
    }
    if (s[0] == '+')
    {
        s = s[1 .. $];
    }

    auto r = regex(s);
    auto res = (string p) {
        if (p.match(r) || s == "all")
        {
            if (negate)
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
    };
    return res;
}

bool selected(P)(P pony, string what)
{
    auto selectors = what.split(",").map!(string2selector);

    bool res = false;
    foreach (selector; selectors)
    {
        auto h = selector(pony.to!string);
        switch (h)
        {
        case Vote.up:
            res = true;
            break;
        case Vote.down:
            res = false;
            break;
        default:
            break;
        }
    }
    return res;
}

@("select a pony") unittest
{
    import unit_threaded;

    "test".selected("all").shouldBeTrue;
    "test".selected("-all").shouldBeFalse;
    "test".selected("test1,+test").shouldBeTrue;
    "test".selected("test1,-test").shouldBeFalse;
    "test".selected("all,-test").shouldBeFalse;
    "test".selected("-all,+test").shouldBeTrue;
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
