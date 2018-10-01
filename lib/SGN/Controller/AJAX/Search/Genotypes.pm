
package SGN::Controller::AJAX::Search::Genotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Genotype::Search;
use CXGN::List;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


sub get_selected_accessions :Path('/ajax/search/get_selected_accessions') :Args(0){
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param("dataset_id");
    my $markerset_id = $c->req->param("markerset_id");
    my $marker_name = $c->req->param("marker_name");
    my $allele_dosage = $c->req->param("allele_dosage");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $dataset = CXGN::Dataset->new(
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id=> $dataset_id,
    );

    my $dataset_ref = $dataset->get_dataset_data();
#    print STDERR "DATASET =" .Dumper($dataset_ref). "\n";

    my %data = %{$dataset_ref};

    my $genotype_accessions_ref = $data{'categories'}{'accessions'};
    my $genotype_protocol_ref = $data{'categories'}{'genotyping_protocols'};

    my @genotype_accessions = @{$genotype_accessions_ref};

    my $protocol_id = $genotype_protocol_ref-> [0];

#    print STDERR "ACCESSIONS =" .Dumper(@genotype_accessions). "\n";
#    print "type of ACCESSIONS: " . ref(@genotype_accessions). "\n";

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items_ref = $markerset->retrieve_elements_with_ids($markerset_id);
    my @markerset_items = @{$markerset_items_ref};

    my @parameters;
    foreach my $item (@markerset_items){
        my $param = $item->[1];
        push @parameters, $param;
    }

    my $genotypes_accessions_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        accession_list=>\@genotype_accessions,
        protocol_id=>$protocol_id,
        filtering_parameters=>\@parameters,
    });

    my $result = $genotypes_accessions_search->get_selected_accessions();

    my @selected_accessions;

    foreach my $r(@$result){
        my ($selected_id, $selected_uniquename, $marker_dosage_string) = @$r;
#        push @selected_accessions, [qq{<a href="/stock/$selected_id/view">$selected_uniquename</a>}, $marker_dosage_string];
        push @selected_accessions, {
            stock_id => $selected_id,
            stock_name => $selected_uniquename,
            genotypes => $marker_dosage_string
        };
    }

    $c->stash->{rest}={data=> \@selected_accessions};

}


1;
