/++
 + License: MIT
 +/

module ponies;

import std.algorithm;
import std.conv;
import std.file;
import std.stdio;
import std.string;
import std.traits;

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

import std.typecons;

class GithubPagesShieldPony : Pony
{
    alias UserAndProject = Tuple!(string, "user", string, "project");
    UserAndProject userAndProject;
    this()
    {
        userAndProject = getUserAndProject;
    }

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

    override bool applicable()
    {
        return exists("readme.org") && userAndProject.user != null && userAndProject.project != null;
    }

    override string name()
    {
        return "Setup github pages shields in readme.org";
    }

    string shield()
    {
        return "[[https://%s.github.io/%s][https://img.shields.io/readthedocs/pip.svg]]\n".format(
                userAndProject.user, userAndProject.project);
    }

    override bool check()
    {
        return readText("readme.org").canFind(shield);
    }

    override void run()
    {
        append("readme.org", shield);

    }
}
