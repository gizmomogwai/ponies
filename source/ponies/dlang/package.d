/++
 + License: MIT
 +/

module ponies.dlang;

import ponies;
import std.stdio;
import std.file;
import std.algorithm;
import std.string;
import std.traits;
import std.conv;
import std.array;
import std.regex;
import std.experimental.logger;

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

abstract class DlangPony : Pony
{
    bool applicable()
    {
        return exists("dub.sdl");
    }

    protected auto getFromDubSdl(string what)
    {
        auto pattern = "^%1$s \"(?P<%1$s>.*)\"$".format(what);
        auto text = readText("dub.sdl");
        auto match = matchFirst(text, regex(pattern, "m"));
        return match[what];
    }
}

class DDoxPony : DlangPony
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

class RakeFormatPony : DlangPony
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

class LicenseCommentPony : DlangPony
{
    string[] noLicenseFiles;
    string license;

    this()
    {
        license = getFromDubSdl("license");
    }

    bool check()
    {
        auto res = appender!(string[]);
        foreach (string file; dirEntries(".", "*.d", SpanMode.depth))
        {
            auto content = readText(file);
            auto pattern = "^ \\+ License: %s$".format(license);
            auto found = matchFirst(content, regex(pattern, "m"));
            if (!found)
            {
                res.put(file);
            }
        }
        noLicenseFiles = res.data;
        return noLicenseFiles.length == 0;
    }

    void doSetup()
    {
        "Fixing license for %s".format(noLicenseFiles).info;

        foreach (file; noLicenseFiles)
        {
            auto content = readText(file);
            auto newContent = replaceFirst(content, regex("^ \\+ License: .*?$",
                    "m"), " + License: %s".format(license));
            if (content == newContent)
            {
                "Adding license %s to file %s".format(license, file).info;
                newContent = "/++\n + License: %s\n +/\n\n".format(license.to!string) ~ content;
            }
            else
            {
                "Change license to %s in file %s".format(license, file).info;
            }
            std.file.write(file, newContent);
        }

    }
}
