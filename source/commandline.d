/++
 + License: MIT
 +/

module commandline;

import std.string;
import std.range;
import std.typecons;
import std.algorithm;
import std.experimental.logger;

auto toKv(string s)
{
    if (s.startsWith("--"))
    {
        s = s[2 .. $];
    }
    else
    {
        return null;
    }
    return s.split("=");
}

alias ParseResult = Tuple!(string[string], "parsed", string[], "rest");
/++
 + parses args (takes out all options and returns the rest).
 +/
ParseResult parse(Option[] options, string[] args)
{
    string[string] keyValues;
    foreach (option; options) {
        if (option.defaultValue != null) {
            keyValues[option.name] = option.defaultValue;
        }
    }
    while (!args.empty)
    {
        auto arg = args.front;

        auto kv = toKv(arg);
        if (kv == null)
        {
            return ParseResult(keyValues, args);
        }
        args.popFront;
        if (kv.length == 2)
        {
            keyValues[kv[0]] = kv[1];
        }

        else
        {
            keyValues[kv[0]] = null;
        }
    }
    return ParseResult(keyValues, args);
}

struct Option
{
    string name;
    string defaultValue;
    string description;
    static Option withName(string name) {
        return Option(name);
    }
    Option withDefault(string defaultValue) {
        return Option(name, defaultValue, description);
    }
    Option withDescription(string description) {
        return Option(name, defaultValue, description);
    }
    string help() {
        return (this.name ~ "\t" ~ ((this.description != null)? this.description : "no description"));
    }
}

struct Command
{
    string name;
    void delegate(Command) runDelegate;
    Option[] options;
    Command[] subCommands;
    ParseResult result;
    Command* subCommand;
    bool helpNeeded() {
        return ("help" in result.parsed) != null;
    }
    void parse(string[] args) {
        "Parsing command %s".format(name).trace;
        result = options.parse(args);
        auto wrongOptions = result.parsed.keys.filter!(i => !options.canFind!("a.name == b")(i)).array;
        if (wrongOptions.length > 0) {
            throw new Exception("wrong options: %s".format(wrongOptions));
        }
        "Parsed %s".format(result).trace;
        if (result.rest.length > 0) {
            auto help = subCommands.find!("a.name == b")(result.rest.front);
            if (!help.empty) {
                subCommand = &help.front;
                subCommand.parse(result.rest[1..$]);
            }
        } else {
            if (!subCommands.empty) {
                subCommand = &subCommands.front;
                subCommand.parse(result.rest);
            }
        }
    }
    string help() {
        auto res = "Options:\n    " ~ options.map!("a.help").join("\n    ") ~ "\n";
        if (!subCommands.empty) {
            res ~= "\nSubcommands:\n    " ~ subCommands.map!("a.name").join("\n    ");
        }
        return res;
    }
    void run() {
        runDelegate(this);
        if (subCommand != null) {
            subCommand.run;
        }
    }
}

@("process normal options") unittest
{
    import unit_threaded;

    auto res = parse(["--test1=1", "--test2=2", "command", "--test3=3"]);
    res.parsed.shouldEqual(["test1" : "1", "test2" : "2"]);
    res.rest.shouldEqual(["command", "--test3=3"]);
}

@("process empty options") unittest
{
    import unit_threaded;

    auto res = parse(["--test1", "--test2=2", "command", "all"]);
    res.parsed.shouldEqual(["test1" : null, "test2" : "2"]);
    res.rest.shouldEqual(["command", "all"]);
}
