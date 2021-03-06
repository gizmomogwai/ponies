/++
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 +/

module ponies.dlang;

import dyaml;
import ponies.dlang.dub;
import ponies.shields;
import ponies.utils;
import ponies;
import std.experimental.logger;
import std;

bool dfmtAvailable()
{
    return works(["dub", "run", "dfmt", "--", "--version"]);
}

void sh(string command)
{
    auto result = command.executeShell;
    (result.status == 0).enforce("Cannot execute '%s' (%s)".format(command, result.output.strip));
}

void sh(string[] command)
{
    auto result = command.execute;
    (result.status == 0).enforce("Cannot execute %s (%s)".format(command, result.output.strip));
}

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

auto travisYamlAvailable()
{
    return exists(DlangPony.travisYaml);
}

abstract class DlangPony : Pony
{
    public static const travisYaml = ".travis.yml";

    override bool applicable()
    {
        return dubSdlAvailable();
    }

    protected auto sources()
    {
        return dirEntries("source", "*.d", SpanMode.depth);
    }
}

class DDoxPony : DlangPony
{
    override string name()
    {
        return "Setup ddox in %s".format(dubSdl);
    }

    override CheckStatus check()
    {
        try
        {
            auto content = readText(dubSdl);
            return content.canFind("x:ddoxFilterArgs").to!CheckStatus;
        }
        catch (FileException e)
        {
            return CheckStatus.todo;
        }
    }

    override void run()
    {
        append(dubSdl, "x:ddoxFilterArgs \"--min-protection=%s\"\n".format(askFor!ProtectionLevel));
    }
}

class FormatSourcesPony : DlangPony
{
    override string name()
    {
        return "Format sources with dfmt";
    }

    override CheckStatus check()
    {
        return CheckStatus.dont_know;
    }

    override void run()
    {
        foreach (string file; sources)
        {
            import std.process;

            auto oldContent = readText(file);
            sh(["dub", "run", "dfmt", "--", "-i", file]);
            auto newContent = readText(file);
            if (oldContent != newContent)
            {
                "FormatSources:%s changed by dfmt -i".format(file).warning;
            }
        }
    }

    override string[] doctor()
    {
        if (!dfmtAvailable)
        {
            return ["Please install dfmt"];
        }
        return [];
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
        return "Setup copyright headers in .d files (taken from %s)".format(dubSdl);
    }

    override CheckStatus check()
    {
        auto res = appender!(string[]);
        foreach (string file; sources)
        {
            auto content = readText(file);
            auto pattern = "^ \\+ Copyright: %s$".format(copyright.escaper);
            auto found = matchFirst(content, regex(pattern, "gm"));
            if (!found)
            {
                res.put(file);
            }
        }
        noCopyrightFiles = res.data;
        return (noCopyrightFiles.length == 0).to!CheckStatus;
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
        return "Setup correct authors line in all .d files (taken from git log)";
    }

    override CheckStatus check()
    {
        return CheckStatus.dont_know;
    }

    override void run()
    {
        foreach (file; sources)
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
        return "Setup license headers in .d files (taken from %s)".format(dubSdl);
    }

