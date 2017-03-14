package CXGN::BrAPI::v1::Trials;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial::Folder;
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

sub trials_search {
	my $self = shift;
	my $search_params = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $schema = $self->bcs_schema;
    #my $auth = _authenticate_user($c);

    my @location_dbids = $search_params->{locationDbIds} ? @{$search_params->{locationDbIds}} : ();
    my @program_dbids = $search_params->{programDbIds} ? @{$search_params->{programDbIds}} : ();

	my %location_id_list;
    if (scalar(@location_dbids)>0){
        %location_id_list = map { $_ => 1} @location_dbids;
    }
	my %program_id_list;
    if (scalar(@program_dbids)>0){
        %program_id_list = map { $_ => 1} @program_dbids;
    }

    my $total_count = 0;

    my $folder_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'trial_folder', 'project_property')->cvterm_id();
    my $folder_rs = $self->bcs_schema()->resultset("Project::Project")->search_related('projectprops', {'projectprops.type_id'=>$folder_cvterm_id});

    my @folder_studies;
    my %additional_info;
    my @data;
    if ($folder_rs) {
        $total_count = $folder_rs->count();
        my $rs_slice = $folder_rs->slice($page_size*$page, $page_size*($page+1)-1);
        while (my $p = $rs_slice->next()) {
            my $folder = CXGN::Trial::Folder->new({bcs_schema=>$self->bcs_schema, folder_id=>$p->project_id});
            if ($folder->is_folder) {
                my $children = $folder->children();
                foreach (@$children) {
					my $passes_search = 1;
                    if (%location_id_list) {
                        if (!exists($location_id_list{$_->location_id})) {
							$passes_search = 0;
                        }
                    }
					if ($passes_search){
                        push @folder_studies, {
                            studyDbId=>$_->folder_id,
                            studyName=>$_->name,
                            locationDbId=>$_->location_id
                        };
                    }
                }

				my $passes_search = 1;
				if (%program_id_list) {
					if (!exists($program_id_list{$folder->breeding_program->project_id})) {
						$passes_search = 0;
                    }
                }
				if ($passes_search){
                    push @data, {
                        trialDbId=>$folder->folder_id,
                        trialName=>$folder->name,
                        programDbId=>$folder->breeding_program->project_id(),
                        programName=>$folder->breeding_program->name(),
                        startDate=>'',
                        endDate=>'',
                        active=>'',
                        studies=>\@folder_studies,
                        additionalInfo=>\%additional_info
                    };
                }
            }
        }
    }
    my %result = (data => \@data);
	push @$status, { 'success' => 'Trials-search result constructed' };
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
