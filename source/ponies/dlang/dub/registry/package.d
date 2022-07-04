/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin
 +/

module ponies.dlang.dub.registry;

import colored : bold, green, yellow;
import ponies : Pony, CheckStatus;
import asdf;
import optional : some, no, Optional, match, or, none;
import ponies.dlang.dub;
import ponies.shields;
import requests;
import std.datetime.stopwatch;
import std.experimental.logger : warning, info;
import std.exception : ifThrown;
import std.format : format;
import std.file : readText;
import std.process : environment;
import std.algorithm : map, any, filter, find, reverse;
import std.functional : memoize, pipe;
import std.array : array, join, split;
import std.file;
import std.conv : to;
import std.range : empty, front, tee;
import semver;
import std.typecons : tuple;
import std.string : strip;

auto ifOk(T)(Optional!T argument, void delegate(T) okHandler) {
    if (argument == none)
        return argument;
    okHandler(argument.front);
    return argument;
}

version (unittest) { // FIXME workaround for strange linker error when doing dub test!
    @("isstable") unittest
    {
        import unit_threaded;
        " ~master".to!SemVer.isValid.should == false;
        " ~master".to!SemVer.isStable.should == true;
        "0.0.2".to!SemVer.isStable.should == true;
        "0.0.2".to!SemVer.isValid.should == true;
    }
} else {
    Optional!Result timed(Argument, Result)(Optional!Argument argument,
            string message, Result delegate(Argument) operation)
    {
        // dfmt off
        return argument.match!(
            () => no!Result,
            (Argument argument) {
                auto sw = std.datetime.stopwatch.StopWatch(AutoStart.yes);
                void delegate(Result) d = (Result t) {"%s took %s".format(message, sw.peek).info;};
                message.info;
                return operation(argument)
                    .some
                    .ifOk(d)
                .ifThrown((e) { "%s failed after %s".format(message, sw.peek).warning; return no!Result;});
        });
        // dfmt on
    }

    struct Version {
        @serdeKeys("version")
        string semVer;
    }
    struct Package
    {
        string name;
        Version[] versions;
        auto newestStable() {
            return versions.dup.reverse.map!(v => v.pipe!("a.semVer", to!SemVer)).filter!("a.isValid && a.isStable");
        }
        auto newest() {
            return versions.dup.reverse.map!(v => v.pipe!("a.semVer", to!SemVer)).filter!("a.isValid");
        }
    }

    /++ Caching is done on several levels
     + 1. Download is cached in ~/.ponies/dub-registry.dump.cache
     + 2. Names of the packages are stored in ~/.ponies/dub-registry.packagenames.cache
     + 3. Implementation of includes caches the lookups
     + 4. getPackages loads only once
     +/
    class DubRegistryCache
    {
        string path;
        string packageNameCachePath;
        string dumpCachePath;
        this() {
            path = "%s/.ponies".format(environment.get("HOME"));
            packageNameCachePath = "%s/dub-registry.packagenames.cache".format(path);
            dumpCachePath = "%s/dub-registry.dump.cache".format(path);
        }
        bool includes(string name)
        {
            return (memoize!(() => getPackages())).any!(v => v.name == name);
        }

        private Package[] getPackages()
        {
            return memoize!(()
                {
                    auto data = loadFromCache(packageNameCachePath)
                        .or(populateCache(path, packageNameCachePath));
                    if (data.empty)
                    {
                        throw new Exception("Cannot load or download DUB registry data");
                    }
                    return data.front;
                });
        }

        private auto loadFromCache(string cachePath)
        {
            // dfmt off
            return cachePath
                .some
                .timed("Loading DUB registry from cache (%s)".format(cachePath),
                       (string path) => path
                           .readText
                           .dup.split("\n")
                           .map!((v) {
                               auto nameAndVersion = v.split(":").array;
                               return Package(nameAndVersion[0].to!string,
                                              nameAndVersion[1]
                                                  .split(",")
                                                  .map!(s => Version(s.to!string))
                                                  .array);
                               })
                           .array)
                ;
            // dfmt on
        }

        private auto loadDumpFromCache()
        {
            return dumpCachePath
                .some
                .timed("Loading DUB registry dump from cache (%s)".format(dumpCachePath),
                       (string path) => path.readText
                )
            ;
        }

        private auto downloadDubRegistryDump()
        {
            // dfmt off
            return "https://code.dlang.org/api/packages/dump"
                .some
                .timed("Downloading",
                       (string url) => url.getContent.to!string)
                ;
            // dfmt on
        }

        private auto populateCache(string path, string cachePath)
        {
            "Initialize cache %s".format(cachePath).info;
            return loadDumpFromCache()
                .or(downloadDubRegistryDump())
                .timed("Storing DUB registry dump",
                       (string content) {
                           if (dumpCachePath.exists) {
                               return content;
                           }
                           if (!path.exists)
                           {
                               path.mkdir;
                           }
                           write(dumpCachePath, content);
                           return content;
                       })
                .timed("Parsing DUB Registry dump",
                       (string content) => content.deserialize!(Package[]))
                .timed("Filtering DUB Registry packages",
                       (Package[] packages) => packages.filter!("a.versions.length > 0").array)
                // .ifOk((Package[] packages) => packages.map!(a => "  %s: %s".format(a.name, a.newest)).join("\n").info)
                .timed("Storing DUB Registry package name cache",
                    (Package[] packages) {
                           if (packageNameCachePath.exists) {
                               return packages.array;
                           }

                           if (!packages.empty)
                           {
                               std.file.write(packageNameCachePath, packages.map!(v => "%s: %s".format(v.name, v.versions.map!("a.semVer").join(","))).join("\n"));
                           }
                           return packages.array;
                       })
                ;
            // dfmt on
        }
    }

    class DubRegistryShieldPony : ShieldPony
    {
        DubRegistryCache cache;
        string dubPackageName;
        string what;

        this(DubRegistryCache cache, string what)
        {
            this.cache = cache;
            this.dubPackageName = getFromDubSdl("name");
            this.what = what;
        }

        override bool applicable()
        {
            if (dubPackageName == null)
            {
                return false;
            }
            return dubSdlAvailable && cache.includes(dubPackageName) && super.applicable;
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
            if (!cache.includes(dubPackageName))
            {
                hints ~= "Please upload your package to the https://code.dlang.org";
            }
            return hints;
        }

        override string shield()
        {
            return "[[http://code.dlang.org/packages/%1$s][https://img.shields.io/dub/%2$s/%1$s.svg?style=flat-square]]"
                .format(dubPackageName, what);
        }

    }

    class DubLicenseShieldPony : DubRegistryShieldPony
    {
        this(DubRegistryCache cache)
        {
            super(cache, "l");
        }

        override string name()
        {
            return "Setup dub registry license shield in readme.org";
        }
    }

    class DubVersionShieldPony : DubRegistryShieldPony
    {
        this(DubRegistryCache cache)
        {
            super(cache, "v");
        }

        override string name()
        {
            return "Setup dub registry version shield in readme.org";
        }
    }

    class DubWeeklyDownloadsShieldPony : DubRegistryShieldPony
    {
        this(DubRegistryCache cache)
        {
            super(cache, "dw");
        }

        override string name()
        {
            return "Setup dub registry weekly downloads shield in readme.org";
        }
    }

    struct DubSelections
    {
        string[string] versions;
    }

    @("Parse dub selections") unittest
    {
        import unit_threaded;
        string testData = `{
    	"fileVersion": 1,
    	"versions": {
    		"androidlogger": "0.0.16",
    		"asciitable": "0.0.14",
    		"asdf": "0.7.15",
    		"bolts": "1.3.1",
    		"cachetools": "0.3.1",
    		"color": "0.0.9",
    		"colored": "0.0.27",
    		"dyaml": "0.8.6",
    		"mir-algorithm": "3.14.1"
        }
    }`;
        auto result = testData.deserialize!DubSelections;
        import std.stdio : writeln;
        writeln(result);
    }

    const dubSelectionsJson = "dub.selections.json";
    auto dubSelectionsJsonAvailable()
    {
        return dubSelectionsJson.exists;
    }

    import semver : SemVer;
    class CheckVersionsPony : Pony
    {
        DubRegistryCache dubRegistryCache;
        this(DubRegistryCache dubRegistryCache) {
            this.dubRegistryCache = dubRegistryCache;
        }
        public override string name()
        {
            return "Check versions in dub.selections.json against the DUB registry";
        }
        public override bool applicable() {
            return dubSdlAvailable() && dubSelectionsJsonAvailable();
        }
        public override CheckStatus check()
        {
            return CheckStatus.dont_know;
        }
        private string calcStatus(R)(SemVer selected, R dubPackage)
        {
            string result;
            if (!selected.isValid)
            {
                result ~= "Use valid version";
            }
            if (!selected.isStable)
            {
                result ~= "Use stable version";
            }

            if (dubPackage.empty)
            {
                result ~= "Not in registry";
                return result;
            }

            Package p = dubPackage.front;
            auto newestStable = p.newestStable;
            if (newestStable.empty)
            {
                result ~= "No stable version in DUB registry";
            }
            else {
                auto v = newestStable.front;
                if (v == selected)
                {
                }
                else if (v < selected)
                {
                    result ~= "Update DUB registry or ponies cache";
                }
                else if (selected < v) {
                    result ~= "Upgrade".yellow.to!string;
                }
            }
            if (result.empty) return "ok".green.to!string;
            return result;
        }

        public override string[] doctor()
        {
            import asciitable;
            auto selectedVersions = dubSelectionsJson.readText.deserialize!DubSelections;
            auto allDubPackages = dubRegistryCache.getPackages;
            auto table = new AsciiTable(5)
                .header
                    .add("Package".bold)
                    .add("Used version".bold)
                    .add("Newest stable".bold)
                    .add("Newest".bold)
                    .add("Status".bold);
            foreach (packageName, semVerString; selectedVersions.versions)
            {
                auto dubRegistryPackage = allDubPackages.find!(p => p.name == packageName);
                table.row
                    .add(packageName)
                    .add(semVerString)
                    .add(dubRegistryPackage.empty ? "---" : dubRegistryPackage.front.newestStable.front.to!string)
                    .add(dubRegistryPackage.empty ? "---" : dubRegistryPackage.front.newest.front.to!string)
                    .add(calcStatus(semVerString.to!SemVer, dubRegistryPackage));
            }
            return [table.format
                .headerSeparator(true)
                .columnSeparator(true)
                .to!string];
        }
        public override void run()
        {
        }
    }
}
