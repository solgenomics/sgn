package CXGN::DroneImagery::NativeResults;

=head1 NAME

CXGN::DroneImagery::NativeResults - native random-regression variance readback

=head1 DESCRIPTION

Read the original F90 random-regression covariance contract without changing its
estimator or kernels. Final AIREML coefficients and supplied BLUP covariances are
distinct. Project full covariances at the actual numeric time covariates, retain
physical plot identities, and report an explicit observation-scale variance
share. This is not entry-mean heritability or prediction reliability.

=head1 FUNCTIONS

=head2 observation_mask($data_file, $parameter_file)

Return an arrayref of observed (1) or missing (0) flags in original data-row
order, using the actual observation position and missing code. Numeric zero
remains observed when the declared missing code is -999. No model is fitted.

=head2 summarize(%arguments)

Required arguments are parameter_file, data_file, log_file, cwd, backend
(blupf90 or airemlf90), time_scale (DAP or GDD), and unit_metadata, keyed by the
native physical-unit factor with plot_id and genotype_id. Optional
genotype_factor must agree with the data. kernel_origin controls biological
interpretation; unknown and phenotype-derived kernels never receive an
unqualified heritability label. Returns a version-2 hash with full row-major
covariance/correlation arrays, residual coefficients/diagnostics, actual basis,
fixed reference units and equal weights, and per-time marginal variances/shares.
Dies with a named error for an unsupported or invalid numerical contract.

Covariance validity uses the existing base R symmetric eigen/Cholesky routines,
without fitting a model, adding packages, repairing a matrix, or renormalizing
the supplied kernel. Original inputs are read-only. Applied covariance kernels
need full numerical rank above the original DENSEOP operational-zero precision
and the selected backend inverse tolerance, on a relative eigenvalue scale.
These runtime limits are archived separately from variance-model convergence.

A valid nominal printed covariance is retained unchanged. If text rounding makes
it indefinite, the reported native eigensystem may supply an explicitly
approximate representation only after eigenvalue, orthogonality and propagated
serialization-interval consistency checks. Original covariance/correlation
values, exact printed tokens, eigenvectors/eigenvalues and bounds are retained.
No vector normalization, eigenvalue clipping, matrix repair or unprinted exact
precision is inferred. Representation bounds are not statistical SE or confidence
intervals.

=cut

use strict;
use warnings;
use File::Spec;
use File::Temp qw(tempfile);
use POSIX qw(isfinite);
use Digest::SHA ();
use CXGN::DroneImagery::DesignFactors ();

sub _fail { die "Native RR variance summary: $_[0]\n"; }

sub _number {
    my ($text) = @_;
    _fail('A numerical field is missing or nonfinite.') unless defined($text) &&
        $text =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eEdD][+-]?\d+)?$/;
    $text =~ tr/dD/eE/;
    my $value = 0 + $text;
    _fail('A numerical field is nonfinite.') unless isfinite($value);
    return $value;
}

sub _numbers { return [map {_number($_)} split ' ', $_[0]]; }

