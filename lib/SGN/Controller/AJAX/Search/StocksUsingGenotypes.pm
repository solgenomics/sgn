
package SGN::Controller::AJAX::Search::StocksUsingGenotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Genotype::SearchStocks;
use CXGN::List;
use CXGN::BreederSearch;
use JSON;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub get_stocks_using_markerset :Path('/ajax/search/search_stocks_using_markerset') :Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_list_id = $c->req->param("stock_list_id");
    my $markerset_id = $c->req->param("markerset_id");
    my $search_type = $c->req->param("search_type") || "all";
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items = $markerset->retrieve_elements($markerset_id);

    # Get the stock names
    my $stock_names;

    # ... from the user-provided accession list
    if ( defined $stock_list_id && $stock_list_id ne '' ) {
        my $stock_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $stock_list_id});
        $stock_names = $stock_list->retrieve_elements($stock_list_id);
    }

    # ... from the genotyping protocol associated with the markerset
    else {
        my $markerset_metadata = decode_json($markerset_items->[0]);
        my $proto_id = $markerset_metadata->{genotyping_protocol_id};

        my $q = "SELECT DISTINCT(stock.uniquename)
                FROM nd_experiment_protocol
                LEFT JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
                LEFT JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
                WHERE nd_experiment_protocol.nd_protocol_id = ?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($proto_id);

        my @results_names;
        while (my ($stock_name) = $h->fetchrow_array()){
            push @results_names, $stock_name;
        }

        $stock_names = \@results_names;
    }

    my $genotypes_stocks_search = CXGN::Genotype::SearchStocks->new({
        bcs_schema=>$schema,
        stock_list=>$stock_names,
        filtering_parameters=>$markerset_items,
        search_type=>$search_type
    });

    my $result_ref = $genotypes_stocks_search->get_selected_stocks();
    my %result_hash = %{$result_ref};
#    print STDERR "RESULT HASH =".Dumper(\%result_hash);

    my $incorrect_marker_names_ref = $result_hash{'incorrect_marker_names'};
    if ($incorrect_marker_names_ref) {
        my @incorrect_names_array = @$incorrect_marker_names_ref;
        my $incorrect_names_string = join(",", @incorrect_names_array);
        $c->stash->{rest} = { error => $incorrect_names_string };
        $c->detach();
    }

    my $stocks_ref = $result_hash{'selected_stocks'};
    my @stocks;
    if ($stocks_ref) {
        @stocks = @$stocks_ref;
    }

    my @selected_stocks;

    foreach my $st(@stocks){
        my ($selected_id, $selected_uniquename, $selected_sample_id, $selected_sample_name, $sample_type, $params_string) = @$st;
        push @selected_stocks, {
            stock_id => $selected_id,
            stock_name => $selected_uniquename,
            sample_id => $selected_sample_id,
            sample_name => $selected_sample_name,
            sample_type => $sample_type,
            genotypes => $params_string
        };
    }

    $c->stash->{rest}={data=> \@selected_stocks};

}


1;
