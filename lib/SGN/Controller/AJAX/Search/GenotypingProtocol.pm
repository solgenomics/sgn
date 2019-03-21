
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingProtocol - a REST controller class to provide genotyping protocol search

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::GenotypingProtocol;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;
use CXGN::Genotype::Protocol;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub genotyping_protocol_search : Path('/ajax/genotyping_protocol/search') : ActionClass('REST') { }

sub genotyping_protocol_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @protocol_list = $c->req->param('protocol_ids') ? split ',', $c->req->param('protocol_ids') : ();
    my @accession_list = $c->req->param('accession_ids') ? split ',', $c->req->param('accession_ids') : ();
    my @tissue_sample_list = $c->req->param('tissue_sample_ids') ? split ',', $c->req->param('tissue_sample_ids') : ();
    my @genotyping_data_project_list = $c->req->param('genotyping_data_project_ids') ? split ',', $c->req->param('genotyping_data_project_ids') : ();
    my $limit;
    my $offset;

    my $protocol_search_result;
    if (scalar(@protocol_list)>0 || scalar(@accession_list)>0 || scalar(@tissue_sample_list)>0 || scalar(@genotyping_data_project_list)>0) {
        $protocol_search_result = CXGN::Genotype::Protocol::list($bcs_schema, \@protocol_list, \@accession_list, \@tissue_sample_list, $limit, $offset, \@genotyping_data_project_list);
    } else {
        $protocol_search_result = CXGN::Genotype::Protocol::list_simple($bcs_schema);
    }

    my @result;
    foreach (@$protocol_search_result){
        my $num_markers = scalar keys %{$_->{markers}};
        my @trimmed;
        foreach (@{$_->{header_information_lines}}){
            $_ =~ tr/<>//d;
            push @trimmed, $_;
        }
        my $description = join '<br/>', @trimmed;
        $description = $description ? $description : 'Not set. Please reload this protocol using new genotype protocol format.';
        push @result,
          [
            "<a href=\"/breeders_toolbox/protocol/$_->{protocol_id}\">$_->{protocol_name}</a>",
            "<a href=\"/breeders_toolbox/trial/$_->{project_id}\">$_->{project_name}</a>",
            $description,
            $num_markers,
            $_->{protocol_description},
            $_->{reference_genome_name},
            $_->{species_name},
            $_->{sample_observation_unit_type_name},
            $_->{create_date}
          ];
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

1;
