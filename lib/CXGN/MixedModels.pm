
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
use File::Basename;
use File::Copy;
use CXGN::Tools::Run;
use CXGN::Job;
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
    foreach my $rf (@$random_factors) {
	if ($rf) {
	    $formatted_random_factors .= "(1|$rf)" ;
	    print STDERR " formatted random factor now $formatted_random_factors\n";
	    push @addends, $formatted_random_factors;
	}
    }
    
    #}
    $model .= join(" + ", @addends);

    return ($model, $error);
}

sub generate_model_sommer {
    my $self = shift;

    my $tempfile = $self->tempfile();
    my @dependent_variables_cleaned = map { make_R_variable_name($_) } @{$self->dependent_variables()};
    my $dependent_variables = \@dependent_variables_cleaned;
    my $fixed_factors = $self->fixed_factors();
    my $fixed_factors_interaction = $self->fixed_factors_interaction();
    my $random_factors_interaction = $self->random_factors_interaction();
    my $variable_slope_intersects = $self->variable_slope_intersects();
    my $random_factors = $self->random_factors();
    my $formula = "";
    print STDERR "FIXED FACTORS FED TO GENERATE MODEL SOMMER: ".Dumper($fixed_factors);
    print STDERR "FIXED Interaction FACTORS FED TO GENERATE MODEL SOMMER: ".Dumper($fixed_factors_interaction);
    print STDERR "RANDOM Interaction FACTORS FED TO GENERATE MODEL SOMMER: ".Dumper($random_factors_interaction);

    my $error;
    
    ## generate the fixed factor formula
    #
    my $mmer_fixed_factors = "";
    my $mmer_random_factors = "";
    my $mmer_fixed_factors_interaction = "";
    my $mmer_variable_slope_intersects ="";
    
    if (scalar(@$dependent_variables) > 1) { return ("", "For Sommer, only one trait can be analyzed at one time. Please go back and select only one trait or select lme4.") }
    
    if (scalar(@$dependent_variables) > 0) {
	print STDERR "preparing fixed factors...\n";
	if (scalar(@$fixed_factors) == 0) { $mmer_fixed_factors = "1"; }
	else { $mmer_fixed_factors = join(" + ", @$fixed_factors); }
	
	print STDERR "DEPENDENT VARIABLES: ".Dumper($dependent_variables);
	
	$mmer_fixed_factors = make_R_variable_name($dependent_variables->[0]) ." ~ ". $mmer_fixed_factors;
	
	if (scalar(@$random_factors)== 0) {$mmer_random_factors = 1; }

	else {
	    print STDERR "Preparing random factors...\n";
	    $mmer_random_factors = join("+", @$random_factors);
	}
	
	if (scalar(@$fixed_factors_interaction)== 0) {$mmer_fixed_factors_interaction = ""; }
	
	else {
	    
	    foreach my $interaction(@$fixed_factors_interaction){
		
		
		if (scalar(@$interaction) != 2) { $error = "interaction needs to be pairs :-(";}

		
		else { $mmer_fixed_factors_interaction .= " + ". join(":", @$interaction);}
	    }
	}


	#####
	# if (scalar(@$variable_slope_intersects)== 0) {$mmer_variable_slope_intersects = ""; }
	
	# else {
	    
	#     foreach my $intersects(@$variable_slope_intersects){
		
		
	# 	if (scalar(@$intersects) != 2) { $error = "intersects needs to be pairs :-(";}
	# 	#if (scalar(@$random_factors_interaction)== 1) { $error .= "Works only with one interaction for now! :-(";}
		
	# 	else { $mmer_variable_slope_intersects .= " + vsr(". join(",", @$intersects) . ")";} # vsr(Days, Subject)
	#     }
	# }
	
	
	
	# $mmer_random_factors = " ~ ".$mmer_random_factors ." ".$mmer_fixed_factors_interaction." ".$mmer_variable_slope_intersects;
    

# <<<<<<< HEAD
# =======
	if (scalar(@$variable_slope_intersects)== 0) {$mmer_variable_slope_intersects = ""; }
	
	else {
	    
	    foreach my $intersects(@$variable_slope_intersects){
		
		
		if (scalar(@$intersects) != 2) { $error = "intersects needs to be pairs :-(";}
		#if (scalar(@$random_factors_interaction)== 1) { $error .= "Works only with one interaction for now! :-(";}
		
		else { $mmer_variable_slope_intersects .= " + vsr(". join(",", @$intersects) . ")";} # vsr(Days, Subject)
	    }
	}
	
	if ($mmer_random_factors){
	    $formula = " ~ ".$mmer_random_factors ;
	}
	if ($mmer_fixed_factors_interaction) {
	    $formula.=" ".$mmer_fixed_factors_interaction;
	}
	if ($mmer_variable_slope_intersects) {
	    $formula.=" ".$mmer_variable_slope_intersects;
	}
    
	# >>>>>>> master
	#location:genotype
	
	print STDERR "mmer_fixed_factors = $mmer_fixed_factors\n";
	print STDERR "mmer_random_factors = $formula\n";
	
	#my $data = { fixed_factors => $mmer_fixed_factors,
	#	 random_factors => $mmer_random_factors,
	#};
	
	my $model = [ $mmer_fixed_factors, $formula ];
	
	print STDERR "Data returned from generate_model_sommer: ".Dumper($model);
	
	return ($model, $error);
    }
    else {
	return ("", $error);
    }
}



