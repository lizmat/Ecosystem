use JSON::Fast:ver<0.16>;
use Identity::Utils:ver<0.0.4>:auth<zef:lizmat>;
use Rakudo::CORE::META:ver<0.0.3>:auth<zef:lizmat>;
use Map::Match:ver<0.0.2>:auth<zef:lizmat>;

constant rea-meta-url =
  "https://raw.githubusercontent.com/Raku/REA/main/META.json";
constant fez-meta-url =
  "https://360.zef.pm/";

class Ecosystem:ver<0.0.1>:auth<zef:lizmat> {
    has Str $.meta-url;
    has Int $.stale-period is built(:bind) = 86400;
    has Str $.meta-as-json is built(False);
    has IO::Path $.IO;
    has @.meta;
    has %.identities   is built(False);
    has %.distro-names is built(False);
    has %.use-targets  is built(False);
    has %.descriptions is built(False);
    has Lock $!meta-lock;

    method TWEAK(Bool :$fez, Bool :$rea) {
        without $!meta-url {
            if $fez {
                $!meta-url := fez-meta-url;
                $!IO       := %?RESOURCES<fez.json>.IO;
            }
            elsif $rea || !$!IO {
                $!meta-url := rea-meta-url;
                $!IO       := %?RESOURCES<rea.json>.IO;
            }
        }
        $!meta-lock := Lock.new;
        now - $!IO.modified > $!stale-period && $!meta-url
          ?? self!update-meta-from-URL
          !! self!update-meta-from-json($!IO.slurp)
    }

    method !update-meta-from-URL() {
        $!meta-lock.protect: {
            my $proc := run 'curl', $!meta-url, :out, :!err;
            self!update-meta-from-json: $proc.out.slurp;
            $!IO.spurt: $!meta-as-json;
        }
    }

    method !update-meta-from-json($!meta-as-json --> Nil) {
        my @meta := from-json $!meta-as-json;
        my %identities;
        my %distro-names;
        my %descriptions;
        my %use-targets;

        with %Rakudo::CORE::META -> %distribution {
            my $name     := %distribution<name>;
            my $identity := %distribution<dist>;

            %identities{$identity} := %distribution;
            %distro-names{$name}  := my str @ = $identity;
            for %distribution<provides>.keys {
                %use-targets{$_} := my str @ = $identity;
            }
        }

        for @meta -> %distribution {
            if %distribution<name> -> $name {
                my $identity := %distribution<dist>;
                %identities{$identity} := %distribution;
                (%distro-names{$name} // (%distro-names{$name} := my str @))
                  .push($identity);

                if %distribution<description> -> $text {
                    ( %descriptions{$text} // (%descriptions{$text} := my str @)
                    ).push($identity);
                }
                if %distribution<provides> -> %provides {
                    ( %use-targets{$_} // (%use-targets{$_} := my str @)
                    ).push($identity) for %provides.keys;
                }
            }
        }

        @!meta         := @meta;
        await
          (start { %!identities   := Map::Match.new: %identities }),
          (start { %!distro-names := Map::Match.new: %distro-names }),
          (start { %!descriptions := Map::Match.new: %descriptions }),
          (start { %!use-targets  := Map::Match.new: %use-targets });
    }
}

#my $ea = Ecosystem.new.descriptions;
#{
#    .say for Ecosystem.new.distro-names{ / All | Utils / }:p;
#    LEAVE say now - ENTER now;
#}

=begin pod

=head1 NAME

Ecosystem - Accessing a Raku Ecosystem

=head1 SYNOPSIS

=begin code :lang<raku>

use Ecosystem;

my $ea = Ecosystem.new;  # access the REA

say "Archive has $ea.meta.elems() identities:";
.say for $ea.meta.keys.sort;

=end code

=head1 DESCRIPTION

Ecosystem provides the basic logic to accessing a Raku Ecosystem,
defaulting to the Raku Ecosystem Archive, a place where (almost) every
distribution ever available in the Raku Ecosystem, can be obtained
even after it has been removed (specifically in the case of the old
ecosystem master list and the distributions kept on CPAN).

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Ecosystem .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
