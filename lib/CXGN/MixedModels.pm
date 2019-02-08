
package CXGN::MixedModels;

use Moose;
use Data::Dumper;
use File::Slurp qw| slurp |;
use CXGN::Tools::Run;
use CXGN::Phenotypes::File;

has 'dependent_variable' => (is => 'rw', isa => 'Str');

has 'fixed_factors' => (is => 'rw', isa => 'Ref');

has 'fixed_factors_interaction' => (is => 'rw', isa => 'Ref');

has 'random_factors' => (is => 'rw', isa => 'Ref');

has 'phenotyping_data' => (is => 'rw', isa => 'Ref');

has 'random_factors_random_slope' => (is => 'rw', isa => 'Bool');

has 'traits' => (is => 'rw', isa => 'Ref');

has 'levels' => (is => 'rw', isa => 'HashRef' );

has 'phenotype_file' => (is => 'rw', isa => 'CXGN::Phenotypes::File');

has 'tempfile' => (is => 'rw', isa => 'Str');

sub BUILD {
    my $self = shift;

    my $phenotype_file = CXGN::Phenotypes::File->new( { file => $self->tempfile() } );

    $self->phenotype_file($phenotype_file);
   
}

sub generate_model {
    my $self = shift;

    my $tempfile = $self->tempfile();
    my $dependent_variable = $self->dependent_variable();
    my $fixed_factors = $self->fixed_factors();
    my $fixed_factors_interaction = $self->fixed_factors_interaction();
    my $random_factors = $self->random_factors();
    my $random_factors_random_slope = $self->random_factors_random_slope();
    
    print STDERR "DV: $dependent_variable FF: $fixed_factors - RF: $random_factors TF: $tempfile. FFI: $fixed_factors_interaction RFRS: $random_factors_random_slope\n";

    print STDERR Dumper($fixed_factors);
    my $model = "";
    $model .= "dependent_variable = \"$dependent_variable\"\n";
    my $formatted_fixed_factors = join(",", map { "\"$_\"" } @$fixed_factors);

    $model .= "fixed_factors <- c($formatted_fixed_factors)\n";

    if ($random_factors_random_slope) { 
        $model.= "random_factors_random_slope = T\n";
    }

    my $formatted_fixed_factors_interaction = 
    
    my $formatted_random_factors = "";
    if ($random_factors_random_slope) { 
	$formatted_random_factors = "\" (1 + $random_factors->[0] | $random_factors->[1]) \"";

    }
    else { 
	$formatted_random_factors = join(",", map { "\"(1|$_)\"" } @$random_factors);	
    }
    $model .= "random_factors <- c($formatted_random_factors)\n";
    
    return $model;
}

sub run_model {
    my $self = shift;

    my $tempfile = $self->tempfile();
    # generate params_file
    #
    my $param_file = $tempfile.".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    my $model = $self->generate_model();
    print $F $model;
    close($F);
    # run r script to create model
    #
    my $cmd = "R CMD BATCH  '--args datafile=\"".$tempfile."\" paramfile=\"".$tempfile.".params\"' /R/mixed_models.R $tempfile.out";
    
    print STDERR "running R command $cmd...\n";
    system($cmd);
    print STDERR "Done.\n";

    my $resultfile = $tempfile.".results";

}


1;
