package CXGN::DroneImagery::DesignFactors;

=head1 NAME

CXGN::DroneImagery::DesignFactors - recorded design effects for drone models

=head1 DESCRIPTION

These functions consume recorded design replication tags and physical blocks.
They never infer blocking groups from accession occurrence counters. CRD has
no blocking group; RCBD uses blocks; Alpha/Lattice uses replicate/block groups.
Missing required metadata raises a named error before model execution.

=head1 METHODS

=head2 kind($study_design)

Return CRD, RCBD or Incomplete for an explicitly supported declared design.

=head2 fixed_terms($study_design, $replicate_column, $block_column)

Return the fixed design formula fragment using the supplied column names.

=head2 group_key($study_design, $recorded_replicate, $block, $environment)

Return an unambiguous categorical key, or undef for an unblocked CRD.

=head2 validate_rows($study_design, \@rich_phenotype_rows)

Validate the recorded obsunit_rep and obsunit_block fields required by a design.

=head2 category_codes(\@keys)

Return a deterministic text-key to positive-integer category bijection for
numeric model matrices. Literal 01, 1, 0 and NA remain distinct keys.

=head2 numeric_group_code($study_design, $replicate, $block, \%codes)

Resolve the F90 matrix metadata column from its explicit category map. A CRD
uses zero in this unused metadata column; no blocking factor is introduced.

=head2 native_executable_error($selection, \@search_paths)

Return a named prerequisite error for a missing BLUPF90/AIREMLF90 executable,
or undef when available or irrelevant. Search paths default to the process PATH.

=head2 r_package_error($selection)

Check the loadable ASReml R namespace only for an ASReml selection. Return a
named missing-package prerequisite or undef. The read-only check is memoized
per process; it does not activate, install, or claim acceptance of a license.

=head2 statistics_prerequisite_error($selection)

Return the first native-executable or R-package prerequisite error. Both
primary and simulation callers use this shared entrypoint before fitting.

=head2 cnn_design($prediction_type, \@declared_trial_designs)

Resolve one supported declared design for the optional CNN mixed-model
evaluation. Ordinary CNN predictions return undef and require no design model.

=head2 working_directory($existing_root, $selection)

Return a fresh retained directory for an F90 request. The original programs
write fixed solution/residual basenames, so requests cannot share their cwd.
Other engines retain the supplied root and their existing unique file paths.

=head2 validate_genotype_names(\@rows, $id_key, $name_key)

Validate both directions of known genotype ID/name mapping before name-keyed
genetic output. Default keys match rich phenotype rows. Repeated observations
of one consistent genotype are valid; missing IDs retain legacy name-only use.
Plot-only readers do not call this guard.

=head2 native_convergence_criterion()

Return the documented original F90 solver standard criterion, 1e-12. It is
independent of the UI's Sommer matrix-inversion tolerance. Keep this explicit
in archived parameter files so numerical accuracy is reproducible.

=head2 native_inverse_tolerance($selection)

Return the documented original backend precision for positive-definite/general
inverse subroutines: BLUPF90 1e-12, AIREMLF90 1e-14. It is separate from model
convergence and Sommer inversion tolerance. Explicit parameters retain it.

=head2 native_missing_value()

Return the explicit native missing-observation code, -999. It is not an
accession/group code or a replacement for a measured zero.

=head2 native_observation($value)

Return the missing code for absent/empty input, otherwise a finite numeric
observation. Preserve zero and refuse a measured value that collides with the
reserved missing code; never silently discard or rescale an observation.

=head2 native_solver_settings($selection)

Return explicit parameter_options, solver and convergence_criterion for an
original F90 backend. BLUPF90 uses its documented FSPAK mode for stable saved
coefficient solutions. AIREMLF90 retains its own default solver; no BLUP-only
solver option is passed to it. Both retain the same equations and covariance.

=head2 native_variance_design_error($selection, $time_levels, $coefficients)

Return a named AIREML error for a saturated physical-plot polynomial covariance
that cannot be separated from its free residual variance function. Fixed-
covariance BLUPF90 models do not need variance-component identifiability.

=head2 native_fit_error($selection, $parameter_file, $data_file, $log_file, $cwd)

Check completion, finite solution/readback files and the reported native solver.
AIREML additionally requires a converged final section and positive finite
residual variances at the actual supplied covariates. Return a named error
before any output can be saved, or undef. This does not change an estimator.

=head2 native_residual_start($declared_variance, \@observed_basis_rows)

Derive an initial constant log-residual variance from the actual declared R
and supplied constant intercept. The original binary fixes coefficients whose
starts are exactly zero (observed free-parameter mask); intended free zeros
therefore receive a named 0.001 log-scale activation, near the declared scale.
Return coefficients, initial_variance_range and activation for provenance.
Time coordinates are never treated as residual coefficients.

