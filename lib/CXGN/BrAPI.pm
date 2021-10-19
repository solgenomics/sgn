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
use CXGN::BrAPI::v1::Observations;
use CXGN::BrAPI::v1::ObservationUnits;
use CXGN::BrAPI::v1::ObservationTables;
use CXGN::BrAPI::v1::ServerInfo;
use CXGN::BrAPI::v1::Results;
use CXGN::BrAPI::v1::Images;
use CXGN::BrAPI::v1::Markers;
use CXGN::BrAPI::v1::Variables;
use CXGN::BrAPI::v2::Authentication;
use CXGN::BrAPI::v2::BreedingMethods;
use CXGN::BrAPI::v2::Calls;
use CXGN::BrAPI::v2::CommonCropNames;
use CXGN::BrAPI::v2::CallSets;
use CXGN::BrAPI::v2::Crossing;
use CXGN::BrAPI::v2::GenomeMaps;
use CXGN::BrAPI::v2::Germplasm;
use CXGN::BrAPI::v2::GermplasmAttributes;
use CXGN::BrAPI::v2::GermplasmAttributeValues;
use CXGN::BrAPI::v2::Events;
use CXGN::BrAPI::v2::Images;
use CXGN::BrAPI::v2::Lists;
use CXGN::BrAPI::v2::Locations;
use CXGN::BrAPI::v2::MarkerPositions;
use CXGN::BrAPI::v2::Observations;
use CXGN::BrAPI::v2::ObservationTables;
use CXGN::BrAPI::v2::ObservationUnits;
use CXGN::BrAPI::v2::ObservationVariables;
use CXGN::BrAPI::v2::People;
use CXGN::BrAPI::v2::Programs;
use CXGN::BrAPI::v2::ReferenceSets;
use CXGN::BrAPI::v2::References;
use CXGN::BrAPI::v2::Results;
use CXGN::BrAPI::v2::Samples;
use CXGN::BrAPI::v2::Seasons;
use CXGN::BrAPI::v2::SeedLots;
use CXGN::BrAPI::v2::ServerInfo;
use CXGN::BrAPI::v2::Studies;
use CXGN::BrAPI::v2::Traits;
use CXGN::BrAPI::v2::Trials;
use CXGN::BrAPI::v2::Variants;
use CXGN::BrAPI::v2::VariantSets;


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
	push @{$self->brapi_module_inst->{status}}, { 'INFO' => "Loading $brapi_package" };
	my $brapi_module = $brapi_package->new($self->brapi_module_inst);
	return $brapi_module;
}


1;
