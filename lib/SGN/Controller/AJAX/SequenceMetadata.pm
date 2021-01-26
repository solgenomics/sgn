use strict;

package SGN::Controller::AJAX::SequenceMetadata;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

#
# Get a list of the maps from the database and their associated organisms
# PATH: GET /ajax/sequence_metadata/reference_genomes
# 
sub get_reference_genomes : Path('/ajax/sequence_metadata/reference_genomes') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Get map and organism info
    my $q = "SELECT map.map_id, map.short_name, map.long_name, map.map_type, map.units, p1o.abbreviation AS parent1_abbreviation, p1o.genus AS parent1_genus, p1o.species AS parent1_species, p2o.abbreviation AS parent2_abbreviation, p2o.genus AS parent2_genus, p2o.species AS parent2_species FROM sgn.map LEFT JOIN public.stock AS p1s ON (p1s.stock_id = map.parent1_stock_id) LEFT JOIN public.organism AS p1o ON (p1o.organism_id = p1s.organism_id) LEFT JOIN public.stock AS p2s ON (p2s.stock_id = map.parent2_stock_id) LEFT JOIN public.organism AS p2o ON (p2o.organism_id = p2s.organism_id);";
    my $h = $dbh->prepare($q);
    $h->execute();

    my @results = ();
    while ( my ($map_id, $short_name, $long_name, $map_type, $units, $p1_abb, $p1_genus, $p1_species, $p2_abb, $p2_genus, $p2_species) = $h->fetchrow_array()  ) {
        my %result = (
            map_id => $map_id,
            short_name => $short_name,
            long_name => $long_name,
            map_type => $map_type,
            units => $units,
            parent1_abbreviation => $p1_abb,
            parent1_genus => $p1_genus,
            parent1_species => $p1_species,
            parent2_abbreviation => $p2_abb,
            parent2_genus => $p2_genus,
            parent2_species => $p2_species
        );
        push(@results, \%result);
    }

    $c->stash->{rest} = {
        maps => \@results
    };
}

#
# Process the gff file upload and perform file verification
# PATH: POST /ajax/sequence_metadata/file_upload_verify
#
sub sequence_metadata_upload_verify : Path('/ajax/sequence_metadata/file_upload_verify') : ActionClass('REST') { }
sub sequence_metadata_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my @params = $c->req->params();

    use Data::Dumper;
    print STDERR "UPLOAD VERIFY:\n";
    print STDERR Dumper \@params;

    $c->stash->{rest} = {
        success => "Yes",
        error => ()
    };
}