=cut

use strict;
use warnings;
use JSON::PP;
use File::Spec;
use File::Temp qw(tempdir);
use POSIX qw(isfinite);

# Labels are recorded design tags, never operational accession occurrences.
sub kind {
    my ($design) = @_;
    die "Declare studyDesign before fitting drone design effects.\n" unless defined($design) && length($design);
    return 'CRD' if $design =~ /^(?:CRD|completely randomi[sz]ed(?: design)?)$/i;
    return 'RCBD' if $design =~ /RCBD|randomi[sz]ed complete block|augmented/i;
    return 'Incomplete' if $design =~ /alpha|lattice|incomplete/i;
    die "Unsupported studyDesign for drone design effects: $design\n";
}

sub fixed_terms {
    my ($design, $rep, $block) = @_;
    $rep //= 'replicate'; $block //= 'block';
    my $kind = kind($design);
    return '1' if $kind eq 'CRD';
    return $block if $kind eq 'RCBD';
    return "$rep/$block";
}

sub group_key {
    my ($design, $rep, $block, $environment) = @_;
    my $kind = kind($design);
    return undef if $kind eq 'CRD'; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    die "Recorded block metadata is missing; an accession occurrence cannot replace it.\n" unless defined($block) && length($block);
    my @key = (defined($environment) ? "$environment" : (), "$block");
    if ($kind eq 'Incomplete') {
        die "Recorded design replication metadata is missing for an incomplete-block design.\n" unless defined($rep) && length($rep);
        unshift @key, "$rep";
    }
    return JSON::PP->new->canonical->encode(\@key);
}

sub validate_rows {
    my ($design, $rows) = @_;
    for my $row (@$rows) {
        group_key($design,$row->{obsunit_rep},$row->{obsunit_block});
    }
    return 1;
}

# R/YapRI's numeric matrices need integer category codes. The bijection is
# local to this model; literal tags such as 01, 1, 0 and NA stay distinct.
sub category_codes {
    my ($keys) = @_;
    my %seen = map {defined($_) ? ($_ => 1) : ()} @$keys;
    my $index = 0;
    return {map {$_ => ++$index} sort keys %seen};
}

sub numeric_group_code {
    my ($design,$rep,$block,$codes) = @_;
    my $key = group_key($design,$rep,$block);
    return 0 if !defined($key); # Unused metadata column in an unblocked CRD.
    die "Recorded group is missing from the model category map.\n" if !exists($codes->{$key});
    return $codes->{$key};
}

