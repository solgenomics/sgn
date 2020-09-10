
package SGN::Controller::AJAX::Search::Trait;

use Moose;
use Data::Dumper;
use CXGN::Trait;
use CXGN::Trait::Search;


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub search : Path('/ajax/search/traits') Args(0) {
    my $self = shift;
    my $c    = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $params = $c->req->params() || {};
    #print STDERR Dumper $params;

    my $ontology_db_ids;
    if ($params->{'ontology_db_id[]'}){
        $ontology_db_ids = ref($params->{'ontology_db_id[]'}) eq 'ARRAY' ? $params->{'ontology_db_id[]'} : [$params->{'ontology_db_id[]'}];
    }

    my $rows = $params->{length};
    my $offset = $params->{start};
    my $limit = defined($offset) && defined($rows) ? ($offset+$rows)-1 : undef;

    my $trait_search_list_id = $params->{trait_search_list_id};

    my $subset_traits = [];
    if ($trait_search_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $trait_search_list_id });
        foreach (@{$list->elements()}){
            my @trait = split '\|', $_;
            pop @trait;
            my $trait_name = join '\|', @trait;
            push @$subset_traits, $trait_name;
        }
    }

    if ($params->{trait_any_name}){
        push @$subset_traits, $params->{trait_any_name};
    }

    my $definitions;
    if ($params->{trait_definition}){
        push @$definitions, $params->{trait_definition};
    }

    my $trait_search = CXGN::Trait::Search->new({
        bcs_schema=>$schema,
	is_variable=>1,
        ontology_db_id_list => $ontology_db_ids,
        limit => $limit,
        offset => $offset,
        trait_name_list => $subset_traits,
        trait_definition_list => $definitions
    });
    my ($data, $records_total) = $trait_search->search();
    my @result;

    foreach (@$data){
        my $db_name = $_->{db_name};
        my $accession = $_->{accession};
        my $trait_accession = $db_name .":". $accession ;
        push @result,
            [
                '',
                "<a href=\"/cvterm/$_->{trait_id}/view\">$trait_accession</a>",
                "<a href=\"/cvterm/$_->{trait_id}/view\">$_->{trait_name}</a>",
                $_->{trait_definition},
	        $_->{trait_name},
                $trait_accession
            ];
    }
    #print STDERR Dumper \@result;

    my $draw = $params->{draw};
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}
