package CXGN::BrAPI::v2::ReferenceSets;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $inputs = shift;
	my $schema = $self->bcs_schema();
	my $page_size = $self->page_size;
	my $page = $self->page;

    my $referenceset_ids = $inputs->{referenceSetDbId} || ($inputs->{referenceSetDbIds} || ());
    my $accession = $inputs->{accession} || ($inputs->{accessions} || ());
    my $assembly_pui = $inputs->{assemblyPUI} || ($inputs->{assemblyPUIs} || ());
    my $md5checksum = $inputs->{md5checksum} || ($inputs->{md5checksums} || ());

	my @data;
	my $counter = 0;
	my $where_clause;

	if ($referenceset_ids){
		$where_clause = "and nd_protocolprop.value->'reference_genome_name' ?& array['" . $referenceset_ids->[0] . "'] ";
	}
	my $subquery = "SELECT distinct value->'reference_genome_name', value->'species_name' from nd_protocolprop where type_id = '77645' $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    while (my ($reference, $species ) = $h->fetchrow_array()) {
    	$reference =~ s/"//g;
    	$species =~ s/"//g;
        push @data, {
        	additionalInfo => {},
        	assemblyPUI => undef,
        	description => $reference,
        	md5checksum => undef,
        	referenceSetDbId => $reference,
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

	my $status = $self->status;

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Reference sets result constructed');
}

1;
