package CXGN::Trial::TrialDesignStore;

=head1 NAME

CXGN::Trial::TrialDesignStore - Module to validate and store a trial's design (both genotyping and phenotyping trials)


=head1 USAGE

 my $design_store = CXGN::Trial::TrialDesignStore->new({
	bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	design_type => 'CRD',
	design => $design_hash,
 });
 my $validate_error = $design_store->validate_design();
 if ($validate_error) {
 	print STDERR "VALIDATE ERROR: $validate_error\n";
 } else {
 	try {
		$design_store->store();
	} catch {
		print STDERR "ERROR SAVING TRIAL!: $_\n";
 	};
}


=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales (nm529@cornell.edu)

=cut


use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use CXGN::BreedersToolbox::Projects;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => (
	is       => 'rw',
	isa      => 'DBIx::Class::Schema',
	predicate => 'has_chado_schema',
	required => 1,
);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str|ArrayRef]]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );

sub validate_design {
	my $self = shift;
	my $chado_schema = $self->bcs_schema;
	my $design_type = $self->design_type;
	my $design = $self->design;
	my $error = '';

	if ($self->is_genotyping && $design_type ne 'genotyping_plate') {
		$error .= "is_genotyping is true; however design_type not equal to 'genotyping_plate'";
	}
	if (!$self->is_genotyping && $design_type eq 'genotyping_plate') {
		$error .= "The design_type 'genotyping_plate' requires is_genotyping to be true";
	}
	if ($design_type ne 'genotyping_plate' && $design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type && 'Augmented' && $design_type ne 'RCBD'){
		$error .= "Design type must be either: genotyping_plate, CRD, Alpha, Augmented, or RCBD";
	}
	my @valid_properties;
	if ($design_type eq 'genotyping_plate'){
		@valid_properties = ('stock_name', 'plot_name'); #plot_name is tissue sample name in well. during store, the stock is saved as stock_type 'tissue_sample' with uniquename = plot_name 
	} elsif ($design_type eq 'CRD' || $design_type eq 'Alpha' || $design_type eq 'Augmented' || $design_type eq 'RCBD'){
		@valid_properties = ('stock_name', 'plot_name', 'plot_number', 'block_number', 'rep_number', 'is_a_control', 'range_number', 'row_number', 'col_number', 'plant_names');
	}
	
}

sub store {
	my $self = shift;
	my $chado_schema = $self->bcs_schema;
	my $design_type = $self->design_type;
	my %design = %{$self->design};
	
}

1;
