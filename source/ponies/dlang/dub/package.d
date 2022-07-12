/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin
 +/

module ponies.dlang.dub;

import asdf : deserialize;
import std.file : readText, exists, write;
import std.format : format;
import std.algorithm : canFind;
import std.experimental.logger : info, warning;
import std.regex : matchFirst, regex;
import ponies : CheckStatus;
import ponies.dlang : DlangPony;
import std.conv : to;

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

class CompilerInfoPony : DlangPony
{
    string preGenerateCommands = "preGenerateCommands \"$DC --version\"\n";

    override string name()
    {
        return "Print compiler version before compilation in %s".format(dubSdl);
    }

    override CheckStatus check()
    {
        return dubSdl.readText.canFind(preGenerateCommands).to!CheckStatus;
    }

    override void run()
    {
        const oldContent = dubSdl.readText;
        auto content = oldContent.dup;
        if (!content.canFind(preGenerateCommands))
        {
            "Adding preGenerateCommands to %s".format(dubSdl).info;
            content ~= preGenerateCommands;
        }

        if (content != oldContent)
        {
            "Writing new %s".format(dubSdl).info;
            dubSdl.write(content);
        }
    }
}
