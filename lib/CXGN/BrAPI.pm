package CXGN::BrAPI;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::v1::Authentication;
use CXGN::BrAPI::v1::Calls;
use CXGN::BrAPI::v1::Crops;
use CXGN::BrAPI::v1::ObservationVariables;
use CXGN::BrAPI::v1::Studies;
use CXGN::BrAPI::v1::Germplasm;
use CXGN::BrAPI::v1::Trials;

has 'version' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'brapi_module_inst' => (
	isa => 'HashRef',
	is => 'rw',
	required => 1,
);

sub brapi_logout {
	my $self = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Authentication';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_auth = $brapi_package->new($self->brapi_module_inst);
    my $brapi_package_result = $brapi_auth->logout();
	return $brapi_package_result;
}

sub brapi_login {
	my $self = shift;
	my $grant_type = shift;
	my $password = shift;
	my $username = shift;
	my $client_id = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Authentication';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_auth = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_auth->login($grant_type, $password, $username, $client_id);
	return $brapi_package_result;
}

sub brapi_calls {
	my $self = shift;
	my $datatype = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Calls';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_calls = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_calls->calls($datatype);
	return $brapi_package_result;
}

sub brapi_crops {
	my $self = shift;
	my $supported_crop = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Crops';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_crops = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_crops->crops($supported_crop);
	return $brapi_package_result;
}

sub brapi_observation_levels {
	my $self = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::ObservationVariables';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_obs = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_obs->observation_levels();
	return $brapi_package_result;
}

sub brapi_seasons {
	my $self = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Studies';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_obs = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_obs->seasons();
	return $brapi_package_result;
}

sub brapi_study_types {
	my $self = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Studies';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_studies = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_studies->study_types();
	return $brapi_package_result;
}

sub brapi_germplasm_search {
	my $self = shift;
	my $search_params = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Germplasm';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_germplasm = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_germplasm->germplasm_search($search_params);
	return $brapi_package_result;
}

sub brapi_germplasm_detail {
	my $self = shift;
	my $stock_id = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Germplasm';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_germplasm = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_germplasm->germplasm_detail($stock_id);
	return $brapi_package_result;
}

sub brapi_studies_search {
	my $self = shift;
	my $search_params = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Studies';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_studies = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_studies->studies_search($search_params);
	return $brapi_package_result;
}

sub brapi_trials_search {
	my $self = shift;
	my $search_params = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Trials';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_trials = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_trials->trials_search($search_params);
	return $brapi_package_result;
}

sub brapi_trial_details {
	my $self = shift;
	my $folder_id = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Trials';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_trials = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_trials->trial_details($folder_id);
	return $brapi_package_result;
}

sub brapi_studies_germplasm {
	my $self = shift;
	my $study_id = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Studies';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_studies = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_studies->studies_germplasm($study_id);
	return $brapi_package_result;
}

sub brapi_germplasm_pedigree {
	my $self = shift;
	my $inputs = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Germplasm';
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_germplasm = $brapi_package->new($self->brapi_module_inst);
	my $brapi_package_result = $brapi_germplasm->germplasm_pedigree($inputs);
	return $brapi_package_result;
}


1;
