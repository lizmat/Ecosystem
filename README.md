[![Actions Status](https://github.com/lizmat/Ecosystem-Archive/workflows/test/badge.svg)](https://github.com/lizmat/Ecosystem-Archive/actions)

NAME
====

Ecosystem::Archive - Accessing the Raku Ecosystem Archive

SYNOPSIS
========

```raku
use Ecosystem::Archive;

my $ea = Ecosystem::Archive.new(
  http-client => default-http-client
);

say "Archive has $ea.meta.elems() identities:";
.say for $ea.meta.keys.sort;
```

DESCRIPTION
===========

Ecosystem::Archive provides the basic logic to accessing the Raku Ecosystem Archive, a place where (almost) every distribution ever available in the Raku Ecosystem, can be obtained even after it has been removed (specifically in the case of the old ecosystem master list and the distributions kept on CPAN).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Ecosystem-Archive . Comments and Pull Requests are welcome.

COPYRIGHT AND LICENSE
=====================

Copyright 2021, 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

