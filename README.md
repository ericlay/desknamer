# desknamer.sh

`desknamer.sh` is a daemon that intelligently renames open desktops (workspaces) according to the applications open inside.

# Installation

To clone to `~/bin/desknamer`, make executable, and add to available commands:

```bash
git clone https://gitlab.com/jallbrit/desknamer ~/bin/desknamer
chmod +x ~/bin/desknamer/desknamer.sh
ln -s ~/bin/desknamer/desknamer.sh ~/.local/bin/desknamer
```

## Supported Window Managers

Currently, `desknamer` only supports `bspwm` but has the opportunity to be ported to other window managers.

# Usage

```
Usage: desknamer [OPTIONS]

desknamer.sh monitors your open desktops and renames them according to what's inside.

optional args:
  -a, --all             print all application categories found on your machine
  -n, --norecursive     don't inspect windows recursively
  -s, --search PROGRAM  find .desktop files matching *program*.desktop
  -g, --get PROGRAM     get categories for given program
  -h, --help            show help
```

Since `desknamer` is designed to be used as a daemon, you'll want to run it in the background like so:

```bash
desknamer &
```

# How it Works

Fortunately for us, most applications installed on your system have a `.desktop` file that tells us, among other things, the name of the application, a comment, and categories. These categories allow `desknamer` to know what type of application it's looking at.

Unfortunately, not all of your open programs have `.desktop` files on your machine, and even if they do, they may not have categories assigned. `desknamer` knows this and is prepared.

## Specificity Rules

Obviously, there are going to be collisions. What happens if `desknamer` encounters a terminal and a web browser in the *same desktop*? `desknamer` follows specificity rules to determine the proper name for the desktop. These rules are as follows:

1. An application is recognized by command name (e.g. `firefox-esr`)
2. An application is recognized by assigned known categories (e.g. `Game` or `WordProcessor`)
3. Applications exist but are unrecognized; desktop is assigned a generic name
4. No applications exist; defaults to desktop index

The first match on this list determines the name of the desktop. Lists of recognized applications and categories are currently in the source code, but will eventually be moved to an external `rules` file.

# Why?

`bspwm` allows for the static naming of desktops.

Some people prefer to leave their desktops named `1, 2, 3, 4` and so forth.

Others prefer to dedicate desktops to certain purposes, and name them accordingly. For example, if you wish to place chat applications in desktop 1, terminals in desktop 2, a web browser in desktop 3, and leave desktop 4 open for anything, you may name your desktops `chat terminal browser 4`.

However, this is a limiting action. Once you have done this, it forces you to stick to those positions. What if you want browsers open in 2 desktops, and terminals open in 2 desktops? Desktop 1 will always say `chat`, regardless of what's inside. This can cause confusion and inefficiency.

`desknamer` solves this problem by *dynamically* assigning names to your desktops according to what's inside. It allows for specificity rules to intelligently determine what each desktop should be named. So now, open any window you want anywhere and you'll always be able to tell where it is.
