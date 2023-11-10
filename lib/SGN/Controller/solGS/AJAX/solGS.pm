
=head1 NAME

SGN::Controller::solGS::AJAX::solGS - a REST controller class to provide the
backend for objects linked with solgs

=head1 AUTHOR

Isaak Yosief Tecle <iyt2@cornell.edu>

=cut

package SGN::Controller::solGS::AJAX::solGS;

use Moose;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



sub solgs_trait_search_autocomplete :  Path('/solgs/ajax/trait/search') : ActionClass('REST') { }

sub solgs_trait_search_autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');

    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my $traits = $c->controller('solGS::Search')->model($c)->search_trait($term);

    $c->{stash}->{rest} = $traits;

}


sub solgs_population_search_autocomplete :  Path('/solgs/ajax/population/search') : ActionClass('REST') { }

sub solgs_population_search_autocomplete_GET :Args() {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @response_list;
    my $rs = $c->controller('solGS::Search')->model($c)->project_details_by_name($term);

    while (my $row = $rs->next)
    {
        my $pop_id = $row->id;    
        my $page_type = $c->controller('solGS::Path')->page_type($c, $c->req->referer);
        my $is_computation = $c->controller('solGS::Search')->check_saved_analysis_trial($c, $pop_id);
        
        if ($page_type =~ /training_model/) 
        {
            #filter out trials of analysis_type (with stored analyzed results) from search
            #result of trials relevant to selection prediction. 
            if (!$is_computation)
            {
                push @response_list, $row->name;
            }           
        }  
    else
	{  
        #filter out trials of analysis_type (with stored analyzed results) and with out phenotype data from search
        #result of trials relevant to training populations. 
        my $has_phenotype = $c->controller('solGS::Search')->model($c)->has_phenotype($pop_id);            
        if ($has_phenotype && !$is_computation)
        {
            push @response_list, $row->name;
        }
     }
    }

    $c->{stash}->{rest} = \@response_list;
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

###
1;
###
