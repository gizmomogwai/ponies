/++
 + Authors: Christian Köstlin
 +/

module ponies.dlang.gitlab;

import ponies : Pony, CheckStatus, and;
import std.algorithm : canFind, endsWith;
import std.conv : to;
import std.exception : ifThrown;
import std.experimental.logger : warning;
import std.file : exists, readText, write;
import std.format : format;
import std.process : execute, executeShell;

private:

const TAG = "v1.0.2";
const GITLAB_CI_YML = ".gitlab-ci.yml";
const GITLAB_CI_YML_CONTENT = `include:
  - project: "gizmomogwai/dlang-build"
    file: "dlang-build.yml"
    ref: "` ~ TAG ~ "\"\n";

const DLANG_BUILD_SUBMODULE_CHECK = "git submodule status | grep .gitlab | grep " ~ TAG;

/++ Add gitlab ci to a project
 + Checks for .gitlab-ci.yml and the
 + https://gitlab.com/gizmomogwai/dlang-build git submodule
 +/
public class GitlabPony : Pony
{
    this()
    {
        super([
                EnsureStringInFile(GITLAB_CI_YML, GITLAB_CI_YML_CONTENT),
              ]);
    }

    override public string name()
    {
        return "Prepare project for gitlab ci";
    }

    override public bool applicable()
    {
        return super.applicable() && gitlabRemote;
    }

    override public CheckStatus check()
    {
        return super.check().and(dlangBuildSubmoduleExists);
    }

    private bool dlangBuildSubmoduleExists()
    {
        return DLANG_BUILD_SUBMODULE_CHECK.executeShell.status == 0;
    }

    private bool gitlabRemote()
    {
        return "git remote -v | grep gitlab".executeShell.status == 0;
    }

    override public string[] doctor()
    {
        auto res = super.doctor();
        if (!gitlabRemote)
        {
            return res ~ "Please put project to gitlab and add it as the only remote.";
        }
        return res;
    }

    override public void run()
    {
        super.run();

        if (!dlangBuildSubmoduleExists)
        {
            "%s:Adding git@gitlab.com:gizmomogwai/dlang-build.git with tag %s as submodule in .gitlab".format(logTag, TAG).warning;
            ["git", "submodule", "add", "../../gizmomogwai/dlang-build.git", ".gitlab"].execute;
            ["git", "--workdir=.gitlab", "--git-dir=.gitlab/.git", "reset", "--hard", TAG].execute;
        }
    }
}
