use JSON::Fast:ver<0.16>;
use Identity::Utils:ver<0.0.5>:auth<zef:lizmat>;
use Rakudo::CORE::META:ver<0.0.3>:auth<zef:lizmat>;
use Map::Match:ver<0.0.2>:auth<zef:lizmat>;

constant rea-meta-url =
  "https://raw.githubusercontent.com/Raku/REA/main/META.json";
constant fez-meta-url =
  "https://360.zef.pm/";

class Ecosystem:ver<0.0.1>:auth<zef:lizmat> {
    has IO::Path $.IO;
    has Str $.meta-url;
    has Int $.stale-period is built(:bind) = 86400;
    has Str $.meta     is built(False);
    has %.identities   is built(False);
    has %.distro-names is built(False);
    has %.use-targets  is built(False);
    has %.matches      is built(False);
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

        without $!IO {
            die "Must specify IO with a specified meta-url";
        }

        $!meta-lock := Lock.new;
        self!stale
          ?? self!update-meta-from-URL
          !! self!update-meta-from-json($!IO.slurp)
    }

    method !stale() {
        $!meta-url && now - $!IO.modified > $!stale-period
    }

    method !update-meta-from-URL() {
        $!meta-lock.protect: {
            my $proc := run 'curl', $!meta-url, :out, :!err;
            self!update-meta-from-json: $proc.out.slurp;
            $!IO.spurt: $!meta;
        }
    }

    sub add-identity(%hash, str $key, str $identity) {
        with %hash{$key} -> @identities {
            @identities.push: $identity;
        }
        else {
            %hash{$key} := (my str @ = $identity);
        }
    }

    sub sort-identities(@identities) {
        @identities.sort(&version).reverse.sort(&short-name)
    }

    sub sort-identities-of-hash(%hash) {
        for %hash.kv -> $key, @identities {
            %hash{$key} :=
              my str @ = sort-identities @identities.unique;
        }
    }

    method !update-meta-from-json($!meta --> Nil) {
        my @meta := from-json $!meta;
        my %identities;
        my %distro-names;
        my %use-targets;
        my %matches;

        with %Rakudo::CORE::META -> %distribution {
            my $name     := %distribution<name>;
            my $identity := %distribution<dist>;

            %identities{$identity} := %distribution.Map;
            add-identity %distro-names, $name, $identity;
            add-identity %use-targets, $_, $identity
              for %distribution<provides>.keys;
        }

        for @meta -> %distribution {
            if %distribution<name> -> $name {
                my $identity := %distribution<dist>;
                %identities{$identity} := %distribution;
                add-identity %distro-names, $name, $identity;
                add-identity %matches, $name, $identity;

                if %distribution<description> -> $text {
                    add-identity %matches, $text, $identity;
                }
                if %distribution<provides> -> %provides {
                    add-identity %use-targets, $_, $identity
                      for %provides.keys;
                }
            }
        }

        for %!distro-names, %!use-targets, %!matches -> %hash {
            sort-identities-of-hash %hash;
        }

        %!identities   := %identities.Map;
        %!distro-names := %distro-names.Map;
        %!use-targets  := %use-targets.Map;
        %!matches      := Map::Match.new: %matches;
    }

    method find-identities($name, :$ver, :$auth, :$api) {

        my sub filter(@identities) {
            my $auth-needle := $auth ?? ":auth<$auth>" !! "";
            my $api-needle  := $api && $api ne '0' ?? ":api<$api>" !! "";
            my $version;
            my &comp;
            if $ver && $ver ne '*' {
                $version := $ver.Version;
                &comp = $ver.contains("+" | "*")
                  ?? &infix:«>»
                  !! &infix:«==»;
            }

            @identities.grep: {
                (!$auth-needle || .contains($auth-needle))
                  &&
                (!$api-needle || .contains($api-needle))
                  && 
                (!&comp || comp(.&version, $version))
            }
        }

        if %!matches{$name}.map(*.Slip).unique -> @identities {
            sort-identities filter @identities
        }
    }
}

=begin pod

=head1 NAME

Ecosystem - Accessing a Raku Ecosystem

=head1 SYNOPSIS

=begin code :lang<raku>

use Ecosystem;

my $ec = Ecosystem.new;  # access the REA ecosystem

say "Ecosystem has $ec.identities.elems() identities:";
.say for $ec.identities.keys.sort;

=end code

=head1 DESCRIPTION

