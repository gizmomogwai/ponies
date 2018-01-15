import ps;
import std.algorithm;
import std.experimental.logger;
import std.stdio;
import std.string;

int main(string[] args)
{
    auto projectSetups = [
                          new DDoxPS,

                          ];

    auto applicable = projectSetups.filter!(a => a.applicable);
    foreach (projectSetup; applicable) {
        "Checking %s".format(projectSetup).info;
        if (!projectSetup.check)
            {
                "Running %s".format(projectSetup).info;
                projectSetup.doSetup;
            }

    }

    return 0;
}
