use Ecosystem:ver<0.0.9>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.8>:auth<zef:lizmat>;

my subset Target of Str where $_ eq 'use' | 'distro' | 'identity';

sub meh($message) { exit note $message }

my $eco;
sub eco(str $ecosystem) {
    $eco // ($eco := Ecosystem.new(:$ecosystem))
}
my $identity;
sub resolve($ecosystem, $needle, $ver, $auth, $api, $from) {
    $identity := eco($ecosystem).resolve:
      $needle, :$ver, :$auth, :$api,
      :from($from eq 'Perl6' | 'Raku' ?? Any !! $from)
}

proto sub MAIN(|c) is export { dd c; {*} }
multi sub MAIN(
  Bool() :$help      = False,  #= show this
  Str()  :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Bool() :$verbose   = False,  #= whether to provide verbose info
) {
    eco($ecosystem);
    say "$*PROGRAM-NAME v{ Ecosystem.^ver }";
    say "-" x 80;
    say "Ecosystem: $ecosystem ($eco.identities.elems() identities)";
    with $eco.least-recent-release -> $from {
        say "   Period: $from - $eco.most-recent-release()";
    }
    say "  Updated: $eco.IO.modified.DateTime.Str.substr(0,19)";
    say " Meta-URL: $eco.meta-url()" if $verbose;
    say "-" x 80;
    say "\n$*USAGE";
}

multi sub MAIN("dependencies",
  Str()   $needle,              #= string to search for
  Str()  :$ver,                 #= :ver<> value to match
  Str()  :$auth,                #= :auth<> value to match
  Str()  :$api       = "0",     #= :api<> value to match
  Str()  :$from      = 'Raku',  #= Raku | Perl5
  Str()  :$ecosystem = 'rea',   #= rea | fez | p6c | cpan
  Bool() :$verbose   = False,   #= whether to provide verbose info
) {
    if resolve($ecosystem, $needle, $ver, $auth, $api, $from) -> $identity {
        if $verbose {
            say "Dependencies of $identity";
            say "-" x 80;
        }
        if $eco.dependencies($identity, :recurse($verbose)) -> @identities {
            .say for @identities;
        }
        elsif $verbose {
            meh "No dependencies found";
        }
    }
    else {
        meh "Could not resolve $needle";
    }
}

multi sub MAIN("search",
  Str()   $needle,             #= string to search for
  Str()  :$ver,                #= :ver<> value to match
  Str()  :$auth,               #= :auth<> value to match
  Str()  :$api       = "0",    #= :api<> value to match
  Str()  :$from      = 'Raku', #= Raku | Perl5
  Str()  :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Target :$target    = 'use',  #= use | distro | identity
  Bool()   :$verbose   = False,  #= whether to provide verbose info
) {
    eco $ecosystem;
    if $target eq 'use' {
        if $eco.find-use-targets(
          $needle, :$ver, :$auth, :$api, :$from
        ).sort(*.fc) -> @use-targets {
            if $verbose {
                for @use-targets -> $use-target {
                    my @distros = $eco.distros-of-use-target($use-target);
                    say @distros == 1 && $use-target eq @distros.head
                      ?? $use-target
                      !! "$use-target (@distros[])";
                }
            }
            else {
                .say for @use-targets;
            }
        }
        else {
            meh "No use-targets found for '$needle'";
        }
    }
    elsif $target eq 'distro' {
        if $eco.find-distro-names(
          $needle, :$ver, :$auth, :$api, :$from
        ).sort(*.fc) -> @names {
            if $verbose {
                my %identities := $eco.distro-names;
                for @names -> $name {
                    my $versions := %identities{$name}.elems;
                    say $versions == 1
                      ?? $name
                      !! "$name ({$versions}x)";
                }
            }
            else {
                .say for @names;
            }
        }
        else {
            meh "No distributions found for '$needle'";
        }
    }
    elsif $target eq 'identity' {
        if $eco.find-identities(
          $needle, :$ver, :$auth, :$api, :$from, :all($verbose)
        ).sort(*.fc) -> @identities {
            .say for @identities;
        }
        else {
            meh "No identities found for '$needle'";
        }
    }
}

multi sub MAIN("meta",
  Str()   $needle,             #= use target to produce META of
         *@additional,         #= additional keys to drill down to
  Str()  :$ver,                #= :ver<> value to match, default: highest
  Str()  :$auth,               #= :auth<> value to match, default: any
  Str()  :$api       = "0",    #= :api<> value to match
  Str()  :$from      = 'Raku', #= Raku | Perl5 | bin | native
  Str()  :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
) {
    if resolve($ecosystem, $needle, $ver, $auth, $api, $from) -> $identity {
        if $eco.identities{$identity} -> $found {
            my $data := $found;
            while @additional
              && $data ~~ Associative
              && $data{@additional.shift} -> $deeper {
                $data := $deeper;
            }
            say $eco.to-json: $data;
        }
        else {
            meh "No meta information for '$identity' found";
        }
    }
    else {
        meh "'$needle' could not be resolved to an identity";
    }
}

multi sub MAIN("reverse-dependencies",
  Str()   $needle,             #= use target to reverse dependencies of
  Str()  :$ver,                #= :ver<> value to match, default: highest
  Str()  :$auth,               #= :auth<> value to match, default: any
  Str()  :$api       = "0",    #= :api<> value to match
  Str()  :$from      = 'Raku', #= Raku | Perl5 | bin | native
  Str()  :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Bool() :$verbose   = False,  #= whether to provide verbose info
) {
    if resolve($ecosystem, $needle, $ver, $auth, $api, $from)
      // build($needle, :$ver, :$auth, :$api, :$from) -> $identity {
        if $verbose {
            say "Reverse dependencies of $identity";
            say "-" x 80;
            if $eco.reverse-dependencies{$identity} -> @identities {
                .say for Ecosystem.sort-identities: @identities;
            }
            else {
                meh "Does not appear to have any reverse dependencies";
            }
        }
        else {
            my str $short-name = short-name($identity);
            say "Reverse dependencies of $short-name";
            say "-" x 80;
            if $eco.reverse-dependencies-for-short-name($short-name) -> @sn {
                .say for @sn.sort(*.fc)
            }
            else {
                meh "Does not appear to have any reverse dependencies";
            }
        }
    }
    else {
        meh "'$needle' could not be resolved to an identity";
    }
}

multi sub MAIN("unresolvable",
  Str()  :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Bool() :$verbose   = False,  #= whether to provide verbose info
) {
    say $verbose
      ?? "All unresolvable identities"
      !! "Unresolvable identities in most recent versions only";
    say "-" x 80;
    my %rd := eco($ecosystem).reverse-dependencies;
    if $eco.unresolvable-dependencies(:all($verbose)) -> %ud {
        for %ud.keys.sort(*.fc) {
            say "$_:";
            say "  $_" for %ud{$_};
            say "";
        }
    }
    else {
        say "None";
    }
}

use shorten-sub-commands:ver<0.0.2>:auth<zef:lizmat> &MAIN;

# vim: expandtab shiftwidth=4
