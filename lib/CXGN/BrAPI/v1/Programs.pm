package CXGN::BrAPI::v1::Programs;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::Projects;
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

sub programs_list {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $program_names = $inputs->{program_names};
	my %program_names_q = map { $_ => 1 } @$program_names;

	my $ps = CXGN::BreedersToolbox::Projects->new({ schema => $self->bcs_schema });
	my $programs = $ps->get_breeding_programs();

	my @available;
	foreach (@$programs){
		my $passes_search;
		if (scalar(@$program_names)>0){
			if(exists($program_names_q{$_->[1]})){
				$passes_search = 1;
			}
		} else {
			$passes_search = 1;
		}
		if ($passes_search){
			push @available, $_;
		}
	}
	my $total_count = scalar(@available);
	my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($available[$i]) {
			my $prop_hash = $self->get_projectprop_hash($available[$i]->[0]);
			push @data, {
				programDbId=>$available[$i]->[0],
				name=>$available[$i]->[1],
				abbreviation=>$available[$i]->[1],
				objective=>$available[$i]->[2],
				leadPerson=> $prop_hash->{sp_person_id} ? join ',', @{$prop_hash->{sp_person_id}} : '',
			};
		}
	}

	my %result = (data=>\@data);
	push @$status, { 'success' => 'Program list result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}


sub get_projectprop_hash {
	my $self = shift;
	my $project_id = shift;
	my $prop_rs = $self->bcs_schema->resultset('Project::Projectprop')->search({'me.project_id' => $project_id}, {join=>['type'], +select=>['type.name', 'me.value'], +as=>['name', 'value']});
	my $prop_hash;
	while (my $r = $prop_rs->next()){
		push @{ $prop_hash->{$r->get_column('name')} }, $r->get_column('value');
	}
	#print STDERR Dumper $prop_hash;
	return $prop_hash;
}

1;
