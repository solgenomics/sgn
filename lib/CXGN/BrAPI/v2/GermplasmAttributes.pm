package CXGN::BrAPI::v2::GermplasmAttributes;

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
	my @attribute_category_dbids = $inputs->{attribute_category_dbids} ? @{$inputs->{attribute_category_dbids}} : ();
	my $attribute_ids = $inputs->{attributeDbId} || ($inputs->{attributeDbIds} || ());

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;
	my $where_clause = '';
	if (scalar(@attribute_category_dbids)>0) {
		my $s = join ',', @attribute_category_dbids;
		$where_clause .= "AND cv.cv_id IN ($s)";
	}
	if ($attribute_ids) {
		my $attribute_id = _sql_from_arrayref($attribute_ids);
		$where_clause .= "AND b.cvterm_id IN ($attribute_id)";
	}
	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT cv.cv_id, cv.name, cv.definition, b.cvterm_id, b.name, b.definition, stockprop.value, stock.create_date, stock.organism_id
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
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $attributeDbId, $name, $description, $value, $date, $organism_id) = $h->fetchrow_array()) {
		if (!exists($attribute_hash{$attributeDbId})) {
			$attribute_hash{$attributeDbId} = [$attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $name, $description, [$value], $date, $organism_id];
		}
	}

	foreach (keys %attribute_hash) {
		my $prophash = $self->get_cvtermprop_hash($_);
		my $organism = $self->bcs_schema->resultset("Organism::Organism")->find( { organism_id => $attribute_hash{$_}->[7] } );

		push @data, {
			additionalInfo => {},
			attributeDbId => "$_",
			attributeCategory => $attribute_hash{$_}->[1],
			attributeDescription => $attribute_hash{$_}->[4],
			attributeName => $attribute_hash{$_}->[3],
			commonCropName => $organism->common_name,
			contextOfUse => [],
			defaultValue => undef,
			documentationURL => undef,
			externalReferences => [],
			growthStage => undef,
			institution => undef,
			language => 'English',
			method => {},
			ontologyReference => undef,
			scale => {},
			scientist => undef,
			status => undef,
			submissionTimestamp => $attribute_hash{$_}->[6],
			synonyms => [],
			trait => {},
		};
	}

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);
	my %result = (data => $data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm attributes list result constructed');
}

sub detail {
	my $self = shift;
	my $attribute_id = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;

	my $accession_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT cv.cv_id, cv.name, cv.definition, b.cvterm_id, b.name, b.definition, stockprop.value, stock.create_date, stock.organism_id
		FROM stockprop
		JOIN stock using(stock_id)
		JOIN cvterm as b on (stockprop.type_id=b.cvterm_id)
		JOIN cv on (b.cv_id=cv.cv_id)
		WHERE stock.type_id=? and b.cvterm_id=?
		ORDER BY cv.cv_id;";

	my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
	$h->execute($accession_type_cvterm_id,$attribute_id);
	my %attribute_hash;
	while (my ($attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $attributeDbId, $name, $description, $value, $date, $organism_id) = $h->fetchrow_array()) {
		if (!exists($attribute_hash{$attributeDbId})) {
			$attribute_hash{$attributeDbId} = [$attributeCategoryDbId, $attributeCategoryName, $attributeCategoryDesc, $name, $description, [$value], $date, $organism_id];
		}
	}

	foreach (keys %attribute_hash) {
		my $prophash = $self->get_cvtermprop_hash($_);
		my $organism = $self->bcs_schema->resultset("Organism::Organism")->find( { organism_id => $attribute_hash{$_}->[7] } );

		push @data, {
			additionalInfo => {},
			attributeDbId => "$_",
			attributeCategory => $attribute_hash{$_}->[1],
			attributeDescription => $attribute_hash{$_}->[4],
			attributeName => $attribute_hash{$_}->[3],
			commonCropName => $organism->common_name,
			contextOfUse => [],
			defaultValue => undef,
			documentationURL => undef,
			externalReferences => [],
			growthStage => undef,
			institution => undef,
			language => 'English',
			method => {},
			ontologyReference => undef,
			scale => {},
			scientist => undef,
			status => undef,
			submissionTimestamp => $attribute_hash{$_}->[6],
			synonyms => [],
			trait => {},
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
		push @data, $attributeCategoryName;
	}
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@data,$page_size,$page);
	my %result = (data => $data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Germplasm attributes categories list result constructed');
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

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}

1;
