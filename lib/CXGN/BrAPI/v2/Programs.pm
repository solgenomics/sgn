package CXGN::BrAPI::v2::Programs;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::Projects;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $crop = $inputs->{crop};

	my @abbreviations = $inputs->{abbreviations} ? @{$inputs->{abbreviations}} : ();
	my @commoncrop_names = $inputs->{commonCropNames} ? @{$inputs->{commonCropNames}} : ();
	my @externalreference_ids = $inputs->{externalReferenceIDs} ? @{$inputs->{externalReferenceIDs}} : ();
	my @externalreference_sources = $inputs->{externalReferenceSources} ? @{$inputs->{externalReferenceSources}} : ();
	my @lead_ids = $inputs->{leadPersonDbIds} ? @{$inputs->{leadPersonDbIds}} : ();
	my @lead_names = $inputs->{leadPersonNames} ? @{$inputs->{leadPersonNames}} : ();
	my @objectives = $inputs->{objectives} ? @{$inputs->{objectives}} : ();
	my @program_ids = $inputs->{programDbIds} ? @{$inputs->{programDbIds}} : ();
	my @program_names = $inputs->{programNames} ? @{$inputs->{programNames}} : ();

	if (scalar(@abbreviations)>0 || scalar(@externalreference_sources)>0 || scalar(@externalreference_ids)>0){
        push @$status, { 'error' => 'The following parameters are not implemented: abbreviations, externalReferenceID, externalReferenceSource' };
    }

	my $ps = CXGN::BreedersToolbox::Projects->new({ schema => $self->bcs_schema });
	my $programs = $ps->get_breeding_programs();

	my @available;
	my %program_names = map { $_ => 1 } @program_names;
	my %program_ids = map { $_ => 1 } @program_ids;
	my %objectives = map { $_ => 1 } @objectives;

	foreach (@$programs){
		my $passes_search;
		if (scalar(@program_names)>0 || scalar(@program_ids)>0 || scalar(@objectives)>0 || scalar(@commoncrop_names)>0 ){
			if(exists($program_names{$_->[1]})){
				$passes_search = 1;
			}
			if(exists($program_ids{$_->[0]})){
				$passes_search = 1;
			}
			if(exists($objectives{$_->[2]})){
				$passes_search = 1;
			}
			if ( grep( /^$crop$/, @commoncrop_names ) ) {
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
        my $person_id = join ',',  @sp_persons;
        my %lead_ids = map { $_ => 1 } @lead_ids;
        my %lead_names = map { $_ => 1 } @lead_names;
        my $passes_search;

        if (scalar(@lead_ids)>0 || scalar(@lead_names)>0){
        	if(exists($lead_ids{$person_id})){
        		$passes_search = 1;
        	}
        	if(exists($lead_names{$names})){
        		$passes_search = 1;
        	}
        } else {
			$passes_search = 1;
		}

		if ($passes_search){
			push @data, {
				programDbId=>qq|$_->[0]|,
				programName=>$_->[1],
				abbreviation=>$prop_hash->{breeding_program_abbreviation} ? join ',', @{$prop_hash->{breeding_program_abbreviation}} : '',,
				additionalInfo => {},
	            commonCropName => $inputs->{crop},
	            documentationURL => undef,
	            externalReferences  => [],
	            leadPersonDbId => $person_id,
	            leadPersonName=> $names,
	            objective=>$_->[2],
			};
		}
	}

	my %result = (data=>\@data);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Program list result constructed');
}


sub detail {
	my $self = shift;
	my $program_id = shift;
	my $crop = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $programs = $self->bcs_schema()->resultset('Project::Project')->find({project_id => $program_id});

	my $id = $programs->project_id();
	my $name = $programs->name();
	my $description = $programs->description();

	my @data;
	my @data_files;
	my $total_count = 1;
	my %result;

	my $prop_hash = $self->get_projectprop_hash($id);
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
    my $person_id = join ',',  @sp_persons;

	%result = (
		programDbId=>qq|$id|,
		programName=>$name,
		abbreviation=>$prop_hash->{breeding_program_abbreviation} ? join ',', @{$prop_hash->{breeding_program_abbreviation}} : undef,
		additionalInfo => {},
        commonCropName => $crop,
        documentationURL => undef,
        externalReferences  => [],
        leadPersonDbId => $person_id ? $person_id : undef,
        leadPersonName=> $names ? $names : undef,
        objective=>$description,
	);


	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Program list result constructed');
}

sub store {
	my $self = shift;
    my $data = shift;
    my $user_id =shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema();

    if (!$user_id) {
		return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must login and have permission to access this BrAPI call.'));
	}
	my @program_ids;

	foreach my $params (@{$data}) {
		my $name = $params->{programName} || undef;
		my $desc = $params->{objective} || undef;

		my $p = CXGN::BreedersToolbox::Projects->new({
            schema => $schema
            name => $name,
            description => $desc,
        });

		my $new_program = $p->store_breeding_program();

		print STDERR "New program is ".Dumper($new_program)."\n";

		push @program_ids, $new_program;

	}

	my %result;
	my $count = scalar @program_ids;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, undef, $self->status(), $count . " Programs were stored.");

}

sub update {
	my $self = shift;
    my $params = shift;
    my $user_id =shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema();

    if (!$user_id) {
		return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must login and have permission to access this BrAPI call.'));
	}
	my @program_ids;

	my $name = $params->{programName} || undef;
	my $desc = $params->{objective} || undef;
	my $id = $params->{programDbId} || undef;

	my $program = $schema->resultset('Project::Project')->find({project_id => $id});
	if (!$program) {
		return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Program id %s does not exist.',$id));
	}

	my $row = $schema->resultset("Project::Project")->update_or_create(
	    {
	    project_id=>$id,
		name => $name,
		description => $desc,
	    });

	$row->insert();
	my $project_id = $row->project_id();
	push @program_ids, $project_id;

	my %result;
	my $count = scalar @program_ids;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, undef, $self->status(), $count . " Program updated.");

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
