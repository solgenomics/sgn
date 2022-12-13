package CXGN::BreedersToolbox::OrganismFuzzySearch;

=head1 NAME

CXGN::BreedersToolbox::OrganismFuzzySearch - an object to find approximate matches in the database to a query organism species.

=head1 USAGE

 my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
 my $fuzzy_organism_result = $fuzzy_organism_search->get_matches(\@species_list, $max_distance)};

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use CXGN::String::FuzzyMatch;
use SGN::Model::Cvterm;
#use Data::Dumper;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);


sub get_matches {
    my $self = shift;
    my $species_list_ref = shift;
    my $max_distance = shift;
    my $schema = $self->get_schema();
    my @species_list = @{$species_list_ref};
    my $fuzzy_string_search = CXGN::String::FuzzyMatch->new( { case_insensitive => 0} );
    my @fuzzy_organisms;
    my @absent_organisms;
    my @found_organisms;
    my %results;

    print STDERR "OrganismFuzzySearch 1".localtime()."\n";

    my $q = "SELECT species from organism;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %uniquename_hash;
    while (my ($species) = $h->fetchrow_array()) {
        $uniquename_hash{$species}++;
    }
    my @complete_species_list = keys %uniquename_hash;

    print STDERR "OrganismFuzzySearch 2".localtime()."\n";

    foreach my $species_name (@$species_list_ref) {
        if (exists($uniquename_hash{$species_name})){
            push @found_organisms, {"matched_string" => $species_name, "unique_name" => $species_name};
            next;
        }
        my @matches;
        my @species_matches = @{$fuzzy_string_search->get_matches($species_name, \@species_list, $max_distance)};

        if (scalar @species_matches eq 0) {
            push (@absent_organisms, $species_name);
        } else {

            foreach my $match (@species_matches) {
                my $matched_name = $match->{'string'};
                my $distance = $match->{'distance'};
                my %match_info;
                $match_info{'name'} = $matched_name;
                $match_info{'distance'} = $distance;
                push (@matches, \%match_info);
            }
        }
        my %species_and_fuzzy_matches;
        $species_and_fuzzy_matches{'name'} = $species_name;
        $species_and_fuzzy_matches{'matches'} = \@matches;
        push (@fuzzy_organisms, \%species_and_fuzzy_matches);
    }
    print STDERR "OrganismFuzzySearch 3".localtime()."\n";
    $results{'found'} = \@found_organisms;
    $results{'fuzzy'} = \@fuzzy_organisms;
    $results{'absent'} = \@absent_organisms;
    return \%results;
}



###
1;
###
