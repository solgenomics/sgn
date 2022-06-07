
=head1 NAME

CXGN::MixedModels - a package to run user-specified mixed models

=head1 DESCRIPTION

  my $mm = CXGN::MixedModels->new();
  my $mm->phenotype_file("t/data/phenotype_data.csv");
  my $mm->dependent_variables(qw | |);
  my $mm->fixed_factors( qw | | );
  my $mm->random_factors( qw| | );
  my $mm->traits( qw|  | );

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::MixedModels;

use Moose;
use Data::Dumper;
use File::Slurp qw| slurp |;
use File::Basename;
use CXGN::Tools::Run;
use CXGN::Phenotypes::File;

=head2 dependent_variables()

sets the dependent variables (a listref of traits)

=cut

has 'dependent_variables' => (is => 'rw', isa => 'ArrayRef[Str]|Undef');

=head2 fixed_factors()

sets the fixed factors (listref)

=cut

has 'fixed_factors' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 fixed_factors_interaction()

sets the fixed factors with interaction (listref)

=cut

has 'fixed_factors_interaction' => (is => 'rw', isa => 'Ref', default => sub{[]});

=head2 random_factors_interaction()

sets the random factors with interaction (listref)

=cut

has 'random_factors_interaction' => (is => 'rw', isa => 'Ref', default => sub{[]});

=head2 variable_slope_factors()

=cut

has 'variable_slope_factors' => (is => 'rw', isa => 'Ref', default => sub{[]});

=head2 random_factors()

=cut

has 'random_factors' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 variable_slop_intersects

=cut

has 'variable_slope_intersects' => (is => 'rw', isa => 'Ref', default => sub {[]});

=head2 traits()

sets the traits

=cut

has 'traits' => (is => 'rw', isa => 'Ref');

=head2 levels()


=head2 engine()

sets the engine. Either sommer or lme4. Default: lme4.

=cut

has 'engine' => (is => 'rw', isa => 'Maybe[Str]', default => 'lme4' );

has 'levels' => (is => 'rw', isa => 'HashRef' );

has 'phenotype_file' => (is => 'rw', isa => 'CXGN::Phenotypes::File|Undef');

=head2 tempfile()

the tempfile that contains the phenotypic information.

=cut

has 'tempfile' => (is => 'rw', isa => 'Str|Undef');

sub BUILD {
    my $self = shift;

    my $phenotype_file;

    if ($self->tempfile()) {
	$phenotype_file = CXGN::Phenotypes::File->new( { file => $self->tempfile() } );
    }
    $self->phenotype_file($phenotype_file);

}

=head2 generate_model()

generates the model string, in lme4 format, from the current parameters

=cut

sub generate_model {
    my $self = shift;

    my $tempfile = $self->tempfile();
    my $dependent_variables = $self->dependent_variables();
    my $fixed_factors = $self->fixed_factors();
    my $fixed_factors_interaction = $self->fixed_factors_interaction();
    my $variable_slope_intersects = $self->variable_slope_intersects();
    my $random_factors = $self->random_factors();

    my $error;

    my @addends = ();

    print STDERR join("\n", ("DV", Dumper($dependent_variables), "FF", Dumper($fixed_factors), "RF", Dumper($random_factors), "TF", $tempfile, "FFI", Dumper($fixed_factors_interaction), "VSI: ", Dumper($variable_slope_intersects)));

    print STDERR Dumper($fixed_factors);
    my $model = "";

    if (! $dependent_variables || scalar(@$dependent_variables)==0) {
	die "Need a dependent variable(s) set in CXGN::MixedModels... Ciao!";
    }

    my $formatted_fixed_factors = "";
    if (@$fixed_factors) {
	$formatted_fixed_factors = join(" + ", @$fixed_factors);
	push @addends, $formatted_fixed_factors;
    }

    my $formatted_fixed_factors_interaction = "";
    foreach my $interaction (@$fixed_factors_interaction) {
	my $terms = "";
	if (ref($interaction)) {
	    $terms = join("*", @$interaction);
	    push @addends, $terms;
	}
	else {
	    $error = "Interaction terms are not correctly defined.";
	}
    }

    my $formatted_variable_slope_intersects = "";
    foreach my $variable_slope_groups (@$variable_slope_intersects) {
	if (exists($variable_slope_groups->[0]) && exists($variable_slope_groups->[1])) {
	    my $term = " (1+$variable_slope_groups->[0] \| $variable_slope_groups->[1]) ";
	    print STDERR "TERM: $term\n";
	    $formatted_variable_slope_intersects .= $term;
	    push @addends, $formatted_variable_slope_intersects;
	}
    }


    my $formatted_random_factors = "";
#    if ($random_factors_random_slope) {
#	$formatted_random_factors = " (1 + $random_factors->[0] | $random_factors->[1]) ";
#
#    }
 #   else {
	if (@$random_factors) {
	    $formatted_random_factors = join(" + ",  map { "(1|$_)" } @$random_factors);
	    push @addends, $formatted_random_factors;
	}

    #}
    $model .= join(" + ", @addends);

    return ($model, $error);
}

