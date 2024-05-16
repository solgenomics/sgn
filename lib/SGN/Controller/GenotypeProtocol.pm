package SGN::Controller::GenotypeProtocol;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial::Folder;
use CXGN::Genotype::Protocol;
use File::Basename qw | basename dirname|;
use File::Spec::Functions;
use File::Slurp qw | read_file |;


BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);

sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub protocol_page :Path("/breeders_toolbox/protocol") Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;
    my $schema = $self->schema;

    if (!$c->user()) {

	my $url = '/' . $c->req->path;
	$c->res->redirect("/user/login?goto_url=$url");

    } else {

	my $protocol = CXGN::Genotype::Protocol->new({
	    bcs_schema => $schema,
	    nd_protocol_id => $protocol_id
	});

    my $display_observation_unit_type;
    my $observation_unit_type = $protocol->sample_observation_unit_type_name;
    if ($observation_unit_type eq 'tissue_sample_or_accession') {
        $display_observation_unit_type = 'tissue sample or accession';
    } else {
        $display_observation_unit_type = $observation_unit_type;
    }

    my $marker_info_keys = $protocol->marker_info_keys;
    my $assay_type = $protocol->assay_type;
    my @marker_info_headers = ();
    if (defined $marker_info_keys) {
        foreach my $info_key (@$marker_info_keys) {
            if ($info_key eq 'name') {
                push @marker_info_headers, 'Marker Name';
            } elsif (($info_key eq 'intertek_name') || ($info_key eq 'facility_name')) {
                push @marker_info_headers, 'Facility Marker Name';
            } elsif ($info_key eq 'chrom') {
                push @marker_info_headers, 'Chromosome';
            } elsif ($info_key eq 'pos') {
                push @marker_info_headers, 'Position';
            } elsif ($info_key eq 'alt') {
                if ($assay_type eq 'KASP') {
                    push @marker_info_headers, 'Y-allele';
                } else {
                    push @marker_info_headers, 'Alternate';
                }
            } elsif ($info_key eq 'ref') {
                if ($assay_type eq 'KASP') {
                    push @marker_info_headers, 'X-allele';
                } else {
                    push @marker_info_headers, 'Reference';
                }
            } elsif ($info_key eq 'qual') {
                push @marker_info_headers, 'Quality';
            } elsif ($info_key eq 'filter') {
                push @marker_info_headers, 'Filter';
            } elsif ($info_key eq 'info') {
                push @marker_info_headers, 'Info';
            } elsif ($info_key eq 'format') {
                push @marker_info_headers, 'Format';
            } elsif ($info_key eq 'sequence') {
                push @marker_info_headers, 'Sequence';
            }
        }
    } else {
        @marker_info_headers = ('Marker Name','Chromosome','Position','Alternate','Reference','Quality','Filter','Info','Format');
    }

    my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $protocolprop_rs = $schema->resultset('NaturalDiversity::NdProtocolprop')->find({'nd_protocol_id' => $protocol_id, 'type_id' => $protocol_vcf_details_cvterm_id});
    my $map_details_protocolprop_id;
    if ($protocolprop_rs) {
        $map_details_protocolprop_id = $protocolprop_rs->nd_protocolprop_id();
    }

	$c->stash->{protocol_id} = $protocol_id;
	$c->stash->{protocol_name} = $protocol->protocol_name;
	$c->stash->{protocol_description} = $protocol->protocol_description;
	$c->stash->{markers} = $protocol->markers || {};
	$c->stash->{marker_names} = $protocol->marker_names || [];
	$c->stash->{header_information_lines} = $protocol->header_information_lines || [];
	$c->stash->{reference_genome_name} = $protocol->reference_genome_name;
	$c->stash->{species_name} = $protocol->species_name;
	$c->stash->{create_date} = $protocol->create_date;
	$c->stash->{sample_observation_unit_type_name} = $display_observation_unit_type;
    $c->stash->{marker_type} = $protocol->marker_type;
    $c->stash->{marker_info_headers} = \@marker_info_headers;
    $c->stash->{assay_type} = $protocol->assay_type;
    $c->stash->{map_details_protocolprop_id} = $map_details_protocolprop_id;
    $c->stash->{template} = '/breeders_toolbox/genotyping_protocol/index.mas';
    }
}


sub pcr_protocol_genotype_data_download : Path('/protocol_genotype_data/pcr_download/') Args(1) {
    my $self  =shift;
    my $c = shift;
    my $file_id = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    my $contents = read_file($file_destination);
    my $file_name = $file_row->basename;

    $c->res->content_type('Application/trt');
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
    $c->res->body($contents);
}


1;
