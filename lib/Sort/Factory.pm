use strict;
use warnings;
package Sort::Factory;

use base 'Exporter';

use Module::Load qw/ load /;
use Module::Load::Conditional qw/ check_install /;
use Params::Validate qw/ validate SCALAR ARRAYREF HASHREF /;

our @EXPORT = qw/ create_sort /;

my %operators = (
    string  => '%s cmp %s',
    numeric => '%s <=> %s',
);

if ( check_install( module => 'Sort::Naturally') ) {
    $operators{natural} = 'Sort::Naturally::ncmp( %s, %s )';
}



=head1 SYNOPSIS

    my $sort_fn = create_sort(
        field => 'foo',
        order => 'asc',             # default
        type  => 'alphanumeric',    # default
    );

    my $sort_fn = create_sort(
        field => 'bar',
        order => 'desc',
        type  => 'numeric',
    );

    my $sort_fn = create_sort(
        field => [ 'foo',          'bar' ],
        order => [ 'asc',          'desc' ],
        type  => [ 'alphanumeric', 'numeric' ],
    );

    my $sort_fn = create_sort(
        field => [ 'foo', 'bar' ],
        order => 'asc',   # apply to all
        type => 'alphanumeric',    # apply to all
    );

    # precompute expensive operations - adds temp key with value returned
    # from sub
    my $sort_fn = create_sort(
        field => 'blah',
        precompute => { blah => sub { ... } },
    );

);

=head2 create_sort


=cut

use vars qw/ $a $b /;

sub create_sort {
    my %args = validate(
        @_,
        {   field      => { type => SCALAR | ARRAYREF },
            order      => { type => SCALAR | ARRAYREF, default => 'asc' },
            type       => { type => SCALAR | ARRAYREF, default => 'string' },
            precompute => { type => HASHREF, optional => 1 },
        }
    );

    my @fields = ref $args{field} ? @{ $args{field} } : ( $args{field} );

    my @orders
        = ref $args{order} ? @{ $args{order} } : ( $args{order} ) x @fields;
    my @types    #
        = ref $args{type} ? @{ $args{type} } : ( $args{type} ) x @fields;

    my $use_natural = grep { $_ eq 'natural' } @types;

warn $use_natural;

    my @clauses = map {
        _build_clause(
            $_,    #
            shift @orders || 'asc',     #
            shift @types  || 'string'
        );
    } @fields;

    my $pkg = caller();

    my $sub_tmpl = q!
package %s;
%s
$sub = sub { %s }
!;

    my $sort_str = sprintf( $sub_tmpl,
        $pkg,
        $use_natural ? 'require Sort::Naturally;' : '',
        join( ' || ', @clauses ) );

    warn $sort_str;
    my $sub;
    eval $sort_str;
    die $@ if $@;

    return $sub;
}


sub _build_clause {
    my ( $field, $order, $type ) = @_;

    my $operator = $operators{$type} or die "Invalid type: '$type'";

    my @vars = lc $order eq 'asc' ? ( '$a', '$b' ) : ( '$b', '$a' );

    return
        sprintf( $operator, $vars[0] . "->{$field}", $vars[1] . "->{$field}" );
}

1;

__END__

