package CXGN::BrAPI::v2::GermplasmAttributeValues;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Chado::Stock;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $inputs = shift;
	my @attribute_dbids = $inputs->{attribute_dbids} ? @{$inputs->{attribute_dbids}} : ();
	my $value_id = $inputs->{attributeValueDbId} || ($inputs->{attributeValueDbIds} || ());

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $where = '';
	if (scalar(@attribute_dbids)>0){
		my $sql = join ',', @attribute_dbids;
		$where = "and b.cvterm_id IN ($sql)";
	}
	if ($value_id){
		my $stock_ids;
		my $attribute_ids;
		foreach(@$value_id){
			my ($stock_id, $attribute_id) = split(/b/, $_);
			$stock_ids .=  $stock_id . ",";
			$attribute_ids .=  $attribute_id . ",";
		}
		if($stock_ids && $attribute_ids){
			chop($stock_ids);
			chop($attribute_ids);
			$where = $where . "and stock.stock_id IN ($stock_ids) and b.cvterm_id IN ($attribute_ids)";
		}
	}

	my $offset = $page_size*$page;
	my $limit = $page_size;
	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT cv.cv_id, cv.name, cv.definition, b.cvterm_id, b.name, b.definition, stockprop.value, stockprop.stockprop_id, stock.stock_id, stock.name, count(stockprop.value) OVER() AS full_count
		FROM stockprop
		JOIN stock using(stock_id)
		JOIN cvterm as b on (stockprop.type_id=b.cvterm_id)
		JOIN cv on (b.cv_id=cv.cv_id)
		WHERE stock.type_id=? $where
		ORDER BY cv.cv_id
		LIMIT $limit
		OFFSET $offset;";

	my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
	$h->execute($accession_type_cvterm_id);
	my @data;
	my $total_count = 0;
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $attributeDbId, $name, $description, $value, $stockprop_id, $stock_id, $stock_name, $count) = $h->fetchrow_array()) {
		$total_count = $count;
		push @data, {
			additionalInfo=>{},
			germplasmDbId=> qq|$stock_id|,
			germplasmName=> $stock_name,
			attributeDbId => qq|$attributeDbId|,
			attributeName => $name,
			attributeValueDbId=> $stock_id."b".$attributeDbId,
			value => $value,
			determinedDate =>undef,
        	externalReferences=> [],
		};
	}
	my %result = (
		data => \@data
	);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Attribute values detail result constructed');
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}

1;
