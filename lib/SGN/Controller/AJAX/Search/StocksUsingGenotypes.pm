
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


sub get_stocks_using_markerset :Path('/ajax/search/search_stocks_using_markerset') :Args(0){
    my $self = shift;
    my $c = shift;
    my $stock_list_id = $c->req->param("stock_list_id");
    my $markerset_id = $c->req->param("markerset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $stock_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $stock_list_id});
    my $stock_names = $stock_list->retrieve_elements($stock_list_id);

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items = $markerset->retrieve_elements($markerset_id);

    my $genotypes_stocks_search = CXGN::Genotype::SearchStocks->new({
        bcs_schema=>$schema,
        stock_list=>$stock_names,
        filtering_parameters=>$markerset_items,
    });

    my $result = $genotypes_stocks_search->get_selected_stocks();

    my @selected_stocks;

    foreach my $r(@$result){
        my ($selected_id, $selected_uniquename, $selected_sample_id, $selected_sample_name, $sample_type, $params_string) = @$r;
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
