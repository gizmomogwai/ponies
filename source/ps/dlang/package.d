module ps.dlang;

import ps;
import std.stdio;
import std.file;
import std.algorithm;
import std.string;
import std.traits;
import std.conv;

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

abstract class DlangPS : PS
{
    bool applicable()
    {
        return exists("dub.sdl");
    }
}

class DDoxPS : DlangPS
{
    bool check()
    {
        try
        {
            auto content = readText("dub.sdl");
            return content.canFind("x:ddoxFilterArgs");
        }
        catch (FileException e)
        {
            return false;
        }
    }

    void doSetup()
    {
        append("dub.sdl",
                "x:ddoxFilterArgs \"--min-protection=%s\"\n".format(askFor!ProtectionLevel));
    }
}

class RakeFormatPS : DlangPS
{
    bool check()
    {
        try
        {
            auto content = readText("rakefile.rb");
            return content.canFind("dfmt");
        }
        catch (FileException e)
        {
            return false;
        }
    }

    void doSetup()
    {
        append("rakefile.rb",
                "desc 'format'\ntask :format do\n  sh 'find . -name \"*.d\" | xargs dfmt -i'\nend\n");
    }
}
