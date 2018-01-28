/++
 + Copyright: Copyright © 2018, Christian Köstlin
 + License: MIT
 + Authors: Christian Koestlin
 +/

module ponies.dlang.travis;

import dyaml;
import ponies.dlang;
import ponies;
import std.algorithm;
import std.conv;
import std.experimental.logger;
import std.string;

abstract class TravisDlangPony : DlangPony
{
    private Node root;
    private bool upToDate = false;

    /++
     + Do the change on the root node and return if something was changed.
     + Return: true if something was changed
     +/
    protected abstract bool change(ref Node root);

    override CheckStatus check()
    {
        root = Loader(travisYml).load;
        upToDate = !change(root);
        return upToDate.to!CheckStatus;
    }

    override void run()
    {
        if (!upToDate)
        {
            "Writing new %s".format(travisYml).warning;
            Dumper(travisYml).dump(root);
        }
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
        auto language = "language" in root;
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
                "Converting d node to array".warning;
                modified = true;
            }

            dNode = "d" in root;
            if (!dNode.sequence!string.canFind("dmd"))
            {
                dNode.add(Node("dmd"));
                root["d"] = *dNode;
                "Adding dmd".warning;
                modified = true;
            }
            if (!dNode.sequence!string.canFind("ldc"))
            {
                dNode.add(Node("ldc"));
                root["d"] = *dNode;
                "Adding ldc".warning;
                modified = true;
            }
            return modified;
        }
        else
        {
            root["d"] = Node([Node("dmd"), Node("ldc")]);
            "Adding new node with dmd and ldc".warning;
            return true;
        }
    }
}
class NoSudoTravisDlangPony : TravisDlangPony
{
    override string name() {
        return "Setup travis to not run as sudo";
    }
    override bool change(ref Node root)
    {
        auto sudo = "sudo" in root;
        if (sudo) {
            if (sudo.as!string != "false") {
                root["sudo"] = false;
                return true;
            }
            return false;
        } else {
            root["sudo"] = false;
            return true;
        }
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
