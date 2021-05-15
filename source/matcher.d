/++
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 + Authors: Christian Koestlin
 +/
module matcher;

import std.algorithm;
import std.string;
import std.range;
import std.exception;

class Matcher(T)
{
    /++
     + Checks if s is an accepted values.
     + Params:
     + context = some context information for error messages
     + v = what to check
     + Throws: Exception if not accepted.
     +/
    abstract void accept(string context, T v);

    /++
     + Deliver a description of what is accepted.
     +/
    override abstract string toString();
}

class Just(T) : Matcher!T
{
    T value;
    this(T v)
    {
        this.value = v;
    }

    override void accept(string context, T v)
    {
        enforce(v == value, "%s is not allowed, just %s is allowed".format(v, value));
    }

    override string toString()
    {
        return "just %s".format(value);
    }
}

class Everything(T) : Matcher!T
{
    override void accept(string context, T v)
    {
    }

    override string toString()
    {
        return "everything";
    }
}

class Set(T) : Matcher!T
{
    private T[] values;
    this(T[] values)
    {
        this.values = values;
    }

    static auto of(V...)(V values)
    {
        return fromArray([values]);
    }

    static auto fromArray(T[] values)
    {
        return new Set(values);
    }

    static auto fromEnum(E)()
    {
        import std.traits;
        import std.conv;

        return fromArray([EnumMembers!E].map!(e => e.to!string).array);
    }

    override void accept(string context, T givenValues)
    {
        foreach (v; givenValues.split(","))
        {
            enforce(values.canFind(v),
                    "%s is not in allowed values of '%s': %s".format(v, context, values));
        }
    }

    override string toString()
    {
        return "set from %s".format(values);
    }
}

string trimPlusMinus(string s)
{
    if (s.length == 0)
    {
        return s;
    }

    auto first = s[0];
    switch (first)
    {
    case '+':
    case '-':
        return s[1 .. $];
    default:
        return s;
    }
}

class PlusMinusSet(T) : Matcher!T
{
    private string[] values;
    this(string[] values)
    {
        this.values = values;
    }

    static auto fromArray(string[] values)
    {
        return new PlusMinuxSet(values);
    }

    override void accept(string context, T givenValues)
    {
        import std.exception;

        foreach (v; givenValues.split(",").map!(a => a.trimPlusMinus))
        {
            enforce(values.canFind(v),
                    "%s is not in allowed values of '%s': %s".format(v, context, values));
        }
    }

    override string toString()
    {
        return "+/- set from %s".format(values);
    }
}

class One(T) : Matcher!T
{
    private Set!T impl;
    bool done = false;
    this(T[] values)
    {
        impl = new Set!T(values);
    }

    static auto of(V...)(V values)
    {
        return fromArray([values]);
    }

    static auto fromArray(T[] values)
    {
        return new One(values);
    }

    static auto fromEnum(E)()
    {
        import std.traits;
        import std.conv;

        return fromArray([EnumMembers!E].map!(e => e.to!string).array);
    }

    override void accept(string context, T v)
    {
        if (done)
        {
            throw new Exception("Only one value allowed for '%s'".format(context));
        }
        impl.accept(context, v);
        done = true;
    }

    override string toString()
    {
        return "one from %s".format(impl.values);
    }
}
