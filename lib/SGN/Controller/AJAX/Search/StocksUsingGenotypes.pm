
package SGN::Controller::AJAX::Search::StocksUsingGenotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Genotype::SearchStocks;
use CXGN::List;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub get_accessions_using_dosages :Path('/ajax/search/accessions_using_dosages') :Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_list_id = $c->req->param("stock_list_id");
    my $markerset_id = $c->req->param("markerset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

#    my $dataset = CXGN::Dataset->new(
#        schema => $c->dbic_schema("Bio::Chado::Schema"),
#        people_schema => $c->dbic_schema("CXGN::People::Schema"),
#        sp_dataset_id=> $dataset_id,
#    );

#    my $dataset_ref = $dataset->get_dataset_data();
#    print STDERR "DATASET =" .Dumper($dataset_ref). "\n";

#    my %data = %{$dataset_ref};

#    my $genotype_accessions_ref = $data{'categories'}{'accessions'};
#    my $genotype_protocol_ref = $data{'categories'}{'genotyping_protocols'};

#    my @genotype_accessions = @{$genotype_accessions_ref};

#    my $protocol_id = $genotype_protocol_ref-> [0];

    my $stock_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $stock_list_id});
    my $stock_names_ref = $stock_list->retrieve_elements($stock_list_id);
    my @stock_names = @{$stock_names_ref};
#    print STDERR "STOCK IDS =".Dumper(\@stock_ids)."\n";

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items_ref = $markerset->retrieve_elements_with_ids($markerset_id);
    my @markerset_items = @{$markerset_items_ref};
#    print STDERR "MARKERSET ITEMS =".Dumper(\@markerset_items)."\n";

    my @parameters;
    foreach my $item (@markerset_items){
        my $param = $item->[1];
        push @parameters, $param;
    }
#    print STDERR "PARAMETERS =".Dumper(\@parameters)."\n";
    my $genotypes_accessions_search = CXGN::Genotype::SearchStocks->new({
        bcs_schema=>$schema,
        stock_list=>\@stock_names,
#        protocol_id=>$protocol_id,
        filtering_parameters=>\@parameters,
    });

    my $result = $genotypes_accessions_search->get_selected_accessions();

    my @selected_accessions;

    foreach my $r(@$result){
        my ($selected_id, $selected_uniquename, $marker_dosage_string) = @$r;
        push @selected_accessions, {
            stock_id => $selected_id,
            stock_name => $selected_uniquename,
            genotypes => $marker_dosage_string
        };
    }

    $c->stash->{rest}={data=> \@selected_accessions};

}


sub get_accessions_using_snps :Path('/ajax/search/accessions_using_snps') :Args(0){
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param("dataset_id");
    my $markerset_id = $c->req->param("markerset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $dataset = CXGN::Dataset->new(
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id=> $dataset_id,
    );

    my $dataset_ref = $dataset->get_dataset_data();

    print STDERR "DATASET ID =".Dumper($dataset_id)."\n";
    print STDERR "MARKERSET ID =".Dumper($markerset_id)."\n";
    print STDERR "DATASET =".Dumper($dataset_ref). "\n";

    my %data = %{$dataset_ref};

    my $genotype_accessions_ref = $data{'categories'}{'accessions'};
    my $genotype_protocol_ref = $data{'categories'}{'genotyping_protocols'};

    my @genotype_accessions = @{$genotype_accessions_ref};

    my $protocol_id = $genotype_protocol_ref-> [0];

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items_ref = $markerset->retrieve_elements_with_ids($markerset_id);
    my @markerset_items = @{$markerset_items_ref};

    my @parameters;
    foreach my $item (@markerset_items){
        my $param = $item->[1];
        push @parameters, $param;
    }

    my $genotypes_accessions_search = CXGN::Genotype::SearchStocks->new({
        bcs_schema=>$schema,
        stock_list=>\@genotype_accessions,
        protocol_id=>$protocol_id,
        filtering_parameters=>\@parameters,
    });

    my $result = $genotypes_accessions_search->get_accessions_using_snps();

    my @selected_accessions;

    foreach my $r(@$result){
        my ($selected_id, $selected_uniquename, $marker_snp_string) = @$r;
        push @selected_accessions, {
            stock_id => $selected_id,
            stock_name => $selected_uniquename,
            genotypes => $marker_snp_string
        };
    }

    $c->stash->{rest}={data=> \@selected_accessions};

}

1;
