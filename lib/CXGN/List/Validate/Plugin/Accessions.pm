
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

use Data::Dumper;
use CXGN::BreedersToolbox::AccessionsFuzzySearch;

sub name { 
    return "accessions";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    #my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();

    my @missing = ();
    

    my $fs = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema=>$schema});
    my $r = $fs->get_matches($list, 0);

    print STDERR Dumper($r);

    my @non_unique;

    return { missing => [ @{$r->{absent}},  map { $_->{name} } @{$r->{fuzzy}} ]  };
    
}

1;
