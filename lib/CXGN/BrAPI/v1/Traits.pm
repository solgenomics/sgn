package CXGN::BrAPI::v1::Traits;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'metadata_schema' => (
	isa => 'CXGN::Metadata::Schema',
	is => 'rw',
	required => 1,
);

has 'phenome_schema' => (
	isa => 'CXGN::Phenome::Schema',
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


sub list {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my @trait_ids;
    my $q = "SELECT trait_id FROM traitsxtrials ORDER BY trait_id;";
    my $p = $self->bcs_schema()->storage->dbh()->prepare($q);
    $p->execute();
    while (my ($cvterm_id) = $p->fetchrow_array()) {
        push @trait_ids, $cvterm_id;
    }

    my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	my @data_window;
	for (my $line = $start; $line < $end; $line++) {
		if ($trait_ids[$line]) {
			my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$trait_ids[$line]});
	        push @data_window, {
	            traitDbId => $trait->cvterm_id,
	            traitId => $trait->term,
	            name => $trait->name,
	            description => $trait->definition,
	            observationVariables => [
					$trait->display_name
				],
	            defaultValue => $trait->default_value,
	        };
		}
    }

    my $total_count = $p->rows;
    my %result = (data => \@data_window);
	push @$status, { 'success' => 'Traits list result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub detail {
	my $self = shift;
	my $cvterm_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $total_count = 0;
	my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
	if ($trait->name){
		$total_count = 1;
	}
	my %result = (
        traitDbId => $trait->cvterm_id,
        traitId => $trait->term,
        name => $trait->name,
        description => $trait->definition,
        observationVariables => [
			$trait->display_name
		],
        defaultValue => $trait->default_value,
    );

	push @$status, { 'success' => 'Trait detail result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

1;
