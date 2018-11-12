/++
 + Authors: Christian Koestlin, Christian Köstlin
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 +/

module ponies.dlang;

import dyaml;
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
import ponies.utils;

bool dfmtAvailable()
{
    return works(["dfmt", "--version"]);
}

enum ProtectionLevel
{
    Private,
    Protected,
    Public
}

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

abstract class DlangPony : Pony
{
    protected auto travisYml = ".travis.yml";

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
        return "Formats sources with dfmt";
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
            ["dfmt", "-i", file].execute;
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
            auto pattern = "^ \\+ Copyright: %s$".format(copyright);
            auto found = matchFirst(content, regex(pattern, "m"));
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
                    res ~= "\n%s->%s".format(name, d.name);
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

        "dub describe > out/dependencies.json".executeShell;

        auto json = parseJSON(readText("out/dependencies.json"));
        auto packages = Packages();
        auto rootPackage = json["rootPackage"].str;
        writeln(rootPackage);

        foreach (size_t index, value; json["packages"])
        {
            auto packageName = value["name"];
            auto newPackage = packages.addOrGet(packageName.str);
            foreach (size_t index, value; value["dependencies"])
            {
                auto dep = packages.addOrGet(value.str);
                newPackage.addDependency(dep);
            }
        }

        stderr.writeln(packages.addOrGet(rootPackage).to!string);
        auto dot = "digraph G {%s\n}\n".format(packages.addOrGet(rootPackage)
                .setVisited(false).toDot);
        std.file.write("out/dependencies.dot", dot);

        import std.process;

        ["dot", "out/dependencies.dot", "-Tpng", "-o", "docs/images/dependencies.png"].execute;
        ["dot", "out/dependencies.dot", "-Tsvg", "-o", "docs/images/dependencies.svg"].execute;

    }

}

class AddPackageVersionPony : DlangPony
{
    string packageName;
    string preGenerateCommands;
    string sourceFiles;
    auto sourcePaths = "sourcePaths \"source\" \"out/generated/packageversion\"\n";
    auto importPaths = "importPaths \"source\" \"out/generated/packageversion\"\n";
    auto dubFetchPackageVersion = "dub fetch packageversion";
    auto addPackageVersionDependency = `dependency "packageversion" version="~>0.0.17"
subConfiguration "packageversion" "library"
`;
    this()
    {
        packageName = applicable ? getFromDubSdl("name") : null;
        preGenerateCommands = applicable ? "preGenerateCommands \"packageversion || dub run packageversion\"\n"
            : null;
        sourceFiles = applicable ? "sourceFiles \"out/generated/packageversion/%s/packageversion.d\"\n".format(
                packageName) : null;
    }

    override string name()
    {
        return "Add automatic generation of package version to %s".format(dubSdl);
    }

    override CheckStatus check()
    {
        auto dubSdlContent = readText(dubSdl);
        auto travisYml = readText(travisYml);
        // dfmt off
        return (dubSdlContent.canFind(sourcePaths)
                && dubSdlContent.canFind(importPaths)
                && dubSdlContent.canFind(preGenerateCommands)
                && dubSdlContent.canFind(sourceFiles)
                && dubSdlContent.canFind(addPackageVersionDependency)
                && travisYml.canFind(dubFetchPackageVersion)).to!CheckStatus;
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

        if (!content.canFind(sourceFiles))
        {
            "Adding sourceFiles to %s".format(dubSdl).info;
            content ~= sourceFiles;
        }

        if (!content.canFind(addPackageVersionDependency))
        {
            "Adding packageversion dependency to %s".format(dubSdl).info;
            content ~= addPackageVersionDependency;
        }
        if (content != oldContent)
        {
            "Writing new %s".format(dubSdl).info;
            std.file.write(dubSdl, content);
        }

        auto root = Loader(travisYml).load;
        auto beforeInstall = root["before_install"];
        if (beforeInstall.isScalar)
        {
            if (beforeInstall.as!string != dubFetchPackageVersion)
            {
                "adding %s to %s".format(dubFetchPackageVersion, travisYml).info;
                root["before_install"] = Node([beforeInstall, Node(dubFetchPackageVersion)]);
                Dumper(travisYml).dump(root);
            }
        }
        else if (beforeInstall.isSequence)
        {
            if (!beforeInstall.sequence!string.canFind(dubFetchPackageVersion))
            {
                "adding %s to %s".format(dubFetchPackageVersion, travisYml).info;
                beforeInstall.add(Node(dubFetchPackageVersion));
                root["before_install"] = beforeInstall;
                Dumper(travisYml).dump(root);
            }
        }
        else
        {
            throw new Exception("cannot process %s".format(travisYml));
        }
    }
}

class DubRegistryShieldPony : ShieldPony
{
    string dubPackageName;
    string what;
    this(string what)
    {
        dubPackageName = applicable ? getFromDubSdl("name") : null;
        this.what = what;
    }

    override bool applicable()
    {
        return dubSdlAvailable() && super.applicable;
    }

    override string[] doctor()
    {
        string[] hints;
        if (!exists("readme.org"))
        {
            hints ~= "Please add readme.org";
        }
        if (!dubSdlAvailable)
        {
            hints ~= "Please add dub.sdl";
        }
        return hints;
    }

    override string shield()
    {
        return "[[http://code.dlang.org/packages/%1$s][https://img.shields.io/dub/%2$s/%1$s.svg?style=flat-square]]".format(
                dubPackageName, what);
    }

}

class DubLicenseShieldPony : DubRegistryShieldPony
{
    this()
    {
        super("l");
    }

    override string name()
    {
        return "Setup dub registry license shield in readme.org";
    }
}

class DubVersionShieldPony : DubRegistryShieldPony
{
    this()
    {
        super("v");
    }

    override string name()
    {
        return "Setup dub registry license shield in readme.org";
    }
}

class DubWeeklyDownloadsShieldPony : DubRegistryShieldPony
{
    this()
    {
        super("dw");
    }

    override string name()
    {
        return "Setup dub registry weekly downloads shield in readme.org";
    }
}