sub ncmp {
    my ( $x, $x2, $y, $y2, $rv );    # scratch vars

    if ( $a eq $b ) {                # trap this expensive case
        0;

    } else {

        # TODO allow overwrite of lc

        $x = lc($a);                 # ( $lc ? $lc->($a) : lc($a) );
        $x =~ s/\W+//s;
        $y = lc($b);                 #( $lc ? $lc->($b) : lc($b) );
        $y =~ s/\W+//s;

        if ( $x eq $y ) {

            # trap this expensive case first, and then fall thru to tiebreaker
            $rv = 0;

            # Convoluted hack to get numerics to sort first, at string start:
        } elsif ( $x =~ m/^\d/s ) {

            if ( $y =~ m/^\d/s ) {
                $rv = 0;    # fall thru to normal comparison for the two numbers
            } else {
                $rv = X_FIRST;
                DEBUG > 1
                    and print "Numeric-initial $x trumps letter-initial $y\n";
            }
        } elsif ( $y =~ m/^\d/s ) {
            $rv = Y_FIRST;
            DEBUG > 1 and print "Numeric-initial $y trumps letter-initial $x\n";
        } else {
            $rv = 0;
        }

        unless ($rv) {

            # Normal case:
            $rv = 0;
            DEBUG and print "<$x> and <$y> compared...\n";

        Consideration:
            while ( length $x and length $y ) {

                DEBUG > 2 and print " <$x> and <$y>...\n";

                # First, non-numeric comparison:
                $x2 = ( $x =~ m/^(\D+)/s ) ? length($1) : 0;
                $y2 = ( $y =~ m/^(\D+)/s ) ? length($1) : 0;

                # Now make x2 the min length of the two:
                $x2 = $y2 if $x2 > $y2;
                if ($x2) {
                    DEBUG > 1
                        and printf
                        " <%s> and <%s> lexically for length $x2...\n",
                        substr( $x, 0, $x2 ), substr( $y, 0, $x2 );
                    do {
                        my $i = substr( $x, 0, $x2 );
                        my $j = substr( $y, 0, $x2 );
                        my $sv = $i cmp $j;
                        print "SCREAM! on <$i><$j> -- $sv != $rv \n"
                            unless $rv == $sv;
                        last;
                        }

                        if $rv =

                  # The ''. things here force a copy that seems to work around a
                  #  mysterious intermittent bug that 'use locale' provokes in
                  #  many versions of Perl.
                        $cmp
                        ? $cmp->(
                        substr( $x, 0, $x2 ) . '',
                        substr( $y, 0, $x2 ) . '',
                        )
                        : scalar( ( substr( $x, 0, $x2 ) . '' )
                            cmp( substr( $y, 0, $x2 ) . '' ) );

                    # otherwise trim and keep going:
                    substr( $x, 0, $x2 ) = '';
                    substr( $y, 0, $x2 ) = '';
                }

                # Now numeric:
                #  (actually just using $x2 and $y2 as scratch)

                if ( $x =~ s/^(\d+)//s ) {
                    $x2 = $1;
                    if ( $y =~ s/^(\d+)//s ) {

                        # We have two numbers here.
                        DEBUG > 1 and print " <$x2> and <$1> numerically\n";
                        if (    length($x2) < MAX_INT_SIZE
                            and length($1) < MAX_INT_SIZE )
                        {
                            # small numbers: we can compare happily
                            last if $rv = $x2 <=> $1;
                        } else {

                            # ARBITRARILY large integers!

                            # This saves on loss of precision that could happen
                            #  with actual stringification.
                            # Also, I sense that very large numbers aren't too
                            #  terribly common in sort data.

                            # trim leading 0's:
                            ( $y2 = $1 ) =~ s/^0+//s;
                            $x2 =~ s/^0+//s;
                            print "   Treating $x2 and $y2 as bigint\n"
                                if DEBUG;

                            no locale;    # we want the dumb cmp back.
                            last if $rv = (

                                # works only for non-negative whole numbers:
                                length($x2) <=> length($y2)

                                  # the longer the numeral, the larger the value
                                    or $x2 cmp $y2

                        # between equals, compare lexically!!  amazing but true.
                            );
                        }
                    } else {

                        # X is numeric but Y isn't
                        $rv = Y_FIRST;
                        last;
                    }
                } elsif ( $y =~ s/^\d+//s )
                {    # we don't need to capture the substring
                    $rv = X_FIRST;
                    last;
                }

                # else one of them is 0-length.

                # end-while
            }
        }

        # Tiebreakers...
        $rv ||= ( length($x) <=> length($y) )    # shorter is always first
            || ( $x cmp $y )
            || ( $a cmp $b );

        $rv;
    }
}

1;
