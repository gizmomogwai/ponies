/++
 + License: MIT
 +/

import ps.dlang;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;

int main(string[] args)
{
    auto projectSetups = [
        new ps.dlang.DDoxPS, new ps.dlang.RakeFormatPS, new ps.dlang.LicenseCommentPS
    ];

    auto applicable = projectSetups.filter!(a => a.applicable);
    foreach (projectSetup; applicable)
    {
        "Checking %s".format(projectSetup).info;
        if (!projectSetup.check)
        {
            "Running %s".format(projectSetup).info;
            projectSetup.doSetup;
        }

    }

    return 0;
}