sub generate_model_sommer {
    my $self = shift;

    my $tempfile = $self->tempfile();
    my $dependent_variables = $self->dependent_variables();
    my $fixed_factors = $self->fixed_factors();
    my $fixed_factors_interaction = $self->fixed_factors_interaction();
    my $random_factors_interaction = $self->random_factors_interaction();
    my $variable_slope_intersects = $self->variable_slope_intersects();
    my $random_factors = $self->random_factors();

    print STDERR "FIXED FACTORS FED TO GENERATE MODEL SOMMER: ".Dumper($fixed_factors);

    my $error;

    ## generate the fixed factor formula
    #
    my $mmer_fixed_factors = "";
    my $mmer_random_factors = "";
    my $mmer_fixed_factors_interaction = "";

    if (scalar(@$dependent_variables) > 1) { die "Works only with one trait for now! :-("; }
    if (scalar(@$dependent_variables) > 0) {
	if (scalar(@$fixed_factors) == 0) { $mmer_fixed_factors = "1"; }
	else { $mmer_fixed_factors = join(" + ", @$fixed_factors); }

	$mmer_fixed_factors = $dependent_variables->[0] ." ~ ". $mmer_fixed_factors;

	if (scalar(@$random_factors)== 0) {$mmer_random_factors = "1"; }
	else { $mmer_random_factors = join("+", @$random_factors);}

	if (scalar(@$fixed_factors_interaction)== 0) {$mmer_fixed_factors_interaction = ""; }

	elsif (scalar(@$fixed_factors_interaction) != 2) { $error = "Works only with one interaction for now! :-(";}
	#if (scalar(@$random_factors_interaction)== 1) { $error .= "Works only with one interaction for now! :-(";}
	else { $mmer_fixed_factors_interaction = " + ". join(":", @$fixed_factors_interaction);}

	$mmer_random_factors = " ~ ".$mmer_random_factors ." ".$mmer_fixed_factors_interaction;
    }

    print STDERR "mmer_fixed_factors = $mmer_fixed_factors\n";
    print STDERR "mmer_random_factors = $mmer_random_factors\n";

    #my $data = { fixed_factors => $mmer_fixed_factors,
	#	 random_factors => $mmer_random_factors,
    #};

    my $model = [ $mmer_fixed_factors, $mmer_random_factors ];

    print STDERR "Data returned from generate_model_sommer: ".Dumper($model);

    return ($model, $error);
}



=head2 run_model()

runs the model along with the data provided in the phenotyping file.

Produces two results files. If germplasm was a random factor, is will produce files
with the tempfiles stem and the extensions .adjustedBLUPs and .BLUPs, if it was a
fixed factor, the extension are .adjustedBLUEs and .BLUEs. The files have the
accession identifiers in the first column, with the remaining columns being the
adjusted BLUEs, BLUEs, adjusted BLUPs or BLUPs for all the initially selected
traits.

=cut

sub run_model {
    my $self = shift;
    my $backend = shift || 'Slurm';
    my $cluster_host = shift || "localhost";
    my $cluster_shared_tempdir = shift;

    my $random_factors = '"'.join('","', @{$self->random_factors()}).'"';
    my $fixed_factors = '"'.join('","',@{$self->fixed_factors()}).'"';
    my $dependent_variables = '"'.join('","',@{$self->dependent_variables()}).'"';

    my $model;
    my $error;
    my $executable;
    if ($self->engine() eq "lme4") {
	($model, $error) = $self->generate_model();
	$executable = " R/mixed_models.R ";
    }

    elsif ($self->engine() eq "sommer") {
	($model, $error) = $self->generate_model_sommer();
	$executable = " R/mixed_models_sommer.R ";
    }

    my $dependent_variables_R = make_R_variable_name($dependent_variables);

    # generate params_file
    #
    my $param_file = $self->tempfile().".params";
    open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
    print $F "dependent_variables <- c($dependent_variables_R)\n";
    print $F "random_factors <- c($random_factors)\n";
    print $F "fixed_factors <- c($fixed_factors)\n";

    if ($self->engine() eq "lme4") {
	print $F "model <- \"$model\"\n";
    }
    elsif ($self->engine() eq "sommer") {
	print $F "fixed_model <- \"$model->[0]\"\n";
	print $F "random_model <- \"$model->[1]\"\n";
    }
    close($F);

    # run r script to create model
    #

    my $cmd = "R CMD BATCH  '--args datafile=\"".$self->tempfile()."\" paramfile=\"".$self->tempfile().".params\"' $executable ". $self->tempfile().".out";
    print STDERR "running R command $cmd...\n";

    print STDERR "running R command ".$self->tempfile()."...\n";

    my $ctr = CXGN::Tools::Run->new( { backend => $backend, working_dir => dirname($self->tempfile()), submit_host => $cluster_host } );


    $ctr->run_cluster($cmd);

    while ($ctr->alive()) {
	sleep(1);
    }
}

=head2 make_R_variable_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub make_R_variable_name {
    my $name = shift;
    $name =~ s/\s/\_/g;
    $name =~ s/\//\_/g;
    $name =~ tr/ /./;
    $name =~ tr/\//./;
    $name =~ s/\:/\_/g;
    $name =~ s/\|/\_/g;
    $name =~ s/\-/\_/g;

    return $name;
}





1;