=head2 run_model()

runs the model along with the data provided in the phenotyping file.

Produces two results files. If germplasm was a random factor, is will produce files
with the tempfiles stem and the extensions .adjustedBLUPs and .BLUPs, if it was a
fixed factor, the extension are .adjustedBLUEs and .BLUEs. The files have the
accession identifiers in the first column, with the remaining columns being the
adjusted BLUEs, BLUEs, adjusted BLUPs or BLUPs for all the initially selected
traits.

The files from the dataset will contain trait names that are incompatible with R. These names are converted using the clean_file subroutine. The conversion takes place and is saved in a file with a .clean extension. Then, the .clean file is moved to the previous file name, such that there is not difference in file naming.


The result files will initially contain these R-based names as well. The conversion between R and dataset names are stored in a file with the extension .traits . The inital result files will be converted back to dataset names using the sub convert_file_headers_back_to_breedbase_traits() function. The conversion is saved in a file with the .original_traits extension, which is then moved back to the original file name once the conversion is complete. 
  


=cut

sub run_model {
    my $self = shift;
    my $backend = shift || 'Slurm';
    my $cluster_host = shift || "localhost";
    my $cluster_shared_tempdir = shift;
	my $job_record_config = shift;

    my $random_factors = '"'.join('","', @{$self->random_factors()}).'"';
    my $fixed_factors = '"'.join('","',@{$self->fixed_factors()}).'"';
    my $dependent_variables = '"'.join('","',@{$self->dependent_variables()}).'"';

    my $model;
    my $error;
    my $executable;

	my $job_record;
    eval { 
	
	if ($self->engine() eq "lme4") {
	    ($model, $error) = $self->generate_model();
	    $executable = " R/mixed_models.R ";
	}
	
	elsif ($self->engine() eq "sommer") {
	    ($model, $error) = $self->generate_model_sommer();
	    $executable = " R/mixed_models_sommer.R ";
	}

	if ($error) { die "$error"; }
	
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
	
	# clean phenotype file so that trait names are R compatible
	#
	my $clean_tempfile = $self->clean_file($self->tempfile());
	
	# run r script to create model
	#
	my $cmd = "R CMD BATCH  '--args datafile=\"".$clean_tempfile."\" paramfile=\"".$self->tempfile().".params\"' $executable ". $self->tempfile().".out";
	print STDERR "running R command $cmd...\n";
	
	print STDERR "running R command $clean_tempfile...\n";
	
	my $cxgn_tools_run_config = { backend => $backend, working_dir => dirname($self->tempfile()), submit_host => $cluster_host };
	my $ctr = CXGN::Tools::Run->new( $cxgn_tools_run_config );
	$job_record = CXGN::Job->new({
		schema => $job_record_config->{schema},
		people_schema => $job_record_config->{people_schema},
		sp_person_id => $job_record_config->{user},
		cmd => $cmd,
		cxgn_tools_run_config => $cxgn_tools_run_config,
		name => $job_record_config->{name},
		job_type => 'phenotypic_analysis'
	});
	
	$job_record->update_status("submitted");
	$ctr->run_cluster($cmd.$job_record->generate_finish_timestamp_cmd());
	
	while ($ctr->alive()) {
	    sleep(1);
	}

	my $finished = $job_record->read_finish_timestamp();
	if (!$finished) {
		$job_record->update_status("failed");
	} else {
		$job_record->update_status("finished");
	}
	
	# replace the R-compatible traits with original trait names
	#
	print STDERR "Converting files back to non-R headers...\n";
	foreach my $f (
	    $self->tempfile().".adjustedBLUPs",
	    $self->tempfile().".BLUPs",
	    $self->tempfile().".BLUEs",
	    $self->tempfile().".adjustedBLUEs",
	    $self->tempfile().".anova",
	    $self->tempfile().".varcomp",
	    ) {
	    
	    my $conversion_matrix = $self->read_conversion_matrix($self->tempfile().".traits");
	    
	    if (-e $f) { 
		$self->convert_file_headers_back_to_breedbase_traits($f, $conversion_matrix);
	    }
	    else {
		print STDERR "File $f does not exist, not converting. This may be normal.\n";
	    }
	}
    };

    if ($@) {
	$error = $@;
	$job_record->update_status("failed");
    }

    return $error;    
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

sub clean_file {
    my $self = shift;
    my $file = shift;

    open(my $PF, "<", $file) || die "Can't open pheno file ".$file."_phenotype.txt";
    open(my $CLEAN, ">", $file.".clean") || die "Can't open ".$file.".clean for writing";

    open(my $TRAITS, ">", $file.".traits") || die "Can't open ".$file.".traits for writing";

    
    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];

    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	my $R_t = make_R_variable_name($t);
	print $TRAITS "$R_t\t$t\n";
	$t = $R_t;
    }

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    while(<$PF>) {
	print $CLEAN $_;
    }

    close($PF);
    print STDERR "moving $file to $file.before_clean...\n";
    move($file, $file.".before_clean");

    print STDERR "moving $file.clean to $file...\n";
    move($file.".clean", $file);

    return $file;
}


