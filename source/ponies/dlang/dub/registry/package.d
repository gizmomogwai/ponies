/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin, Christian Köstlin
 +/
module ponies.dlang.dub.registry;

import asciitable : AsciiTable;
import asdf : deserialize, serdeKeys;
import colored : bold, green, yellow;
import ponies : Pony, CheckStatus;
import ponies.dlang.dub;
import ponies.shields;
import requests : getContent;
import semver : SemVer;
import std.algorithm : map, any, filter, find, reverse, fold;
import std.array : array, join, split;
import std.conv : to;
import std.datetime.stopwatch : AutoStart, StopWatch;
import std.exception : ifThrown;
import std.experimental.logger : warning, info, LogLevel, log;
import std.file : readText, exists, mkdir, write;
import std.format : format;
import std.functional : memoize, pipe;
import std.process : environment;
import std.range : empty, front, tee;
import std.string : strip;
import std.typecons : tuple;

version (unittest)
{
    import unit_threaded;
}

auto ifOk(T)(Optional!T argument, void delegate(T) okHandler)
{
    if (argument == none)
        return argument;
    okHandler(argument.front);
    return argument;
}

version (unittest)
{ // FIXME workaround for strange linker error when doing dub test!
    @("isstable") unittest
    {
        " ~master".to!SemVer.isValid.should == false;
        " ~master".to!SemVer.isStable.should == true;
        "0.0.2".to!SemVer.isStable.should == true;
        "0.0.2".to!SemVer.isValid.should == true;
    }
}
else
{
    Result timed(Argument, Result)(Argument argument, string logTag,
            string message, Result delegate(Argument) operation, bool error = false)
    {
        auto sw = StopWatch(AutoStart.yes);
        scope (success)
        {
            "%s:%s took %s".format(logTag, message, sw.peek).info;
        }
        scope (failure)
        {
            (error ? LogLevel.error : LogLevel.warning).log("%s:%s failed after %s".format(logTag,
                    message, sw.peek));
        }
        "%s:%s".format(logTag, message).info;
        return operation(argument);
    }

    private struct Version
    {
        @serdeKeys("version")
        string semVer;
    }

    private struct Package
    {
        string name;
        Version[] versions;
        auto newestStable() const
        {
            return versions.dup
                .reverse
                .map!(v => v.pipe!("a.semVer", to!SemVer))
                .filter!("a.isValid && a.isStable")
                .array;
        }

        auto newest() const
        {
            return versions.dup
                .reverse
                .map!(v => v.pipe!("a.semVer", to!SemVer))
                .filter!("a.isValid")
                .array;
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
        this()
        {
            path = "%s/.ponies".format(environment.get("HOME"));
            packageNameCachePath = "%s/dub-registry.packagenames.cache".format(path);
            dumpCachePath = "%s/dub-registry.dump.cache".format(path);
        }

        bool includes(string name, string logTag)
        {
            return (memoize!(() => getPackages(logTag))).any!(v => v.name == name);
        }

        private Package[] getPackages(string logTag)
        {
            // dfmt off
            return memoize!(()
            {
                return loadFromCache(packageNameCachePath, logTag)
                    .ifThrown(populateCache(path, packageNameCachePath, logTag))
                    ;
            });
            // dfmt on
        }

        private auto loadFromCache(string cachePath, string logTag)
        {
            // dfmt off
            return cachePath
                .timed(logTag,
                       "Loading DUB registry from cache (%s)".format(cachePath),
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

        private auto loadDumpFromCache(string logTag)
        {
            return dumpCachePath.timed(logTag,
                    "Loading DUB registry dump from cache (%s)".format(dumpCachePath),
                    (string path) => path.readText);
        }

        private auto downloadDubRegistryDump(string logTag)
        {
            // dfmt off
            return "https://code.dlang.org/api/packages/dump"
                .timed(logTag,
                    "Downloading DUB registry dump",
                    (string url) => url.getContent.to!string,
                    true
                );
            // dfmt on
        }

        private auto populateCache(string path, string cachePath, string logTag)
        {
            // dfmt off
            "%s: Initialize cache %s".format(logTag, cachePath).info;
            return loadDumpFromCache(logTag)
                .ifThrown(downloadDubRegistryDump(logTag))
                .timed(logTag,
                  "Storing DUB registry dump",
                  (string content)
                  {
                    if (dumpCachePath.exists)
                    {
                        return content;
                    }
                    if (!path.exists)
                    {
                        path.mkdir;
                    }
                    write(dumpCachePath, content);
                    return content;
                })
                .timed(logTag,
                  "Parsing DUB Registry dump",
                  (string content) => content.deserialize!(Package[])
                )
                .timed(logTag,
                  "Filtering DUB Registry packages",
                  (Package[] packages) => packages
                      .filter!("a.versions.length > 0")
                      .array
                )
                .timed(logTag,
                  "Storing DUB Registry package name cache", (Package[] packages)
                  {
                    if (packageNameCachePath.exists)
                    {
                        return packages.array;
                    }

                    if (!packages.empty)
                    {
                        // dfmt off
                        packageNameCachePath.write(
                            packages
                                .map!(v => "%s: %s".format(
                                    v.name,
                                    v.versions.map!("a.semVer").join(",")))
                                .join("\n")
                        );
                        // dfmt on
        }
        return packages.array;
    });
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
        return dubSdlAvailable && cache.includes(dubPackageName, logTag) && super.applicable;
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
        if (!cache.includes(dubPackageName, logTag))
        {
            hints ~= "Please upload your package to https://code.dlang.org";
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
    const testData = `{
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
    testData.deserialize!DubSelections;
}

const dubSelectionsJson = "dub.selections.json";
auto dubSelectionsJsonAvailable()
{
    return dubSelectionsJson.exists;
}

class CheckVersionsPony : Pony
{
    DubRegistryCache dubRegistryCache;
    this(DubRegistryCache dubRegistryCache)
    {
        this.dubRegistryCache = dubRegistryCache;
    }

    public override string name()
    {
        return "Check versions in dub.selections.json against the DUB registry";
    }

    public override bool applicable()
    {
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
            return result;
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

        const p = dubPackage.front;
        const newestStable = p.newestStable;

        if (newestStable.empty)
        {
            result ~= "No stable version in DUB registry";
        }
        else
        {
            const v = newestStable.front;
            if (v == selected)
            {
            }
            else if (v < selected)
            {
                result ~= "Update DUB registry or ponies cache";
            }
            else if (selected < v)
            {
                result ~= "Upgrade".yellow.to!string;
            }
        }
        if (result.empty)
        {
            return "ok".green.to!string;
        }
        return result;
    }

    public override string[] doctor()
    {
        auto allDubPackages = dubRegistryCache.getPackages(logTag);
        // dfmt off
        return [
            dubSelectionsJson
                .readText
                .deserialize!DubSelections
                .versions
                .byKeyValue
                .fold!((table, nameAndVersion) {
                    auto packageName = nameAndVersion.key;
                    auto semVerString = nameAndVersion.value;
                    auto dubRegistryPackage = allDubPackages.find!(p => p.name == packageName);
                    return table
                        .row
                            .add(packageName)
                            .add(semVerString)
                            .add(dubRegistryPackage.empty ?
                                 "---" :
                                 dubRegistryPackage.front.newestStable.front.to!string)
                            .add(dubRegistryPackage.empty ?
                                 "---" :
                                 dubRegistryPackage.front.newest.front.to!string)
                            .add(calcStatus(semVerString.to!SemVer, dubRegistryPackage));
                })(new AsciiTable(5)
                    .header
                        .add("Package".bold)
                        .add("Used version".bold)
                        .add("Newest stable".bold)
                        .add("Newest".bold)
                        .add("Status".bold))
            .format
            .headerSeparator(true)
            .columnSeparator(true)
            .to!string
        ];
        // dfmt on
    }

    public override void run()
    {
    }
}
}
