/++
 + Authors: Christian Koestlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

module commandline;

import std.string;
import std.range;
import std.typecons;
import std.algorithm;
import std.experimental.logger;
import asciitable;

class Matcher
{
    /++
     + Checks if s is an accepted values.
     + Params:
     + v = what to check
     + Throws: Exception if not accepted.
     +/
    abstract void accept(Option o, string v);
    /++
     + Deliver a description of what is accepted.
     +/
    override abstract string toString();
}

class Everything : Matcher
{
    override void accept(Option o, string v)
    {
    }

    override string toString()
    {
        return "everything";
    }
}

class Set : Matcher
{
    private string[] values;
    this(string[] values)
    {
        this.values = values;
    }

    static Matcher of(V...)(V values)
    {
        return fromArray([values]);
    }

    static Matcher fromArray(string[] values)
    {
        return new this(values);
    }

    static Matcher fromEnum(T)()
    {
        import std.traits;
        import std.conv;

        return fromArray([EnumMembers!T].map!(e => e.to!string).array);
    }

    override void accept(Option o, string givenValues)
    {
        import std.exception;

        foreach (v; givenValues.split(","))
        {
            enforce(values.canFind(v),
                    "%s is not in allowed values of option '%s': %s".format(v, o.name, values));
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

class PlusMinusSet : Matcher
{
    private string[] values;
    this(string[] values)
    {
        this.values = values;
    }

    static Matcher fromArray(string[] values)
    {
        return new this(values);
    }

    override void accept(Option o, string givenValues)
    {
        import std.exception;

        foreach (v; givenValues.split(",").map!(a => a.trimPlusMinus))
        {
            enforce(values.canFind(v),
                    "%s is not in allowed values of option '%s': %s".format(v, o.name, values));
        }
    }

    override string toString()
    {
        return "+/- set from %s".format(values);
    }
}

class One : Matcher
{
    private Set impl;
    bool done = false;
    this(string[] values)
    {
        impl = new Set(values);
    }

    static Matcher of(V...)(V values)
    {
        return fromArray([values]);
    }

    static Matcher fromArray(string[] values)
    {
        return new this(values);
    }

    static Matcher fromEnum(T)()
    {
        import std.traits;
        import std.conv;

        return fromArray([EnumMembers!T].map!(e => e.to!string).array);
    }

    override void accept(Option o, string v)
    {
        if (done)
        {
            throw new Exception("Only one value allowed for option '%s'".format(o.name));
        }
        impl.accept(o, v);
        done = true;
    }

    override string toString()
    {
        return "one from %s".format(impl.values);
    }
}

auto toKv(ref string[] args)
{
    auto arg = args.front;
    string[] res;
    if (arg.startsWith("--"))
    {
        arg = arg[2 .. $];
        res = arg.split("=");
        args.popFront;
        if (res.length == 1)
        {
            if (args.empty)
            {
                res ~= "true";
            }
            else
            {
                throw new Exception("argument missing");
            }
        }
        return res;
    }
    else
    {
        if (arg.startsWith("-"))
        {
            auto k = arg[1 .. $];
            args.popFront;
            if (args.empty)
            {
                return [k, "true"];
            }
            auto v = args.front;
            args.popFront;
            return [k, v];
        }
        else
        {
            return null;
        }
    }
}

alias ParseResult = Tuple!(string[string], "parsed", string[], "rest");

bool isLongOption(string s)
{
    return s.startsWith("--");
}

bool isShortOption(string s)
{
    return s.startsWith("-");
}

/++
 + parses args (takes out all options and returns the rest).
 +/
ParseResult parse(Option[] options, string[] args)
{
    string[string] keyValues;
    foreach (option; options)
    {
        if (option.defaultValue != null)
        {
            keyValues[option.name] = option.defaultValue;
        }
    }
    while (!args.empty)
    {
        auto arg = args.front;
        if (arg.isLongOption)
        {
            arg = arg[2 .. $];
            auto kv = arg.split("=");
            auto f = options.find!(i => i.name == kv[0]);
            if (f.empty)
            {
                throw new Exception("Illegal option '%s'".format(arg));
            }
            auto option = f.front;
            if (kv.length == 2)
            {
                auto v = kv[1];
                option.accept(v);
                keyValues[kv[0]] = kv[1];
            }
            else if (kv.length == 1)
            {
                auto v = "true";
                option.accept(v);
                keyValues[kv[0]] = v;
            }
            args.popFront;
        }
        else if (arg.isShortOption)
        {
            arg = arg[1 .. $];
            auto f = options.find!(i => i.shortName == arg);
            if (f.empty)
            {
                throw new Exception("Illegal option '%s'".format(arg));
            }
            args.popFront;
            auto option = f.front;
            if (args.empty)
            {
                auto v = "true";
                option.accept(v);
                keyValues[option.name] = v;
            }
            else
            {
                auto v = args.front;
                option.accept(v);
                keyValues[option.name] = v;
                args.popFront;
            }
        }
        else
        {
            break;
        }
    }
    return ParseResult(keyValues, args);
}

struct Option
{
    string name;
    string shortName;
    string defaultValue;
    string description;
    Matcher matcher = new Everything;

    static Option boolWithName(string name)
    {
        return withName(name).allow(One.of("true", "false")).withDefault("false");
    }

    static Option withName(string name)
    {
        return Option(name).withShortName(name[0 .. 1]);
    }

    Option withShortName(string shortName)
    {
        return Option(name, shortName, defaultValue, description, matcher);
    }

    Option withDefault(string defaultValue)
    {
        return Option(name, shortName, defaultValue, description, matcher);
    }

    Option withDescription(string description)
    {
        return Option(name, shortName, defaultValue, description, matcher);
    }

    Option allow(Matcher matcher)
    {
        return Option(name, shortName, defaultValue, description, matcher);
    }

    void accept(string v)
    {
        matcher.accept(this, v);
    }
}

struct Command
{
    string name;
    bool delegate(Command) runDelegate;
    Option[] options;
    Command[] subCommands;
    string[string] parsed;
    string[] rest;
    Command* subCommand;
    bool helpNeeded()
    {
        return parsed["help"] == "true";
    }

    Command parse(string[] args)
    {
        "Parsing command %s".format(name).trace;
        auto result = options.parse(args);
        "Parsed %s".format(result).trace;
        parsed = result.parsed;
        rest = result.rest;
        if (result.rest.length > 0)
        {
            auto h = subCommands.find!("a.name == b")(result.rest.front);
            if (!h.empty)
            {
                subCommand = &h.front;
                subCommand.parse(result.rest[1 .. $]);
            }
        }
        else
        {
            if (!subCommands.empty)
            {
                subCommand = &subCommands.front;
                subCommand.parse(result.rest);
            }
        }
        return this;
    }

    string help()
    {
        auto table = AsciiTable(1, 1, 1, 1).add("long", "short", "description", "allowed values");
        foreach (option; options)
        {
            table.add("--" ~ option.name, option.shortName ? "-" ~ option.shortName
                    : "", option.description, option.matcher.toString);
        }
        auto res = "Options:\n" ~ table.toString("    ", "  ");
        if (!subCommands.empty)
        {
            res ~= "\nSubcommands:\n    " ~ subCommands.map!("a.name").join("\n    ");
        }
        return res;
    }

    void run()
    {
        if (runDelegate(this))
        {
            if (subCommand != null)
            {
                subCommand.run;
            }
        }
    }
}
