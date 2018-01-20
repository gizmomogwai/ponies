/++
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
    string name()
    {
        return "Setup ddox in dub.sdl";
    }

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

    void run()
    {
        append("dub.sdl",
                "x:ddoxFilterArgs \"--min-protection=%s\"\n".format(askFor!ProtectionLevel));
    }
}

class RakeFormatPony : DlangPony
{
    string name()
    {
        return "Setup rake format";
    }

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

    void run()
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

    string name()
    {
        return "Setup license headers in .d files";
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

    void run()
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

class TravisPony : DlangPony {
    string name()
    {
        return "Setup travis build in .travis.yml";
    }
    bool check() {
        return exists(".travis.yml");
    }
    void run() {
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
- dub build --release
- dub build -b ddox
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
