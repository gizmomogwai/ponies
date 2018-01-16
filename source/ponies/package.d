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

interface Pony
{
    string name();
    bool applicable();
    bool check();
    void run();
}
