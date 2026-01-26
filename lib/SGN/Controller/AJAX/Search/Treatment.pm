
package SGN::Controller::AJAX::Search::Treatment;

use Moose;
use Data::Dumper;
use CXGN::Trait;
use CXGN::Trait::Search;
use CXGN::BreederSearch;


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub search : Path('/ajax/search/treatments') Args(0) {
    my $self = shift;
    my $c    = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;    
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $params = $c->req->params() || {};

    my $ontology_db_ids = [];
    if ($params->{'ontology_db_id[]'}){
        $ontology_db_ids = ref($params->{'ontology_db_id[]'}) eq 'ARRAY' ? $params->{'ontology_db_id[]'} : [$params->{'ontology_db_id[]'}];
    }

    my $observation_variables = CXGN::BrAPI::v1::ObservationVariables->new({
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id),
        metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id),
        phenome_schema=>$c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id),
        people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
        page_size => 1000000,
        page => 0,
        status => []
    });

    my $result = $observation_variables->observation_variable_ontologies({cvprop_type_names => ['experiment_treatment_ontology', 'composed_experiment_treatment_ontology']});

    my @ontos;
    if (scalar(@{$ontology_db_ids}) == 0) {
        foreach my $o (@{$result->{result}->{data}}) {
            push @ontos, $o->{ontologyDbId};
        }
    } else {
        @ontos = @{$ontology_db_ids};
    }

    my $rows = $params->{length};
    my $offset = $params->{start};
    my $limit = defined($offset) && defined($rows) ? ($offset+$rows)-1 : undef;

    my $treatment_search_list_id = $params->{treatment_search_list_id};

    my $subset_treatments = [];
    if ($treatment_search_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $treatment_search_list_id });
        foreach (@{$list->elements()}){
            my @treatment = split '\|', $_;
            pop @treatment;
            my $treatment_name = join '\|', @treatment;
            push @$subset_treatments, $treatment_name;
        }
    }

    if ($params->{treatment_any_name}){
        push @$subset_treatments, $params->{treatment_any_name};
    }

    my $definitions;
    if ($params->{treatment_definition}){
        push @$definitions, $params->{treatment_definition};
    }

    my $trait_search = CXGN::Trait::Search->new({
        bcs_schema=>$schema,
	    is_variable=>1,
        ontology_db_id_list => \@ontos,
        limit => $limit,
        offset => $offset,
        trait_name_list => $subset_treatments,
        trait_definition_list => $definitions
    });
    my ($data, $records_total) = $trait_search->search();
    my @result;

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );

    foreach (@$data){
        my $db_name = $_->{db_name};
        my $accession = $_->{accession};
        my $treatment_id = $_->{trait_id};
        my $treatment_accession = $db_name .":". $accession ;
        my $treatment_usage = "<em>None</em>";

        # Get the number of trials that applied the treatment
        my $trial_criteria_list  = ['traits', 'trials'];
        my $trial_dataref = {
            'trials' => {
                'traits' => $treatment_id
            }
        };
        my $trial_queryref = {
            'trials' => {
                'traits' => 0
            }
        };
        my $trial_results_ref = $bs->metadata_query($trial_criteria_list, $trial_dataref, $trial_queryref);
        my $trials = $trial_results_ref->{results};
        my $trial_count = $#{$trials} + 1;
        
        # Get the number of plots that applied the treatment
        if ( $trial_count && $trial_count > 0 ) {
            my $plot_criteria_list  = ['traits', 'plots'];
            my $plot_dataref = {
                'plots' => {
                    'traits' => $treatment_id
                }
            };
            my $plot_queryref = {
                'plots' => {
                    'traits' => 0
                }
            };
            my $plot_results_ref = $bs->metadata_query($plot_criteria_list, $plot_dataref, $plot_queryref);
            my $plots = $plot_results_ref->{results};
            my $plot_count = $#{$plots} + 1;

            $treatment_usage = "Trials:&nbsp;$trial_count<br />Plots:&nbsp;$plot_count";
        }


        push @result,
            [
                '',
                "<button class='btn btn-info btn-$_->{trait_id}' onclick='copy(\"$_->{trait_name}\", \"$treatment_accession\", $_->{trait_id})'><span class='glyphicon glyphicon-copy'></span></button>",
                "<a href=\"/cvterm/$_->{trait_id}/view\">$treatment_accession</a>",
                "<a href=\"/cvterm/$_->{trait_id}/view\">$_->{trait_name}</a>",
                $_->{trait_definition},
                $treatment_usage,
                $_->{trait_name},
                $treatment_accession
            ];
    }
    #print STDERR Dumper \@result;

    my $draw = $params->{draw};
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => [ @result ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}
