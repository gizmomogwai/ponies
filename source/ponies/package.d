/++
 + License: MIT
 +/

module ponies;

import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.file;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;

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

abstract class Pony
{
    public abstract string name();
    public abstract bool applicable();
    public abstract bool check();
    public abstract void run();
}

alias UserAndProject = Tuple!(string, "user", string, "project");
UserAndProject userAndProject;
auto getUserAndProject()
{
    import std.process;
    import std.regex;
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

    override bool check()
    {
        return readText("readme.org").canFind(shield.strip);
    }
    abstract string shield();

    override void run()
    {
        "Please resort your readme.org to put the shield to the right place".warning;
        append("readme.org", shield);
    }
}

class GithubShieldPony : ShieldPony {
    override string name()
    {
        return "Setup a link to github in readme.org";
    }
    override string shield()
    {
        return "[[https://github.com/%1$s/%2$s][https://img.shields.io/github/tag/%1$s/%2$s.svg?style=flat-square]]\n".format(userAndProject.user, userAndProject.project);
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
        return "[[https://travis-ci.org/%1$s/%2$s][https://img.shields.io/travis/%1$s/%2$s/master.svg?style=flat-square]]\n".format(
                userAndProject.user, userAndProject.project);
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
