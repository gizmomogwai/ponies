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

    auto applicable = ponies.filter!(a => a.applicable);
    foreach (pony; applicable)
    {
        "main:Checking %s".format(pony).info;
        if (!pony.check)
        {
            "main:Commit before %s".format(pony).info;
            "Before %s".format(pony.name).commit;
            "main:Running %s".format(pony).info;
            pony.doSetup;
            "After %s".format(pony.name).commit;
            "main:Commit after %s".format(pony).info;
        }
    }

    return 0;
}
