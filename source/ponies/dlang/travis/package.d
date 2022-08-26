/++
 + Copyright: Copyright (c) 2018, Christian Koestlin
 + License: MIT
 + Authors: Christian Koestlin, Christian Köstlin
 +/
module ponies.dlang.travis;

import dyaml : Loader, Node, dumper, NodeID;
import ponies.dlang : DlangPony;
import ponies : CheckStatus;
import std.algorithm : map, canFind;
import std.conv : to;
import std.experimental.logger : info, warning;
import std.stdio : File;
import std.format : format;
import std.file : exists;

const TRAVIS_YAML = ".travis.yml";

auto travisYamlAvailable()
{
    return TRAVIS_YAML.exists;
}

auto isScalar(T)(T node)
{
    return node.nodeID == NodeID.scalar;
}

abstract class TravisDlangPony : DlangPony
{
    private Node root;
    private bool upToDate = false;

    this()
    {
        super();
    }

    /++
     + Do the change on the root node and return if something was changed.
     + Return: true if something was changed
     +/
    protected abstract bool change(ref Node root);

    override CheckStatus check()
    {
        root = Loader.fromFile(TRAVIS_YAML).load;
        upToDate = !change(root);
        return upToDate.to!CheckStatus;
    }

    override void run()
    {
        if (!upToDate)
        {
            "%s:Writing new %s".format(logTag, TRAVIS_YAML).warning;
            dumper.dump(File(TRAVIS_YAML, "w").lockingTextWriter, root);
        }
    }

    override bool applicable()
    {
        return super.applicable && travisYamlAvailable;
    }
}

class LanguageTravisDlangPony : TravisDlangPony
{
    override string name()
    {
        return "Setup travis to work with language d";
    }

    override bool change(ref Node root)
    {
        const language = "language" in root;
        if (language)
        {
            if (language.isScalar)
            {
                if (language.as!string == "d")
                {
                    return false;
                }
            }
        }
        root["language"] = "d";
        return true;
    }
}

class CompilerTravisDlangPony : TravisDlangPony
{
    override string name()
    {
        return "Setup dmd and ldc as compilers";
    }

    override bool change(ref Node root)
    {
        auto dNode = "d" in root;
        if (dNode)
        {
            bool modified = false;
            if (dNode.isScalar)
            {
                root["d"] = Node([*dNode]);
                "%s:Converting d node to array".format(logTag).warning;
                modified = true;
            }

            dNode = "d" in root;
            if (!dNode.sequence!string.canFind("dmd"))
            {
                dNode.add(Node("dmd"));
                root["d"] = *dNode;
                "%s:Adding dmd".format(logTag).warning;
                modified = true;
            }
            if (!dNode.sequence!string.canFind("ldc"))
            {
                dNode.add(Node("ldc"));
                root["d"] = *dNode;
                "%s:Adding ldc".format(logTag).warning;
                modified = true;
            }
            return modified;
        }
        else
        {
            root["d"] = Node([Node("dmd"), Node("ldc")]);
            "%s:Adding new node with dmd and ldc".format(logTag).warning;
            return true;
        }
    }
}

class NoSudoTravisDlangPony : TravisDlangPony
{
    override string name()
    {
        return "Setup travis to not run as sudo";
    }

    override bool change(ref Node root)
    {
        const sudo = "sudo" in root;
        if (sudo)
        {
            if (sudo.as!string != "false")
            {
                root["sudo"] = false;
                return true;
            }
            return false;
        }
        else
        {
            root["sudo"] = false;
            return true;
        }
    }
}

class GhPagesTravisDlangPony : TravisDlangPony
{
    override string name()
    {
        return "Setup travis to autodeploy ddox to ghpages";
    }

    override bool change(ref Node root)
    {
        return addNeededPackages(root) || addDdoxBuildScript(root) || addDeployNode(root);
    }

    private bool addDeployNode(ref Node root)
    {
        const deploy = "deploy" in root;
        if (!deploy)
        {
            "%s:Adding deploy node".format(logTag).warning;
            // dfmt off
            root["deploy"] =
                Node(["provider" : Node("pages"),
                      "skip-cleanup" : Node(true),
                      "local-dir" : Node("docs"),
                      "github-token" : Node("$GH_REPO_TOKEN"),
                      "verbose" : Node(true),
                      "keep-history" : Node(true),
                      "on" : Node(["branch" : "master"])]);
            // dfmt on
            return true;
        }
        return false;
    }

    private bool addDdoxBuildScript(ref Node root)
    {
        const buildDdox = "dub build --compiler=${DC} --build=ddox";
        const script = "script" in root;
        if (!script)
        {
            "%s:Adding ddox build script".format(logTag).warning;
            root["script"] = Node(buildDdox);
            return true;
        }

        if (script.isScalar)
        {
            if (script.as!string != buildDdox)
            {
                root["script"] = Node(script.as!string ~ " && " ~ buildDdox);
            }
            else
            {
                root["script"] = Node(buildDdox);
            }
            return true;
        }

        return false;
    }

    private bool addNeededPackages(ref Node root)
    {
        const addons = "addons" in root;
        if (!addons)
        {
            "%s:Adding addons node".format(logTag).warning;
            root["addons"] = Node([
                "apt": Node(["packages": Node(["libevent-dev"])])
            ]);
            return true;
        }

        if (addons.isScalar)
        {
            "%s:Changing addons node".format(logTag).warning;
            root["addons"] = Node([
                "apt": Node(["packages": Node(["libevent-dev"])])
            ]);
            return true;
        }

        const apt = "apt" in root["addons"];
        if (!apt)
        {
            root["addons"]["apt"] = Node(["packages": Node(["libevent-dev"])]);
            return true;
        }

        if (apt.isScalar)
        {
            "%s:Changing addons.apt node".format(logTag).warning;
            root["addons"]["apt"] = Node(["packages": Node(["libevent-dev"])]);
            return true;
        }

        auto packages = "packages" in root["addons"]["apt"];
        if (!packages)
        {
            "%s:Adding packages to addons.apt".format(logTag).warning;
            root["addons"]["apt"]["packages"] = Node(["libevent-dev"]);
            return true;
        }

        if (packages.isScalar)
        {
            "%s:Changing addons.apt.packages".format(logTag).warning;
            root["addons"]["apt"]["packages"] = Node(["libevent-dev"]);
            return true;
        }

        if (!packages.sequence!string.canFind("libevent-dev"))
        {
            "%s:Adding libevent-dev to addons.apt.packages".format(logTag).warning;
            packages.add("libevent-dev");
            root["addons"]["apt"]["packages"] = *packages;
            return true;
        }

        return false;
    }
}

/+
class TravisPony : DlangPony
{
    override string name()
    {
        return "Setup travis build in %s".format(travisYml);
    }

    override CheckStatus check()
    {
        return exists(travisYml).to!CheckStatus;
    }

    override void run()
    {
        "Creating %s file".format(travisYml).info;
        "userinteraction:Please get gh repo token from https://github.com/settings/tokens".warning;
        "userinteraction:Please enable travis build".warning;
        "userinteraction:Please enable coverage on codecov".warning;
        auto content = "language: d
d:
  - dmd
  - ldc
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
    secure: create this token with 'travis encrypt GH_REPO_TOKEN=key from https://github.com/settings/tokens'
";
        std.file.write(travisYml, content);
    }
}
+/
