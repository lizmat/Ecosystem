use JSON::Fast::Hyper:ver<0.0.9+>:auth<zef:lizmat>;
use Identity::Utils:ver<0.0.11+>:auth<zef:lizmat>;
use Rakudo::CORE::META:ver<0.0.5+>:auth<zef:lizmat>;
use Map::Match:ver<0.0.7+>:auth<zef:lizmat>;

constant %meta-url = do {
    my %hash =
      p6c  => "https://raw.githubusercontent.com/ugexe/Perl6-ecosystems/master/p6c1.json",
      cpan => "https://raw.githubusercontent.com/ugexe/Perl6-ecosystems/master/cpan1.json",
      fez  => "https://360.zef.pm/",
      rea  => "https://raw.githubusercontent.com/Raku/REA/main/META.json",
    ;
    .<zef> := .<fez> with %hash;
    %hash
}

my constant %longname = do {
    my %hash =
      rea  => 'Raku Ecosystem Archive',
      fez  => 'Zef (Fez) Ecosystem Content Storage',
      p6c  => 'Original Git Ecosystem Storage',
      cpan => 'CPAN (PAUSE) Ecosystem Storage',
    ;
    .<zef> := .<fez> with %hash;
    %hash
}

my $store := ($*HOME // $*TMPDIR).add(".zef").add("store");

class Ecosystem {
    has IO::Path $.IO;
    has Str $.meta-url;
    has Int $.stale-period is built(:bind) = 86400;
    has str $.ecosystem is built(False);
    has str $.longname;
    has str $.meta      is built(False);
    has %.identities    is built(False);
    has %.distro-names  is built(False);
    has %.use-targets   is built(False);
    has %.release-dates is built(False);
    has %.authors       is built(False);
    has %.auths         is built(False);
    has %.tags          is built(False);
    has $!matches;
    has $!reverse-dependencies;
    has $!all-unresolvable-dependencies;
    has $!current-unresolvable-dependencies;
    has $!river;
    has Date $!least-recent-release;
    has Date $!most-recent-release;
    has Lock $!meta-lock;

    submethod TWEAK(Str:D :$ecosystem = 'rea') {
        without $!meta-url {
            if %meta-url{$ecosystem} -> $url {
                $!meta-url := $url;
                $!IO       := $store.add($ecosystem).add("$ecosystem.json");
                $!ecosystem = $ecosystem;
            }
            else {
                die "Unknown ecosystem: $ecosystem";
            }
        }

        $!IO
          ?? mkdir($!IO.parent)
          !! die "Must specify IO with a specified meta-url";

        $!meta-lock := Lock.new;
        self!stale
          ?? self!update-meta-from-URL
          !! self!update-meta-from-json($!IO.slurp);

        $!longname = %longname{$ecosystem} // $ecosystem;
    }

    method !stale() {
        $!IO.e
          ?? $!meta-url && now - $!IO.modified > $!stale-period
          !! True
    }

    method !update-meta-from-URL() {
        $!meta-lock.protect: {
            my $proc := run 'curl', $!meta-url, :out, :!err;
            self!update-meta-from-json: $proc.out.slurp;
            $!IO.spurt: $!meta;
        }
    }

    my sub add-identity(%hash, str $key, str $identity) {
        if %hash{$key} -> @identities {
            @identities.push($identity)
        }
        else {
            %hash{$key} := (my str @ = $identity);
        }
    }

    my sub sort-identities(@identities) {
        @identities.sort({ version($_) // "" }).reverse.sort: {
            short-name($_).fc
        }
    }

    my sub sort-identities-of-hash(%hash) {
        for %hash.kv -> $key, @identities {
            %hash{$key} := my str @ =
              @identities.unique.sort(&version).reverse.sort(&short-name);
        }
    }

    my constant @extensions = <.tar.gz .tgz .zip>;
    my sub no-extension(Str:D $string) {
        return $string.chop(.chars) if $string.ends-with($_) for @extensions;
    }
    my sub extension(Str:D $string) {
        @extensions.first: { $string.ends-with($_) }
    }
    my sub determine-base($domain) {
        $domain
          ?? $domain eq 'raw.githubusercontent.com' | 'github.com'
            ?? 'github'
            !! $domain eq 'gitlab.com'
              ?? 'gitlab'
              !! Nil
          !! Nil
    }

    # Version encoded in path has priority over version in META because
    # PAUSE would not allow uploads of the same version encoded in the
    # distribution name, but it *would* allow uploads with a non-matching
    # version in the META.  Also make sure we skip any "v" in the version
    # string.
    method !elide-identity-cpan(str $name, %meta) {
# http://www.cpan.org/authors/id/Y/YN/YNOTO/Perl6/json-path-0.1.tar.gz
# git://github.com/Tux/CSV.git
        if %meta<source-url> -> $URL {
            my @parts = $URL.split('/');
            my $auth := %meta<auth> :=
              'cpan:' ~ @parts[2] ne 'www.cpan.org'
                ?? @parts[3].uc
                !! @parts[7];

            # Determine version from filename
            my $nept := no-extension(@parts.tail);
            with $nept && $nept.rindex('-') -> $index {
                my $ver := $nept.substr($index + 1);
                $ver := $ver.substr(1)
                  if $ver.starts-with('v');

                # keep version in meta if strange in filename
                $ver.contains(/ <-[\d \.]> /)
                  ?? ($ver := %meta<version>)
                  !! (%meta<version> := $ver);

                %meta<dist> :=
                  build $name, :$ver, :$auth, :api(%meta<api>)
            }

            # Assume version in meta is correct
            elsif %meta<version> -> $ver {
                %meta<dist> :=
                  build $name, :$ver, :$auth, :api(%meta<api>)
            }
        }
    }

    # Heuristics for determining identity of a distribution on p6c
    # that does not provide an identity directly
    method !elide-identity-p6c(str $name, %meta) {
        if !$name.contains(' ')
          && %meta<version> -> $ver {
            if %meta<source-url> -> $URL {
                my @parts = $URL.split('/');
                if determine-base(@parts[2]) -> $base {
                    my $user := @parts[3];
                    unless $user eq 'AlexDaniel'
                      and @parts.tail.contains('foo') {
                        my $auth := %meta<auth> := "$base:$user";
                        %meta<dist> :=
                          build $name, :$ver, :$auth, :api(%meta<api>)
                    }
                }
            }
        }
    }

    method !elide-identity(str $name, %meta) {
        $!ecosystem eq 'cpan'
          ?? self!elide-identity-cpan($name, %meta)
          !! $!ecosystem eq 'p6c'
            ?? self!elide-identity-p6c($name, %meta)
            !! die "Cannot elide identity of '$name' in '$!ecosystem'";
    }

    method !update-meta-from-json($!meta --> Nil) {
        my %identities;
        my %distro-names;
        my %use-targets;
        my %descriptions;
        my %authors;
        my %auths;
        my %tags;
        my %release-dates;

        with %Rakudo::CORE::META -> %meta {
            my $name     := %meta<name>;
            my $identity := %meta<dist>;

            %identities{$identity} := %meta.Map;
            add-identity %distro-names, $name, $identity;
            add-identity %use-targets,  $_,    $identity
              for %meta<provides>.keys;
        }

        for from-json($!meta) -> %meta {
            if %meta<name> -> $name {
                if %meta<dist>
                  // self!elide-identity($name, %meta) -> $identity {
                    %identities{$identity} := %meta;
                    add-identity %distro-names, $name, $identity;

                    if %meta<provides> -> %provides {
                        add-identity %use-targets, $_, $identity
                          for %provides.keys;
                    }
                    if %meta<author> -> $author {
                        add-identity %authors, $_, $identity for $author<>;
                    }
                    if %meta<authors> -> $authors {
                        add-identity %authors, $_, $identity for $authors<>;
                    }
                    if %meta<auth> -> $auth {
                        add-identity %auths, $auth, $identity;
                    }
                    if %meta<tags> -> $tags {
                        add-identity %tags, .uc, $identity for $tags<>;
                    }
                    if %meta<release-date> -> $release-date {
                        add-identity %release-dates, $release-date, $identity;
                    }
                }
            }
        }

        if $!ecosystem ne 'rea' {
            for %distro-names, %use-targets -> %hash {
                sort-identities-of-hash %hash;
            }
        }

        %!identities    := %identities.Map;
        %!distro-names  := %distro-names.Map;
        %!use-targets   := %use-targets.Map;
        %!release-dates := Map::Match.new(%release-dates);
        %!auths         := Map::Match.new(%auths);
        %!authors       := Map::Match.new(%authors);
        %!tags          := Map::Match.new(%tags);

        # reset all dependent data structures
        $!least-recent-release = $!most-recent-release = Nil;
        $!matches
          := $!reverse-dependencies
          := $!all-unresolvable-dependencies
          := $!current-unresolvable-dependencies
          := $!river
          := Any;
    }

    my sub filter(@identities, $ver, $auth, $api, $from) {
        my $auth-needle := $auth ?? ":auth<$auth>" !! "";
        my $api-needle  := $api && $api ne '0'
          ?? ":api<$api>"
          !! "";
        my $from-needle := $from && !($from eq 'Perl6' | 'Raku')
          ?? ":from<$from>"
          !! "";
        my $version;
        my &ver-matches;
        if $ver {
            if $ver eq '*' {
                &ver-matches = { ver($_) eq "*" }
            }
            else {
                $version := $ver.Version;  # could be a noop
                &ver-matches = $version.plus || $version.whatever
                  ?? { version($_) ~~ $version }
                  !! { version($_) == $version }
            }
        }
        else {
            my $version := '0.0.1+'.Version;
            &ver-matches = { version($_) ~~ $version }
        }

        @identities.grep: {
            (!$from-needle || .contains($from-needle))
              &&
            (!$api-needle  || .contains($api-needle))
              &&
            (!$auth-needle || .contains($auth-needle))
              &&
            (!&ver-matches || ver-matches($_))
        }
    }

    method find-identities(Ecosystem:D:
      Any:D $needle = "", :$ver, :$auth, :$api, :$from, :$all
    ) {
        if filter($needle ~~ Regex || $needle
                    ?? self.matches{$needle}.map(*.Slip).unique
                    !! %!identities.keys,
                  $ver, $auth, $api, $from) -> @identities {
            my %seen;
            sort-identities $all
              ?? @identities
              !! @identities.map: { $_ unless %seen{short-name($_)}++ }
        }
    }

    method find-no-tags(Ecosystem:D:
      Any:D $needle = "", :$ver, :$auth, :$api, :$from, :$all
    ) {
        my %identities := %!identities;
        if filter($needle ~~ Regex || $needle
                    ?? self.matches{$needle}.map(*.Slip).unique
                    !! %identities.keys,
                  $ver, $auth, $api, $from) -> @identities {
            my %seen;
            sort-identities @identities.grep: $all
              ?? { !%identities{$_}<tags> }
              !! { !%seen{short-name $_}++ && !%identities{$_}<tags> }
        }
    }

    method find-distro-names(Ecosystem:D: Any:D $needle = "", *%_) {
        my &accepts := $needle ~~ Regex
          ?? -> $name { $needle.ACCEPTS($name) }
          !! $needle
            ?? -> $name { $name.contains($needle, :i, :m) }
            !! -> $name { True }

        my %seen;
        self.find-identities($needle, |%_, :all).map: {
            with %!identities{$_}<name> -> $name {
                $name if accepts($name) && not %seen{$name}++
            }
        }
    }

    method find-use-targets(Ecosystem:D: Any:D $needle = "", *%_) {
        my &accepts := $needle ~~ Regex
          ?? -> $use-target { $needle.ACCEPTS($use-target) }
          !! $needle
            ?? -> $use-target { $use-target.contains($needle, :i, :m) }
            !! -> $use-target { True }

        my %seen;
        self.find-identities($needle, |%_, :all).map: {
            with %!identities{$_}<provides> -> %provides {
                %provides.keys.first( -> $use-target {
                    accepts($use-target) && not %seen{$use-target}++
                }) // Empty
            }
        }
    }

    method identity-url(Ecosystem:D: str $identity) {
        %!identities{$identity}<source-url>
    }

    method identity-release-Date(Ecosystem:D: str $identity) {
        %!identities{$identity}<release-date>.Date
    }
    method identity-release-yyyy-mm-dd(Ecosystem:D: str $identity) {
        %!identities{$identity}<release-date>
    }
    method identity-dependencies(Ecosystem:D: str $identity, :$all) {
        if %!identities{$identity} -> %meta {
            ($all
              ?? self!dependencies($identity).unique
              !! dependencies-from-depends(%meta<depends>)
            ).sort(*.fc)
        }
    }

    my sub identities2distros(@identities) {
        my %seen;
        @identities.map: {
            if short-name($_) -> $name {
                $name unless %seen{$name}++
            }
        }
    }

    method distros-of-use-target(str $target) {
        if %!use-targets{$target} -> @identities {
            identities2distros(@identities)
        }
    }

    method !minmax-release-dates(--> Nil) {
        $!meta-lock.protect: {
            my $range := %!identities.values.map( -> %_ {
                $_ with %_<release-date>
            }).minmax;
            if $range.min ~~ Str {
                $!least-recent-release = $range.min.Date;
                $!most-recent-release  = $range.max.Date;
            }
        }
    }

    method least-recent-release() {
        $!least-recent-release
          // self!minmax-release-dates
          // $!least-recent-release

    }

    method most-recent-release() {
        $!most-recent-release
          // self!minmax-release-dates
          // $!most-recent-release
    }

    method update() {
        $!meta-url
          ?? self!update-meta-from-URL
          !! self!update-meta-from-json  # assumes it was changed
    }

    my sub as-short-name(str $needle) {
        $needle eq short-name($needle)
          ?? Nil
          !! short-name($needle)
    }

    my multi sub dependencies-from-depends(Any:U $) { Empty }
    my multi sub dependencies-from-depends(Any:D $depends) {
        if $depends ~~ Positional {
            $depends.grep({ $_ ~~ Str })
        }
        elsif $depends ~~ Associative {
            if $depends<runtime><requires> -> $requires {
                $requires.map: {
                    $_ ~~ Associative
                      ?? build .<name> // '',
                           :ver(.<ver>), :auth(.<auth>),
                           :api(.<api>), :from(.<from>)
                      !! $_
                } if $requires ~~ Positional;
            }
        }
        elsif $depends ~~ Str {
            $depends
        }
    }

    method !dependencies(str $needle) {
        if %!identities{$needle} -> %meta {
            dependencies-from-depends(%meta<depends>).map( -> str $found {
                ($found, self!dependencies($found).Slip).Slip
                  if $found ne $needle
            }).Slip
        }
        elsif %!use-targets{$needle} -> @identities {
            self!dependencies(@identities.head)
        }
        elsif %!distro-names{$needle} -> @identities {
            self!dependencies(@identities.head)
        }
        elsif as-short-name($needle) -> $short-name {
            self!dependencies($short-name)
        }
    }

    method dependencies(Ecosystem:D: str $needle) {
        self!dependencies($needle).unique.sort(*.fc)
    }

    method resolve(Ecosystem:D:
      str $needle,
         :$ver  = ver($needle),
         :$auth = auth($needle),
         :$api  = api($needle),
         :$from = from($needle),
    ) {
        my str $short-name = short-name($needle);
        if %!distro-names{$short-name}
          // %!use-targets{$short-name} -> @identities {
            filter(@identities, $ver, $auth, $api, $from).head
        }
        else {
            Nil
        }
    }

    method reverse-dependencies(Ecosystem:D:) {
        $!reverse-dependencies // $!meta-lock.protect: {

            # done if other thread already updated
            return $!reverse-dependencies if $!reverse-dependencies;

            my %reverse-dependencies;
            for %!identities
              .keys
              .race
              .map( -> $identity {
                self.dependencies($identity).map({$_ => $identity }).Slip
            }) {
                if %reverse-dependencies{.key} -> @found {
                    @found.push: .value;
                }
                else {
                    %reverse-dependencies{.key} := my str @ = .value;
                }
            }

            sort-identities-of-hash %reverse-dependencies;

            $!reverse-dependencies := %reverse-dependencies;
        }
    }

    method reverse-dependencies-for-short-name(Ecosystem:D: str $short-name) {
        self.reverse-dependencies.race.map({
            if short-name(.key) eq $short-name {
                .value.map(*.&short-name).squish.Slip
            }
        }).unique
    }

    method most-recent-identity(Ecosystem:D: str $needle) {
        my str $short-name = short-name($needle);
        if %!distro-names{$short-name}
          // %!use-targets{$short-name} -> @identities {
            @identities.grep({short-name($_) eq $short-name}).head // $needle
        }
        else {
            Nil
        }
    }

    method !all-unresolvable-dependencies() {
        $!all-unresolvable-dependencies // $!meta-lock.protect: {
            $!all-unresolvable-dependencies // do {
                my %id := %!identities;
                my %unr is Map = self.reverse-dependencies.grep: {
                    %id{.key}:!exists
                }
                $!all-unresolvable-dependencies := %unr
            }
        }
    }

    method !current-unresolvable-dependencies() {
        $!current-unresolvable-dependencies // $!meta-lock.protect: {
            $!current-unresolvable-dependencies // do {
                my %unr is Map = self!all-unresolvable-dependencies.map: {
                    if .value.map({
                        self.most-recent-identity($_)
                    }).unique -> @identities {
                        .key => (my str @ = @identities)
                    }
                }
                $!current-unresolvable-dependencies := %unr
            }
        }
    }

    method unresolvable-dependencies(Ecosystem:D: :$all) {
        $all
          ?? self!all-unresolvable-dependencies
          !! self!current-unresolvable-dependencies
    }

    method matches(Ecosystem:D:) {
        $!matches // $!meta-lock.protect: {
            $!matches // do {
                my %matches;
                for %!distro-names, %!use-targets -> %hash {
                    for %hash.kv -> str $key, @additional {
                        if %matches{$key} -> @strings {
                            @strings.append: @additional
                        }
                        else {
                            %matches{$key} := (my str @ = @additional);
                        }
                    }
                }
                for %!identities.kv -> $identity, %meta {
                    if %meta<description> -> $text {
                        if %matches{$identity} -> @strings {
                            @strings.push: $text
                        }
                        else {
                            %matches{$identity} := (my str @ = $text);
                        }
                    }
                }
                $!matches := Map::Match.new: %matches;
            }
        }
    }

    method river(Ecosystem:D:) {
        $!river // $!meta-lock.protect: {
            $!river // do {
                my %river;
                for %!identities.keys.race.map( -> $identity {
                    my $short-name := short-name $identity;
                    self.dependencies($identity).map({
                        short-name($_) unless is-pinned($_)
                    }).squish.map({
                        $_ => $short-name
                    }).Slip
                }) -> (:key($dependency), :value($dependee)) {
                    with %river{$dependency} {
                        .push: $dependee;
                    }
                    else {
                        %river{$dependency} := my str @ = $dependee;
                    }
                }
                for %river.kv -> $short-name, @dependees {
                    %river{$short-name} :=
                      my str @ = @dependees.unique.sort(*.fc)
                }

                $!river := %river.Map
            }
        }
    }

    # Provide interface method so that callers don't need to do an
    # an additional () to get the Map::Match object
    multi method authors()         { %!authors           }
    multi method authors(|c)       { %!authors(|c)       }
    multi method auths()           { %!auths             }
    multi method auths(|c)         { %!auths(|c)         }
    multi method release-dates()   { %!release-dates     }
    multi method release-dates(|c) { %!release-dates(|c) }
    multi method tags()            { %!tags              }
    multi method tags(|c)          { %!tags(|c)          }

    method unversioned-distro-names(Ecosystem:D:) {
        %!identities.keys.grep({
            version($_).whatever
              && version(self.resolve(without-ver($_))).whatever
        }).sort(*.fc)
    }

    # Give CLI access to rendering using whatever JSON::Fast we have
    method to-json(Ecosystem: \data) is implementation-detail {
        use JSON::Fast;
        to-json data, :sorted-keys
    }

    method dependencies-from-meta(Ecosystem: %meta) {
        dependencies-from-depends(%meta<depends>).Slip
    }

    method sort-identities(Ecosystem: @identities) {
        sort-identities @identities
    }
}

# vim: expandtab shiftwidth=4
