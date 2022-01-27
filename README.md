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

The `ecosystem` script provides a direct way to interrogate the contents of a given eco-system. Please see the usage information of the script for further information.

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

INSTANCE METHODS
================

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
```

The `find-distro-names` instance method returns the distribution names that match the given string or regular expression, potentially filtered by `:ver`, `:auth`, `:api` and/or `:from` value.

find-identities
---------------

```raku
my $eco = Ecosystem.new;
.say for $eco.find-identities: / Utils /, :ver<0.0.3+>, :auth<zef:lizmat>;
```

The `find-identities` method returns identities (sorted by short-name, latest version first) that match the given string or regular expression, potentially filtered by `:ver`, `:auth`, `:api` and/or `:from` value.

The specified string is looked up in the distribution names, the use-targets and the descriptions of the distributions.

find-use-targets
----------------

```raku
my $eco = Ecosystem.new;
.say for $eco.find-use-targets: / JSON /;
```

The `find-use-targets` instance method returns the strings that can be used in a `use` command that match the given string or regular expression, potentially filtered by `:ver`, `:auth`, `:api` and/or `:from` value.

identities
----------

```raku
my $eco = Ecosystem.new;
my %identities := $eco.identities;
say "Found %identities.elems() identities";
```

The `identities` instance method returns a `Map` keyed on identity string, with a `Map` of the META information of that identity as the value.

identity-url
------------

```raku
my $eco = Ecosystem.new;
say $eco.identity-url($identity);
```

The `identity-url` instance method returns a `Map` keyed on identity string, with a `Map` of the META information of that identity as the value.

IO
--

```raku
my $eco = Ecosystem.new(:IO("foobar.json").IO);
say $eco.IO;  # "foobar.json".IO
```

The `IO` instance method returns the `IO::Path` object of the file where the local copy of the META data lives.

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

The `meta` method returns the JSON representation of the META data.

meta-url
--------

```raku
my $eco = Ecosystem.new(:ecosystem<fez>);
say $eco.meta-url;  # https://360.zef.pm/
```

The `meta-url` method returns the URL that is used to fetch the META data, if any.

stale-period
------------

```raku
my $eco = Ecosystem.new;
say $eco.stale-period;  # 86400
```

The `stale-period` method returns the number of seconds after which any locally stored META information is considered to be stale.

use-targets
-----------

```raku
my $eco = Ecosystem.new;
say "Found $eco.use-targets.elems() different 'use' targets";
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

