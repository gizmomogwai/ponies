/++
 + Authors: Christian Koestlin
 +/

module ponies.shields;

import ponies;
import std;
import std.experimental.logger;

class ShieldPony : Pony
{
    protected UserAndProject userAndProject;
    this()
    {
        userAndProject = getUserAndProject;
    }

    override bool applicable()
    {
        return exists("readme.org") && userAndProject.user != null && userAndProject.project != null;
    }

    override CheckStatus check()
    {
        return readText("readme.org").canFind(shield.strip).to!CheckStatus;
    }

    override string[] doctor()
    {
        if (!exists("readme.org"))
        {
            return ["Please add readme.org"];
        }
        return [];
    }

    abstract string shield();

    override void run()
    {
        "Please resort your readme.org to put the shield to the right place".warning;
        append("readme.org", shield);
    }
}

class GithubShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a link to github in readme.org";
    }

    override string shield()
    {
        return "[[https://github.com/%1$s/%2$s][https://img.shields.io/github/tag/%1$s/%2$s.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }

    override bool applicable()
    {
        return exists(".travis.yml");
    }
}

class CodecovShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a link to codecov in readme.org";
    }

    override string shield()
    {
        return "[[https://codecov.io/gh/%1$s/%2$s][https://img.shields.io/codecov/c/github/%1$s/%2$s/master.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }

    override bool applicable()
    {
        return exists(".travis.yml");
    }
}

class TravisCiShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a travis ci shield in readme.org";
    }

    override string shield()
    {
        return "[[https://travis-ci.org/%1$s/%2$s][https://img.shields.io/travis/%1$s/%2$s/master.svg?style=flat-square]]\n"
            .format(userAndProject.user, userAndProject.project);
    }

    override bool applicable()
    {
        return exists(".travis.yml");
    }
}

class GithubPagesShieldPony : ShieldPony
{
    override string name()
    {
        return "Setup a documentation shield in readme.org";
    }

    override string shield()
    {
        return "[[https://%s.github.io/%s][https://img.shields.io/readthedocs/pip.svg?style=flat-square]]\n".format(
                userAndProject.user, userAndProject.project);
    }
}

bool mightBeEmacs()
{
    return exists("Cask");
}

class MelpaShieldPony : ShieldPony
{
    protected UserAndProject userAndProject;

    this()
    {
        userAndProject = getUserAndProject;
    }

    override string name()
    {
        return "Setup a melpa shield in readme.org";
    }

    override bool applicable()
    {
        return super.applicable() && mightBeEmacs;
    }

    override string shield()
    {
        return "[[https://melpa.org/#/%1$s][https://melpa.org/packages/%1$s-badge.svg]]".format(
                userAndProject.project);
    }
}
