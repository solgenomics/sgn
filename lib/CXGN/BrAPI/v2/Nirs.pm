package CXGN::BrAPI::v2::Nirs;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
    my $status = $self->status;
	my $schema = $self->bcs_schema();
	my $stock_ids_arrayref = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());

	my @nirs_protocol_ids;
	my @data;
	my @data_files;
	my $total_count = 1;

	my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();

	my $q = "SELECT nd_protocol_id FROM nd_protocol where type_id = ?;";
	my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
	$h->execute($high_dim_nirs_protocol_cvterm_id);
	print STDERR Dumper $high_dim_nirs_protocol_cvterm_id;

	while (my ($nirs_protocol_id) = $h->fetchrow_array()) {
		push @nirs_protocol_ids, $nirs_protocol_id;
	}
	print STDERR Dumper @nirs_protocol_ids;


# 	my $accession_ids = $ds->accessions();
#	my @accession_array = ['41786'];
#	my $accession_ids = \@accession_array;
#     my $plot_ids = $ds->plots();
#     my $plant_ids = $ds->plants();
#	foreach (@nirs_protocol_ids){
#		print STDERR Dumper $_;

		my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
	        bcs_schema=>$schema,
#	        nd_protocol_id=>$_,
	        nd_protocol_id=>'6',
	        high_dimensional_phenotype_type=>'NIRS',
	        query_associated_stocks=>1,
	        accession_list=>$stock_ids_arrayref,
	        plot_list=>undef,
	        plant_list=>undef
	    });
		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
		print STDERR Dumper $identifier_names;

		push @data, {
            device_type=>undef,
			header_column_names=>$identifier_names,
            header_column_details=>undef,

        };
#	}
	print STDERR Dumper @data;


# # print STDERR Dumper $data_matrix;
#
#
#
#     foreach (@crosstypes){
#     	my $id = $_;
#     	$id =~ s/ /_/g;
#

#     }
#
my %result = (data => \@data);
my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Nirs result constructed');
}

# sub nirs_detail {
#     my $self = shift;
#     my $stock_id = shift;
#
#     my $status = $self->status;
#     my $page_size = $self->page_size;
#     my $page = $self->page;
#     my @data_files;
#
# 	foreach (@nirs_protocol_ids){
# 		print STDERR Dumper $_;
#
# 		my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
# 	        bcs_schema=>$schema,
# 	        nd_protocol_id=>$_,
# 	        high_dimensional_phenotype_type=>'NIRS',
# 	        query_associated_stocks=>1,
# 	        accession_list=>undef,
# 	        plot_list=>undef,
# 	        plant_list=>undef
# 	    });
# 		my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
# 		print STDERR Dumper $identifier_names;
#
# 		push @data, {
#             name=>$identifier_names,
#             metadata=>$identifier_metadata,
#         };
# 	}
#
# 	my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
# 		bcs_schema=>$schema,
# 		nd_protocol_id=>$_,
# 		high_dimensional_phenotype_type=>'NIRS',
# 	    query_associated_stocks=>1,
# 	    accession_list=>undef,
# 	    plot_list=>undef,
# 	    plant_list=>undef
# 	});
# 	my ($data_matrix, $identifier_metadata, $identifier_names) = $phenotypes_search->search();
#
#
#     my @result = _simple_search($self,[$stock_id]);
#     my $total_count = scalar(@result);
#
#     my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
#     return CXGN::BrAPI::JSONResponse->return_success(@result, $pagination, \@data_files, $status, 'Nirs detail result constructed');
# }