sub convert_file_headers_back_to_breedbase_traits {
    my $self = shift;
    my $file = shift;
    my $conversion_matrix = shift;

    open(my $F, "<", $file) ||  die "Can't open $file\n";

    print STDERR "Opening ".$self->tempfile().".original_traits for writing...\n";
    open(my $G, ">", $file.".original_traits") || die "Can't open $file.original_traits";
    
    my $header = <$F>;
    chomp($header);
    
    my @fields = split /\t/, $header;
    
    foreach my $f (@fields) {
	if ($conversion_matrix->{$f}) {
	    print STDERR "Converting $f to $conversion_matrix->{$f}...\n";
	    $f = $conversion_matrix->{$f};
	}
    }

    
    print $G join("\t", @fields)."\n";
    while(<$F>) {
	chomp;

	# replace NA or . with undef throughout the file
	# (strings are not accepted by store phenotypes routine
	# used in analysis storage).
	#
	my @fields = split /\t/;
	foreach my $f (@fields) {
	    if ($f eq "NA" || $f eq '.') { $f = undef; }
	}
	my $line = join("\t", @fields);
	print $G "$line\n";
    }
    close($G);

    print STDERR "move file $file.original_traits back to $file...\n";
    move($file.".original_traits", $file);
}

sub read_conversion_matrix {
    my $self = shift;
    my $file = shift;

    my $conversion_file = $file;
    
    open(my $F, "<", $conversion_file) || die "Can't open file $conversion_file";

    my %conversion_matrix;
    
    while (<$F>) {
	chomp;
	my ($new, $old) = split "\t";
	$conversion_matrix{$new} = $old;
    }
    return \%conversion_matrix;
    }


1;
