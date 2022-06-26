[![Actions Status](https://github.com/lizmat/Ecosystem/workflows/test/badge.svg)](https://github.com/lizmat/Ecosystem/actions)

NAME
====

Ecosystem - Accessing a Raku Ecosystem

SYNOPSIS
========

```raku
use Ecosystem;

my $eco = Ecosystem.new;  # access the REA ecosystem

say "Ecosystem has $eco.identities.elems() identities:";
.say for $eco.identities.keys.sort;
```

DESCRIPTION
===========

Ecosystem provides the basic logic to accessing a Raku Ecosystem, defaulting to the Raku Ecosystem Archive, a place where (almost) every distribution ever available in the Raku Ecosystem, can be obtained even after it has been removed (specifically in the case of the old ecosystem master list and the distributions kept on CPAN).

COMMAND LINE INTERFACE
======================

An `ecosystem` CLI script is provided by the [CLI::Ecosystem](https://raku.land/zef:lizmat/CLI::Ecosystem) distribution.

CONSTRUCTOR ARGUMENTS
=====================

ecosystem
---------

```raku
my $eco = Ecosystem.new(:ecosystem<fez>);
```

The `ecosystem` named argument is string that indicates which ecosystem (content-storage) should be used: it basically is a preset for the `meta-url` and `IO` arguments. The following names are recognized:

  * p6c the original content storage / ecosystem

  * cpan the content storage that uses CPAN

  * fez the zef (fez) ecosystem

  * rea the Raku Ecosystem Archive (default)

If this argument is not specified, then at least the `IO` named argument must be specified.

IO
--

```raku
my $eco = Ecosystem.new(IO => "path".IO);
```

The `IO` named argument specifies the path of the file that contains / will contain the META information. If not specified, will default to whatever can be determined from the other arguments.

meta-url
--------

```raku
my $eco = Ecosystem.new(meta-url => "https://foo.bar/META.json");
```

The `meta-url` named argument specifies the URL that should be used to obtain the META information if it is not available locally yet, or if it has been determined to be stale. Will default to whatever can be determined from the other arguments. If specified, then the `IO` arguments **must** also be specified to store the meta information in.

stale-period
------------

```raku
my $eco = Ecosystem.new(stale-period => 3600);
```

The `stale-period` named argument specifies the number of seconds after which the meta information is considered to be stale and needs updating using the `meta-url`. Defaults to `86400`, aka 1 day.

CLASS METHODS
=============

dependencies-from-meta
----------------------

```raku
my $eco = Ecosystem.new;
.say for $eco.dependencies-from-meta(from-json $io.slurp);
```

The `dependencies-from-meta` class method returns the list of `use-targets` as specified in the `depends` field of the given hash with meta information.

sort-identities
---------------

```raku
.say for Ecosystem.sort-identities(@identities);
```

The `sort-identities` class method sorts the given identities with the highest version first, and then by the `short-name` of the identity.

INSTANCE METHODS
================

dependencies
------------

```raku
my $eco = Ecosystem.new;
.say for $eco.dependencies("Ecosystem");
```

The `dependencies` instance method returns a sorted list of all `use-target`s (either directly or recursively) for an `identity`, `use-target` or `distro-name`.

distro-names
------------

```raku
my $eco = Ecosystem.new;
say "Found $eco.distro-names.elems() differently named distributions";
```

The `distro-names` instance method returns a `Map` keyed on distribution name, with a sorted list of the identities that have that distribution name (sorted by short-name, latest version first).

distros-of-use-target
---------------------

```raku
my $eco = Ecosystem.new;
.say for $eco.distros-of-use-target($target);
```

The `distro-of-use-target` instance method the names of the distributions that provide the given use target.

ecosystem
---------

```raku
my $eco = Ecosystem.new;
say "The ecosystem is $_" with $eco.ecosystem;
```

The `ecosystem` instance method returns the value (implicitely) specified with the `:ecosystem` named argument.

find-distro-names
-----------------

```raku
my $eco = Ecosystem.new;
.say for $eco.find-distro-names: / JSON /;

.say for $eco.find-distro-names: :auth<zef:lizmat>;
```

The `find-distro-names` instance method returns the distribution names that match the optional given string or regular expression, potentially filtered by a `:ver`, `:auth`, `:api` and/or `:from` value.

find-identities
---------------

```raku
my $eco = Ecosystem.new;
.say for $eco.find-identities: / Utils /, :ver<0.0.3+>, :auth<zef:lizmat>;

.say for $eco.find-identities: :auth<zef:lizmat>, :all;
```

The `find-identities` method returns identities (sorted by short-name, latest version first) that match the optional given string or regular expression, potentially filtered by `:ver`, `:auth`, `:api` and/or `:from` value.

The specified string is looked up / regular expression is matched in the distribution names, the use-targets and the descriptions of the distributions.

By default, only the identity with the highest `:ver` value will be returned: a `:all` flag can be specified to return **all** possible identities.

find-use-targets
----------------

```raku
my $eco = Ecosystem.new;
.say for $eco.find-use-targets: / JSON /;

.say for $eco.find-use-targets: :auth<zef:lizmat>;
```

The `find-use-targets` instance method returns the strings that can be used in a `use` command that match the optional given string or regular expression, potentially filtered by a `:ver`, `:auth`, `:api` and/or `:from` value.

identities
----------

```raku
my $eco = Ecosystem.new;
my %identities := $eco.identities;
say "Found %identities.elems() identities";
```

The `identities` instance method returns a `Map` keyed on identity string, with a `Map` of the META information of that identity as the value.

identity-dependencies
---------------------

```raku
my $eco = Ecosystem.new;
.say for $eco.identity-dependencies($identity);

.say for $eco.identity-dependencies($identity, :all);
```

The `identity-dependencies` instance method returns a sorted list of the dependencies of the given **identity** string, if any. Takes an optional `:all` named to also return any dependencies of the initial dependencies, recursively.

identity-release-Date
---------------------

```raku
my $eco = Ecosystem.new;
say $eco.identity-release-Date($identity);
```

The `identity-release-Date` instance method returns the `Date` when the the distribution of the given identity string was released, or `Nil` if either the identity could not be found, or if there is no release date information available.

identity-release-yyyy-mm-dd
---------------------------

```raku
my $eco = Ecosystem.new;
say $eco.identity-release-yyyy-mm-dd($identity);
```

The `identity-release-yyyy-mm-dd` instance method returns a `Str` in YYYY-MM-DD format of when the the distribution of the given identity string was released, or `Nil` if either the identity could not be found, or if there is no release date information available.

identity-url
------------

```raku
my $eco = Ecosystem.new;
say $eco.identity-url($identity);
```

The `identity-url` instance method returns the `URL` of the distribution file associated with the given identity string, or `Nil`.

IO
--

```raku
my $eco = Ecosystem.new(:IO("foobar.json").IO);
say $eco.IO;  # "foobar.json".IO
```

The `IO` instance method returns the `IO::Path` object of the file where the local copy of the META data lives.

least-recent-release
--------------------

```raku
my $eco = Ecosystem.new;
say $eco.least-recent-release;
```

The `least-recent-release` instancemethod returns the `Date` of the least recent release in the ecosystem, if any.

matches
-------

```raku
my $eco = Ecosystem.new;
.say for $eco.matches{ / Utils / };
```

The `matches` instance method returns a [Map::Match](https://raku.land/zef:lizmat/Map::Match) with the string that caused addition of an identity as the key, and a sorted list of the identities that either matched the distribution name or the description (sorted by short-name, latest version first). It is basically the workhorse of the [find-identities](#find-identities) method.

meta
----

```raku
my $eco = Ecosystem.new;
say $eco.meta;  # ...
```

The `meta` instance method returns the JSON representation of the META data.

meta-url
--------

```raku
my $eco = Ecosystem.new(:ecosystem<fez>);
say $eco.meta-url;  # https://360.zef.pm/
```

The `meta-url` instance method returns the URL that is used to fetch the META data, if any.

most-recent-release
-------------------

```raku
my $eco = Ecosystem.new;
say $eco.most-recent-release;
```

The `most-recent-release` instance method returns the `Date` of the most recent release in the ecosystem, if any.

resolve
-------

```raku
my $eco = Ecosystem.new;
say $eco.resolve("eigenstates");  # eigenstates:ver<0.0.9>:auth<zef:lizmat>
```

The `resolve` instance method attempts to resolve the given string and the given `:ver`, `:auth`, `:api` and `:from` named arguments to the identity that would be assumed when specified with e.g. `dependencies`.

reverse-dependencies
--------------------

```raku
my $eco = Ecosystem.new;
my %reverse-dependencies := $eco.reverse-dependencies;
say "Found %reverse-dependencies.elems() reverse dependencies";
```

The `reverse-dependencies` instance method returns a `Map` keyed on resolved dependencies, with a list of identities that depend on it.

reverse-dependencies-for-short-name
-----------------------------------

```raku
my $eco = Ecosystem.new;
.say for $eco.reverse-dependencies-for-short-name("File::Temp");
```

The `reverse-dependencies-for-short-name` instance method returns a unique list of short-names of identities that depend on any version of the given short-name.

river
-----

```raku
my $eco = Ecosystem.new;
say "Top five modules on the Raku Ecosystem River:";
.say for $eco.river.sort(-*.value.elems).map(*.key).head(5);
```

The `river` instance method returns a `Map` keyed on short-name of an identity, with as value a list of short-names of identities that depend on it **without** having pinned `:ver` and `:auth` in their dependency specification.

stale-period
------------

```raku
my $eco = Ecosystem.new;
say $eco.stale-period;  # 86400
```

The `stale-period` instance method returns the number of seconds after which any locally stored META information is considered to be stale.

update
------

```raku
my $eco = Ecosystem.new;
$eco.update;
```

The `update` instance method re-fetches the META information from the `meta-url` and updates it internal state in a thread-safe manner.

unresolvable-dependencies
-------------------------

```raku
my $eco = Ecosystem.new;
say "Found $eco.unresolvable-dependencies.elems() unresolvable dependencies";
```

The `unresolvable-dependencies` instance method returns a `Map` keyed on an unresolved dependency, and a `List` of identities that have this unresolvable dependency as the value. By default, only current (as in the most recent version) identities will be in the list. You can specify the named `:all` argument to have also have the non-current identities listed.

unversioned-distros
-------------------

```raku
my $eco = Ecosystem.new;
say "Found $eco.unversioned-distro-names.elems() unversioned distributions";
```

The `unversioned-distro-names` instance method returns a sorted list of distribution names (identity without `:ver`) that do not have any release with a valid `:ver` value (typically **:ver<*>**).

use-targets
-----------

```raku
my $eco = Ecosystem.new;
say "Found $eco.use-targets.elems() different 'use' targets";
```

The `use-targets` instance method returns a `Map` keyed on 'use' target, with a sorted list of the identities that provide that 'use' target (sorted by short-name, latest version first).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Ecosystem . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

