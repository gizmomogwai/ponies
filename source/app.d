/++
 + License: MIT
 +/

import ponies.dlang;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;
import androidlogger;

void commit(string message)
{
    import std.process;

    auto addCommand = ["git", "add", "-u"];
    auto res = addCommand.execute;
    "result of %s: %s".format(addCommand, res).info;
    auto commitCommand = ["git", "commit", "-m", message];
    res = commitCommand.execute;
    "result of %s: %s".format(commitCommand, res).info;
}

auto readyToRun(P)(P ponies)
{
    return ponies.filter!(a => a.applicable);
}

int run(P)(P ponies, CommandLine commandLine)
{

    foreach (pony; ponies.readyToRun)
    {
        "main:Checking %s".format(pony).info;
        if (!pony.check)
        {
            "main:Commit before %s".format(pony).info;
            "Before %s".format(pony.name).commit;
            "main:Running %s".format(pony).info;
            pony.run;
            "After %s".format(pony.name).commit;
            "main:Commit after %s".format(pony).info;
        }
    }

    return 0;
}

class CommandLine
{
    public immutable string command;
    public string[string] args;
    this(string[] args)
    {
        if (args.length < 2)
        {
            command = "run";
            return;
        }
        this.command = args[1];
        foreach (arg; args[2 .. $])
        {
            string[] keyValue = arg.split("=");
            this.args[keyValue[0]] = keyValue[1];
        }
    }
}

int list(P)(P ponies, CommandLine commandLine)
{
    switch (commandLine.args["set"])
    {
    case "all":
        ("All ponies: " ~ ponies.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    case "readyToRun":
        ("Ready to run ponies: " ~ ponies.readyToRun.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    default:
        throw new Exception("unknown list option %s".format(commandLine));
    }
}

int main(string[] args)
{
    sharedLog = new AndroidLogger(true, LogLevel.all);

    // dfmt off
    auto ponies = [
        new ponies.dlang.DDoxPony,
        new ponies.dlang.RakeFormatPony,
        new ponies.dlang.LicenseCommentPony,
    ];
    // dfmt on

    auto commandLine = new CommandLine(args);
    switch (commandLine.command)
    {
    case "run":
        return run(ponies, commandLine);
    case "list":
        return list(ponies, commandLine);
    default:
        throw new Exception("unknown command: %s".format(args));
    }
}
