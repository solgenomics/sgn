
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
use CXGN::Genotype::MarkersSearch;
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
        my $num_markers = $_->{marker_count};
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

sub genotyping_protocol_markers_search : Path('/ajax/genotyping_protocol/markers_search') : ActionClass('REST') { }

sub genotyping_protocol_markers_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $params = $c->req->params() || {};
    my $protocol_id = $params->{protocol_id};
    my @marker_names = $params->{marker_names} ? split ',', $params->{marker_names} : ();
    my $rows = $params->{length};
    my $offset = $params->{start};
    my $limit = defined($offset) && defined($rows) ? ($offset+$rows)-1 : undef;
    my @result;

    my $marker_search = CXGN::Genotype::MarkersSearch->new({
        bcs_schema => $bcs_schema,
        protocol_id_list => [$protocol_id],
        #protocol_name_list => \@protocol_name_list,
        marker_name_list => \@marker_names,
        #protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'] Use default which is all marker info
        limit => $limit,
        offset => $offset
    });
    my ($search_result, $total_count) = $marker_search->search();

    foreach (@$search_result) {
        push @result, [
            $_->{marker_name},
            $_->{chrom},
            $_->{pos},
            $_->{alt},
            $_->{ref},
            $_->{qual},
            $_->{filter},
            $_->{info},
            $_->{format}
        ];
    }

    $c->stash->{rest} = { data => \@result, recordsTotal => $total_count, recordsFiltered => scalar(@result) };
}

1;
