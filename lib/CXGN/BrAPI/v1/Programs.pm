package CXGN::BrAPI::v1::Programs;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::Projects;
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
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@available, $page_size, $page);
	my @data;
	my @data_files;
	foreach (@$data_window){
		my $prop_hash = $self->get_projectprop_hash($_->[0]);
		my @sp_persons = $prop_hash->{sp_person_id} ? @{$prop_hash->{sp_person_id}} : ();
		my @sp_person_names;
		my $q = "SELECT username FROM sgn_people.sp_person where sp_person_id = ?;";
		my $h = $self->bcs_schema->storage()->dbh()->prepare($q);
		foreach (@sp_persons){
			$h->execute($_);
			while (my ($username) = $h->fetchrow_array()) {
				push @sp_person_names, $username;
			}
		}
        my $names = join ',', @sp_person_names;
		push @data, {
			programDbId=>qq|$_->[0]|,
			name=>$_->[1],
			abbreviation=>$prop_hash->{breeding_program_abbreviation} ? join ',', @{$prop_hash->{breeding_program_abbreviation}} : '',,
			objective=>$_->[2],
			leadPerson=> $names,
            commonCropName => $inputs->{crop}
		};
	}

	my %result = (data=>\@data);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Program list result constructed');
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