sub native_executable_error {
    my ($selection,$paths) = @_;
    my ($binary) = ($selection // '') =~ /^(blupf90|airemlf90)_/;
    return undef unless $binary; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    $paths ||= [File::Spec->path];
    for my $directory (@$paths) {
        my $file = File::Spec->catfile($directory,$binary);
        return undef if -f $file && -x $file; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    }
    return "Required statistics executable $binary was not found in PATH. Configure that project engine before running this analysis.";
}

my %r_package_available;
sub r_package_error {
    my ($selection) = @_;
    return undef unless ($selection // '') =~ /^asreml_/; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    if (!exists($r_package_available{asreml})) {
        my $pid = open(my $check, '-|', 'Rscript', '--vanilla', '-e',
            'quit(status=if(suppressWarnings(suppressMessages(requireNamespace("asreml",quietly=TRUE))))0L else 1L)');
        if ($pid) {
            # Discard package startup output; never report license details.
            1 while <$check>;
            my $loaded = close($check);
            $r_package_available{asreml} = $loaded ? 1 : 0;
        } else {
            $r_package_available{asreml} = 0;
        }
    }
    return undef if $r_package_available{asreml}; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    return 'The selected model requires the licensed ASReml R package, which is not loadable in this runtime. Configure the project package and valid license before running this analysis.';
}

sub statistics_prerequisite_error {
    my ($selection) = @_;
    return native_executable_error($selection) || r_package_error($selection);
}

sub cnn_design {
    my ($prediction_type,$designs) = @_;
    return undef unless ($prediction_type // '') eq 'cnn_prediction_mixed_model'; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    die "CNN mixed-model evaluation requires declared trial designs.\n" unless ref($designs) eq 'ARRAY' && @$designs;
    my %unique;
    for my $design (@$designs) {
        kind($design);
        $unique{lc($design)}=1;
    }
    die "CNN mixed-model evaluation requires one supported studyDesign.\n" unless keys(%unique)==1;
    return $designs->[0];
}

sub working_directory {
    my ($root,$selection) = @_;
    die "The model working-directory root must exist.\n" unless defined($root) && -d $root;
    return $root unless ($selection // '') =~ /^(?:blupf90|airemlf90)_/;
    return tempdir('drone_f90_XXXXX',DIR=>$root,CLEANUP=>0);
}

sub validate_genotype_names {
    my ($rows,$id_key,$name_key) = @_;
    $id_key //= 'germplasm_stock_id';
    $name_key //= 'germplasm_uniquename';
    my (%name_to_id,%id_to_name);
    for my $row (@$rows) {
        my ($id,$name) = @{$row}{$id_key,$name_key};
        next unless defined($id) && length($id) && $id !~ /^(?:0|NA|--|-|\.|\.\.)$/ && defined($name) && length($name);
        if (exists($name_to_id{$name}) && $name_to_id{$name} ne $id) {
            die "A genotype name maps to multiple known germplasm IDs; this name-keyed analysis cannot represent them separately.\n";
        }
        if (exists($id_to_name{$id}) && $id_to_name{$id} ne $name) {
            die "A known germplasm ID maps to multiple genotype names; this name-keyed analysis requires consistent genotype metadata.\n";
        }
        $name_to_id{$name}=$id;
        $id_to_name{$id}=$name;
    }
    return 1;
}

sub native_convergence_criterion { return 1e-12; }

sub native_inverse_tolerance {
    my ($selection) = @_;
    return 1e-12 if ($selection // '') =~ /^blupf90(?:_|$)/;
    return 1e-14 if ($selection // '') =~ /^airemlf90(?:_|$)/;
    die "Select an original native backend for inverse precision.\n";
}

sub native_missing_value { return -999; }

sub native_observation {
    my ($value) = @_;
    return native_missing_value() unless defined($value) && length($value);
    my $number = _native_number($value);
    die "Native statistics observations must be finite numeric values.\n" unless defined($number);
    die "A measured value equals the reserved native missing-observation code -999; no observations were silently discarded.\n"
        if $number == native_missing_value();
    return $number;
}


sub native_solver_settings {
    my ($selection) = @_;
    die "Select an original F90 backend for native solver settings.\n" unless ($selection // '') =~ /^(blupf90|airemlf90)_/;
    my $backend=$1;
    my $criterion=native_convergence_criterion();
    my @options=('OPTION conv_crit '.$criterion,'OPTION missing '.native_missing_value(),'OPTION tol '.native_inverse_tolerance($selection));
    push @options,'OPTION solv_method FSPAK' if $backend eq 'blupf90';
    return {solver=>$backend eq 'blupf90' ? 'FSPAK' : 'AIREMLF90 default',convergence_criterion=>$criterion,inverse_tolerance=>native_inverse_tolerance($selection),parameter_options=>\@options};
}

sub native_variance_design_error {
    my ($selection,$time_levels,$coefficients) = @_;
    return undef unless ($selection // '') =~ /^airemlf90_/; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    return 'The AIREML variance model requires more distinct time levels than Legendre coefficients; saturated physical-plot covariance and free residual variances are not separately identifiable.'
        if $time_levels <= $coefficients;
    return undef; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
}

sub _native_number {
    my ($text) = @_;
    return undef unless defined($text) && $text =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eEdD][+-]?\d+)?$/; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    $text =~ tr/dD/eE/;
    my $value=0+$text;
    return isfinite($value) ? $value : undef;
}

sub native_fit_error {
    my ($selection,$parameter_file,$data_file,$log_file,$cwd) = @_;
    return undef unless ($selection // '') =~ /^(?:blupf90|airemlf90)_/; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    return 'The native statistics solver did not produce a complete result; no genotype estimates were saved.'
        unless -s $log_file && -s File::Spec->catfile($cwd,'solutions') && -s File::Spec->catfile($cwd,'yhat_residual');
    open(my $log_handle,'<',$log_file) or return 'The native solver log could not be read.';
    my @log=<$log_handle>;close $log_handle;
    open(my $parameter_handle,'<',$parameter_file) or return 'The native solver parameters could not be read.';
    my @parameters=<$parameter_handle>;close $parameter_handle;
    for my $name ('solutions','yhat_residual') {
        open(my $handle,'<',File::Spec->catfile($cwd,$name)) or return 'The native solver output could not be read.';
        <$handle> if $name eq 'solutions';
        my $records=0;
        while(my $line=<$handle>) {
            my @values=split ' ',$line;
            my @numbers=$name eq 'solutions' ? @values[0..3] : @values[0..1];
            if (grep {!defined(_native_number($_))} @numbers) {
                close $handle;
                return 'The native solver returned nonfinite or incomplete coefficients/readback; no genotype estimates were saved.';
            }
            $records++;
        }
        close $handle;
        return 'The native solver returned an empty numerical result.' unless $records;
    }
    if ($selection =~ /^blupf90_/) {
        return 'The native coefficient solver did not report the required original FSPAK mode.'
            unless grep {/solving method.*FSPAK/} @log;
        return undef; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    }
    my @final=grep {$log[$_] =~ /^Final Estimates/} 0..$#log;
    return 'AIREML did not report a complete final variance result; no genotype estimates were saved.'
        unless @final && grep {/FINISHED \(AIREMLF90\)/} @log;
    my ($criterion) = map {/OPTION conv_crit\s+(\S+)/ ? _native_number($1) : ()} @parameters;
    my @convergence=map {/In round\s+\d+\s+convergence=\s*(\S+)/ ? _native_number($1) : ()} @log;
    my @delta=map {/delta convergence=\s*(\S+)/ ? _native_number($1) : ()} @log;
    return 'AIREML did not report convergence; no genotype estimates were saved.'
        unless defined($criterion) && $criterion>0 && @convergence && defined($convergence[-1]) &&
          ($convergence[-1] <= $criterion || (@delta && defined($delta[-1]) && $delta[-1] <= sqrt($criterion)));
    my @positions=map {/OPTION hetres_pos\s+(.+)/ ? split(' ',$1) : ()} @parameters;
    my @initial_gamma=map {/OPTION hetres_pol\s+(.+)/ ? split(' ',$1) : ()} @parameters;
    return 'AIREML residual-variance coefficients were inactive at zero initialization; no estimated heterogeneous result was saved.'
        if grep {defined(_native_number($_)) && _native_number($_)==0} @initial_gamma;
    my %gamma;
    for my $line (@log[$final[-1]..$#log]) {
        if ($line =~ /^\s*1\s+-th trait:\s*(\d+)\s+-th coefficient\s*=\s*(\S+)/) {
            $gamma{$1}=_native_number($2);
        }
    }
    my @gamma=map {$gamma{$_}} sort {$a<=>$b} keys %gamma;
    return 'AIREML did not return supported finite residual-variance coefficients.'
        unless @positions && (@gamma==@positions || @gamma==@positions+1) && !grep {!defined($_)} @gamma;
    open(my $data_handle,'<',$data_file) or return 'AIREML covariates could not be read for result validation.';
    my $records=0;
    while(my $line=<$data_handle>) {
        my @values=split ' ',$line;
        my $intercept=@gamma==@positions+1 ? 1 : 0;
        my $log_variance=$intercept ? $gamma[0] : 0;
        for my $i (0..$#positions) {
            my $value=_native_number($values[$positions[$i]-1]);
            if (!defined($value)) {close $data_handle;return 'AIREML residual-variance covariates are incomplete.';}
            $log_variance+=$gamma[$i+$intercept]*$value;
        }
        my $variance=eval {exp($log_variance)};
        if ($@ || !defined($variance) || !isfinite($variance) || $variance<=0) {
            close $data_handle;
            return 'AIREML residual-variance estimation failed numerically (zero or nonfinite fitted variance); no genotype estimates were saved.';
        }
        $records++;
    }
    close $data_handle;
    return $records ? undef : 'AIREML received no records for residual-variance validation.';
}

sub native_residual_start {
    my ($declared_variance,$basis_rows) = @_;
    die "Initial native residual variance must be finite and positive.\n" unless defined($declared_variance) && isfinite($declared_variance) && $declared_variance>0;
    die "Observed native residual basis rows are required.\n" unless ref($basis_rows) eq 'ARRAY' && @$basis_rows && ref($basis_rows->[0]) eq 'ARRAY' && @{$basis_rows->[0]};
    my $count=@{$basis_rows->[0]};
    my $intercept=_native_number($basis_rows->[0][0]);
    die "The native residual basis requires its supplied nonzero constant intercept.\n" unless defined($intercept) && $intercept!=0;
    my @coefficients=(0)x$count;
    $coefficients[0]=log($declared_variance)/$intercept;
    my $activation=0.001;
    for my $coefficient (@coefficients) {$coefficient=$activation if $coefficient==0;}
    my ($minimum,$maximum);
    for my $row (@$basis_rows) {
        die "Native residual basis rows are inconsistent.\n" unless ref($row) eq 'ARRAY' && @$row==$count;
        my $first=_native_number($row->[0]);
        die "The supplied native residual intercept is not constant.\n" unless defined($first) && abs($first-$intercept)<1e-12*(1+abs($intercept));
        my $log_variance=0;
        for my $i (0..$#coefficients) {
            my $value=_native_number($row->[$i]);
            die "Native residual covariates must be finite.\n" unless defined($value);
            $log_variance+=$coefficients[$i]*$value;
        }
        my $variance=eval {exp($log_variance)};
        die "Initial native residual variances are not finite and positive.\n" unless !$@ && defined($variance) && isfinite($variance) && $variance>0;
        $minimum=$variance if !defined($minimum) || $variance<$minimum;
        $maximum=$variance if !defined($maximum) || $variance>$maximum;
    }
    return {coefficients=>\@coefficients,initial_variance_range=>[$minimum,$maximum],activation=>$activation};
}

1;