Ecosystem provides the basic logic to accessing a Raku Ecosystem,
defaulting to the Raku Ecosystem Archive, a place where (almost) every
distribution ever available in the Raku Ecosystem, can be obtained
even after it has been removed (specifically in the case of the old
ecosystem master list and the distributions kept on CPAN).

=head1 CONSTRUCTOR ARGUMENTS

=head2 IO

=begin code :lang<raku>

my $ec = Ecosystem.new(IO => "path".IO);

=end code

The C<IO> named argument specifies the path of the file that contains
/ will contain the META information.  If not specified, will default
to whatever can be determined from the other arguments.

=head2 meta-url

=begin code :lang<raku>

my $ec = Ecosystem.new(meta-url => "https://foo.bar/META.json");

=end code

The C<meta-url> named argument specifies the URL that should be used to
obtain the META information if it is not available locally yet, or if
it has been determined to be stale.  Will default to whatever can be
determined from the other arguments.  If specified, then the C<IO>
arguments B<must> also be specified to store the meta information in.

=head2 stale-period

=begin code :lang<raku>

my $ec = Ecosystem.new(stale-period => 3600);

=end code

The C<stale-period> named argument specifies the number of seconds
after which the meta information is considered to be stale and needs
updating using the C<meta-url>.  Defaults to C<86400>, aka 1 day.

=head2 fez

=begin code :lang<raku>

my $ec = Ecosystem.new(:fez);

=end code

The C<fez> named argument is a boolean that indicates that the
C<IO> and C<meta-url> named arguments should be set to the values
needed to access the C<fez> ecosystem.  Defaults to C<False>.

=head2 rea

=begin code :lang<raku>

my $ec = Ecosystem.new(:rea);

=end code

The C<rea> named argument is a boolean that indicates that the
C<IO> and C<meta-url> named arguments should be set to the values
needed to access the Raku Ecosystem Archive.  Defaults to C<True>
if no C<fez> or C<meta-url> argument has been specified.

=head1 METHODS

=head2 distro-names

=begin code :lang<raku>

my $ec = Ecosystem.new;
say "Found $ec.distro-names.elems() differently named distributions";

=end code

The C<distro-names> method returns a C<Map> keyed on distribution
name, with a sorted list of the identities that have that distribution
name (sorted by short-name, latest version first).

=head2 find-identities

=begin code :lang<raku>

my $ec = Ecosystem.new;
.say for $ec.find-identities: / Utils /, :ver<0.0.3+>, :auth<zef:lizmat>;

=end code

The C<find-identiities> method returns identities (sorted by short-name,
latest version first) that match the given string or regular expression,
potentially filtered by C<:ver>, C<:auth> and/or C<:api> value.

=head2 identities

=begin code :lang<raku>

my $ec = Ecosystem.new;
my %identities := $ec.identities;
say "Found %identities.elems() identities";

=end code

The C<identities> method returns a C<Map> keyed on identity string,
with a C<Map> of the META information of that identity as the value.

=head2 IO

=begin code :lang<raku>

my $ec = Ecosystem.new(:IO("foobar.json").IO);
say $ec.IO;  # "foobar.json".IO

=end code

The C<IO> method returns the C<IO::Path> object of the file where the
local copy of the META data lives.

=head2 matches

=begin code :lang<raku>

my $ec = Ecosystem.new;
.say for $ec.matches{ / Utils / };

=end code

The C<matches> method returns a
L<Map::Match|https://raku.land/zef:lizmat/Map::Match> with the
string that caused addition of an identity as the key, and a
sorted list of the identities that either matched the distribution
name or the description (sorted by short-name, latest version first).
It is basically the workhorse of the L<find-identities> method.

=head2 meta

=begin code :lang<raku>

my $ec = Ecosystem.new;
say $ec.meta;  # ...

=end code

The C<meta> method returns the JSON representation of the META data.

=head2 meta-url

=begin code :lang<raku>

my $ec = Ecosystem.new(:fez);
say $ec.meta-url;  # https://360.zef.pm/

=end code

The C<meta-url> method returns the URL that is used to fetch the
META data, if any.

=head2 stale-period

=begin code :lang<raku>

my $ec = Ecosystem.new;
say $ec.stale-period;  # 86400

=end code

The C<stale-period> method returns the number of seconds after which
any locally stored META information is considered to be stale.

=head2 use-targets

=begin code :lang<raku>

my $ec = Ecosystem.new;
say "Found $ec.use-targets.elems() different 'use' targets";

=end code

The C<use-targets> method returns a C<Map> keyed on 'use' target,
with a sorted list of the identities that provide that 'use' target
(sorted by short-name, latest version first).

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Ecosystem .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
