
=head1 NAME

qtl.t - tests for cgi-bin/phenome/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/phenome/qtl.pl

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use URI::FromHash 'uri';

use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;
    
    $mech->get_ok( '/phenome/qtl.pl?population_id=12&term_id=39945&chr=3&peak_marker=T0581&lod=3.6&qtl=../data/qtl.png',
        'got a qtl detail page' );
    
    $mech->content_contains($_) for ('QTL map', 
    'QTL 95%', 'QTL markers\' genomic matches', 
    'Browse QTL region', 
    'QTL markers\' genetic positions',
    'Population genetic map',
    'User comments',
);

}

done_testing;
