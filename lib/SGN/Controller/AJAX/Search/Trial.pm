
package SGN::Controller::AJAX::Search::Trial;

use Moose;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::Search;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub search : Path('/ajax/search/trials') Args(0) {
    my $self = shift;
    my $c    = shift;

    my @location_names;
    my $nd_geolocation = $c->req->param('nd_geolocation');
    if ($nd_geolocation && $nd_geolocation ne 'not_provided'){
        push @location_names, $nd_geolocation;
    }

    print STDERR "location: " . $nd_geolocation . "\n";
    #print STDERR Dumper $c->req->params();
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trials_only = $c->req->param('field_trials_only') || 1;
    my $trial_design_list = $c->req->param('trial_design') ? [$c->req->param('trial_design')] : [];

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_list=>\@location_names,
        field_trials_only=>$field_trials_only,
        trial_design_list=>$trial_design_list
    });
    my ($data, $total_count) = $trial_search->search();
    my @result;
    my %selected_columns = ('plot_name'=>1, 'plot_id'=>1, 'block_number'=>1, 'plot_number'=>1, 'rep_number'=>1, 'row_number'=>1, 'col_number'=>1, 'accession_name'=>1, 'is_a_control'=>1);
    my $selected_columns_json = encode_json \%selected_columns;
    foreach (@$data){
        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$_->{trial_id}'>";
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{trial_type},
            $_->{design},
            $_->{project_planting_date},
            $_->{project_harvest_date},
            "<a class='btn btn-sm btn-default' href='/breeders/trial/$_->{trial_id}/download/layout?format=csv&dataLevel=plots&selected_columns=$selected_columns_json'>Download Plot Layout</a>"
        );
        push @result, \@res;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}
