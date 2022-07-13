module ponies.dlang.gitlab;

import ponies : Pony, CheckStatus;
import std.algorithm : canFind, endsWith;
import std.conv : to;
import std.exception : ifThrown;
import std.experimental.logger : warning;
import std.file : exists, readText, write;
import std.format : format;
import std.process : execute, executeShell;


private:

const TAG = "v1.0.0";
const GITLAB_CI_YML = ".gitlab-ci.yml";
const GITLAB_CI_YML_CONTENT = `variables:
  GIT_SUBMODULE_STRATEGY: recursive
include:
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

    override public string name()
    {
        return "Prepare project for gitlab ci";
    }

    override public bool applicable()
    {
        return gitlabRemote;
    }

    override public CheckStatus check()
    {
        return (
          GITLAB_CI_YML.exists
          && GITLAB_CI_YML.readText.canFind(GITLAB_CI_YML_CONTENT)
          && dlangBuildSubmoduleExists
        ).to!CheckStatus;
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
        import std.stdio : writeln; writeln("blub");
        if (!gitlabRemote)
        {
            return ["Please put project to gitlab and add it as the only remote."];
        }
        return [];
    }

    override public void run()
    {
        const oldContent = GITLAB_CI_YML.readText.ifThrown("");
        auto newContent = oldContent.dup;
        if (!newContent.endsWith("\n"))
        {
            newContent ~= "\n";
        }
        if (!oldContent.canFind(GITLAB_CI_YML_CONTENT))
        {
            newContent ~= GITLAB_CI_YML_CONTENT;
        }

        if (oldContent != newContent)
        {
            "Updating %s".format(GITLAB_CI_YML).warning;
            GITLAB_CI_YML.write(newContent);
            ["git", "add", GITLAB_CI_YML].execute;
        }

        if (!dlangBuildSubmoduleExists)
        {
            "Adding git@gitlab.com:gizmomogwai/dlang-build.git with tag %s as submodule in .gitlab".format(TAG).warning;
            ["git", "submodule", "add", "../../gizmomogwai/dlang-build.git", ".gitlab"].execute;
            ["git", "--workdir=.gitlab", "--git-dir=.gitlab/.git", "reset", "--hard", TAG].execute;
        }
    }
}
