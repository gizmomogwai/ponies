/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin, Christian Köstlin
 +/

module ponies.dlang.dub;

import asdf : deserialize;
import std.file : readText, exists, write;
import std.format : format;
import std.algorithm : canFind;
import std.regex : matchFirst, regex;
import ponies : CheckStatus;
import ponies.dlang : DlangPony;
import std.conv : to;

const DUB_SDL = "dub.sdl";
auto dubSdlAvailable()
{
    return DUB_SDL.exists;
}

auto getFromDubSdl(string what)
{
    auto pattern = "^%1$s \"(?P<%1$s>.*)\"$".format(what);
    auto text = DUB_SDL.readText;
    auto match = text.matchFirst(regex(pattern, "m"));
    if (match)
    {
        return match[what];
    }
    return null;
}

class DdoxWithScodSkinPony : DlangPony
{
    const SCOD_SKIN = `x:ddoxTool "scod"
`;
    this()
    {
        super([
                EnsureStringInFile(DUB_SDL, SCOD_SKIN),
              ]);
    }
    override string name()
    {
        return "build: Generate ddox with the scod skin";
    }
}

class CompilerInfoPony : DlangPony
{
    string PRE_GENERATE_COMMANDS = "preGenerateCommands \"$DC --version\"\n";

    this()
    {
        super([
                EnsureStringInFile(DUB_SDL, PRE_GENERATE_COMMANDS),
              ]);
    }
    override string name()
    {
        return "build: Print compiler version before compilation in %s".format(DUB_SDL);
    }
}

class Lst2ErrorMessagesPony : DlangPony
{
    string POST_RUN_COMMANDS = "postRunCommands \"$DUB run lst2errormessages || true\"\n";

    this()
    {
        super([
                EnsureStringInFile(DUB_SDL, POST_RUN_COMMANDS),
              ]);
    }

    override string name()
    {
        return "build: Analyze codecoverage after `dub test --coverage` in %s".format(DUB_SDL);
    }
}
