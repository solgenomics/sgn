package CXGN::BrAPI::v2::References;

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
    my $reference_ids = $inputs->{referenceDbId} || ($inputs->{referenceDbIds} || ());
    my $accession = $inputs->{accession} || ($inputs->{accessions} || ());
    my $is_derived = $inputs->{isDerived} || ($inputs->{isDerived} || ());
    my $md5checksum = $inputs->{md5checksum} || ($inputs->{md5checksums} || ());
    my $max_length = $inputs->{maxLength} || ($inputs->{maxLength} || ());
    my $min_length = $inputs->{minLength} || ($inputs->{minLength} || ());

    if ($md5checksum || $accession || $is_derived ){
        push @$status, { 'error' => 'The following parameters search are not implemented: md5checksum, accession, isDerived' };
    }

	my @data;
	my $counter = 0;
	my $where_clause = "";
    my %reference_sets;

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

    while (my ($referenceset, $species, $protocol, $header ) = $h->fetchrow_array()) {   
    	$referenceset =~ s/"//g;
    	$species =~ s/"//g;
        $protocol =~ s/"//g;
        my $source;

        my $head = decode_json $header;

        foreach (@{$head}){
            $source = $1 if ($_ =~ /##source=(\w+)/);
        }

        foreach (@{$head}){        
            my $referenceName = $1 if ($_ =~ /##contig=<ID=(\w+)/) ;
            my $length = $1 if ($_ =~ /,length=(\d+)/) ;
            my $md5 = $1 if ($_ =~ /,md5=(\w+)/) ;
            if ( $md5checksum && $md5 && ! grep { $_ eq $md5 } @{$md5checksum}  ) { next; } 
            if ( $referenceName && $reference_ids && ! grep { $_ eq $referenceName } @{$reference_ids} ) { next; } 
            if ( $max_length && $length && $max_length->[0] < $length + 0 ) { next; } 
            if ( $min_length && $length && $min_length->[0] > $length + 0 ) { next; } 

            if($referenceName){
                if ($counter >= $start_index && $counter <= $end_index) {
                    push @data, {
                        additionalInfo => {},
                        isDerived => JSON::false,
                        length => $length + 0,
                        md5checksum => $md5,
                        referenceSetDbId => qq|$protocol|,
                        referenceSetName => $referenceset,
                        referenceDbId => qq|$referenceName|,
                        referenceName => qq|$referenceName|,
                        sourceAccessions => undef,
                        sourceDivergence => undef,
                        sourceURI => undef,
                        species => { 
                            term => $species,
                            termURI => undef
                        }
                    };
                }
                $counter++;
            }
        }
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'References result constructed');
}

sub detail {
    my $self = shift;
    my $reference_ids = shift;
    my $schema = $self->bcs_schema();
    my $page_size = $self->page_size;
    my $page = $self->page;

    my @data;
    my $counter = 0;
    my $where_clause;
    my %reference_sets;

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();

    my $subquery = "SELECT distinct value->'reference_genome_name', value->'species_name', nd_protocol_id, value->'header_information_lines' from nd_protocolprop where type_id = $vcf_map_details_cvterm_id $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    while (my ($referenceset, $species, $protocol, $header ) = $h->fetchrow_array()) {   
        $referenceset =~ s/"//g;
        $species =~ s/"//g;
        $protocol =~ s/"//g;
        my $source;

        my $head = decode_json $header;

        foreach (@{$head}){
            $source = $1 if ($_ =~ /##source=(\w+)/);
        }

        foreach (@{$head}){        
            my $referenceName = $1 if ($_ =~ /##contig=<ID=(\w+)/) ;
            my $length = $1 if ($_ =~ /,length=(\d+)/) ;
            my $md5 = $1 if ($_ =~ /,md5=(\w+)/) ;

            if($referenceName  && $reference_ids eq $referenceName ){
                push @data, {
                    additionalInfo => {},
                    isDerived => JSON::false,
                    length => $length + 0,
                    md5checksum => $md5,
                    referenceSetDbId => qq|$protocol|,
                    referenceSetName => $referenceset,
                    referenceDbId => qq|$referenceName|,
                    referenceName => qq|$referenceName|,
                    sourceAccessions => undef,
                    sourceDivergence => undef,
                    sourceURI => undef,
                    species => { 
                        term => $species,
                        termURI => undef
                    }
                };
                $counter++;
            }
        }
    }
 

    my $status = $self->status;

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'References result constructed');
}

1;
