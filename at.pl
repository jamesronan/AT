#!/usr/bin/perl
# A wrapper for apt-* programs to simulate the slick interface of 
# Arch's "Pacman".  Backtick because ` -Syu is easy to type, and a valid 
# file name that no one in their right mind would use.
#
# I was sick of the difference between apt-get install * and apt-cache search *
#
use strict;
use v5.10;

use Getopt::Long qw(:config no_ignore_case bundling);

our $VERSION = '0.11';

# First off, let set up stuff we'll need.
# Allowable options: 
my %options;
Getopt::Long::GetOptions(
    \%options,
    
    'help|h|?',  # HELP!! I need somebody!

    'S',   # apt-get install $x
    'y',   # used with 'S' preforms apt-get update before primary operation.
    's',   # used with 'S' apt-cache search $x 
    'c+',  # used with 'S', c = apt-get autoclean, cc = apt-get clean.
    'u',   # used with 'S' changes apt-get install to apt-get upgrade
    'd',   # Alternate to 'u' - invokes apt-get dist-upgrade instead 
           #  - Yeah I know it wasn't in Arch's pacman, but this is an apt 
           #    wrapper :-).

    'R',   # apt-get remove $x
    'p',   # used with 'R' changes apt-get remove to apt-get purge

    'Q',   # dpkg -l $x
    'q',   # used with 'Q', searches for files within installed packages.
    'i',   # used with 'Q', gives info about a package.
    'f',   # used with 'Q', lists files withing a given package.
    
    'U',   # dpkg -i $x
);

# System paths to executables we'll need
my %exec = (
    'sudo'     => `which sudo`,
    'aptget'   => `which apt-get`,
    'aptcache' => `which apt-cache`,
    'dpkg'     => `which dpkg`,
);
chomp %exec;

# If they asked for help... so be it.
if (   !%options
    || $options{help})
{
    die usage();
}

# First off, check for the "update the cache" flag as this needs to be 
# performed first regardless of which mode it was listed in.
if ($options{y}) {
    print "Updating Local Cache... ";
    say my $result = (system("$exec{sudo} $exec{aptget} -qq update") == 0)
        ? 'complete'
        : "FAILED! ($!)";
}

# Right, we're looking for the primary switches (the uc ones), and process them
# in the order: Query (and exit), purges, remote install, local install 

# First up, Query. If we have a query, we want to use dpkg to find info on
# installed modules, Exist after this as we don't want to perform any other
# actions after a search.
if ($options{Q}) {
    my $switch = ($options{f}) ? '-L' 
               : ($options{i}) ? '-s'
               : ($options{q}) ? '-S'
               :                 '-l';
    system($exec{dpkg}, $switch, @ARGV);
    exit;
}

# Next: Local install...
if ($options{U}) {
    system($exec{sudo}, $exec{dpkg}, "-i", @ARGV);
    exit;
}

# Then: Removals
if ($options{R}) {
    my $command = ($options{p}) ? 'purge' : 'remove'; 
    system($exec{sudo}, $exec{aptget}, $command, @ARGV);
}

# Finally: Sync.  Installs new modules, updates stuff, and searchs the remote
# repos.
if ($options{S}) {

    # Apt-cache search - search for modules that are not installed, but are
    # available.  Exit after this, as we don't want to perform anything else 
    # if a search was specified.
    if ($options{s}) {
        system($exec{aptcache}, "search", @ARGV);
        exit; 
    }

    # Cache cleaning.
    if ($options{c}) {
        if ( $options{c} == 1 ) {
            print "Autocleaning cache... ";
            say my $result =
              ( system($exec{sudo}, $exec{aptget}, "-qq", "autoclean") == 0 )
              ? 'complete'
              : "FAILED! ($!)";
        }
        else {
            print "Cleaning cache... ";
            say my $result =
              ( system($exec{sudo}, $exec{aptget}, "-qq", "clean") == 0 )
              ? 'complete'
              : "FAILED! ($!)";
        }
        exit;
    }

    # System Upgrade.
    if ($options{u}) {
        system($exec{sudo}, $exec{aptget}, "upgrade");
    }

    # System Distribution
    if ($options{d}) {
        system($exec{sudo}, $exec{aptget}, "dist-upgrade");
    }

    # Finally, we want to install said package(s) if specified.
    if (@ARGV) {
        system($exec{sudo}, $exec{aptget}, "install", @ARGV);
    }
}


sub usage {
    return <<USAGE

@ - apt wrapper version $VERSION

Usage: @ -[QRSU][cdfipqsuy] [<package name>|<search term>]

@ (at) is a wrapper around apt-*|dpkg programs in the style of Arch Linux's 
pacman. I got sick of remembering to type "cache" instead of "get" etc. and 
all the commands are sooo long.  Enter @. @ does all the thinking for you, tap
the right switch and @ applies the query to the correct application and even
requests sudo for the ones that require it.

This script should be softlinked to /usr/bin/@ on your system by doing this:

    sudo ln -sf /path/to/at.pl /usr/bin/@

Takes a primary command switch and optionally sub switches. The switches can 
be bundled together in a form such as  `@ -Syu` this will do: 
apt-get update, followed by apt-get upgrade.

Available switches are described below:

  --help, 
  -h, -?  - Displays this help message.

  -S     - Primary option: Sync. Runs `apt-get install \$x`
    -y   - Used with 'S', preforms apt-get update before primary operation.
    -s   - used with 'S', swtiches to `apt-cache search \$x` 
    -c   - used with 'S', switches to `apt-get autoclean`
    -cc  - used with 'S', switches to `apt-get clean`
    -u   - used with 'S', switches to `apt-get upgrade`
    -d   - used with 'S', Alternate to 'u' - switches to apt-get dist-upgrade

  -R     - Primary option: Remove. Runs `apt-get remove \$x`
    -p   - used with 'R', switches to `apt-get purge`

  -Q     - Primary Option: Query. Runs `dpkg -l \$x` searchs installed packages.
    -q   - used with 'Q', searches for files within installed packages.
    -i   - used with 'Q', gives info about the specified package.
    -f   - used with 'Q', lists files withing a given package.
    
  -U     - Primary Option: Local Install. Runs `dpkg -i \$x`

See the man pages for apt-get, apt-cache, and dpkg.

Author: James Ronan <james\@ronanweb.co.uk>

USAGE

}

