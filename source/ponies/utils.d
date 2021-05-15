/++
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

module ponies.utils;

bool works(string[] cmd)
{
    import std.process;

    try
    {
        auto res = cmd.execute;
        return res.status == 0;
    }
    catch (Exception e)
    {
        return false;
    }
}

bool gitAvailable()
{
    return works(["git", "--version"]);
}
