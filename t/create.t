# create.t

use Test::Most;
use Data::Dumper::Concise;
use Module::Load qw/ load /;
use Module::Load::Conditional qw/ check_install /;

use Sort::Factory;

note "single field";

my @arr = ( { foo => 3 }, { foo => 6 }, { foo => 1 } );

ok my $s1 = create_sort( field => 'foo' ), "created sort sub";
ok my $s2 = create_sort( field => 'foo', type => 'numeric' ),
    "created sort sub - numeric";
ok my $s3 = create_sort( field => 'foo', type => 'numeric', order => 'desc' ),
    "created sort sub - numeric, descending";

is_deeply [ sort $s1 @arr ], [ { foo => 1 }, { foo => 3 }, { foo => 6 } ],
    "sorted";
is_deeply [ sort $s2 @arr ], [ { foo => 1 }, { foo => 3 }, { foo => 6 } ],
    "sorted numerically";
is_deeply [ sort $s3 @arr ], [ { foo => 6 }, { foo => 3 }, { foo => 1 } ],
    "sorted numerically, descending";

note "multiple fields";

@arr = (
    { foo => 3, bar => 'ABC' },
    { foo => 6, bar => 'GHI' },
    { foo => 1, bar => 'DEF' },
    { foo => 3, bar => 'DEF' },
);

ok my $s4 = create_sort(
    field => [ 'foo',     'bar' ],
    type  => [ 'numeric', 'string' ],
    order => [ 'asc',     'desc' ]
    ),
    "created sort sub";

is_deeply [ sort $s4 @arr ],
    [
    { foo => 1, bar => 'DEF' },
    { foo => 3, bar => 'DEF' },
    { foo => 3, bar => 'ABC' },
    { foo => 6, bar => 'GHI' }
    ],
    "sorted";

note "natural";

if ( check_install( module => 'Sort::Naturally' ) ) {

    ok my $s5 = create_sort( field => 'foo', type => 'natural' ),
        "created natural sort sub";

    @arr = map +{ foo => $_ }, qw/ aaa aaa2 aaa1 aaa2foo aaa3 a3 ab2 ab22 /;

    is_deeply [ map { $_->{foo} } sort $s5 @arr ],
        [ "aaa", "aaa1", "aaa2", "aaa2foo", "aaa3", "ab2", "ab22", "a3" ],
    "sorted naturally";

}

done_testing();

