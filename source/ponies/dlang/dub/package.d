module ponies.dlang.dub;

import std;

const dubSdl = "dub.sdl";
auto dubSdlAvailable()
{
    return exists(dubSdl);
}

auto getFromDubSdl(string what)
{

    auto pattern = "^%1$s \"(?P<%1$s>.*)\"$".format(what);
    auto text = readText(dubSdl);
    auto match = matchFirst(text, regex(pattern, "m"));
    return match[what];
}
