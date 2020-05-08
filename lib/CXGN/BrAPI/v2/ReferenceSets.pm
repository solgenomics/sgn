package CXGN::BrAPI::v2::ReferenceSets;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use JSON;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $inputs = shift;
	my $schema = $self->bcs_schema();
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;

    my $referenceset_ids = $inputs->{referenceSetDbId} || ($inputs->{referenceSetDbIds} || ());
    my $accession = $inputs->{accession} || ($inputs->{accessions} || ());
    my $assembly_pui = $inputs->{assemblyPUI} || ($inputs->{assemblyPUIs} || ());
    my $md5checksum = $inputs->{md5checksum} || ($inputs->{md5checksums} || ());

    if ($md5checksum || $accession || $assembly_pui ){
        push @$status, { 'error' => 'The following parameters search are not implemented: md5checksum, accession, assemblyPUI' };
    }

	my @data;
	my $counter = 0;
	my $where_clause ="";

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    if ($referenceset_ids && scalar(@$referenceset_ids)>0) {
        my $protocol_sql = join ("," , @$referenceset_ids);
        $where_clause = "AND nd_protocolprop.nd_protocol_id in ($protocol_sql)";
    }

	my $subquery = "SELECT distinct value->'reference_genome_name', value->'species_name', nd_protocol_id, value->'header_information_lines' from nd_protocolprop where type_id = $vcf_map_details_cvterm_id $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;

    while (my ($reference, $species, $protocol, $header ) = $h->fetchrow_array()) {
    	$reference =~ s/"//g;
    	$species =~ s/"//g;
    	my $head = decode_json $header;
    	my $assembly;

        foreach (@{$head}){
            $assembly = $1 if ($_ =~ /##assembly=(\.+)/);
        }
	    if ($counter >= $start_index && $counter <= $end_index) {
	        push @data, {
	        	additionalInfo => {},
	        	assemblyPUI => $assembly,
	        	description => $reference,
	        	md5checksum => undef,
	        	referenceSetDbId => qq|$protocol|,
	            referenceSetName => $reference,
	            sourceAccessions => undef,
	            sourceURI => undef,
	            species => { 
	            	term => $species,
	            	termURI => undef
	            }
	        };
	    }
	    $counter++;
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Reference sets result constructed');
}

sub detail {
	my $self = shift;
	my $referenceset_ids = shift;
	my $schema = $self->bcs_schema();
	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my @data;
	my $counter = 0;
	my $where_clause;

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    if ($referenceset_ids) {
        $where_clause = "AND nd_protocolprop.nd_protocol_id = $referenceset_ids";
    }

	my $subquery = "SELECT distinct value->'reference_genome_name', value->'species_name', nd_protocol_id, value->'header_information_lines' from nd_protocolprop where type_id = $vcf_map_details_cvterm_id $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    while (my ($reference, $species, $protocol, $header ) = $h->fetchrow_array()) {
    	$reference =~ s/"//g;
    	$species =~ s/"//g;
    	my $head = decode_json $header;
    	my $assembly;

        foreach (@{$head}){
            $assembly = $1 if ($_ =~ /##assembly=(\.+)/);
        }

        push @data, {
        	additionalInfo => {},
        	assemblyPUI => $assembly,
        	description => $reference,
        	md5checksum => undef,
        	referenceSetDbId => qq|$protocol|,
            referenceSetName => $reference,
            sourceAccessions => undef,
            sourceURI => undef,
            species => { 
            	term => $species,
            	termURI => undef
            }
        };
        $counter++;
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Reference sets result constructed');
}

1;
