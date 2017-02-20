package Test::SGN::View::Feature;
use strict;
use warnings;
use base 'Test::Class';

use Test::Class;
use Test::More tests => 19;
use Test::Exception;

use Data::Dump;
use List::MoreUtils qw/ any /;

use lib 't/lib';
use SGN::Test::Data qw/create_test/;

use_ok('SGN::View::Feature', qw/
    feature_table related_stats cvterm_link
    feature_link organism_link
    mrna_cds_protein_sequence
/ );

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{feature} = create_test('Sequence::Feature');
}

sub teardown : Test(teardown) {
    my $self = shift;
    # SGN::Test::Data objects self-destruct, don't clean them up here!
}

sub TEST_MRNA_CDS_PROTEIN_SEQUENCE : Tests {
    my $self = shift;
    my $f = $self->{feature};

    lives_ok( sub { mrna_cds_protein_sequence($f) } );
}

sub TEST_FEATURE_TABLE : Tests {
    my $self = shift;
    my $f = $self->{feature};
    my %table_data = feature_table( [$f] );
    is( scalar @{$table_data{data}}, 1, 'got one row for the one, unlocated feature' );
    table_row_contains( $table_data{data}->[0], 'not located', 'says feature is not located' );
    table_row_contains( $table_data{data}->[0], $f->name, 'has feature name' );
    table_row_contains( $table_data{data}->[0], $f->organism->species, 'has species' );

}

sub TEST_UTR_LENGTHS : Tests {
    my $self = shift;
    local *_calc = sub {
        SGN::View::Feature::_calculate_cdna_utr_lengths(
            _make_range( @{+shift} ),
            [ map { _make_range(@$_) } @_ ]
        )
    };

    is_deeply( [ _calc( [6,10,1], [1,3,1], [5,10,1] ) ],
               [ 4, 0 ]
             );
    is_deeply( [ _calc( [6,10,1], [1,3,1], [5,20,1] ) ],
               [ 4, 10 ]
             );
    is_deeply( [ _calc( [1,10,1], [1,3,1], [5,20,1] ) ],
               [ 0, 10 ]
             );
}

sub _make_range {
    Bio::Range->new( -start => shift, -end => shift, -strand => shift );
}

sub table_row_contains {
    my $row = shift;
    my $substr  = shift;
    my $name = shift;
    ok( ( any { index($_,$substr) != -1 } @$row ), $name )
       or diag "$substr not found in ".Data::Dump::dump( $row );
}

sub TEST_CVTERM_LINK : Tests {
    my $self = shift;
    my $f = $self->{feature};
    my ($id,$name) = ($f->type->cvterm_id,$f->type->name);
    $name =~ s/_/ /g;
    my $link = qq{<a href="/cvterm/$id/view">$name</a>};
    is(cvterm_link($f->type),$link, 'cvterm link');
}

sub TEST_RELATED_STATS : Tests {
    my $self = shift;
    my $feature = create_test('Sequence::Feature');

    my $name1 = cvterm_link( $self->{feature}->type );
    my $name2 = cvterm_link( $feature->type );
    my $stats = related_stats([ $self->{feature}, $feature, $feature ]);
    is($stats->[0][1], $name1);
    is($stats->[0][0], 1);
    is($stats->[1][0], 2);
    is($stats->[1][1], $name2);
    is($stats->[2][0], 3);
    like($stats->[2][1] , qr'Total');
}

sub TEST_ORGANISM_LINK : Tests {
    my $self = shift;
    my $o             = create_test('Organism::Organism');
    my ($id,$species) = ($o->organism_id,$o->species);
    my $link          = qq{<a class="species_binomial" href="/chado/organism.pl?organism_id=$id">$species</a>};
    is(organism_link($o),$link, 'organism_link on a organism');
}

sub TEST_FEATURE_LINK : Tests {
    my $self = shift;
    my $f          = $self->{feature};
    my ($id,$name) = ($f->feature_id,$f->name);
    my $link       = qq{<a href="/feature/$id/details">$name</a>};
    is(feature_link($f),$link, 'feature_link on a feature');
    is(feature_link(),'<span class="ghosted">null</span>','feature_link returns a ghosted null when not given a feature');
}

Test::Class->runtests;
