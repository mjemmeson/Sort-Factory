#!/usr/bin/perl

use Sort::Naturally;

my $sort = sub { $a ncmp $b };

print sort $sort qw/ a b A A1 A2 B1 A2A /;

