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
            auto option = options.find!(i => i.name == kv[0]);
            if (option.empty)
            {
                throw new Exception("Illegal option '%s'".format(arg));
            }
            if (kv.length == 2)
            {
                keyValues[kv[0]] = kv[1];
            }
            else if (kv.length == 1)
            {
                keyValues[kv[0]] = "true";
            }
            args.popFront;
        }
        else if (arg.isShortOption)
        {
            arg = arg[1 .. $];
            auto option = options.find!(i => i.shortName == arg);
            if (option.empty)
            {
                throw new Exception("Illegal option '%s'".format(arg));
            }
            args.popFront;
            if (args.empty)
            {
                keyValues[option.front.name] = "true";
            }
            else
            {
                keyValues[option.front.name] = args.front;
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
    static Option withName(string name)
    {
        return Option(name);
    }

    Option withShortName(string shortName)
    {
        return Option(name, shortName, defaultValue, description);
    }

    Option withDefault(string defaultValue)
    {
        return Option(name, shortName, defaultValue, description);
    }

    Option withDescription(string description)
    {
        return Option(name, shortName, defaultValue, description);
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
        return ("help" in parsed) != null;
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
            auto help = subCommands.find!("a.name == b")(result.rest.front);
            if (!help.empty)
            {
                subCommand = &help.front;
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
        auto table = AsciiTable(1, 1, 1);
        foreach (option; options)
        {
            table.add("--" ~ option.name, option.shortName
                    ? "-" ~ option.shortName : "", option.description);
        }
        auto res = "Options:\n" ~ table.toString("    ", " ");
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
