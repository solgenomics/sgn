package CXGN::BrAPI::v1::GermplasmAttributes;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Chado::Stock;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'page_size' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'page' => (
	isa => 'Int',
	is => 'rw',
	required => 1,
);

has 'status' => (
	isa => 'ArrayRef[Maybe[HashRef]]',
	is => 'rw',
	required => 1,
);

sub germplasm_attributes_list {
	my $self = shift;
	my $inputs = shift;
	my @attribute_category_dbids = $inputs->{attribute_category_dbids} ? @{$inputs->{attribute_category_dbids}} : ();

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;
	my $where_clause = '';
	if (scalar(@attribute_category_dbids)>0) {
		my $s = join ',', @attribute_category_dbids;
		$where_clause .= "AND cv.cv_id IN ($s)";
	}
	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT cv.cv_id, cv.name, cv.definition, b.cvterm_id, b.name, b.definition, stockprop.value
		FROM stockprop
		JOIN stock using(stock_id)
		JOIN cvterm as b on (stockprop.type_id=b.cvterm_id)
		JOIN cv on (b.cv_id=cv.cv_id)
		WHERE stock.type_id=?
		$where_clause
		ORDER BY cv.cv_id;";

	my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
	$h->execute($accession_type_cvterm_id);
	my %attribute_hash;
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $attributeDbId, $name, $description, $value) = $h->fetchrow_array()) {
		if (exists($attribute_hash{$attributeDbId})) {
			my $values = $attribute_hash{$attributeDbId}->[5];
			push @$values, $value;
			$attribute_hash{$attributeDbId}->[5] = $values;
		} else {
			$attribute_hash{$attributeDbId} = [$attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $name, $description, [$value]];
		}
	}

	foreach (keys %attribute_hash) {
		my $prophash = $self->get_cvtermprop_hash($_);
		push @data, {
			attributeDbId => $_,
			code => $prophash->{'code'} ? join ',', @{$prophash->{'code'}} : '',
			uri => $prophash->{'uri'} ? join ',', @{$prophash->{'uri'}} : '',
			name => $attribute_hash{$_}->[3],
			description => $attribute_hash{$_}->[4],
			attributeCategoryDbId => $attribute_hash{$_}->[0],
			attributeCategoryName => $attribute_hash{$_}->[1],
			datatype => $prophash->{'datatype'} ? join ',', @{$prophash->{'datatype'}} : '',
			values => $attribute_hash{$_}->[5]
		};
	}

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);
	my %result = (data => $data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm-attributes list result constructed');
}

sub germplasm_attributes_categories_list {
	my $self = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT distinct(cv.cv_id), cv.name, cv.definition
		FROM stockprop
		JOIN stock using(stock_id)
		JOIN cvterm as b on (stockprop.type_id=b.cvterm_id)
		JOIN cv on (b.cv_id=cv.cv_id)
		WHERE stock.type_id=?
		GROUP BY (cv.cv_id)
		ORDER BY cv.cv_id;";

	my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
	$h->execute($accession_type_cvterm_id);
	my @data;
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc) = $h->fetchrow_array()) {
		push @data, {
			attributeCategoryDbId => $attributeCategoryDbId,
			attributeCategoryName => $attributeCategoryName,
		};
	}
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);
	my %result = (data => $data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm-attributes categories list result constructed');
}


sub germplasm_attributes_germplasm_detail {
	my $self = shift;
	my $inputs = shift;
	my $stock_id = $inputs->{stock_id};
	my @attribute_dbids = $inputs->{attribute_dbids} ? @{$inputs->{attribute_dbids}} : ();

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $where = '';
	if (scalar(@attribute_dbids)>0){
		my $sql = join ',', @attribute_dbids;
		$where = "and b.cvterm_id IN ($sql)";
	}

	my $offset = $page_size*$page;
	my $limit = $page_size;
	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT cv.cv_id, cv.name, cv.definition, b.cvterm_id, b.name, b.definition, stockprop.value, stockprop.stockprop_id, count(stockprop.value) OVER() AS full_count
		FROM stockprop
		JOIN stock using(stock_id)
		JOIN cvterm as b on (stockprop.type_id=b.cvterm_id)
		JOIN cv on (b.cv_id=cv.cv_id)
		WHERE stock.type_id=? and stock.stock_id=? $where
		ORDER BY cv.cv_id
		LIMIT $limit
		OFFSET $offset;";

	my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
	$h->execute($accession_type_cvterm_id, $stock_id);
	my @data;
	my $total_count = 0;
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $attributeDbId, $name, $description, $value, $stockprop_id, $count) = $h->fetchrow_array()) {
		$total_count = $count;
		push @data, {
			attributeDbId => $attributeDbId,
			attributeName => $name,
			attributeCode => $name,
			description => $description,
			attributeCategoryDbId => $attributeCategoryDbId,
			attributeCategoryName => $attributeCategoryName,
			value => $value,
			dateDetermined => '',
		};
	}
	my %result = (
		germplasmDbId=>$stock_id,
		data => \@data
	);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm-attributes detail result constructed');
}

sub get_cvtermprop_hash {
	my $self = shift;
	my $cvterm_id = shift;
	my $prop_rs = $self->bcs_schema->resultset('Cv::Cvtermprop')->search({'me.cvterm_id' => $cvterm_id}, {join=>['type'], +select=>['type.name', 'me.value'], +as=>['name', 'value']});
	my $prop_hash;
	while (my $r = $prop_rs->next()){
		push @{ $prop_hash->{$r->get_column('name')} }, $r->get_column('value');
	}
	#print STDERR Dumper $prop_hash;
	return $prop_hash;
}

1;
