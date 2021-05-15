module ponies.dlang.dub.registry;

import ponies.shields;
import ponies.dlang.dub;
import std;
import std.experimental.logger;
import requests;
import mir.ion.deser.json;

class DubRegistryCache
{
    private static bool parsed;
    private static JSONValue json = false;
    bool includes(string name)
    {
        writeln("includes");
        if (!parsed)
        {
            json = getData();
            parsed = true;
        }
        return json.array.any!(v => v["name"].str == name);
    }

    private auto getData()
    {
        const path = "%s/.ponies".format(environment.get("HOME"));
        const cachePath = "%s/dub-registry.cache".format(path);
        if (!cachePath.exists)
        {
            const url = "https://code.dlang.org/api/packages/dump";
            "Downloading %s to %s".format(url, cachePath).info;
            if (!path.exists)
            {
                path.mkdir;
            }
            "Parsing %s".format(cachePath).writeln;
            std.file.write(cachePath, url.getContent.data);
            "Parsing %s done".format(cachePath).writeln;
        }

        return cachePath.readText.parseJSON;
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
        return "[[http://code.dlang.org/packages/%1$s][https://img.shields.io/dub/%2$s/%1$s.svg?style=flat-square]]"
            .format(dubPackageName, what);
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
        return "Setup dub registry version shield in readme.org";
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
