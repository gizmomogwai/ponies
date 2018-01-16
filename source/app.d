/++
 + License: MIT
 +/

import ponies.dlang;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;
import androidlogger;

int main(string[] args)
{
    sharedLog = new AndroidLogger(true, LogLevel.all);

    // dfmt off
    auto projectSetups = [
        new ponies.dlang.DDoxPony,
        new ponies.dlang.RakeFormatPony,
        new ponies.dlang.LicenseCommentPony,
    ];
    // dfmt on

    auto applicable = projectSetups.filter!(a => a.applicable);
    foreach (projectSetup; applicable)
    {
        "main:Checking %s".format(projectSetup).info;
        if (!projectSetup.check)
        {
            "main:Running %s".format(projectSetup).info;
            projectSetup.doSetup;
        }
    }

    return 0;
}
