/++
 + Authors: Christian Koestlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

module ponies.dlang;

import ponies;
import std.algorithm;
import std.array;
import std.conv;
import std.experimental.logger;
import std.file;
import std.regex;
import std.stdio;
import std.string;
import std.traits;

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

abstract class DlangPony : Pony
{
    override bool applicable()
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
    override string name()
    {
        return "Setup ddox in dub.sdl";
    }

    override bool check()
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

    override void run()
    {
        append("dub.sdl",
                "x:ddoxFilterArgs \"--min-protection=%s\"\n".format(askFor!ProtectionLevel));
    }
}

class FormatSourcesPony : DlangPony
{
    override string name()
    {
        return "Formats sources with dfmt";
    }

    override bool check()
    {
        return false; // we cannot know if dfmt will have to do some work
    }

    override void run()
    {
        foreach (string file; dirEntries(".", "*.d", SpanMode.depth))
        {
            import std.process;

            auto oldContent = readText(file);
            ["dfmt", "-i", file].execute;
            auto newContent = readText(file);
            if (oldContent != newContent)
            {
                "FormatSources:%s changed by dfmt -i".format(file).warning;
            }
        }
    }
}

class CopyrightCommentPony : DlangPony
{
    string[] noCopyrightFiles;
    string copyright;
    this()
    {
        copyright = applicable ? getFromDubSdl("copyright") : null;
    }

    override string name()
    {
        return "Setup copyright headers in .d files";
    }

    override bool check()
    {
        auto res = appender!(string[]);
        foreach (string file; dirEntries(".", "*.d", SpanMode.depth))
        {
            auto content = readText(file);
            auto pattern = "^ \\+ Copyright: %s$".format(copyright);
            auto found = matchFirst(content, regex(pattern, "m"));
            if (!found)
            {
                res.put(file);
            }
        }
        noCopyrightFiles = res.data;
        return noCopyrightFiles.length == 0;
    }

    override void run()
    {
        "Fixing copyright for %s".format(noCopyrightFiles).info;

        foreach (file; noCopyrightFiles)
        {
            auto content = readText(file);
            auto newContent = replaceFirst(content, regex("^ \\+ Copyright: .*?$",
                    "m"), " + Copyright: %s".format(copyright));
            if (content == newContent)
            {
                "Adding copyright %s to file %s".format(copyright, file).info;
                newContent = "/++\n + Copyright: %s\n +/\n\n".format(copyright.to!string) ~ content;
            }
            else
            {
                "Change copyright to %s in file %s".format(copyright, file).info;
            }
            std.file.write(file, newContent);
        }
    }
}

class AuthorsPony : DlangPony
{
    override string name()
    {
        return "Puts correct authors line in all .d files";
    }

    override bool check()
    {
        return false;
    }

    override void run()
    {
        foreach (file; dirEntries(".", "*.d", SpanMode.depth))
        {
            import std.process;

            auto content = readText(file);
            auto authors = ["git", "log", "--pretty=format:%an", file].execute.output.split("\n")
                .sort.uniq.join(", ");
            auto authorsRegex = regex("^ \\+ Authors: (.*)$", "m");
            auto hasAuthorsLine = !content.matchFirst(authorsRegex).empty;
            auto newContent = replaceFirst(content, authorsRegex,
                    " + Authors: %s".format(authors));
            if (hasAuthorsLine)
            {
                if (content == newContent)
                {
                    "No change of authors in file %s".format(file).info;
                }
                else
                {
                    "Change authors to %s in file %s".format(authors, file).info;
                    std.file.write(file, newContent);
                }
            }
            else
            {
                "Adding authors line %s to file %s".format(authors, file).warning;
                newContent = "/++\n + Authors: %s\n +/\n\n".format(authors) ~ content;
                std.file.write(file, newContent);
            }
        }

    }
}

class LicenseCommentPony : DlangPony
{
    string[] noLicenseFiles;
    string license;

    this()
    {
        license = applicable ? getFromDubSdl("license") : null;
    }

    override string name()
    {
        return "Setup license headers in .d files";
    }

    override bool check()
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

    override void run()
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

class TravisPony : DlangPony
{
    override string name()
    {
        return "Setup travis build in .travis.yml";
    }

    override bool check()
    {
        return exists(".travis.yml");
    }

    override void run()
    {
        "Creating .travis.yml file".info;
        "userinteraction:Please get gh repo token from https://github.com/settings/tokens".warning;
        "userinteraction:Please enable travis build".warning;
        "userinteraction:Please enable coverage on codecov".warning;
        auto content = "language: d
sudo: false
addons:
  apt:
    packages:
    - libevent-dev
before_install: pip install --user codecov
script:
- dub test --compiler=${DC} --coverage
- dub build --build=release
- dub build --build=ddox
after_success: codecov
deploy:
  provider: pages
  skip-cleanup: true
  local-dir: \"docs\"
  github-token: \"$GH_REPO_TOKEN\"
  verbose: true
  keep-history: true
  on:
    branch: master
env:
  global:
    secure: create this token with travis encrypt GH_REPO_TOKEN=key from https://github.com/settings/tokens
";
        std.file.write(".travis.yml", content);
    }
}
