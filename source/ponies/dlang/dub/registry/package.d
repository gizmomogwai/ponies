module ponies.dlang.dub.registry;

import ponies.shields;
import ponies.dlang.dub;
import std;

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
