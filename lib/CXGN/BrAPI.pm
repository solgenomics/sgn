package CXGN::BrAPI;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::v1::Authentication;
use CXGN::BrAPI::v1::Calls;
use CXGN::BrAPI::v1::Crops;
use CXGN::BrAPI::v1::ObservationVariables;
use CXGN::BrAPI::v1::Studies;
use CXGN::BrAPI::v1::Germplasm;
use CXGN::BrAPI::v1::GermplasmAttributes;
use CXGN::BrAPI::v1::Trials;
use CXGN::BrAPI::v1::Markerprofiles;
use CXGN::BrAPI::v1::Programs;
use CXGN::BrAPI::v1::Locations;
use CXGN::BrAPI::v1::Phenotypes;
use CXGN::BrAPI::v1::Traits;
use CXGN::BrAPI::v1::GenomeMaps;
use CXGN::BrAPI::v1::Samples;
use CXGN::BrAPI::v1::VendorSamples;

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

sub brapi_wrapper {
	my $self = shift;
	my $module = shift;

	my $brapi_package = 'CXGN::BrAPI::'.$self->version().'::'.$module;
	push @{$self->brapi_module_inst->{status}}, { 'info' => "Loading $brapi_package" };
	my $brapi_module = $brapi_package->new($self->brapi_module_inst);
	return $brapi_module;
}


1;
