
package SGN::Controller::AJAX::Search::Trial;

use Moose;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::Search;


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

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_list=>\@location_names,
    });
    my $data = $trial_search->search();
    my @result;
    foreach (@$data){
        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        push @result,
          [
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            $_->{breeding_program_name},
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{trial_type},
            $_->{design},
            $_->{project_planting_date},
            $_->{project_harvest_date}
          ];
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}
