/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin
 +/

module ponies.dlang.dub;

import asdf : deserialize;
import std.file : readText, exists;
import std.format : format;
import std.regex : matchFirst, regex;

const dubSdl = "dub.sdl";
auto dubSdlAvailable()
{
    return dubSdl.exists;
}

auto getFromDubSdl(string what)
{
    auto pattern = "^%1$s \"(?P<%1$s>.*)\"$".format(what);
    auto text = dubSdl.readText;
    auto match = text.matchFirst(regex(pattern, "m"));
    if (match)
    {
        return match[what];
    }
    return null;
}
