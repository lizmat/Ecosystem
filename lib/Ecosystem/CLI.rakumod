use Ecosystem:ver<0.0.7>:auth<zef:lizmat>;

my subset Target of Str where $_ eq 'use' | 'distro' | 'identity';

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

    my $eco := Ecosystem.new(:$ecosystem);
    if $eco.resolve(
      $needle, :$ver, :$auth, :$api, :from($from eq 'Raku' ?? Any !! $from)
    ) -> $identity {
        if $verbose {
            say "Dependencies of $identity";
            say "-" x 80;
        }
        if $eco.dependencies($identity) -> @identities {
            .say for @identities;
        }
        elsif $verbose {
            exit note "No dependencies found";
        }
    }
    else {
        exit note "Could not resolve $needle";
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
    my $eco := Ecosystem.new(:$ecosystem);
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
            exit note "No use-targets found for '$needle'";
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
            exit note "No distributions found for '$needle'";
        }
    }
    elsif $target eq 'identity' {
        if $eco.find-identities(
          $needle, :$ver, :$auth, :$api, :$from, :all($verbose)
        ).sort(*.fc) -> @identities {
            .say for @identities;
        }
        else {
            exit note "No identities found for '$needle'";
        }
    }
}

# vim: expandtab shiftwidth=4