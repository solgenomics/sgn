package SGN::Feature::LocusPages;
use Moose;
use namespace::autoclean;

use URI;

use CXGN::Phenome;

use SGN::SiteFeatures::CrossReference;

extends 'SGN::Feature';

has '+description' => (
    default    => 'Genetic loci',
   );

sub xrefs {
    my ( $self, $query ) = @_;

    return if ref $query;

    return ( $self->_name_xrefs( $query ),
             #$self->_phenotype_xrefs( $query ),
           );
}

sub _name_xrefs {
    my ( $self, $q ) = @_;

    my $search = CXGN::Phenome->new;
    my $query = $search->new_query;
    $query->locus_obsolete(" = 'f' ");
    $query->any_name(" = ? ", $q );
    my $result = $search->do_search($query);

    # fetch at most 5 results, hashing by locus name
    my %results = map { $_->[1] => $_ } reverse grep $_, map { $result->next_result } 1..5;

    # make xrefs out of them
    my @xrefs;
    for my $locus_name ( sort keys %results ) {
        my $r = $results{$locus_name};

        my $text = qq|$r->[14] locus $r->[2]|;
        $text .= " ($locus_name)" unless $locus_name eq $r->[2];

        push @xrefs, SGN::SiteFeatures::CrossReference->new({
            feature => $self,
            text    => $text,
            url     => URI->new( '/phenome/locus_display.pl?locus_id='.$r->[0] ),
        });
    }

    return @xrefs;
}


1;
