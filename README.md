[![Actions Status](https://github.com/lizmat/Ecosystem/workflows/test/badge.svg)](https://github.com/lizmat/Ecosystem/actions)

NAME
====

Ecosystem - Accessing a Raku Ecosystem

SYNOPSIS
========

```raku
use Ecosystem;

my $ec = Ecosystem.new;  # access the REA ecosystem

say "Ecosystem has $ec.identities.elems() identities:";
.say for $ec.identities.keys.sort;
```

DESCRIPTION
===========

Ecosystem provides the basic logic to accessing a Raku Ecosystem, defaulting to the Raku Ecosystem Archive, a place where (almost) every distribution ever available in the Raku Ecosystem, can be obtained even after it has been removed (specifically in the case of the old ecosystem master list and the distributions kept on CPAN).

CONSTRUCTOR ARGUMENTS
=====================

IO
--

```raku
my $ec = Ecosystem.new(IO => "path".IO);
```

The `IO` named argument specifies the path of the file that contains / will contain the META information. If not specified, will default to whatever can be determined from the other arguments.

meta-url
--------

```raku
my $ec = Ecosystem.new(meta-url => "https://foo.bar/META.json");
```

The `meta-url` named argument specifies the URL that should be used to obtain the META information if it is not available locally yet, or if it has been determined to be stale. Will default to whatever can be determined from the other arguments. If specified, then the `IO` arguments **must** also be specified to store the meta information in.

stale-period
------------

```raku
my $ec = Ecosystem.new(stale-period => 3600);
```

The `stale-period` named argument specifies the number of seconds after which the meta information is considered to be stale and needs updating using the `meta-url`. Defaults to `86400`, aka 1 day.

fez
---

```raku
my $ec = Ecosystem.new(:fez);
```

The `fez` named argument is a boolean that indicates that the `IO` and `meta-url` named arguments should be set to the values needed to access the `fez` ecosystem. Defaults to `False`.

rea
---

```raku
my $ec = Ecosystem.new(:rea);
```

The `rea` named argument is a boolean that indicates that the `IO` and `meta-url` named arguments should be set to the values needed to access the Raku Ecosystem Archive. Defaults to `True` if no `fez` or `meta-url` argument has been specified.

METHODS
=======

distro-names
------------

```raku
my $ec = Ecosystem.new;
say "Found $ec.distro-names.elems() differently named distributions";
```

The `distro-names` method returns a `Map` keyed on distribution name, with a sorted list of the identities that have that distribution name (sorted by short-name, latest version first).

find-identities
---------------

```raku
my $ec = Ecosystem.new;
.say for $ec.find-identities: / Utils /, :ver<0.0.3+>, :auth<zef:lizmat>;
```

The `find-identiities` method returns identities (sorted by short-name, latest version first) that match the given string or regular expression, potentially filtered by `:ver`, `:auth` and/or `:api` value.

identities
----------

```raku
my $ec = Ecosystem.new;
my %identities := $ec.identities;
say "Found %identities.elems() identities";
```

The `identities` method returns a `Map` keyed on identity string, with a `Map` of the META information of that identity as the value.

IO
--

```raku
my $ec = Ecosystem.new(:IO("foobar.json").IO);
say $ec.IO;  # "foobar.json".IO
```

The `IO` method returns the `IO::Path` object of the file where the local copy of the META data lives.

matches
-------

```raku
my $ec = Ecosystem.new;
.say for $ec.matches{ / Utils / };
```

The `matches` method returns a [Map::Match](https://raku.land/zef:lizmat/Map::Match) with the string that caused addition of an identity as the key, and a sorted list of the identities that either matched the distribution name or the description (sorted by short-name, latest version first). It is basically the workhorse of the [find-identities](#find-identities) method.

meta
----

```raku
my $ec = Ecosystem.new;
say $ec.meta;  # ...
```

The `meta` method returns the JSON representation of the META data.

meta-url
--------

```raku
my $ec = Ecosystem.new(:fez);
say $ec.meta-url;  # https://360.zef.pm/
```

The `meta-url` method returns the URL that is used to fetch the META data, if any.

stale-period
------------

```raku
my $ec = Ecosystem.new;
say $ec.stale-period;  # 86400
```

The `stale-period` method returns the number of seconds after which any locally stored META information is considered to be stale.

use-targets
-----------

```raku
my $ec = Ecosystem.new;
say "Found $ec.use-targets.elems() different 'use' targets";
```

The `use-targets` method returns a `Map` keyed on 'use' target, with a sorted list of the identities that provide that 'use' target (sorted by short-name, latest version first).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Ecosystem . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

