/++
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
        auto kv = toKv(args);
        if (kv == null)
        {
            return ParseResult(keyValues, args);
        }

        if (kv.length == 2)
        {
            keyValues[kv[0]] = kv[1];
        }
        else
        {
            throw new Exception("kv.length not 2");
        }
    }
    return ParseResult(keyValues, args);
}

struct Option
{
    string name;
    string defaultValue;
    string description;
    static Option withName(string name)
    {
        return Option(name);
    }

    Option withDefault(string defaultValue)
    {
        return Option(name, defaultValue, description);
    }

    Option withDescription(string description)
    {
        return Option(name, defaultValue, description);
    }

    string help()
    {
        return (this.name ~ "\t" ~ ((this.description != null) ? this.description : "no description"));
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
        auto wrongOptions = result.parsed.keys.filter!(
                i => !options.canFind!("a.name == b")(i)).array;
        if (wrongOptions.length > 0)
        {
            throw new Exception("wrong options: %s".format(wrongOptions));
        }
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
        auto table = AsciiTable(16, 80);
        foreach (option; options)
        {
            table.add(option.name, option.description);
        }
        auto res = "Options:\n" ~ table.toString("    ");
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