sub _lines {
    my ($path) = @_;
    open(my $handle, '<', $path) or _fail("Cannot read $path.");
    my @lines = <$handle>;
    close($handle);
    for (@lines) {s/^\s+|\s+$//g;}
    return \@lines;
}

sub _matrix_rows {
    my ($lines, $index, $size) = @_;
    my @matrix;
    for (1..$size) {
        ++$$index;
        _fail('A covariance matrix is incomplete.') if $$index > $#$lines;
        my $row = _numbers($lines->[$$index]);
        _fail('A covariance matrix has inconsistent dimensions.') unless @$row == $size;
        push @matrix, $row;
    }
    return \@matrix;
}

sub _parameters {
    my ($path) = @_;
    my $lines = _lines($path);
    my (@groups, @effects, $residual, $observation_column);
    my $missing_value = 0;
    my $inverse_tolerance;
    my (@residual_positions, @initial_gamma);
    for my $i (0..$#$lines) {
        my $line = $lines->[$i];
        if ($line =~ /^EFFECTS:/) {
            my $j = $i + 1;
            while ($j <= $#$lines && $lines->[$j] !~ /^RANDOM_RESIDUAL/) {
                if (length($lines->[$j])) {
                    my @effect = split ' ', $lines->[$j];
                    _fail('The native effect definition is unsupported.') unless @effect >= 3;
                    push @effects, \@effect;
                }
                ++$j;
            }
        }
        $observation_column = _number($lines->[$i+1]) if $line eq 'OBSERVATION(S)';
        $missing_value = _number($1) if $line =~ /^OPTION missing\s+(\S+)$/;
        $inverse_tolerance = _number($1) if $line =~ /^OPTION tol\s+(\S+)$/;
        if ($line eq 'RANDOM_RESIDUAL VALUES') {
            my $values = _numbers($lines->[$i + 1]);
            _fail('Only a single-trait native RR residual is supported.') unless @$values == 1 && $values->[0] > 0;
            $residual = $values->[0];
        }
        if ($line eq 'RANDOM_GROUP') {
            my $group = _numbers($lines->[++$i]);
            _fail('The native random group is empty.') unless @$group;
            _fail('The native random type header is missing.') unless $lines->[++$i] eq 'RANDOM_TYPE';
            my $type = $lines->[++$i];
            _fail('The native kernel file header is missing.') unless $lines->[++$i] eq 'FILE';
            my $file = $lines->[++$i];
            _fail('The native covariance header is missing.') unless $lines->[++$i] eq '(CO)VARIANCES';
            my $covariance = _matrix_rows($lines, \$i, scalar(@$group));
            push @groups, {effects=>$group, random_type=>$type, file=>$file, covariance=>$covariance};
        }
        @residual_positions = @{_numbers($1)} if $line =~ /^OPTION hetres_pos\s+(.+)/;
        @initial_gamma = @{_numbers($1)} if $line =~ /^OPTION hetres_pol\s+(.+)/;
    }
    _fail('Two native RR random groups and one supplied residual are required.') unless @groups == 2 && defined($residual);
    for my $group (@groups) {
        my (@positions, $identity_column, $levels);
        for my $index (@{$group->{effects}}) {
            _fail('A random effect index is invalid.') unless $index >= 1 && $index == int($index) && $index <= @effects;
            my $effect = $effects[$index - 1];
            _fail('Only native random-regression covariate effects are supported.') unless @$effect == 4 && $effect->[2] eq 'cov';
            my ($position, $count, $column) = map {_number($_)} @{$effect}[0,1,3];
            _fail('Native effect positions and levels must be positive integers.') if grep {$_ < 1 || $_ != int($_)} ($position,$count,$column);
            _fail('Random-regression levels or identity columns are inconsistent.') if
                defined($identity_column) && ($identity_column != $column || $levels != $count);
            ($identity_column, $levels) = ($column, $count);
            push @positions, $position;
        }
        $group->{positions} = \@positions;
        $group->{identity_column} = $identity_column;
        $group->{levels} = $levels;
    }
    _fail('Genetic and permanent RR bases differ; this interface cannot guess a common basis.') unless
        join(',',@{$groups[0]{positions}}) eq join(',',@{$groups[1]{positions}});
    _fail('A valid native observation-column position is required.') unless defined($observation_column) && $observation_column>=1 && $observation_column==int($observation_column);
    return {groups=>\@groups,residual=>$residual,residual_positions=>\@residual_positions,initial_gamma=>\@initial_gamma,observation_column=>$observation_column,missing_value=>$missing_value,inverse_tolerance=>$inverse_tolerance};
}

sub observation_mask {
    my ($data_file,$parameter_file) = @_;
    my $parameters = _parameters($parameter_file);
    my @mask;
    for my $line (@{_lines($data_file)}) {
        next unless length($line);
        my $row = _numbers($line);
        _fail('A native data row is missing its declared observation column.') unless @$row >= $parameters->{observation_column};
        push @mask, $row->[$parameters->{observation_column}-1] == $parameters->{missing_value} ? 0 : 1;
    }
    return \@mask;
}

sub _final_matrix {
    my ($final, $effect, $size, $section) = @_;
    my ($body) = $final =~ /Genetic variance\(s\) for effect\s+\Q$effect\E\s+(.*?)correlations/s;
    _fail('The final native covariance section is incomplete.') unless defined($body);
    if ($section eq 'correlation') {
        ($body) = $final =~ /Genetic variance\(s\) for effect\s+\Q$effect\E\s+.*?correlations\s+(.*?)eigenvectors/s;
        _fail('The final native correlation section is incomplete.') unless defined($body);
    }
    my @rows = grep {length($_)} split /\n/, $body;
    my @matrix = map {_numbers($_)} @rows;
    _fail('The final native matrix dimensions are inconsistent.') unless @matrix == $size && !grep {@$_ != $size} @matrix;
    return \@matrix;
}

# A text token represents its displayed number plus/minus half a unit in its
# last printed decimal. These intervals describe serialization precision only.
sub _printed_number {
    my ($token) = @_;
    my $value = _number($token);
    my $normalized = $token;
    $normalized =~ tr/dD/eE/;
    my ($mantissa,$exponent) = split /[eE]/, $normalized;
    $exponent //= 0;
    my ($fraction) = $mantissa =~ /\.(\d*)$/;
    my $digits = defined($fraction) ? length($fraction) : 0;
    my $half_unit = 0.5 * 10 ** ($exponent - $digits);
    _fail('Native printed precision cannot be represented safely.') unless
        isfinite($half_unit) && $half_unit > 0;
    my @bounds=($value-$half_unit,$value+$half_unit);
    _fail('Native printed precision bounds are nonfinite.') if grep {!isfinite($_)} @bounds;
    return ($value,\@bounds);
}

sub _interval_product {
    my ($left,$right) = @_;
    my @products = sort {$a<=>$b} map {
        my $value = $_; map {$value*$_} @$right
    } @$left;
    _fail('Printed covariance precision bounds overflowed.') if grep {!isfinite($_)} @products;
    my $epsilon = 16 * 2.220446049250313e-16;
    my $padding = $epsilon*abs($products[0]) + $epsilon*abs($products[-1]);
    my @bounds = ($products[0]-$padding,$products[-1]+$padding);
    _fail('Printed covariance precision bounds overflowed.') if grep {!isfinite($_)} @bounds;
    return \@bounds;
}

sub _interval_sum {
    my ($left,$right) = @_;
    my @sum = ($left->[0]+$right->[0],$left->[1]+$right->[1]);
    _fail('Printed covariance precision bounds overflowed.') if grep {!isfinite($_)} @sum;
    my $epsilon = 16 * 2.220446049250313e-16;
    my $padding = $epsilon*abs($left->[0]) + $epsilon*abs($left->[1]) +
        $epsilon*abs($right->[0]) + $epsilon*abs($right->[1]);
    my @bounds = ($sum[0]-$padding,$sum[1]+$padding);
    _fail('Printed covariance precision bounds overflowed.') if grep {!isfinite($_)} @bounds;
    return \@bounds;
}

sub _contains {
    my ($interval,$value) = @_;
    _fail('Interval consistency requires finite values.') if grep {!isfinite($_)} (@$interval,$value);
    my $epsilon = 32 * 2.220446049250313e-16;
    my $roundoff = $epsilon*abs($interval->[0]) + $epsilon*abs($interval->[1]) + $epsilon*abs($value);
    return $interval->[0]-$roundoff <= $value && $interval->[1]+$roundoff >= $value;
}

sub _reported_covariance {
    my ($final,$effect,$size) = @_;
    my ($body) = $final =~ /Genetic variance\(s\) for effect\s+\Q$effect\E\s+(.*?)(?=Genetic variance\(s\)|new R|\z)/s;
    _fail('The final native covariance/eigensystem is incomplete.') unless defined($body);
    my ($raw_text) = $body =~ /^(.*?)correlations/s;
    my ($vector_text,$value_text) = $body =~ /eigenvectors\s+(.*?)eigenvalues\s+(.*)$/s;
    _fail('The final native eigensystem is missing; no covariance repair was attempted.') unless
        defined($raw_text) && defined($vector_text) && defined($value_text);
    my @raw_tokens = map {[split ' ',$_]} grep {/\S/} split /\n/,$raw_text;
    my @vector_tokens = map {[split ' ',$_]} grep {/\S/} split /\n/,$vector_text;
    my @value_tokens = split ' ',$value_text;
    _fail('The final native eigensystem dimensions are inconsistent.') unless
        @raw_tokens==$size && @vector_tokens==$size && @value_tokens==$size &&
        !grep {@$_!=$size} (@raw_tokens,@vector_tokens);
    my (@raw,@raw_bounds,@vectors,@vector_bounds,@values,@value_bounds);
    for my $i (0..$size-1) {
        for my $j (0..$size-1) {
            ($raw[$i][$j],$raw_bounds[$i][$j]) = _printed_number($raw_tokens[$i][$j]);
            ($vectors[$i][$j],$vector_bounds[$i][$j]) = _printed_number($vector_tokens[$i][$j]);
        }
        ($values[$i],$value_bounds[$i]) = _printed_number($value_tokens[$i]);
        _fail('The final native covariance has negative reported eigenvalues.') if $values[$i] < 0;
    }
    # Do not normalize rounded vectors. A consistent orthonormal native matrix
    # must remain possible within the intervals of every printed column dot.
    for my $i (0..$size-1) {
        for my $j (0..$size-1) {
            my $dot = [0,0];
            for my $k (0..$size-1) {
                $dot = _interval_sum($dot,_interval_product($vector_bounds[$k][$i],$vector_bounds[$k][$j]));
            }
            _fail('The printed native eigenvectors are inconsistent with orthogonality.') unless
                _contains($dot,$i==$j ? 1 : 0);
        }
    }
    my (@spectral,@spectral_bounds);
    for my $i (0..$size-1) {
        for my $j (0..$size-1) {
            my ($value,$interval) = (0,[0,0]);
            for my $k (0..$size-1) {
                $value += $vectors[$i][$k]*$values[$k]*$vectors[$j][$k];
                $interval = _interval_sum($interval,_interval_product(
                    _interval_product($vector_bounds[$i][$k],$value_bounds[$k]),$vector_bounds[$j][$k]));
            }
            _fail('The native spectral covariance is nonfinite.') unless isfinite($value);
            my $overlap = [$raw_bounds[$i][$j][0] > $interval->[0] ? $raw_bounds[$i][$j][0] : $interval->[0],
                           $raw_bounds[$i][$j][1] < $interval->[1] ? $raw_bounds[$i][$j][1] : $interval->[1]];
            _fail('The printed covariance and eigensystem disagree beyond their serialization precision.') unless
                _contains($overlap,($overlap->[0]/2+$overlap->[1]/2));
            $spectral[$i][$j] = $value;
            $spectral_bounds[$i][$j] = $interval;
        }
    }
    return {raw=>\@raw,spectral=>\@spectral,metadata=>{
        raw_tokens=>\@raw_tokens,raw_intervals=>\@raw_bounds,
        eigenvalue_tokens=>\@value_tokens,eigenvector_tokens=>\@vector_tokens,
        eigenvalues=>\@values,eigenvectors=>\@vectors,
        spectral_covariance=>\@spectral,spectral_intervals=>\@spectral_bounds,
        source=>'raw_nominal',approximate=>0,
        note=>'Native printed covariance; serialization bounds are not statistical SE or confidence intervals.',
    }};
}

sub _correlation {
    my ($matrix) = @_;
    my @rows;
    for my $i (0..$#$matrix) {
        my @row;
        for my $j (0..$#$matrix) {
            my $denominator = $matrix->[$i][$i] * $matrix->[$j][$j];
            push @row, $denominator > 0 ? $matrix->[$i][$j] / sqrt($denominator) : undef;
        }
        push @rows, \@row;
    }
    return \@rows;
}

sub _kernel {
    my ($group, $cwd) = @_;
    my $count = $group->{levels};
    my %diagonal = map {$_=>1} 1..$count;
    return {random_type=>'diagonal',diagonal_by_factor=>\%diagonal,source=>{representation=>'identity',levels=>$count}} if $group->{random_type} eq 'diagonal';
    _fail('The supplied native kernel type is unsupported; no covariance/inverse interpretation was guessed.') unless $group->{random_type} eq 'user_file_inv';
    my $file = File::Spec->file_name_is_absolute($group->{file}) ? $group->{file} : File::Spec->catfile($cwd,$group->{file});
    open(my $source_handle,'<',$file) or _fail('Cannot read the actual covariance-kernel source.');
    binmode($source_handle);
    my $source_sha=Digest::SHA->new(256)->addfile($source_handle)->hexdigest;
    close($source_handle);
    my $lines = _lines($file);
    my @matrix = map {[(0)x$count]} 1..$count;
    my %seen;
    for my $line (@$lines) {
        next unless length($line);
        my $values = _numbers($line);
        _fail('A native covariance-kernel row must have three fields.') unless @$values == 3;
        my ($i,$j,$value) = @$values;
        _fail('A native covariance-kernel level is outside its declared group.') if grep {$_ < 1 || $_ > $count || $_ != int($_)} ($i,$j);
        my $key = $i < $j ? "$i,$j" : "$j,$i";
        _fail('Conflicting reciprocal native kernel values were supplied.') if exists($seen{$key}) && abs($seen{$key} - $value) > 1e-10 * (1 + abs($value));
        $seen{$key} = $value;
        $matrix[$i-1][$j-1] = $matrix[$j-1][$i-1] = $value;
    }
    for my $i (1..$count) {
        _fail('A native covariance-kernel diagonal is missing.') unless exists($seen{"$i,$i"});
        $diagonal{$i} = $matrix[$i-1][$i-1];
    }
    return {random_type=>'user_file_inv',diagonal_by_factor=>\%diagonal,matrix=>\@matrix,source=>{file=>$group->{file},sha256=>$source_sha,representation=>'native_covariance_triplets',levels=>$count}};
}

sub _validate_covariances {
    my ($cwd, $matrices, $inverse_tolerance, $alternatives) = @_;
    my %validation = %$matrices;
    for my $name (keys %{$alternatives || {}}) {
        $validation{$name.'_spectral'} = [$alternatives->{$name},0];
    }
    my ($handle, $path) = tempfile('native_rr_covariances_XXXXX',DIR=>$cwd,UNLINK=>1);
    print $handle "matrix\ti\tj\tvalue\tstrict\n";
    for my $name (sort keys %validation) {
        my ($matrix,$strict) = @{$validation{$name}};
        for my $i (0..$#$matrix) {
            for my $j (0..$#$matrix) {
                print $handle join("\t",$name,$i+1,$j+1,$matrix->[$i][$j],$strict),"\n";
            }
        }
    }
    close($handle);
    # Use the platform's existing base R/LAPACK routines. Do not add a custom
    # eigen solver, silently repair a covariance, or alter its kernel scale.
    my $code = <<'RSCRIPT';
args <- commandArgs(TRUE)
entries <- read.delim(args[1])
relative_tolerance <- as.numeric(args[2])
read_matrix <- function(name) {
    values <- entries[entries$matrix == name, ]
    covariance <- matrix(NA_real_, max(values$i), max(values$i))
    covariance[cbind(values$i, values$j)] <- values$value
    if (any(!is.finite(covariance))) stop(paste(name, "is not finite"))
    scale <- max(abs(covariance))
    if (max(abs(covariance - t(covariance))) > 1e-12 * scale) {
        stop(paste(name, "is not symmetric"))
    }
    covariance
}
positive_semidefinite <- function(covariance) {
    eigenvalues <- eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
    scale <- max(abs(eigenvalues))
    min(eigenvalues) >= -64 * .Machine$double.eps * nrow(covariance) * scale
}
for (name in unique(entries$matrix[!grepl("_spectral$", entries$matrix)])) {
    covariance <- read_matrix(name)
    strict <- entries$strict[match(name, entries$matrix)]
    if (strict) {
        eigenvalues <- eigen(covariance, symmetric = TRUE, only.values = TRUE)$values
        tryCatch(chol(covariance), error = function(e) {
            stop(paste(name, "is not positive definite"))
        })
        if (min(eigenvalues) / max(eigenvalues) <= relative_tolerance) {
            stop(paste(name, "is numerically rank deficient at native inverse precision"))
        }
    } else if (positive_semidefinite(covariance)) {
        cat("SELECT", name, "raw\n")
    } else if (paste0(name, "_spectral") %in% entries$matrix) {
        spectral <- read_matrix(paste0(name, "_spectral"))
        if (!positive_semidefinite(spectral)) stop(paste(name, "native eigensystem is not PSD"))
        cat("SELECT", name, "spectral\n")
    } else {
        stop(paste(name, "is not positive semidefinite"))
    }
}
cat("COVARIANCES_VALID\n")
RSCRIPT
    my $pid = open(my $check, '-|', 'Rscript', '--vanilla', '-e', $code, $path, $inverse_tolerance);
    if (!$pid) {unlink($path);_fail('The standard R covariance-validation runtime could not be started.');}
    my $answer = join('',<$check>);
    my $success = close($check);
    unlink($path);
    _fail('A supplied or fitted covariance matrix is invalid or unsupported at the selected native inverse precision; no variance share was produced.') unless $success && $answer =~ /COVARIANCES_VALID/;
    my %selection;
    while ($answer =~ /^SELECT\s+(Q_G|Q_PE)\s+(raw|spectral)\s*$/mg) {$selection{$1}=$2;}
    return \%selection;
}

sub _quadratic {
    my ($basis,$matrix) = @_;
    my $value = 0;
    for my $i (0..$#$basis) {
        for my $j (0..$#$basis) {$value += $basis->[$i] * $matrix->[$i][$j] * $basis->[$j];}
    }
    _fail('A projected covariance is negative or nonfinite.') unless isfinite($value) && $value >= 0;
    return $value;
}

sub _share {
    my ($genetic,$permanent,$residual) = @_;
    _fail('A projected marginal covariance is negative or nonfinite.') if
        grep {!defined($_) || !isfinite($_) || $_ < 0} ($genetic,$permanent,$residual);
    my $denominator = $genetic + $permanent + $residual;
    _fail('The marginal variance denominator is nonpositive or nonfinite.') unless isfinite($denominator) && $denominator > 0;
    my $share = $genetic / $denominator;
    _fail('The marginal genetic variance share is invalid.') unless isfinite($share) && $share >= 0 && $share <= 1;
    return $share;
}

sub _flatten { return [map {@$_} @{$_[0]}]; }

sub summarize {
    my %args = @_;
    for my $key (qw(parameter_file data_file log_file cwd backend time_scale unit_metadata)) {
        _fail("Required $key is missing.") unless defined($args{$key});
    }
    _fail('Select an original supported native backend.') unless $args{backend} =~ /^(?:blupf90|airemlf90)$/;
    _fail('Declare DAP or GDD time units.') unless $args{time_scale} =~ /^(?:DAP|GDD)$/;
    _fail('Physical-unit identity metadata is required.') unless ref($args{unit_metadata}) eq 'HASH';
    my $fit_error = CXGN::DroneImagery::DesignFactors::native_fit_error(
        $args{backend}.'_grm_random_regression_dap_blups',@args{qw(parameter_file data_file log_file cwd)});
    _fail($fit_error) if $fit_error;
    my $parameters = _parameters($args{parameter_file});
    my ($genetic,$permanent) = @{$parameters->{groups}};
    my $count = @{$genetic->{positions}};
    my ($qg,$qp) = ($genetic->{covariance},$permanent->{covariance});
    my ($cg,$cp) = (_correlation($qg),_correlation($qp));
    my $log = join("\n",@{_lines($args{log_file})});
    my (@gamma,@se);
    my %reported;
    if ($args{backend} eq 'airemlf90') {
        my @final = split /^Final Estimates\s*$/m, $log;
        _fail('AIREML has no complete final estimate section.') unless @final > 1 && $final[-1] =~ /FINISHED \(AIREMLF90\)/;
        my $final = $final[-1];
        $reported{genetic} = _reported_covariance($final,$genetic->{effects}[0],$count);
        $reported{permanent} = _reported_covariance($final,$permanent->{effects}[0],$count);
        $qg = $reported{genetic}{raw}; $qp = $reported{permanent}{raw};
        $cg = _final_matrix($final,$genetic->{effects}[0],$count,'correlation');
        $cp = _final_matrix($final,$permanent->{effects}[0],$count,'correlation');
        my %coefficients;
        while ($final =~ /^1\s+-th trait:\s*(\d+)\s+-th coefficient\s*=\s*(\S+)/mg) {
            _fail('Duplicate final residual coefficients were reported.') if exists($coefficients{$1});
            $coefficients{$1} = _number($2);
        }
        @gamma = map {$coefficients{$_}} 1..$count;
        _fail('Final residual coefficients do not match the supplied explicit basis.') unless keys(%coefficients) == $count && !grep {!defined($_)} @gamma;
        _fail('Residual and random-regression basis positions differ.') unless join(',',@{$parameters->{residual_positions}}) eq join(',',@{$genetic->{positions}});
        if ($final =~ /SE for R\s+(.*?)\* FINISHED \(AIREMLF90\)/s) {@se = @{_numbers($1)};}
    }
    my ($raw_qg,$raw_qp,$raw_cg,$raw_cp) = ($qg,$qp,$cg,$cp);
    my $kg = _kernel($genetic,$args{cwd});
    my $kp = _kernel($permanent,$args{cwd});
    my %matrices = (Q_G=>[$qg,0],Q_PE=>[$qp,0]);
    $matrices{K} = [$kg->{matrix},1] if $kg->{matrix};
    $matrices{L} = [$kp->{matrix},1] if $kp->{matrix};
    my $inverse_tolerance = $parameters->{inverse_tolerance} // CXGN::DroneImagery::DesignFactors::native_inverse_tolerance($args{backend});
    _fail('Native inverse precision must be positive.') unless $inverse_tolerance > 0;
    # The original DENSEOP generalized inverse has a separate operational-zero
    # default, 1e-10 (2022 manual, module DENSEOP). Original-binary controls show
    # rank loss at relative eigenvalue 5e-11, while 5e-9 is preserved. Use a
    # scale-invariant covariance condition; do not repair or rescale the input.
    my $dense_inverse_tolerance = 1e-10;
    my $kernel_relative_tolerance = $inverse_tolerance > $dense_inverse_tolerance ? $inverse_tolerance : $dense_inverse_tolerance;
    my %alternatives;
    $alternatives{Q_G}=$reported{genetic}{spectral} if $reported{genetic};
    $alternatives{Q_PE}=$reported{permanent}{spectral} if $reported{permanent};
    my $selection = _validate_covariances($args{cwd},\%matrices,$kernel_relative_tolerance,\%alternatives);
    for my $pair (['genetic','Q_G'],['permanent','Q_PE']) {
        my ($kind,$name)=@$pair;
        _fail('The covariance representation selector returned no result.') unless $selection->{$name};
        if ($reported{$kind} && $selection->{$name} eq 'spectral') {
            $reported{$kind}{metadata}{source}='reported_spectral_approximation';
            $reported{$kind}{metadata}{approximate}=1;
            $reported{$kind}{metadata}{note}='Approximate native printed eigensystem within validated serialization bounds; representation precision, not estimator SE or confidence intervals. No vectors normalized or eigenvalues clipped.';
            if ($kind eq 'genetic') {$qg=$reported{$kind}{spectral};}else{$qp=$reported{$kind}{spectral};}
        }
    }
    ($cg,$cp)=(_correlation($qg),_correlation($qp));
    delete $kg->{matrix}; delete $kp->{matrix};
    my (%times,%units,%observed_units,%observed_times,%observed_cells);
    my @observation_mask;
    for my $line (@{_lines($args{data_file})}) {
        next unless length($line);
        my $row = _numbers($line);
        _fail('A native data row is missing its declared observation column.') unless @$row >= $parameters->{observation_column};
        my $observed = $row->[$parameters->{observation_column}-1] == $parameters->{missing_value} ? 0 : 1;
        push @observation_mask, $observed;
        my ($g,$p,$time) = @{$row}[$genetic->{identity_column}-1,$permanent->{identity_column}-1,3];
        _fail('A data identity is outside the declared kernel.') unless defined($g) && defined($p) &&
            exists($kg->{diagonal_by_factor}{$g}) && exists($kp->{diagonal_by_factor}{$p});
        my @basis = map {$row->[$_-1]} @{$genetic->{positions}};
        _fail('Actual RR covariates are incomplete.') if !defined($time) || grep {!defined($_)} @basis;
        if (exists($times{$time})) {
            for my $i (0..$#basis) {_fail('RR covariates disagree at the same actual time.') if abs($times{$time}[$i]-$basis[$i]) > 1e-10 * (1+abs($basis[$i]));}
        } else {$times{$time} = \@basis;}
        _fail('A physical plot has conflicting genotype identities.') if exists($units{$p}) && $units{$p} != $g;
        $units{$p} = $g;
        if ($observed) {$observed_units{$p}++;$observed_times{$time}++;$observed_cells{$p}{$time}++;}
    }
    _fail('No native physical units or time points were supplied.') unless keys(%units) && keys(%times);
    _fail('No nonmissing native observations remain for a fitted reference.') unless keys(%observed_units);
    my (@reference,@excluded,%plot_ids,%genotype_ids,%genotype_factors);
    for my $unit (sort {$a<=>$b} keys %units) {
        my $metadata = $args{unit_metadata}{$unit};
        _fail('A fitted physical plot has no explicit identity metadata.') unless ref($metadata) eq 'HASH' && defined($metadata->{plot_id}) && length($metadata->{plot_id}) && defined($metadata->{genotype_id}) && length($metadata->{genotype_id});
        _fail('Physical plot identity is duplicated across native unit factors.') if $plot_ids{$metadata->{plot_id}}++;
        _fail('Native and external genotype factors disagree.') if defined($metadata->{genotype_factor}) && $metadata->{genotype_factor} != $units{$unit};
        _fail('External genotype identity metadata is inconsistent.') if
            (exists($genotype_ids{$units{$unit}}) && $genotype_ids{$units{$unit}} ne $metadata->{genotype_id}) ||
            (exists($genotype_factors{$metadata->{genotype_id}}) && $genotype_factors{$metadata->{genotype_id}} != $units{$unit});
        $genotype_ids{$units{$unit}} = $metadata->{genotype_id};
        $genotype_factors{$metadata->{genotype_id}} = $units{$unit};
        my $identity = {unit_factor=>0+$unit,plot_id=>$metadata->{plot_id},genotype_factor=>$units{$unit},genotype_id=>$metadata->{genotype_id}};
        if ($observed_units{$unit}) {
            push @reference, {%$identity,weight=>1/scalar(keys %observed_units),observed_records=>$observed_units{$unit}};
        } else {
            push @excluded, {%$identity,reason=>'No nonmissing native phenotype; excluded from fitted reference weights.'};
        }
    }
    my @time_keys = sort {$a<=>$b} keys %times;
    my $intercept = $times{$time_keys[0]}[0];
    _fail('The supplied RR intercept is not constant.') if grep {abs($times{$_}[0]-$intercept)>1e-10*(1+abs($intercept))} @time_keys;
    my @points;
    for my $time (sort {$a<=>$b} keys %times) {
        my $basis = $times{$time};
        my ($g,$p) = (_quadratic($basis,$qg),_quadratic($basis,$qp));
        my $residual = $parameters->{residual};
        if (@gamma) {my $log_r=0;for my $i (0..$#gamma) {$log_r += $gamma[$i]*$basis->[$i];}$residual=eval {exp($log_r)};}
        _fail('The fitted residual variance is not finite and positive.') unless defined($residual) && isfinite($residual) && $residual > 0;
        my (@values,$mean_g,$mean_p,$minimum,$maximum);
        ($mean_g,$mean_p)=(0,0);
        for my $unit (@reference) {
            my $vg = $kg->{diagonal_by_factor}{$unit->{genotype_factor}} * $g;
            my $vp = $kp->{diagonal_by_factor}{$unit->{unit_factor}} * $p;
            my $share = _share($vg,$vp,$residual);
            $mean_g += $unit->{weight}*$vg; $mean_p += $unit->{weight}*$vp;
            _fail('Mean marginal variances are nonfinite.') unless isfinite($mean_g) && isfinite($mean_p);
            $minimum=$share if !defined($minimum) || $share<$minimum;
            $maximum=$share if !defined($maximum) || $share>$maximum;
            push @values, {unit_factor=>$unit->{unit_factor},plot_id=>$unit->{plot_id},genotype_id=>$unit->{genotype_id},genetic_variance=>$vg,permanent_variance=>$vp,residual_variance=>$residual,genetic_share=>$share,observed=>($observed_cells{$unit->{unit_factor}}{$time} ? 1 : 0)};
        }
        push @points, {time=>0+$time,observed_records=>($observed_times{$time}||0),basis=>[@$basis],genetic_base_variance=>$g,permanent_base_variance=>$p,residual_variance=>$residual,mean_genetic_variance=>$mean_g,mean_permanent_variance=>$mean_p,genetic_share=>_share($mean_g,$mean_p,$residual),genetic_share_range=>[$minimum,$maximum],units=>\@values};
    }
    my $origin = $args{kernel_origin} // 'unknown';
    _fail('The declared kernel origin is unsupported.') unless $origin =~ /^(?:genotypic_identity|additive_marker|additive_pedigree|additive_combined|phenotypic_similarity|unknown)$/;
    _fail('The declared identity genetic origin conflicts with the actual kernel.') if $origin eq 'genotypic_identity' && $genetic->{random_type} ne 'diagonal';
    my $label = 'Observation-scale model genetic variance share';
    $label = 'Observation-scale broad-sense genotypic H2' if $origin eq 'genotypic_identity' && $genetic->{random_type} eq 'diagonal';
    $label = 'Observation-scale additive genetic h2' if $origin =~ /^additive_(?:marker|pedigree|combined)$/;
    my $interpretation = $origin eq 'phenotypic_similarity' || $origin eq 'unknown' ? 'A model-kernel component fraction; biological heritability is not established.' : 'Conditional on the declared genetic-effect interpretation and supplied kernel.';
    for my $kernel ($kg,$kp) {
        my @diagonal = values %{$kernel->{diagonal_by_factor}};
        $kernel->{mean_diagonal} = 0; $kernel->{mean_diagonal} += $_/@diagonal for @diagonal;
    }
    $kg->{reference_weighted_diagonal}=0; $kp->{reference_weighted_diagonal}=0;
    for my $unit (@reference) {
        $kg->{reference_weighted_diagonal} += $unit->{weight}*$kg->{diagonal_by_factor}{$unit->{genotype_factor}};
        $kp->{reference_weighted_diagonal} += $unit->{weight}*$kp->{diagonal_by_factor}{$unit->{unit_factor}};
    }
    return {
        version=>2,native_inverse_tolerance=>$inverse_tolerance,native_dense_inverse_tolerance=>$dense_inverse_tolerance,native_kernel_relative_tolerance=>$kernel_relative_tolerance,estimand_id=>'rr_observation_marginal_genetic_share',quantity_label=>$label,
        kernel_origin=>$origin,time_scale=>$args{time_scale},covariance_source=>$args{backend} eq 'airemlf90' ? 'estimated' : 'supplied',
        genetic_covariance=>_flatten($qg),env_covariance=>_flatten($qp),genetic_correlation=>_flatten($cg),env_correlation=>_flatten($cp),coefficient_count=>$count,
        raw_genetic_covariance=>_flatten($raw_qg),raw_env_covariance=>_flatten($raw_qp),
        raw_genetic_correlation=>_flatten($raw_cg),raw_env_correlation=>_flatten($raw_cp),
        covariance_readback=>{map {$_=>$reported{$_} ? $reported{$_}{metadata} : {source=>'supplied_parameters',approximate=>0,note=>'Unchanged declared covariance; no estimated-output representation was inferred.'}} qw(genetic permanent)},
        residual=>{model=>@gamma ? 'log_linear_basis' : 'homogeneous',link=>@gamma ? 'exp' : 'identity',gamma=>\@gamma,printed_se_for_R=>\@se,supplied_variance=>$parameters->{residual}},
        basis=>{source=>'actual_native_covariates',normalization=>'supplied_numeric_basis',positions=>[@{$genetic->{positions}}],intercept_value=>$points[0]{basis}[0]},
        reference_units=>\@reference,excluded_units=>\@excluded,observation_mask=>\@observation_mask,missing_value=>$parameters->{missing_value},kernels=>{genetic=>$kg,permanent=>$kp},by_time=>\@points,
        definition=>{reference=>'Fixed set of physical plots with at least one nonmissing native phenotype; equal per-plot weights across all dates.',aggregation=>'Ratio of mean marginal genetic variance to mean total marginal variance at each date; not mean of ratios.',scale=>'Individual observation after fixed-effect adjustment; not entry-mean heritability or prediction reliability.',interpretation=>$interpretation},
    };
}

1;
