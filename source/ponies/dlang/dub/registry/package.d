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

struct Package {
    string name;
}
class DubRegistryCache
{
    private static bool packagesRead;

    private static Package[] packages;

    bool includes(string name)
    {
        if (!packagesRead)
        {
            packages = getPackages();
            packagesRead = true;
        }
        return packages.any!(v => v.name == name);
    }


    private auto getPackages()
    {
        const path = "%s/.ponies".format(environment.get("HOME"));
        const cachePath = "%s/dub-registry.cache".format(path);
        if (!cachePath.exists)
        {
            "Populating cache %s".format(cachePath).info;
            const url = "https://code.dlang.org/api/packages/dump";
            auto sw = std.datetime.stopwatch.StopWatch(AutoStart.yes);
            auto content = url.getContent;
            "Downloading took %s".format(sw.peek).info;
            sw.reset;
            auto packages = content.to!string.deserialize!(Package[]);
            "Parsing took %s".format(sw.peek).info;
            if (!path.exists)
            {
                path.mkdir;
            }
            std.file.write(cachePath, packages.map!(v => v.name).join("\n"));
            return packages;
        }
        auto sw = std.datetime.stopwatch.StopWatch(AutoStart.yes);
        auto result = cachePath.readText.splitter("\n").map!(v => Package(v)).array;
        "Loading cache took %s".format(sw.peek).info;
        return result;
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
        if (!cache.includes(dubPackageName)) {
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
