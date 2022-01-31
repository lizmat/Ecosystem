use Ecosystem:ver<0.0.8>:auth<zef:lizmat>;

my subset Target of Str where $_ eq 'use' | 'distro' | 'identity';

sub meh($message) { exit note $message }

my $eco;
sub eco(str $ecosystem) {
    $eco // ($eco := Ecosystem.new(:$ecosystem))
}

proto sub MAIN(|) is export {*}
multi sub MAIN(
  Str  :$ecosystem = 'rea', #= rea | fez | p6c | cpan
  Bool :$help,              #= show this
  Bool :$verbose = False,   #= whether to provide verbose info
) {
    my $eco := Ecosystem.new(:$ecosystem);
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
  Str     $needle,             #= string to search for
  Str    :$ver,                #= :ver<> value to match
  Str    :$auth,               #= :auth<> value to match
  Str    :$api       = "0",    #= :api<> value to match
  Str    :$from      = 'Raku', #= Raku | Perl5
  Str    :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Bool   :$verbose   = False,  #= whether to provide verbose info
) {

    if eco($ecosystem).resolve(
      $needle, :$ver, :$auth, :$api, :from($from eq 'Raku' ?? Any !! $from)
    ) -> $identity {
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
  Str     $needle,             #= string to search for
  Str    :$ver,                #= :ver<> value to match
  Str    :$auth,               #= :auth<> value to match
  Str    :$api       = "0",    #= :api<> value to match
  Str    :$from      = 'Raku', #= Raku | Perl5
  Str    :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
  Target :$target    = 'use',  #= use | distro | identity
  Bool   :$verbose   = False,  #= whether to provide verbose info
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
  Str     $needle,             #= use target to produce META of
         *@additional,         #= additional keys to drill down to
  Str    :$ver,                #= :ver<> value to match
  Str    :$auth,               #= :auth<> value to match
  Str    :$api       = "0",    #= :api<> value to match
  Str    :$from      = 'Raku', #= Raku | Perl5
  Str    :$ecosystem = 'rea',  #= rea | fez | p6c | cpan
) {
    if eco($ecosystem).resolve(
      $needle, :$ver, :$auth, :$api, :$from
    ) -> $identity {
        if $eco.identities{$identity} -> $found {
            my $data := $found;
            while @additional
              && $data ~~ Associative
              && $data{@additional.shift} -> $deeper {
                $data := $deeper;
            }
            say nice-json $data;
        }
        else {
            meh "No meta information for '$identity' found";
        }
    }
    else {
        meh "'$needle' could not be resolved to an identity";
    }
}

use shorten-sub-commands:ver<0.0.1>:auth<zef:lizmat> &MAIN;

# vim: expandtab shiftwidth=4
