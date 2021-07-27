
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingDataProject - a REST controller class to provide genotyping data project

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::GenotypingDataProject;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Trial::Search;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub genotyping_data_project_search : Path('/ajax/genotyping_data_project/search') : ActionClass('REST') { }

sub genotyping_data_project_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotype_data_project', 'pcr_genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search();
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
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{genotyping_facility}
          ];
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

1;
