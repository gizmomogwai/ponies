/++
 + License: MIT
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + Authors: Christian Koestlin
 +/

module ponies.dlang.dub.registry;

import asdf;
import ponies.dlang.dub;
import ponies.shields;
import requests;
import std.experimental.logger;
import std;
import std.datetime.stopwatch;
import optional;

Optional!Result timed(Argument, Result)
    (Optional!Argument argument,
     string message,
     Result delegate(Argument) operation)
{
    message.info;
    auto sw = std.datetime.stopwatch.StopWatch(AutoStart.yes);
    scope (exit)
    {
        (message ~ " took %s").format(sw.peek).info;
    }
    // dfmt off
    return argument.match!(
        () => no!Result,
        (Argument argument) => operation(argument).some.ifThrown(no!Result),
    );
    // dfmt on
}

struct Package
{
    string name;
}

/++ Caching is done on two levels.
 + 1. http request is processed into ~/.ponies/dub-registry.cache
 + 2. reading of ~/.ponies/dub-registry.cache is memoized
 +/
class DubRegistryCache
{
    bool includes(string name)
    {
        return (memoize!(() => getPackages())).any!(v => v.name == name);
    }

    private Package[] getPackages()
    {
        const path = "%s/.ponies".format(environment.get("HOME"));
        const cachePath = "%s/dub-registry.cache".format(path);

        return loadFromCache(cachePath).or(populateCache(path, cachePath)).front;
    }

    private auto loadFromCache(string cachePath)
    {
        // dfmt off
        return cachePath
            .some
            .timed("Loading cache",
                   (string path) => path.readText.splitter("\n").map!(v => Package(v)).array)
            ;
        // dfmt on
    }

    private auto populateCache(string path, string cachePath)
    {
        "Initialize cache %s".format(cachePath).info;
        // dfmt off
        return "https://code.dlang.org/api/packages/dump"
            .some
            .timed("Downloading",
                   (string url) => url.getContent.to!string)
            .timed("Parsing",
                   (string content) => content.deserialize!(Package[]))
            .timed("Storing cache",
                (Package[] packages) {
                       if (!packages.empty)
                       {
                           if (!path.exists)
                           {
                               path.mkdir;
                           }
                           std.file.write(cachePath, packages.map!(v => v.name).join("\n"));
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
            hints ~= "Please upload you package to the https://code.dlang.org";
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
