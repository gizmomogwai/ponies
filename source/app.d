/++
 + License: MIT
 +/

import ponies.dlang;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;
import androidlogger;
import commandline;

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

int run(P)(P ponies, string[] args)
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

int list(T)(T ponies, string[] args)
{

    auto res = commandline.parse(args[1..$]);
    switch (res.rest[0]) {
    case "all":
        ("All ponies: " ~ ponies.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    case "readyToRun":
        ("Ready to run ponies: " ~ ponies.readyToRun.map!(a => a.toString).join("\n  ")).writeln;
        return 0;
    default:
        throw new Exception("unknown list option %s".format(args));
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

    auto res = commandline.parse(args[1..$]);
    if ("help" in res.parsed)
    {
        writeln("Usage: ponies [--help] command
  Commands:
    list [--help] all|readyToRun
    run");
    }

    if ((res.rest == []) || (res.rest[0] == "run")) {
        return run(ponies, res.rest);
    } else if (res.rest[0] == "list") {
        return list(ponies, res.rest);
    }

    return 1;
}
