package CXGN::BrAPI;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::v1::Authentication;
use CXGN::BrAPI::v1::Calls;
use CXGN::BrAPI::v1::Crops;

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

has 'version' => (
	isa => 'Str',
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

sub logout {
	my $self = shift;
	my $status = $self->status;
	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Authentication';
	push @$status, { 'info' => "Loading $brapi_package" };
	my $brapi_auth = $brapi_package->new({
        bcs_schema => $self->bcs_schema,
        status => $status
    });
    my $brapi_package_result = $brapi_auth->logout();
	return $brapi_package_result;
}

sub login {
	my $self = shift;
	my $grant_type = shift;
	my $password = shift;
	my $username = shift;
	my $client_id = shift;
	my $status = $self->status;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Authentication';
	push @$status, { 'info' => "Loading $brapi_package" };
	my $brapi_auth = $brapi_package->new({
		bcs_schema => $self->bcs_schema,
		status => $status
	});
	my $brapi_package_result = $brapi_auth->login($grant_type, $password, $username, $client_id);
	return $brapi_package_result;
}

sub calls {
	my $self = shift;
	my $datatype = shift;
	my $status = $self->status;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Calls';
	push @$status, { 'info' => "Loading $brapi_package" };
	my $brapi_calls = $brapi_package->new({
		status => $self->status
	});
	my $brapi_package_result = $brapi_calls->calls($datatype, $self->page_size, $self->page);
	return $brapi_package_result;
}

sub crops {
	my $self = shift;
	my $supported_crop = shift;
	my $status = $self->status;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::Crops';
	push @$status, { 'info' => "Loading $brapi_package" };
	my $brapi_calls = $brapi_package->new({
		status => $self->status
	});
	my $brapi_package_result = $brapi_calls->crops($supported_crop, $self->page_size, $self->page);
	return $brapi_package_result;
}

1;
