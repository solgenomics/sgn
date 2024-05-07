
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingProtocol - a REST controller class to provide genotyping protocol search

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::GenotypingProtocol;

use Moose;
use Data::Dumper;
use CXGN::People::Login;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::MarkersSearch;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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
        my $header_line_count = 0;
        foreach (@{$_->{header_information_lines}}){
            if ($header_line_count < 10) {
                $_ =~ tr/<>//d;
                push @trimmed, $_;
            }
            else {
                push @trimmed, "### ----- SHOWING FIRST 10 LINES ONLY ----- ###";
                last;
            }
            $header_line_count++;
        }
        my $description = join '<br/>', @trimmed;
        $description = $description ? $description : 'NA';
        push @result,
          [
            "<a href=\"/breeders_toolbox/protocol/$_->{protocol_id}\">$_->{protocol_name}</a>",
            $_->{marker_type},
            $description,
            $num_markers,
            $_->{protocol_description},
            $_->{reference_genome_name},
            $_->{species_name},
            $_->{sample_observation_unit_type_name},
            $_->{create_date}
          ];
    }
    #print STDERR "PROTOCOL LIST =".Dumper \@result."\n";

    $c->stash->{rest} = { data => \@result };
}

sub genotyping_protocol_number : Path('/ajax/genotyping_protocol/num_markers') : ActionClass('REST') { }

sub genotyping_protocol_number_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @protocol_list = $c->req->param('protocol_ids') ? split ',', $c->req->param('protocol_ids') : ();
    my @accession_list = $c->req->param('accession_ids') ? split ',', $c->req->param('accession_ids') : ();

    my $protocol_search_result;
    if (@protocol_list) {
        $protocol_search_result = CXGN::Genotype::Protocol::list_simple($bcs_schema, \@protocol_list);
    }

    my @result;
    my $num_markers;
    foreach (@$protocol_search_result){
        $num_markers = $_->{marker_count};
        push @result,[$num_markers];
	#print STDERR "PROTOCOL number of markers $num_markers\n";
    }

    $c->stash->{rest} = { data => $num_markers };

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

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $bcs_schema,
        nd_protocol_id => $protocol_id
    });
    my $marker_info_keys = $protocol->marker_info_keys;

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
        if (defined $marker_info_keys) {
            my @each_row = ();
            foreach my $info_key (@$marker_info_keys) {
                push @each_row, $_->{$info_key};
            }
            push @result, [@each_row];
        } else {
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
    }

    $c->stash->{rest} = { data => \@result, recordsTotal => $total_count, recordsFiltered => $total_count };
}


sub genotyping_protocol_pcr_markers : Path('/ajax/genotyping_protocol/pcr_markers') : ActionClass('REST') { }

sub genotyping_protocol_pcr_markers_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $protocol_id = $c->req->param('protocol_id');

    my $pcr_marker_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'pcr_marker_details', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocolprop.value FROM nd_protocolprop WHERE nd_protocolprop.type_id = ? AND nd_protocolprop.nd_protocol_id = ?";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($pcr_marker_details_cvterm_id, $protocol_id);
    my @info = $h->fetchrow_array();
    my $protocol_info_string = $info[0];

    my $protocol_info_ref = decode_json $protocol_info_string;
    my $marker_details_ref = $protocol_info_ref->{marker_details};
    my %marker_details = %{$marker_details_ref};
    my @results;
    foreach my $marker_name (keys %marker_details) {
        my $product_sizes = $marker_details{$marker_name}{'product_sizes'};
        my $forward_primer = $marker_details{$marker_name}{'forward_primer'};
        my $reverse_primer = $marker_details{$marker_name}{'reverse_primer'};
        my $annealing_temperature = $marker_details{$marker_name}{'annealing_temperature'};
        my $sequence_motif = $marker_details{$marker_name}{'sequence_motif'};
        my $sequence_source = $marker_details{$marker_name}{'sequence_source'};
        my $linkage_group = $marker_details{$marker_name}{'linkage_group'};
        push @results, [$marker_name, $product_sizes, $forward_primer, $reverse_primer, $annealing_temperature, $sequence_motif, $sequence_source, $linkage_group];
    }

    $c->stash->{rest} = {data => \@results};
    
}


1;
