/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin
 +/

module ponies.dlang.dub;

import std;
import ponies : Pony, CheckStatus;
import asdf : deserialize;

const dubSdl = "dub.sdl";
auto dubSdlAvailable()
{
    return dubSdl.exists;
}

auto getFromDubSdl(string what)
{
    auto pattern = "^%1$s \"(?P<%1$s>.*)\"$".format(what);
    auto text = readText(dubSdl);
    auto match = matchFirst(text, regex(pattern, "m"));
    if (match)
    {
        return match[what];
    }
    return null;
}
