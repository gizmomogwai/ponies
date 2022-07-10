/++
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 +/
module ponies.utils;

import std.process : execute;

bool works(string[] cmd)
{
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
    return ["git", "--version"].works;
}
