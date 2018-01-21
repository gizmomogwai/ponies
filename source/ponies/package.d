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

class ShieldsPony : Pony {
    auto getUserAndProject() {
        import std.process;
        import std.regex;
        import std.typecons;
        auto res = ["git", "remote", "get-url", "origin"].execute;
        auto pattern = "github.com:(?P<user>.*)/(?P<project>.*)";
        auto match = matchFirst(res.output, regex(pattern, "m"));
        if (match) {
            return tuple!("user", "project")(match["user"], match["project"]);
        } else {
            return tuple!("user", "project")(cast(string)null, cast(string)null);
        }
    }

    override bool applicable()
    {
        auto userAndProject = getUserAndProject;
        return exists("readme.org") && userAndProject.user != null && userAndProject.project != null;
    }

    override string name()
    {
        return "Setup shields in readme.org";
    }
    override bool check() {
        return true;
    }
    override void run() {
        import std.experimental.logger;
        "Add docs shield to readme.org".info;
    }
}