    override CheckStatus check()
    {
        auto res = appender!(string[]);
        foreach (string file; sources)
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
        return (noLicenseFiles.length == 0).to!CheckStatus;
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

class GeneratePackageDependenciesPony : DlangPony
{
    override string name()
    {
        return "Generate dependency diagrams.";
    }

    override CheckStatus check()
    {
        return CheckStatus.dont_know;
    }

    override void run()
    {
        import std.conv;
        import std.file;
        import std.json;
        import std.stdio;
        import std.string;

        class Package
        {
            string name;
            Package[] dependencies;
            bool visited;
            this(string name)
            {
                this.name = name;
            }

            auto addDependency(Package p)
            {
                dependencies ~= p;
            }

            override string toString()
            {
                return toString("");
            }

            string toString(string indent)
            {
                string res = indent;
                res ~= name ~ "\n";
                foreach (p; dependencies)
                {
                    res ~= p.toString(indent ~ "  ");
                }
                return res;
            }

            Package setVisited(bool value)
            {
                visited = value;
                foreach (d; dependencies)
                {
                    d.setVisited(value);
                }
                return this;
            }

            string toDot(string indent = "")
            {
                auto res = "";
                visited = true;
                foreach (d; dependencies)
                {
                    res ~= "\n\"%s\"->\"%s\"".format(name, d.name);
                    if (d.visited == false)
                    {
                        res ~= d.toDot(indent ~ "  ");
                    }
                }
                return res;
            }

        }

        struct Packages
        {
            Package[string] packages;
            Package addOrGet(string name)
            {
                if (name !in packages)
                {
                    auto newPackage = new Package(name);
                    packages[name] = newPackage;
                }
                return packages[name];
            }
        }

        import std.process;

        sh("mkdir -p out");
        sh("dub describe > out/dependencies.json");

        auto json = parseJSON(readText("out/dependencies.json"));
        auto packages = Packages();
        auto rootPackage = json["rootPackage"].str;

        foreach (size_t index, value; json["packages"])
        {
            auto packageName = value["name"];
            auto newPackage = packages.addOrGet(packageName.str);
            foreach (size_t i, v; value["dependencies"])
            {
                auto dep = packages.addOrGet(v.str);
                newPackage.addDependency(dep);
            }
        }

        stderr.writeln(packages.addOrGet(rootPackage).to!string);
        auto dot = "digraph G {%s\n}\n".format(packages.addOrGet(rootPackage)
                .setVisited(false).toDot);
        std.file.write("out/dependencies.dot", dot);
        import std.process;

        sh("mkdir -p docs/images");
        sh("dot out/dependencies.dot -Tpng -o docs/images/dependencies.png");
        sh("dot out/dependencies.dot -Tsvg -o docs/images/dependencies.svg");
    }

}

class AddPackageVersionPony : DlangPony
{
    string packageName;
    string preGenerateCommands;
    auto sourcePaths = "sourcePaths \"source\" \"out/generated/packageversion\"\n";
    auto importPaths = "importPaths \"source\" \"out/generated/packageversion\"\n";
    auto packageVersionDependency = "dependency \"packageversion\" version=";
    auto addPackageVersionDependency = "dependency \"packageversion\" version=\"~>0.0.17\"\n";
    this()
    {
        packageName = applicable ? getFromDubSdl("name") : null;
        preGenerateCommands = applicable ? "preGenerateCommands \"packageversion || dub run --yes packageversion\"\n"
            : null;
    }

    override string name()
    {
        return "Add automatic generation of package version to %s".format(dubSdl);
    }

    override bool applicable()
    {
        return super.applicable && travisYamlAvailable;
    }

    override CheckStatus check()
    {
        auto dubSdlContent = readText(dubSdl);
        auto travisYml = readText(travisYaml);
        // dfmt off
        return (dubSdlContent.canFind(sourcePaths)
                && dubSdlContent.canFind(importPaths)
                && dubSdlContent.canFind(preGenerateCommands)
                && dubSdlContent.canFind(addPackageVersionDependency)).to!CheckStatus;
        // dfmt on
    }

    override void run()
    {
        auto oldContent = readText(dubSdl);
        auto content = oldContent;
        if (!content.canFind(sourcePaths))
        {
            "Adding sourcePaths to %s".format(dubSdl).info;
            content ~= sourcePaths;
        }

        if (!content.canFind(importPaths))
        {
            "Adding importPaths to %s".format(dubSdl).info;
            content ~= importPaths;
        }
        if (!content.canFind(preGenerateCommands))
        {
            "Adding preGenerateCommands to %s".format(dubSdl).info;
            content ~= preGenerateCommands;
        }

        if (!content.canFind(packageVersionDependency))
        {
            writeln("content: ", content);
            writeln("searched for: ", packageVersionDependency);
            "Adding packageversion dependency to %s".format(dubSdl).info;
            content ~= addPackageVersionDependency;
        }
        if (content != oldContent)
        {
            "Writing new %s".format(dubSdl).info;
            std.file.write(dubSdl, content);
        }
    }
}
