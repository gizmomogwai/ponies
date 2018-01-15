module ps;
import std.stdio;
import std.file;
import std.algorithm;
import std.string;
import std.traits;
import std.conv;

auto possibleValues(E)() if (is(E == enum))
{
    return [EnumMembers!E].map!("a.to!string").join(", ");
}

T askFor(T)()
{
    writeln("Please enter %s [%s]: ".format(T.stringof, possibleValues!T));
    auto line = readln.strip;
    return line.to!T;
}

interface PS
{
    bool applicable();
    bool check();
    void doSetup();
}

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

abstract class DlangPS : PS
{
    bool applicable()
    {
        return exists("dub.sdl");
    }
}

class DDoxPS : DlangPS
{
    bool check()
    {
        auto content = readText("dub.sdl");
        return content.canFind("x:ddoxFilterArgs");
    }

    void doSetup()
    {
        auto level = askFor!ProtectionLevel;
        append("dub.sdl", "x:ddoxFilterArgs \"--min-protection=%s\"\n".format(level));
    }
}
