package CXGN::BLUPF90;

=head1 NAME

CXGN::BLUPF90 - fit linear mixed models with blupf90+ (BLUPF90 family)

=head1 SYNOPSIS

  my $f90 = CXGN::BLUPF90->new({ keep_dir => "/tmp/run_blupf90", log => sub { print STDERR @_, "\n" } });
  die "BLUPF90+ is not installed" if !$f90->program();

  # data: column oriented, every column an arrayref of the same length
  my $d = { y => [...], accession => [...], rep_eff => [...] };

  # one model
  my $fit = $f90->fit({ data => $d, fixed => [], random => ['rep_eff'], genotype_random => 0, label => 'trial1_yield' });

  # many independent models at once (run in parallel)
  my @jobs = map { $f90->prepare($_) } @specs;
  $f90->run(\@jobs);
  my @fits = map { $f90->read($_) } @jobs;   # each: hashref, or { error => '...' }

=head1 DESCRIPTION

Phenotype models y ~ genotype + fixed terms + random terms are written in
the native BLUPF90 format and solved by blupf90+ (Misztal et al.; sparse
AI-REML). No R is involved: Breedbase's BLUPF90+ analysis engine
(L<CXGN::BLUPF90::Pipeline>) is built on this module.

=over

=item *

every factor is coded here as consecutive integers (no renumf90), so the
solutions map straight back to level names (levels_*.txt in each fit
folder);

=item *

fixed factors are 'cross' effects, numeric covariates 'cov' effects
(nested in a factor for terms such as trial:rowN); numeric variables are
those named rowN, colN, mday or cov_* (or listed in 'numeric');

=item *

genotype BLUEs: when the other fixed effects need few columns (at most
DENSE_MAX) they are coded as centred covariates, which makes each genotype
solution an estimable BLUE (mean over the other fixed effects) with an
exact standard error;

=item *

random effects are diagonal (identity), the genotype can follow the
additive relationship of a pedigree (add_animal);

=item *

a model without random effect is solved by least squares (BLUP method,
residual variance from the residuals).

=back

The program is blupf90+ in the folder given to new() or by the BLUPF90_DIR
environment variable, else in the PATH. The parameter and data files of
every fit are kept in keep_dir/NNN_label/ so a model can be inspected or
re-run outside Breedbase.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use File::Path qw(make_path);
use File::Spec;
use Time::HiRes qw(time);
use List::Util qw(sum max);
use Parallel::ForkManager;
use CXGN::BLUPF90::Stats qw(var mean);

our $DENSE_MAX = 60;       # max. fixed covariate columns for exact BLUE standard errors
our $MAX_ROUNDS = 200;
our $EM_ROUNDS = 50;    # EM-REML rounds before AI-REML when a fit is refitted

has 'bin_dir' => (is => 'rw', isa => 'Maybe[Str]');
has 'keep_dir' => (is => 'rw', isa => 'Str', default => sub { File::Spec->tmpdir() . "/blupf90_$$" });
has 'log' => (is => 'rw', isa => 'CodeRef', default => sub { sub { } });
has 'max_parallel' => (is => 'rw', isa => 'Int', lazy => 1, builder => '_default_parallel');
has 'n_fits' => (is => 'rw', isa => 'Int', default => 0);
has 'numeric' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
# REML control (advanced settings of the Analysis Pipeline); the defaults
# write the same parameter files as before these settings existed
has 'max_rounds' => (is => 'rw', isa => 'Int', default => sub { $MAX_ROUNDS });
has 'conv_crit' => (is => 'rw', isa => 'Str', default => '1e-9');
has 'em_rounds' => (is => 'rw', isa => 'Int', default => 0);    # EM-REML rounds before AI-REML (>= max_rounds: EM-REML only)

# REML options of a parameter file
sub _reml_options {
    my $self = shift;
    return ('OPTION conv_crit ' . $self->conv_crit, 'OPTION maxrounds ' . $self->max_rounds, ($self->em_rounds > 0 ? ('OPTION EM-REML ' . $self->em_rounds) : ()));
}

sub _default_parallel {
    my $n = $ENV{BLUPF90_PARALLEL};
    return $n if defined($n) && $n =~ /^\d+$/ && $n > 0;
    my $cores = 1;
    if (open(my $F, '<', '/proc/cpuinfo')) { $cores = scalar(grep { /^processor\s*:/ } <$F>) || 1; close($F); }
    $cores = 8 if $cores > 8;
    return $cores > 1 ? $cores - 1 : 1;
}

our $F_MAX = 0.99;    # inbreeding is capped here (F = 1 makes the relationship matrix singular)

# Inbreeding coefficients of a pedigree ({ id, s, d }: parent codes are
# positions, 1-based, 0 = unknown), Meuwissen & Luo (1992). Parents may come
# after their offspring in the coding: the individuals are processed in an
# order where parents come first. Returns ([F...], number of capped values).
sub inbreeding {
    my $ped = shift;
    my $n = scalar(@{$ped->{id}});
    my @s = map { $_ || 0 } @{$ped->{s}};
    my @d = map { $_ || 0 } @{$ped->{d}};
    # order with parents first (iterative depth-first search)
    my (@order, @state);
    for my $start (1 .. $n) {
        next if $state[$start];
        my @stack = ([$start, 0]);
        while (@stack) {
            my $top = $stack[-1];
            my ($i, $k) = @$top;
            $state[$i] ||= 1;
            my @par = grep { $_ && !$state[$_] } ($s[$i - 1], $d[$i - 1]);
            if (@par) { push @stack, [$par[0], 0]; $state[$par[0]] = 1; next; }
            pop @stack;
            if ($state[$i] == 1) { $state[$i] = 2; push @order, $i; }
        }
    }
    my %rank; $rank{$order[$_]} = $_ + 1 for 0 .. $#order;    # new index, parents < offspring
    my @S = (0); my @D = (0);
    $S[$rank{$_}] = $s[$_ - 1] ? $rank{ $s[$_ - 1] } : 0 for @order;
    $D[$rank{$_}] = $d[$_ - 1] ? $rank{ $d[$_ - 1] } : 0 for @order;
    my @F = (-1);    # F of an unknown parent: -1 in the recurrences below
    my @dii = (0);
    my $capped = 0;
    for my $i (1 .. $n) {
        my ($si, $di) = ($S[$i], $D[$i]);
        $dii[$i] = 0.5 - 0.25 * ($F[$si] + $F[$di]);
        if (!$si || !$di) { $F[$i] = 0; next; }
        if ($i > 1 && $si == $S[$i - 1] && $di == $D[$i - 1]) { $F[$i] = $F[$i - 1]; next; }
        # path coefficients of i to its ancestors, oldest last
        my %L = ($i => 1);
        my @todo = ($i);
        my $aii = 0;
        my %queued = ($i => 1);
        while (@todo) {
            @todo = sort { $b <=> $a } @todo;
            my $j = shift @todo;
            my ($sj, $dj) = ($S[$j], $D[$j]);
            foreach my $p ($sj, $dj) {
                next if !$p;
                $L{$p} += 0.5 * $L{$j};
                push @todo, $p if !$queued{$p}++;
            }
            $aii += $L{$j} * $L{$j} * $dii[$j];
        }
        my $f = $aii - 1;
        if ($f > $F_MAX) { $f = $F_MAX; $capped++; }
        $F[$i] = $f;
    }
    my @out = map { my $v = $F[ $rank{$_} ]; $v < 0 ? 0 : $v } 1 .. $n;
    return (\@out, $capped);
}

# full path of blupf90+, '' when not installed
sub program {
    my $self = shift;
    foreach my $dir (grep { defined && $_ ne '' } ($self->bin_dir, $ENV{BLUPF90_DIR})) {
        return "$dir/blupf90+" if -x "$dir/blupf90+";
    }
    foreach my $dir (split /:/, ($ENV{PATH} // '')) {
        return "$dir/blupf90+" if $dir ne '' && -x "$dir/blupf90+";
    }
    return '';
}

sub is_numeric_var {
    my ($self, $v) = @_;
    return 1 if $v =~ /^(rowN|colN|rcN|mday|cov_.+)$/;
    return (grep { $_ eq $v } @{$self->numeric}) ? 1 : 0;
}

# R terms() expansion of fixed terms: a*b -> a + b + a:b, a/b -> a + a:b
sub expand_fixed {
    my ($self, @terms) = @_;
    my (@out, %seen);
    foreach my $t (@terms) {
        $t =~ s/\s+//g;
        next if $t eq '' || $t eq '1' || $t eq '0';
        my @labs;
        if ($t =~ /\*/) {
            my @v = split /\*/, $t;
            # all interactions of the factors
            foreach my $mask (1 .. 2**@v - 1) {
                push @labs, join(':', map { $v[$_] } grep { int($mask / 2**$_) % 2 } 0 .. $#v);
            }
            @labs = sort { (($a =~ tr/://) <=> ($b =~ tr/://)) } @labs;
        }
        elsif ($t =~ /\//) {
            my @v = split /\//, $t;
            push @labs, join(':', @v[0 .. $_]) for 0 .. $#v;
        }
        else { @labs = ($t); }
        foreach my $l (@labs) { push @out, $l if !$seen{$l}++; }
    }
    return @out;
}

# integer codes 1..n of the combination of factor columns (0 = missing)
sub _codes {
    my ($d, $vars, $n) = @_;
    my (%code, @labels, @c);
    for my $i (0 .. $n - 1) {
        my @k = map { $d->{$_}->[$i] } @$vars;
        if (grep { !defined($_) || $_ eq '' } @k) { push @c, 0; next; }
        my $key = join(':', @k);
        if (!$code{$key}) { push @labels, $key; $code{$key} = scalar(@labels); }
        push @c, $code{$key};
    }
    # levels in sorted order (as R factor levels), codes renumbered
    my @order = sort { $labels[$a] cmp $labels[$b] } 0 .. $#labels;
    my %new; $new{$order[$_] + 1} = $_ + 1 for 0 .. $#order;
    return { code => [ map { $_ ? $new{$_} : 0 } @c ], n => scalar(@labels), labels => [ map { $labels[$_] } @order ] };
}

sub _fmt { my $v = shift; return defined($v) ? (0 + sprintf('%.15g', $v)) : -999999999; }

# Write the files of one fit. Spec:
#   data             { column => [values] }, with y and accession
#   fixed            fixed terms other than the genotype (a, a:b, a*b, a:x)
#   random           random grouping terms (a, a:b)
#   genotype_random  1: BLUPs (random genotype), 0: BLUEs
#   weights          optional arrayref (residual variance / w)
#   fixed_mean_by    column over which the fixed part is averaged into the
#                    population mean of the BLUPs (e.g. trial)
#   genomic          { snp_file => path, minfreq => 0.05, callrate => 0.90 }:
#                    genomic relationships of the genotype (needs ped, whose
#                    codes are the ids of the SNP file): with known parents
#                    in ped the single-step matrix H, with none G (GBLUP);
#                    blupf90+ builds and tunes G (VanRaden) and runs the QC
#   ped              { id => [names], s => [codes], d => [codes] }: the
#                    genotype follows the pedigree (add_animal); its first
#                    ids are the accessions of the data
#   gxe              structured genotype effect (random regression of the
#                    accession, genotype random; with ped / genomic its
#                    covariance is G (x) A, G (x) the genomic G or G (x) H):
#                    { kind => 'us' | 'diag' | 'cs_het', by => 'trial' }: one
#                    effect per level of 'by' (accession nested in the level
#                    indicators), unstructured, diagonal or heterogeneous
#                    compound symmetry (one variance per level, one common
#                    correlation: EM-REML around blupf90+, see _fit_cs_het)
#                    covariance among the levels; or
#                    { kind, cols => [[x...], ...], labels => [...], L => [...],
#                    term => text }: any covariates (e.g. 1 and time: random
#                    regression in time). The genotype value is L' u_i (mean
#                    over the levels by default), its standard error exact
#                    from the prediction error covariances (store_pev_pec)
#   rr_plot          { kind, cols, labels, group => 'plot_u', term }: the plot
#                    effect as a random regression on 'cols' (e.g. occasion
#                    indicators: unstructured covariance of the occasions of
#                    a plot); replaces the term 'group' of 'random'
#   hetres           { by => 'trial' }: one residual variance per level of
#                    'by' (log-linear residual model on the level dummies,
#                    hetres_pos / hetres_pol; AI-REML)
#   known_resid      1: the residual variance of a record is 1 / weight (the
#                    weights are 1 / SE^2 of stage-1 means): the residual is
#                    held at 1 (OPTION constant_var), not estimated
#   ge_by            'trial': genotype x trial effect with one variance per
#                    level of 'trial' (diagonal random regression of the
#                    accession, iid, on the level indicators), next to the
#                    genotype effect; with known_resid the stage-2 model with
#                    one G x E + error variance per trial
#   label            folder name
# Returns a job (hashref) for run() / read(); dies on an impossible model.
sub prepare {
    my ($self, $spec) = @_;
    my $d = $spec->{data};
    my $n = scalar(@{$d->{y}});
    die "not enough observations\n" if $n < 3;
    my $grandom = $spec->{genotype_random} ? 1 : 0;
    my $ped = $spec->{ped};
    die "a pedigree needs the genotype as random effect\n" if $ped && !$grandom;
    my $genomic = $spec->{genomic};
    die "genomic relationships need the pedigree coding of the genotyped accessions\n" if $genomic && !$ped;
    my $gxe = $grandom && $spec->{gxe} ? $spec->{gxe} : undef;
    my $rrp = $spec->{rr_plot};
    my @notes;

    my $acc = _codes($d, ['accession'], $n);
    my @labs = grep { $_ ne 'accession' } $self->expand_fixed(@{ $spec->{fixed} || [] });
    my $num = sub { $self->is_numeric_var($_[0]) };

    # dense coding: centred covariates with an exact BLUE standard error
    my @X;          # columns
    my $dense = 0;
    my $n_cols_r = 0;
    if (!$grandom && @labs) {
        my @mm;
        foreach my $lab (@labs) {
            my @vars = split /:/, $lab;
            my @nums = grep { $num->($_) } @vars;
            my @facs = grep { !$num->($_) } @vars;
            next if @nums > 1;
            if (!@facs) {
                push @mm, [ map { $_ // 0 } @{$d->{$nums[0]}} ];
                $n_cols_r++;
                next;
            }
            my $cd = _codes($d, \@facs, $n);
            $n_cols_r += @nums ? $cd->{n} : $cd->{n} - 1;
            for my $l (1 .. $cd->{n}) {
                push @mm, [ map { $cd->{code}->[$_] == $l ? (@nums ? ($d->{$nums[0]}->[$_] // 0) : 1) : 0 } 0 .. $n - 1 ];
            }
        }
        if ($n_cols_r <= $DENSE_MAX) {
            $dense = 1;
            # part of each column not explained by the genotype, then a
            # pivoted Gram-Schmidt keeps the independent columns (in order)
            my (@R, @keep_norm);
            foreach my $col (@mm) {
                my (%s, %c);
                for (0 .. $n - 1) { $s{$acc->{code}->[$_]} += $col->[$_]; $c{$acc->{code}->[$_]}++; }
                my @r = map { $col->[$_] - $s{$acc->{code}->[$_]} / $c{$acc->{code}->[$_]} } 0 .. $n - 1;
                push @R, \@r;
            }
            my @Q;
            foreach my $j (0 .. $#R) {
                my @v = @{$R[$j]};
                my $orig = sum(map { $_ * $_ } @v) || 0;
                my $tot = sum(map { $_ * $_ } @{$mm[$j]}) || 0;
                next if $orig <= 1e-8 * ($tot > 1 ? $tot : 1);
                foreach my $q (@Q) {
                    my $dot = 0; $dot += $v[$_] * $q->[$_] for 0 .. $n - 1;
                    $v[$_] -= $dot * $q->[$_] for 0 .. $n - 1;
                }
                my $nn = sum(map { $_ * $_ } @v);
                next if $nn <= 1e-14 * $orig;
                my $s = sqrt($nn);
                push @Q, [ map { $_ / $s } @v ];
                my $m = sum(@{$mm[$j]}) / $n;
                push @X, [ map { $_ - $m } @{$mm[$j]} ];
            }
        }
    }

    my @cols = ([ 'y', [ map { _fmt($_) } @{$d->{y}} ] ]);
    push @cols, [ 'w', [ map { _fmt($_) } @{$spec->{weights}} ] ] if $spec->{weights};
    my (@eff, @fx);
    my $add_col = sub { push @cols, [ $_[0], $_[1] ]; return scalar(@cols); };
    my $rank = 0;
    if (!$grandom) {
        push @eff, $add_col->('acc', $acc->{code}) . " $acc->{n} cross";
        $rank += $acc->{n};
    }
    if ($dense) {
        for my $j (0 .. $#X) { push @eff, $add_col->("x" . ($j + 1), [ map { _fmt($_) } @{$X[$j]} ]) . " 1 cov"; }
        $rank += @X;
    }
    else {
        foreach my $lab (@labs) {
            my @vars = split /:/, $lab;
            my @nums = grep { $num->($_) } @vars;
            my @facs = grep { !$num->($_) } @vars;
            if (@nums > 1) { push @notes, "$lab (product of covariates, not supported by BLUPF90+)"; next; }
            if (@nums == 1) {
                my $m = mean(@{$d->{$nums[0]}}) // 0;
                my @x = map { defined($_) ? $_ - $m : 0 } @{$d->{$nums[0]}};
                if (@facs) {
                    my $cd = _codes($d, \@facs, $n);
                    my $fpos = $add_col->("f_$lab", $cd->{code});
                    my $xpos = $add_col->("x_$lab", [ map { _fmt($_) } @x ]);
                    push @eff, "$xpos $cd->{n} cov $fpos";
                    push @fx, { effect => scalar(@eff), code => $cd->{code}, x => \@x };
                    $rank += $cd->{n};
                }
                else {
                    push @eff, $add_col->("x_$lab", [ map { _fmt($_) } @x ]) . " 1 cov";
                    push @fx, { effect => scalar(@eff), code => [ (1) x $n ], x => \@x };
                    $rank += 1;
                }
            }
            else {
                my $cd = _codes($d, \@facs, $n);
                next if $cd->{n} < 2;
                push @eff, $add_col->("f_$lab", $cd->{code}) . " $cd->{n} cross";
                push @fx, { effect => scalar(@eff), code => $cd->{code}, x => [ (1) x $n ], name => $lab, labels => $cd->{labels}, cross => 1 };
                $rank += $cd->{n} - 1;    # used for least squares fits (genotype fixed: it holds the mean)
            }
        }
    }
    # overall mean when nothing else absorbs it
    if ($grandom && !grep { $_->{cross} } @fx) {
        push @eff, $add_col->('mu', [ (1) x $n ]) . " 1 cross";
        push @fx, { effect => scalar(@eff), code => [ (1) x $n ], x => [ (1) x $n ], cross => 1 };
        $rank += 1;
    }

    my $first_random = @eff + 1;
    my @rnames;
    my %rcodes;
    if ($grandom) {
        if ($ped) {
            my %pos; $pos{$ped->{id}->[$_]} = $_ + 1 for 0 .. $#{$ped->{id}};
            $rcodes{accession} = { code => [ map { defined($_) ? $pos{$_} // 0 : 0 } @{$d->{accession}} ], n => scalar(@{$ped->{id}}), labels => $ped->{id} };
        }
        else { $rcodes{accession} = $acc; }
        push @rnames, 'accession' if !$gxe;
    }
    # random effects with a supplied covariance (user_cov: name -> {file,
    # levels, key}: covariance over 'levels', the level key of every record)
    my $ucov = $spec->{user_cov} || {};
    foreach my $rt (@{ $spec->{random} || [] }) {
        next if $rt eq 'accession' || $rcodes{$rt};
        next if $rrp && $rt eq $rrp->{group};
        if (my $u = $ucov->{$rt}) {
            my %pos; $pos{ $u->{levels}->[$_] } = $_ + 1 for 0 .. $#{ $u->{levels} };
            $rcodes{$rt} = { code => [ map { defined($_) ? $pos{$_} // 0 : 0 } @{ $u->{key} } ], n => scalar(@{ $u->{levels} }), labels => $u->{levels}, file => $u->{file} };
            push @rnames, $rt;
            next;
        }
        my $cd = _codes($d, [ split /:/, $rt ], $n);
        next if $cd->{n} < 2;
        $rcodes{$rt} = $cd;
        push @rnames, $rt;
    }
    push @eff, $add_col->("r_$_", $rcodes{$_}->{code}) . " $rcodes{$_}->{n} cross" for @rnames;
    # random regressions (genotype: structured G x E or genotype in time;
    # plot: covariance of the occasions): the factor nested in every covariate
    # (last effects, so the other random effects keep their numbers)
    my @rr;
    if ($gxe) {
        my ($cols, $labels, $L, $term) = @{$gxe}{qw(cols labels L term)};
        if (!$cols) {
            my $lv = _codes($d, [ $gxe->{by} ], $n);
            die "the genotype x $gxe->{by} covariance needs at least two levels of $gxe->{by}\n" if $lv->{n} < 2;
            $cols = [ map { my $k = $_; [ map { $lv->{code}->[$_] == $k ? 1 : 0 } 0 .. $n - 1 ] } 1 .. $lv->{n} ];
            $labels = $lv->{labels};
            $term = ($gxe->{kind} eq 'cs_het' ? 'cs' : $gxe->{kind}) . "(0 + $gxe->{by} | accession)";
        }
        my $K = @$cols;
        push @rr, { role => 'genotype', kind => $gxe->{kind}, cols => $cols, labels => $labels, K => $K, L => $L || [ (1 / $K) x $K ], term => $term,
                    codes => ($ped ? $rcodes{accession} : $acc), name => 'acc' };
    }
    if ($rrp) {
        my $pc = _codes($d, [ $rrp->{group} ], $n);
        push @rr, { role => 'plot', kind => $rrp->{kind}, cols => $rrp->{cols}, labels => $rrp->{labels}, K => scalar(@{ $rrp->{cols} }), term => $rrp->{term}, codes => $pc, name => $rrp->{group} };
    }
    if (my $by = $spec->{ge_by}) {
        die "a genotype x $by variance per level cannot be combined with a structured genotype covariance\n" if $gxe;
        my $lv = _codes($d, [ $by ], $n);
        die "a genotype x $by variance per level needs at least two levels of $by\n" if $lv->{n} < 2;
        push @rr, { role => 'ge', kind => 'diag', cols => [ map { my $k = $_; [ map { $lv->{code}->[$_] == $k ? 1 : 0 } 0 .. $n - 1 ] } 1 .. $lv->{n} ],
                    labels => $lv->{labels}, K => $lv->{n}, term => "diag(0 + $by | accession:$by)", codes => $acc, name => 'acc_ge' };
    }
    # heterogeneous compound symmetry (EM-REML around blupf90+, which has no
    # EM-REML for hetres) with one residual variance per level: a record effect
    # with one variance per level over a small residual held fixed (eps), so
    # the residual variance of level k is var_k + eps
    my ($unit, $eps);
    if ($gxe && $gxe->{kind} eq 'cs_het' && $spec->{hetres}) {
        my $by = $spec->{hetres}->{by};
        my $lv = _codes($d, [ $by ], $n);
        die "one residual variance per $by needs at least two levels\n" if $lv->{n} < 2;
        my @nk = (0) x $lv->{n}; $nk[ $_ - 1 ]++ for grep { $_ } @{ $lv->{code} };
        $eps = 1e-4 * (var(@{$d->{y}}) || 1);
        $unit = { role => 'unit', kind => 'diag', cols => [ map { my $k = $_; [ map { $lv->{code}->[$_] == $k ? 1 : 0 } 0 .. $n - 1 ] } 1 .. $lv->{n} ],
                  labels => $lv->{labels}, K => $lv->{n}, n_by => \@nk, term => "one residual variance per $by", codes => { code => [ 1 .. $n ], n => $n }, name => 'unit' };
        push @rr, $unit;
    }
    die "known residual variances need the weights (1 / SE^2)\n" if $spec->{known_resid} && !$spec->{weights};
    die "known residual variances cannot be combined with one residual variance per level\n" if $spec->{known_resid} && $spec->{hetres};
    foreach my $r (@rr) {
        die "a random regression needs at least two covariates\n" if $r->{K} < 2;
        my $gpos = $add_col->("rr_$r->{name}", $r->{codes}->{code});
        $r->{first} = @eff + 1;
        for my $k (0 .. $r->{K} - 1) {
            my $ipos = $add_col->("rr_$r->{name}_x" . ($k + 1), [ map { _fmt($_) } @{ $r->{cols}->[$k] } ]);
            push @eff, "$ipos $r->{codes}->{n} cov $gpos";
        }
    }
    # heterogeneous residual: dummies of the levels after the first
    my ($hr, @hr_pos);
    if ($spec->{hetres} && !$unit) {
        $hr = _codes($d, [ $spec->{hetres}->{by} ], $n);
        die "one residual variance per $spec->{hetres}->{by} needs at least two levels\n" if $hr->{n} < 2;
        @hr_pos = map { my $k = $_; $add_col->("hetres_$k", [ map { $hr->{code}->[$_] == $k ? 1 : 0 } 0 .. $n - 1 ]) } 2 .. $hr->{n};
        # blupf90+ (2.x) leaves the coefficient of the LAST listed position at
        # its starting value: a column of zeros goes last, so that every level
        # gets its own variance (checked against glmmTMB dispformula = ~0 + trial)
        push @hr_pos, $add_col->('hetres_pad', [ (0) x $n ]);
    }

    $self->n_fits($self->n_fits + 1);
    (my $safe = $spec->{label} // 'model') =~ s/[^A-Za-z0-9_.-]+/_/g;
    my $wd = sprintf("%s/%03d_%s", File::Spec->rel2abs($self->keep_dir), $self->n_fits, $safe);
    make_path($wd);

    open(my $D, '>', "$wd/data.txt") or die "Cannot write $wd/data.txt\n";
    for my $i (0 .. $n - 1) { print $D join(' ', map { $_->[1]->[$i] } @cols), "\n"; }
    close($D);
    _write_lines("$wd/data_columns.txt", map { $_->[0] } @cols);

    my $vce = (@rnames || @rr) ? 1 : 0;
    my $v0 = $vce ? (var(@{$d->{y}}) || 1e-6) / (@rnames + @rr + 1) : 1;
    $v0 = 1e-6 if $v0 < 1e-6;
    my ($rg) = grep { $_->{role} eq 'genotype' } @rr;
    my ($rp) = grep { $_->{role} eq 'plot' } @rr;
    my ($rge) = grep { $_->{role} eq 'ge' } @rr;
    my $known = $spec->{known_resid} ? 1 : 0;
    my $gterm = $rg ? $rg->{term} : $grandom ? '(1|accession)' : 'accession';
    my $model = "y ~ " . join(' + ', $gterm, @labs, ($rp ? $rp->{term} : ()), map { "(1|$_)" } grep { $_ ne 'accession' } @rnames, ($rge ? $rge->{term} : ())) . ($hr || $unit ? ", one residual variance per $spec->{hetres}->{by}" : '')
              . ($known ? ', residual = 1/weight (known, held fixed)' : '');
    my @par = ('DATAFILE', 'data.txt', 'NUMBER_OF_TRAITS', 1, 'NUMBER_OF_EFFECTS', scalar(@eff),
               'OBSERVATION(S)', 1, 'WEIGHT(S)', ($spec->{weights} ? 2 : ''),
               'EFFECTS: POSITIONS_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT[EFFECT NESTED]', @eff,
               'RANDOM_RESIDUAL VALUES', ($known ? 1 : $unit ? sprintf('%.10g', $eps) : sprintf('%.10g', $v0)));
    foreach my $k (0 .. $#rnames) {
        if (my $uf = $rcodes{ $rnames[$k] }->{file}) {
            # covariance supplied: blupf90+ inverts it (user_file_inv); path
            # relative to the fit folder so the folders can be re-run elsewhere
            push @par, 'RANDOM_GROUP', $first_random + $k, 'RANDOM_TYPE', 'user_file_inv',
                       'FILE', File::Spec->abs2rel(File::Spec->rel2abs($uf), $wd), '(CO)VARIANCES', sprintf('%.10g', $v0);
            next;
        }
        my $animal = $ped && $rnames[$k] eq 'accession';
        # add_an_upginb: the relationship inverse with the inbreeding of every
        # individual (inbred lines; the genomic module's A22 includes it too)
        push @par, 'RANDOM_GROUP', $first_random + $k, 'RANDOM_TYPE', ($animal ? 'add_an_upginb' : 'diagonal'),
                   'FILE', ($animal ? 'pedigree.txt' : ''), '(CO)VARIANCES', sprintf('%.10g', $v0);
    }
    foreach my $r (@rr) {
        # one group: unstructured, or diagonal (zero starting covariances stay
        # zero in AI-REML); prediction error covariances of the genotype group
        # (the genotype group on the relationship matrix: G (x) A / G / H)
        my $K = $r->{K};
        my $animal = $ped && $r->{role} eq 'genotype';
        push @par, 'RANDOM_GROUP', join(' ', $r->{first} .. $r->{first} + $K - 1), 'RANDOM_TYPE', ($animal ? 'add_an_upginb' : 'diagonal'), 'FILE', ($animal ? 'pedigree.txt' : ''), '(CO)VARIANCES',
             map { my $i = $_; join(' ', map { sprintf('%.10g', $i == $_ ? $v0 : ($r->{kind} eq 'diag' ? 0 : 0.5 * $v0)) } 1 .. $K) } 1 .. $K;
    }
    push @par, "OPTION store_pev_pec $rg->{first}" if $rg;
    # heterogeneous compound symmetry: EM-REML by Breedbase around blupf90+
    # runs that only solve the mixed model equations (_fit_cs_het)
    my $csh = $rg && $rg->{kind} eq 'cs_het' && $vce;
    # known residual variances: R = 1 / weight, the residual (effect number
    # after the last effect) held at 1; AI-REML then starts from EM-REML rounds
    push @par, 'OPTION constant_var ' . (scalar(@eff) + 1) . ' 1 1' if $known && $vce && !$csh;
    if ($hr) {
        # log(residual variance) = a0 + a_k (level k); zero starting values
        # would stay zero, so they start slightly away from it
        push @par, 'OPTION hetres_pos ' . join(' ', @hr_pos), 'OPTION hetres_pol ' . join(' ', sprintf('%.6g', log($v0)), ('0.05') x @hr_pos);
        push @notes, "EM-REML is not available with one residual variance per $spec->{hetres}->{by}; AI-REML was used" if $self->em_rounds > 0;
    }
    push @par, 'OPTION method VCE' if $vce;
    # YAMS (sparse supernodal factorization) pays off on large and pedigree models only
    push @par, 'OPTION use_yams' if $vce && ($ped || $n > 20000);
    if ($genomic) {
        # path relative to the fit folder, so the folders can be re-run elsewhere
        my $snp = File::Spec->abs2rel(File::Spec->rel2abs($genomic->{snp_file}), $wd);
        push @par, "OPTION SNP_file $snp", sprintf('OPTION minfreq %.4g', $genomic->{minfreq} // 0.05), sprintf('OPTION callrate %.4g', $genomic->{callrate} // 0.90);
    }
    push @par, 'OPTION sol se', 'OPTION missing -999999999', 'OPTION residual';
    push @par, ($hr ? grep { !/EM-REML/ } $self->_reml_options() : $self->_reml_options()) if $vce;
    push @par, "OPTION EM-REML $EM_ROUNDS" if $known && $vce && $self->em_rounds == 0 && !$csh;
    # cs_het: one EM-REML round per run (f90_em.par), the final run solves the
    # equations at the estimates (f90.par)
    if ($csh) {
        my @base = grep { !/^OPTION (maxrounds|EM-REML|conv_crit)\b/ } @par;
        _write_lines("$wd/f90_em.par", (grep { !/^OPTION (sol se|store_pev_pec|residual)\b/ } @base), 'OPTION EM-REML 1', 'OPTION maxrounds 1');
        @par = (@base, 'OPTION maxrounds 0');
    }
    _write_lines("$wd/f90.par", @par);
    _write_lines("$wd/f90_start.par", (grep { !/^OPTION (hetres_|store_pev_pec|EM-REML)/ } @par), "OPTION EM-REML $EM_ROUNDS") if $hr;
    _write_lines("$wd/README.txt", "# BLUPF90+ parameter file written by the Breedbase Analysis Pipeline (BLUPF90+ engine)",
                 "# model: $model" . ($dense ? "   [fixed effects other than accession as centred covariates]" : ''),
                 "# columns of data.txt: see data_columns.txt", "# run: echo f90.par | blupf90+");
    my $inb_info = $ped ? _write_pedigree($wd, $ped, \@notes) : undef;
    foreach my $f (grep { $_->{labels} } @fx) {
        (my $nm = $f->{name}) =~ s/:/_x_/g;
        _write_levels("$wd/levels_$nm.txt", $f->{labels});
    }
    _write_levels("$wd/levels_accession.txt", $acc->{labels}) if !$grandom;
    foreach my $k (@rnames) {
        (my $nm = $k) =~ s/:/_x_/g;
        _write_levels("$wd/levels_$nm.txt", $rcodes{$k}->{labels});
    }

    return {
        dir => $wd, label => $spec->{label} // 'model', n => $n, model => $model, notes => \@notes,
        inbreeding => $inb_info,
        dense => $dense, vce => $vce, grandom => $grandom, ped => $ped ? 1 : 0, genomic => $genomic ? 1 : 0, acc => $acc, fx => \@fx,
        rnames => \@rnames, rcodes => \%rcodes, first_random => $first_random, rank => $rank,
        weights => $spec->{weights}, y => $d->{y},
        mean_by => $spec->{fixed_mean_by} ? $d->{ $spec->{fixed_mean_by} } : undef,
        n_fixed_other => scalar(@labs),
        ($rg ? (gxe => { kind => $rg->{kind}, first => $rg->{first}, K => $rg->{K}, labels => $rg->{labels}, L => $rg->{L} }) : ()),
        ($rp ? (rr_plot => { kind => $rp->{kind}, first => $rp->{first}, K => $rp->{K}, labels => $rp->{labels} }) : ()),
        ($hr ? (hetres => { labels => $hr->{labels}, n => $hr->{n} }) : ()),
        ($rge ? (ge => { first => $rge->{first}, K => $rge->{K}, labels => $rge->{labels} }) : ()),
        ($csh ? (cs_het => { first => $rg->{first}, K => $rg->{K}, resid => ($known ? 'known' : $unit ? 'eps' : 'free'), eps => $eps, genomic => $genomic ? 1 : 0,
                             # every other random group: [first effect, size, kind]
                             groups => [ (map { [ $first_random + $_, 1, 'us' ] } 0 .. $#rnames), (map { [ $_->{first}, $_->{K}, $_->{kind} eq 'diag' ? 'diag' : 'us' ] } grep { $_ ne $rg && $_ ne ($unit // '') } @rr) ],
                             ($unit ? (unit => { first => $unit->{first}, K => $unit->{K}, n_by => $unit->{n_by} }) : ()) }) : ()),
        ($unit ? (unit => { first => $unit->{first}, K => $unit->{K}, labels => $unit->{labels}, eps => $eps }) : ()),
        known_resid => $known,
    };
}

sub _write_lines {
    my ($file, @lines) = @_;
    open(my $F, '>', $file) or die "Cannot write $file\n";
    print $F join("\n", @lines), "\n";
    close($F);
}

sub _write_levels {
    my ($file, $labels) = @_;
    _write_lines($file, "code\tlevel", map { ($_ + 1) . "\t" . $labels->[$_] } 0 .. $#$labels);
}

# Run blupf90+ on prepared jobs, several at a time.
sub run {
    my ($self, $jobs) = @_;
    my @todo = grep { $_ && !$_->{done} } @$jobs;
    return if !@todo;
    my $prog = $self->program() or die "blupf90+ is not installed\n";
    my $cmd = _command($prog);
    my $pm = Parallel::ForkManager->new(@todo > 1 ? $self->max_parallel : 0);
    # wait for children without polling (the default sleeps 1 s between checks)
    $pm->set_waitpid_blocking_sleep(0) if $pm->can("set_waitpid_blocking_sleep");
    foreach my $job (@todo) {
        $job->{done} = 1;
        $pm->start and next;
        my $t0 = time();
        # without forking (a single job) this runs in the caller: come back
        my $cwd = File::Spec->rel2abs('.');
        chdir($job->{dir});
        # one residual variance per level: AI-REML of the log-linear residual
        # model needs good starting values, taken from the same model with one
        # residual variance (f90_start.par) fitted first
        if ($job->{hetres} && -e 'f90_start.par') {
            system('bash', '-c', _command($prog, 'f90_start.par', 'blupf90_start.out'));
            _warm_start('f90.par', 'blupf90_start.out');
            unlink(grep { -e } qw(solutions yhat_residual pev_pec_bf90));
        }
        if ($job->{cs_het}) { $self->_fit_cs_het($job, $prog); }
        else { system('bash', '-c', $cmd); }
        chdir($cwd);
        if (open(my $T, '>', "$job->{dir}/elapsed.txt")) { printf $T "%.3f\n", time() - $t0; close($T); }
        $pm->finish(0);
    }
    $pm->wait_all_children;
}

# pedigree.txt (with the BLUPF90 inbreeding codes) and inbreeding.txt of a
# fit folder; returns the inbreeding summary, adds a note when F was capped
sub _write_pedigree {
    my ($wd, $ped, $notes) = @_;
    my ($F, $capped) = inbreeding($ped);
    push @$notes, "inbreeding above $F_MAX in $capped individual(s) of the pedigree was set to $F_MAX (fully inbred lines make the relationship matrix singular)" if $capped;
    open(my $P, '>', "$wd/pedigree.txt") or die "Cannot write the pedigree\n";
    for my $i (0 .. $#{$ped->{id}}) {
        my ($s, $dd) = ($ped->{s}->[$i] || 0, $ped->{d}->[$i] || 0);
        # BLUPF90 inbreeding code: 4000 / ((1+ms)(1-Fs) + (1+md)(1-Fd)), ms/md = 1 for an unknown parent
        my $den = ($s ? 1 - $F->[$s - 1] : 2) + ($dd ? 1 - $F->[$dd - 1] : 2);
        print $P join(' ', $i + 1, $s, $dd, sprintf('%.0f', 4000 / $den)), "\n";
    }
    close($P);
    _write_lines("$wd/inbreeding.txt", "code\tid\tF", map { ($_ + 1) . "\t$ped->{id}->[$_]\t" . sprintf('%.6f', $F->[$_]) } 0 .. $#{$ped->{id}});
    return { mean => mean(@$F) // 0, max => max(@$F, 0), capped => $capped };
}

# shell command that runs blupf90+ in the current folder
sub _command {
    my ($prog, $par, $out) = @_;
    $par //= 'f90.par'; $out //= 'blupf90.out';
    # blupf90+ keeps large arrays on the stack (segfaults with the 8 MB default)
    return "ulimit -s unlimited 2>/dev/null || ulimit -s \$(ulimit -H -s) 2>/dev/null; export OMP_STACKSIZE=64M OMP_NUM_THREADS=1; echo $par | '$prog' > $out 2>&1";
}

# Heterogeneous compound symmetry of the genotype effect: G = S C(rho) S,
# S = diag(sd per level), C(rho) one common correlation. blupf90+ cannot
# constrain a covariance matrix that way, so Breedbase runs the REML
# estimation as an ECM algorithm around blupf90+ (in the fit folder):
#   E + M  one EM-REML round of blupf90+ (f90_em.par: OPTION EM-REML 1,
#          maxrounds 1) from the current variances; blupf90+ computes every
#          expectation itself, whatever the relationship matrix (I, A, G, H)
#   CM     the genotype matrix of that round projected on the structure,
#          G = argmax -log|G| - tr(G^-1 M) (_csh_mstep); the other groups as
#          blupf90+ updated them (diagonal ones kept diagonal; the record
#          effect of 'one residual variance per level' updated on the records
#          of each level); the residual as updated, or held (known / eps)
# accelerated by SQUAREM (Varadhan & Roland 2008) with the REML likelihood as
# safeguard, and a check that lets a variance heading to zero reach it. The
# last run (f90.par, OPTION maxrounds 0) solves the equations at the estimates.
our $CSH_MAX_ITER = 500;    # EM rounds (blupf90+ runs)
our $CSH_TOL = 1e-6;        # change relative to the total variance
our $CSH_LOGL_TOL = 1e-5;   # change of -2logL tolerated by the SQUAREM safeguard
our $CSH_LOGL_STOP = 0.002; # settled: -2logL changes less per cycle (as ASReml's
                            # REML convergence) and the variances by < 0.1% of the total
sub _fit_cs_het {
    my ($self, $job, $prog) = @_;
    my $cs = $job->{cs_het};
    my ($first, $K) = @{$cs}{qw(first K)};
    my @em = _read_lines('f90_em.par');
    my @fin = _read_lines('f90.par');
    my @groups = ([ $first, $K, 'cs_het' ], @{ $cs->{groups} || [] }, ($cs->{unit} ? [ $cs->{unit}->{first}, $cs->{unit}->{K}, 'unit' ] : ()));
    my ($ri) = grep { $em[$_] =~ /^RANDOM_RESIDUAL/ } 0 .. $#em;
    my ($rf) = grep { $fin[$_] =~ /^RANDOM_RESIDUAL/ } 0 .. $#fin;
    my $free_res = $cs->{resid} eq 'free';
    my $lo = $K > 1 ? -1 / ($K - 1) : -1;
    my $n_rec = $cs->{unit} ? sum(@{ $cs->{unit}->{n_by} }) : 0;
    # parameters, transformed so that any value is valid (extrapolation):
    # log variances, logit of the correlation in (lo, 1), log-Cholesky of an
    # unstructured matrix, log residual (when estimated)
    my $to = sub {
        my ($V, $res) = @_;
        my @t;
        foreach my $g (@groups) {
            my ($f, $k, $kind) = @$g;
            my $M = $V->{$f};
            if ($kind eq 'cs_het') {
                my $r = _csh_rho($M); $r = $lo + 1e-6 if $r <= $lo; $r = 1 - 1e-6 if $r >= 1;
                push @t, (map { log(_pos($M->[$_][$_])) } 0 .. $k - 1), log(($r - $lo) / (1 - $r));
            }
            elsif ($kind eq 'diag' || $kind eq 'unit') { push @t, map { log(_pos($M->[$_][$_])) } 0 .. $k - 1; }
            else {
                my $L = _chol($M);
                for my $i (0 .. $k - 1) { push @t, map { $_ == $i ? log(_pos($L->[$i][$i])) : $L->[$i][$_] } 0 .. $i; }
            }
        }
        push @t, log(_pos($res)) if $free_res;
        return \@t;
    };
    my $from = sub {
        my $t = shift;
        my ($p, %V) = (0);
        foreach my $g (@groups) {
            my ($f, $k, $kind) = @$g;
            if ($kind eq 'cs_het') {
                my @sd = map { exp($t->[ $p + $_ ] / 2) } 0 .. $k - 1;
                my $e = exp($t->[ $p + $k ]); my $r = ($lo + $e) / (1 + $e);
                $V{$f} = [ map { my $i = $_; [ map { $sd[$i] * $sd[$_] * ($i == $_ ? 1 : $r) } 0 .. $k - 1 ] } 0 .. $k - 1 ];
                $p += $k + 1;
            }
            elsif ($kind eq 'diag' || $kind eq 'unit') {
                $V{$f} = [ map { my $i = $_; [ map { $i == $_ ? exp($t->[ $p + $i ]) : 0 } 0 .. $k - 1 ] } 0 .. $k - 1 ];
                $p += $k;
            }
            else {
                my @L = map { [ (0) x $k ] } 1 .. $k;
                for my $i (0 .. $k - 1) { for my $j (0 .. $i) { $L[$i][$j] = $i == $j ? exp($t->[$p]) : $t->[$p]; $p++; } }
                $V{$f} = [ map { my $i = $_; [ map { my $j = $_; my $x = 0; $x += $L[$i][$_] * $L[$j][$_] for 0 .. ($i < $j ? $i : $j); $x } 0 .. $k - 1 ] } 0 .. $k - 1 ];
            }
        }
        my $res = $free_res ? exp($t->[$p]) : $cs->{resid} eq 'known' ? 1 : $cs->{eps};
        return (\%V, $res);
    };
    my $total = sub {
        my ($V, $res) = @_;
        my $tot = $free_res ? $res : 0;
        foreach my $g (@groups) { my ($f, $k) = @$g; $tot += sum(map { $V->{$f}->[$_][$_] } 0 .. $k - 1) / ($g->[2] eq 'cs_het' || $g->[2] eq 'unit' ? $k : 1); }
        return $tot > 0 ? $tot : 1e-300;
    };
    # change between two parameter sets on the natural scale: variances and
    # covariances relative to the total variance, the correlation absolute
    my $dist = sub {
        my ($Va, $ra) = $from->($_[0]);
        my ($Vb, $rb) = $from->($_[1]);
        my $tot = $total->($Vb, $rb);
        my $d = abs(_csh_rho($Va->{$first}) - _csh_rho($Vb->{$first}));
        foreach my $g (@groups) {
            my ($f, $k) = @$g;
            for my $i (0 .. $k - 1) { for my $j (0 .. $k - 1) { my $x = abs($Va->{$f}->[$i][$j] - $Vb->{$f}->[$i][$j]) / $tot; $d = $x if $x > $d; } }
        }
        my $x = abs($ra - $rb) / $tot; $d = $x if $x > $d;
        return $d;
    };
    my $genomic = $cs->{genomic};
    my $runs = 0;
    my $setpar = sub {
        my ($par, $rix, $V, $res) = @_;
        _set_group($par, $_->[0], $_->[1], $V->{ $_->[0] }) for @groups;
        $par->[ $rix + 1 ] = sprintf('%.12g', $res);
        # genomic: G^-1 (and A22^-1) built by the first run only
        my @opt = !$genomic ? () : $runs == 0 ? ('OPTION saveGInverse', 'OPTION saveA22Inverse') : ('OPTION readGInverse', 'OPTION readA22Inverse');
        return ((grep { !/^OPTION (save|read)(GInverse|A22Inverse)\b/ } @$par), @opt);
    };
    my $em_step = sub {    # (parameters, -2logL at the input), or () on failure
        my $t = shift;
        my ($V, $res) = $from->($t);
        _write_lines('f90_em.par', $setpar->(\@em, $ri, $V, $res));
        unlink(grep { -e } qw(solutions yhat_residual));
        system('bash', '-c', _command($prog, 'f90_em.par', 'blupf90_em.out'));
        $runs++;
        my @out = _read_lines('blupf90_em.out');
        my ($m2l) = map { /-2logL\s*=\s*(\S+)/ ? $1 + 0 : () } @out;
        my ($fe) = grep { $out[$_] =~ /Final Estimates/ } reverse 0 .. $#out;
        return if !defined $fe;
        my (%N, $nres);
        for my $i ($fe .. $#out) {
            if ($out[$i] =~ /variance\(s\) for effect\s+(\d+)/) {
                my $e = $1;
                my ($g) = grep { $_->[0] == $e } @groups;
                $N{$e} = eval { _matrix_flow(\@out, $i, $g->[1]) } if $g && !$N{$e};
            }
            if (!defined($nres) && $out[$i] =~ /Residual variance/) { ($nres) = map { $_ + 0 } grep { /^-?[\d.]/ } split /\s+/, ($out[$i + 1] // ''); }
        }
        my %U;
        foreach my $g (@groups) {
            my ($f, $k, $kind) = @$g;
            my $M = $N{$f} or return;
            if ($kind eq 'cs_het') { $U{$f} = _csh_mstep($M)->{G}; }
            elsif ($kind eq 'diag') { $U{$f} = [ map { my $i = $_; [ map { $i == $_ ? $M->[$i][$i] : 0 } 0 .. $k - 1 ] } 0 .. $k - 1 ]; }
            elsif ($kind eq 'unit') {
                # blupf90+ averages over every record (a record of another
                # level adds its prior variance): the update over the records
                # of each level
                my @nk = @{ $cs->{unit}->{n_by} };
                $U{$f} = [ map { my $i = $_; [ map { $i != $_ ? 0 : $nk[$i] ? ($M->[$i][$i] * $n_rec - ($n_rec - $nk[$i]) * $V->{$f}->[$i][$i]) / $nk[$i] : $V->{$f}->[$i][$i] } 0 .. $k - 1 ] } 0 .. $k - 1 ];
                $U{$f}->[$_][$_] = 1e-12 * $cs->{eps} for grep { $U{$f}->[$_][$_] <= 0 } 0 .. $k - 1;
            }
            else { $U{$f} = $M; }
        }
        return ($to->(\%U, $free_res ? ($nres // $res) : $res), $m2l);
    };
    my @trace = (join("\t", 'runs', 'change', 'm2logL', 'rho', map { "var_$_" } 1 .. $K));
    my $th = $to->({ map { $_->[0] => _group_start(\@em, $_->[0], $_->[1]) } @groups }, $em[ $ri + 1 ] + 0);
    my ($done, $prev_l) = (0, undef);
    while ($runs < $CSH_MAX_ITER) {
        my ($t1, $l0) = $em_step->($th) or last;
        if ($dist->($t1, $th) < $CSH_TOL) { $th = $t1; $done = 1; last; }
        my ($t2, $l1) = $em_step->($t1) or do { $th = $t1; last };
        if ($dist->($t2, $t1) < $CSH_TOL) { $th = $t2; $done = 1; last; }
        # the likelihood has settled: EM then only crawls towards the optimum
        # (or moves within the precision of the blupf90+ output)
        if (defined($l0) && defined($prev_l) && abs($l0 - $prev_l) < $CSH_LOGL_STOP && $dist->($t1, $th) < 1e-3) { $th = $t1; $done = 1; last; }
        $prev_l = $l0;
        my @r = map { $t1->[$_] - $th->[$_] } 0 .. $#$th;
        my @v = map { $t2->[$_] - 2 * $t1->[$_] + $th->[$_] } 0 .. $#$th;
        my ($nr, $nv) = (sqrt(sum(0, map { $_ * $_ } @r)), sqrt(sum(0, map { $_ * $_ } @v)));
        my $alpha = $nv > 0 ? -$nr / $nv : -1;
        $alpha = -1 if $alpha > -1;
        $alpha = -50 if $alpha < -50;
        my $tx = [ map { $th->[$_] - 2 * $alpha * $r[$_] + $alpha * $alpha * $v[$_] } 0 .. $#$th ];
        my ($t3, $lx) = (grep { !defined($_) || $_ != $_ || abs($_) > 700 } @$tx) ? () : $em_step->($tx);
        # extrapolation kept when the likelihood at the extrapolated point is
        # not worse than after the first EM round (else the second EM round)
        my $new = ($t3 && !(grep { $_ != $_ || abs($_) > 700 } @$t3) && (!defined($lx) || !defined($l1) || $lx <= $l1 + $CSH_LOGL_TOL)) ? $t3 : $t2;
        # a variance heading to zero (EM reaches a zero boundary only very
        # slowly): the same point with it at practically zero, kept when the
        # likelihood there is not worse
        my ($Vo) = $from->($th);
        my ($Vs, $rs) = $from->($new);
        my $tot = $total->($Vs, $rs);
        my $moved = 0;
        foreach my $g (grep { $_->[2] ne 'cs_het' && ($_->[1] == 1 || $_->[2] ne 'us') } @groups) {
            my ($f, $k) = @$g;
            for my $i (0 .. $k - 1) {
                my $v = $Vs->{$f}->[$i][$i];
                next if !($v < 1e-3 * $tot && $v < $Vo->{$f}->[$i][$i] && $v > 1e-7 * $tot);
                $Vs->{$f}->[$i][$i] = 1e-8 * $tot;
                $moved = 1;
            }
        }
        if ($moved && $runs + 2 <= $CSH_MAX_ITER) {
            my ($n1, $ln) = $em_step->($new);
            my ($b1, $lb) = $n1 ? $em_step->($to->($Vs, $rs)) : ();
            $new = ($b1 && defined($lb) && defined($ln) && $lb <= $ln + $CSH_LOGL_TOL) ? $b1 : $n1 ? $n1 : $new;
        }
        my $d = $dist->($new, $th);
        my ($Vn) = $from->($new);
        push @trace, join("\t", $runs, sprintf('%.3g', $d), sprintf('%.6f', $l0 // 'NaN'), sprintf('%.6f', _csh_rho($Vn->{$first})), map { sprintf('%.6g', $Vn->{$first}->[$_][$_]) } 0 .. $K - 1);
        $th = $new;
        if ($d < $CSH_TOL) { $done = 1; last; }
    }
    # last run at the final estimates (solutions and output of the fit)
    my ($V, $res) = $from->($th);
    _write_lines('f90.par', $setpar->(\@fin, $rf, $V, $res));
    unlink(grep { -e } qw(solutions pev_pec_bf90 yhat_residual));
    system('bash', '-c', _command($prog));
    # the saved genomic inverses are working files (large and dense)
    unlink(grep { -e } qw(Gi A22i)) if $genomic;
    _write_lines('cs_het.txt', ($done ? "converged $runs" : "maxiter $runs"), sprintf('rho %.6f', _csh_rho($V->{$first})));
    _write_lines('cs_het_iterations.txt', @trace);
}

sub _pos { my $x = shift; return $x > 1e-300 ? $x : 1e-300; }

# Cholesky factor (lower) of a covariance matrix, with a small ridge when it
# is not positive definite
sub _chol {
    my $M = shift;
    my $k = @$M;
    my $ridge = 0;
    for my $try (0 .. 8) {
        my @L = map { [ (0) x $k ] } 1 .. $k;
        my $ok = 1;
        for my $i (0 .. $k - 1) {
            for my $j (0 .. $i) {
                my $s = $M->[$i][$j] + ($i == $j ? $ridge : 0);
                $s -= $L[$i][$_] * $L[$j][$_] for 0 .. $j - 1;
                if ($i == $j) { if ($s <= 0) { $ok = 0; last; } $L[$i][$i] = sqrt($s); }
                else { $L[$i][$j] = $s / $L[$j][$j]; }
            }
            last if !$ok;
        }
        return \@L if $ok;
        my $dg = sum(map { abs($M->[$_][$_]) } 0 .. $k - 1) / $k || 1;
        $ridge = $ridge ? 10 * $ridge : 1e-8 * $dg;
    }
    return [ map { my $i = $_; [ map { $i == $_ ? sqrt(_pos($M->[$i][$i])) : 0 } 0 .. $k - 1 ] } 0 .. $k - 1 ];
}

# common correlation of a heterogeneous compound symmetry matrix
sub _csh_rho {
    my $G = shift;
    my $K = @$G;
    return 0 if $K < 2;
    my $v = $G->[0][0] * $G->[1][1];
    return $v > 0 ? $G->[0][1] / sqrt($v) : 0;
}

# rows of a RANDOM_GROUP in a parameter file: index of its first row
sub _group_rows {
    my ($par, $first) = @_;
    for my $i (0 .. $#$par - 6) {
        next if $par->[$i] ne 'RANDOM_GROUP';
        my @e = split /\s+/, ($par->[$i + 1] // '');
        return $i + 7 if @e && $e[0] == $first;
    }
    die "random group $first not found in the parameter file\n";
}
sub _group_start {
    my ($par, $first, $K) = @_;
    my $r = _group_rows($par, $first);
    return [ map { [ map { $_ + 0 } split /\s+/, ($par->[ $r + $_ ] =~ s/^\s+//r) ] } 0 .. $K - 1 ];
}
sub _set_group {
    my ($par, $first, $K, $G) = @_;
    my $r = _group_rows($par, $first);
    $par->[ $r + $_ ] = join(' ', map { sprintf('%.12g', $_) } @{ $G->[$_] }) for 0 .. $K - 1;
}

# M-step: heterogeneous compound symmetry closest (Gaussian likelihood) to M:
# max over rho and sd of -log|G| - tr(G^-1 M), G = S C S. For a given rho,
# with t = 1/sd and A = C^-1 o M, the concave g(t) = 2 sum log t - t'At is
# maximised by coordinate ascent; rho by a grid and golden-section search.
sub _csh_mstep {
    my $M = shift;
    my $K = @$M;
    my @t0 = map { my $v = $M->[$_][$_]; $v > 1e-300 ? 1 / sqrt($v) : 1 } 0 .. $K - 1;
    my $prof = sub {
        my $rho = shift;
        my $a = 1 / (1 - $rho);
        my $b = $rho / (1 + ($K - 1) * $rho);
        my @A = map { my $i = $_; [ map { $a * (($i == $_ ? 1 : 0) - $b) * $M->[$i][$_] } 0 .. $K - 1 ] } 0 .. $K - 1;
        my @t = @t0;
        for my $sweep (1 .. 500) {
            my $chg = 0;
            for my $j (0 .. $K - 1) {
                my $bj = 0; $bj += $A[$j][$_] * $t[$_] for grep { $_ != $j } 0 .. $K - 1;
                my $ajj = $A[$j][$j] > 1e-300 ? $A[$j][$j] : 1e-300;
                my $new = (-$bj + sqrt($bj * $bj + 4 * $ajj)) / (2 * $ajj);
                $chg = abs($new - $t[$j]) / $t[$j] if abs($new - $t[$j]) / $t[$j] > $chg;
                $t[$j] = $new;
            }
            last if $chg < 1e-12;
        }
        my $q = 0; for my $i (0 .. $K - 1) { $q += $t[$i] * $A[$i][$_] * $t[$_] for 0 .. $K - 1; }
        my $ldc = ($K - 1) * log(1 - $rho) + log(1 + ($K - 1) * $rho);
        return (2 * sum(map { log($_) } @t) - $ldc - $q, \@t);
    };
    my $lo = $K > 1 ? -1 / ($K - 1) + 1e-4 : 0;
    $lo = -0.999 if $lo < -0.999;
    my $hi = 0.999;
    my @grid = map { $lo + ($hi - $lo) * $_ / 40 } 0 .. 40;
    my @val = map { ($prof->($_))[0] } @grid;
    my ($bi) = sort { $val[$b] <=> $val[$a] } 0 .. $#grid;
    my ($x0, $x1) = ($grid[ $bi > 0 ? $bi - 1 : 0 ], $grid[ $bi < $#grid ? $bi + 1 : $#grid ]);
    my $gr = (sqrt(5) - 1) / 2;
    my ($c, $d) = ($x1 - $gr * ($x1 - $x0), $x0 + $gr * ($x1 - $x0));
    my ($fc, $fd) = (($prof->($c))[0], ($prof->($d))[0]);
    for (1 .. 60) {
        if ($fc > $fd) { ($x1, $d, $fd) = ($d, $c, $fc); $c = $x1 - $gr * ($x1 - $x0); $fc = ($prof->($c))[0]; }
        else { ($x0, $c, $fc) = ($c, $d, $fd); $d = $x0 + $gr * ($x1 - $x0); $fd = ($prof->($d))[0]; }
        last if abs($x1 - $x0) < 1e-9;
    }
    my $rho = ($x0 + $x1) / 2;
    my ($best, $t) = $prof->($rho);
    my @sd = map { 1 / $_ } @$t;
    return { rho => $rho, sd => \@sd, G => [ map { my $i = $_; [ map { $sd[$i] * $sd[$_] * ($i == $_ ? 1 : $rho) } 0 .. $K - 1 ] } 0 .. $K - 1 ] };
}

# Starting values of a parameter file from the final estimates of another
# fit of the same model (random effects in the same order): the (co)variances
# of every random group and, for the log-linear residual model, its
# intercept (log of the residual variance; the level coefficients start near 0)
sub _warm_start {
    my ($par_file, $out_file) = @_;
    my @out = _read_lines($out_file);
    my ($fe) = grep { $out[$_] =~ /Final Estimates/ } reverse 0 .. $#out;
    return if !defined $fe;
    my (%G, $res);
    for my $i ($fe .. $#out) {
        if ($out[$i] =~ /variance\(s\) for effect\s+(\d+)/) {
            # the rows of the matrix: numbers only (the dates and labels below are not)
            my ($e, @v) = ($1);
            for my $r ($i + 1 .. $#out) { (my $l = $out[$r]) =~ s/^\s+|\s+$//g; last if $l !~ /^-?[\d.][\d.eE+\- ]*$/; push @v, map { $_ + 0 } split /\s+/, $l; }
            $G{$e} = \@v;
        }
        if (!defined($res) && $out[$i] =~ /Residual variance/) { ($res) = map { $_ + 0 } grep { /^-?[\d.]/ } split /\s+/, ($out[$i + 1] // ''); }
    }
    my @par = _read_lines($par_file);
    my @new;
    for (my $i = 0; $i <= $#par; $i++) {
        my $l = $par[$i];
        push @new, $l;
        if ($l =~ /^RANDOM_RESIDUAL/ && defined($res) && $res > 0) { push @new, sprintf('%.10g', $res); $i++; next; }
        if ($l eq 'RANDOM_GROUP') {
            my @eff = split /\s+/, ($par[$i + 1] // '');
            my $K = @eff;
            my $g = $G{ $eff[0] };
            push @new, @par[ $i + 1 .. $i + 6 ];    # effects, RANDOM_TYPE, type, FILE, file, (CO)VARIANCES
            $i += 6;
            if ($g && @$g >= $K * $K) {
                # a variance at zero would stay there: start it small instead
                my $d = 0; $d += $g->[$_ * $K + $_] for 0 .. $K - 1; $d = $d / $K || 1;
                for my $r (0 .. $K - 1) { push @new, join(' ', map { my $v = $g->[$r * $K + $_]; sprintf('%.10g', $r == $_ && $v < 1e-6 * $d ? 1e-3 * $d : $v) } 0 .. $K - 1); }
                $i += $K;
            }
            next;
        }
        if ($l =~ /^OPTION hetres_pol\s+(.*)$/ && defined($res) && $res > 0) {
            my $n = scalar(split /\s+/, $1);
            $new[-1] = 'OPTION hetres_pol ' . join(' ', sprintf('%.8g', log($res)), ('0.01') x ($n - 1));
        }
    }
    _write_lines($par_file, @new);
}

# convergence value of blupf90+ (the one compared with conv_crit 1e-9) below
# which AI-REML estimates count as settled when the round limit is reached
our $STABLE_DELTA = 1e-6;

# A fit that reached the round limit: settled (only the strict criterion was
# missed), or refitted once with EM-REML rounds first (steadier near zero
# variances), in the same folder. Returns the convergence note, or undef when
# the fit was refitted (the caller reads it again).
sub _round_limit {
    my ($self, $job, $out) = @_;
    my @delta = map { /In round\s+\d+\s+convergence=\s*(\S+)/ ? $1 + 0 : () } @$out;
    my $last = @delta ? $delta[-1] : undef;
    if (defined($last) && $last < $STABLE_DELTA) {
        return sprintf("AI-REML reached the %d-round limit with the estimates already settled (last convergence value %.1e); the results are reliable", $self->max_rounds, $last);
    }
    if (!$job->{em_refit} && !$job->{hetres}) {
        $self->_refit_em($job);
        return;
    }
    return sprintf("estimates still changing after %d AI-REML rounds (last convergence value %s; no EM-REML refit with one residual variance per level); the variance estimates of this fit are approximate",
                   $self->max_rounds, defined($last) ? sprintf('%.1e', $last) : 'unknown') if $job->{hetres};
    return sprintf("estimates still changing after a refit with %d EM-REML rounds first (%d rounds in all, last convergence value %s); a variance component is probably close to zero, so the variance estimates of this fit are approximate",
                   $EM_ROUNDS, 2 * $self->max_rounds, defined($last) ? sprintf('%.1e', $last) : 'unknown');
}

# Refit a job in its folder with EM-REML rounds before AI-REML (steadier
# near zero variances and from poor starting values)
sub _refit_em {
    my ($self, $job) = @_;
    my $wd = $job->{dir};
    my @par = grep { !/^OPTION (maxrounds|EM-REML)\b/ } _read_lines("$wd/f90.par");
    my $em = $self->em_rounds > $EM_ROUNDS ? $self->em_rounds : $EM_ROUNDS;
    $em = 2 * $self->max_rounds if $self->em_rounds >= $self->max_rounds;    # EM-REML only
    _write_lines("$wd/f90.par", @par, "OPTION EM-REML $em", 'OPTION maxrounds ' . (2 * $self->max_rounds));
    rename("$wd/blupf90.out", "$wd/blupf90_ai-reml.out");
    unlink("$wd/solutions");
    my $prog = $self->program() or return;
    my $cwd = File::Spec->rel2abs('.');
    chdir($wd);
    system('bash', '-c', _command($prog));
    chdir($cwd);
    $job->{em_refit} = 1;
}

# AI-REML that diverged (it can stop early with absurd estimates and report
# them as final): a residual variance at zero or a variance far above the
# variance of the data
sub _diverged {
    my ($vc, $y) = @_;
    my $vy = var(grep { defined } @$y) || return 0;
    return 1 if defined($vc->{Residual}) && $vc->{Residual} <= 1e-8 * $vy;
    return 1 if grep { $_ > 100 * $vy } values %$vc;
    return 0;
}

# Results of a fit run by run():
#   values   [{accession, value, se}] (BLUPs + mean of the fixed part, or BLUEs)
#   vc       { term => variance, Residual => variance } (lme4 names)
#   resid    residual of every record
#   random   { term => [{level, solution, se}] }
#   mu       mean of the fixed part, notes, rounds, seconds, dir
# Dies when blupf90+ failed.
# version printed by blupf90+ ("BLUPF90+ ver. 2.76"), kept from the first fit read
sub _note_version {
    my ($self, $out) = @_;
    return if $self->{program_version};
    my ($v) = map { /BLUPF90\+?\s+ver\.\s*(\S+)/i ? $1 : () } @$out[0 .. ($#$out < 15 ? $#$out : 15)];
    $self->{program_version} = $v if $v;
}
sub program_version { return $_[0]->{program_version}; }

sub read {
    my ($self, $job) = @_;
    return $self->read_mt($job) if $job->{mt};
    my $wd = $job->{dir};
    my @out = -e "$wd/blupf90.out" ? _read_lines("$wd/blupf90.out") : ();
    $self->_note_version(\@out);
    my @notes = @{$job->{notes}};
    my $tail = sub { join(' | ', grep { /\S/ } @out[ ($#out > 2 ? $#out - 1 : 0) .. $#out ]) };
    die "blupf90+ failed: " . $tail->() . "\n" if !-e "$wd/solutions";

    my %sol;    # effect -> level -> [solution, se]
    open(my $S, '<', "$wd/solutions") or die "Cannot read the solutions\n";
    <$S>;
    while (my $l = <$S>) {
        $l =~ s/^\s+//;
        my ($t, $e, $lv, $s, $se) = split /\s+/, $l;
        next if !defined($s);
        $sol{$e}->{$lv} = [ $s + 0, defined($se) ? $se + 0 : undef ];
    }
    close($S);

    my $n = $job->{n};
    my @resid = (undef) x $n;
    if (open(my $Y, '<', "$wd/yhat_residual")) {
        my @r;
        while (my $l = <$Y>) { $l =~ s/^\s+|\s+$//g; next if $l eq ''; my @f = split /\s+/, $l; push @r, $f[-1] + 0; }
        close($Y);
        @resid = @r if @r == $n;
    }

    my %vc;
    my $rounds = scalar(grep { /In round/ } @out);
    if ($job->{vce}) {
        my ($fe) = grep { $out[$_] =~ /Final Estimates/ } reverse 0 .. $#out;
        die "blupf90+ did not converge: " . $tail->() . "\n" if !defined($fe);
        for my $i ($fe .. $#out) {
            if ($out[$i] =~ /variance\(s\) for effect\s+(\d+)/) {
                if ($job->{unit} && $1 >= $job->{unit}->{first}) { $job->{unit}->{G} //= _matrix_flow(\@out, $i, $job->{unit}->{K}); next; }
                if ($job->{ge} && $1 >= $job->{ge}->{first}) { $job->{ge}->{G} //= _matrix_flow(\@out, $i, $job->{ge}->{K}); next; }
                if ($job->{rr_plot} && $1 >= $job->{rr_plot}->{first}) { $job->{rr_plot}->{G} //= _matrix_flow(\@out, $i, $job->{rr_plot}->{K}); next; }
                if ($job->{gxe} && $1 >= $job->{gxe}->{first}) { $job->{gxe}->{G} //= _matrix_flow(\@out, $i, $job->{gxe}->{K}); next; }
                my $k = $1 - $job->{first_random};
                ($vc{ $job->{rnames}->[$k] } = $out[$i + 1]) =~ s/^\s+|\s+$//g;
            }
            if ($out[$i] =~ /Residual variance/ && !defined($vc{Residual})) { ($vc{Residual} = $out[$i + 1]) =~ s/^\s+|\s+$//g; }
        }
        $vc{$_} += 0 for keys %vc;
        # known residual: reported as the mean of the record variances 1/w
        $vc{Residual} = mean(map { 1 / $_ } @{$job->{weights}}) if $job->{known_resid};
        if (my $u = $job->{unit}) {
            # one residual variance per level: record effect of the level + eps
            die "blupf90+ returned no residual variances per level\n" if !$u->{G};
            $job->{resid_by} = { map { $u->{labels}->[$_] => $u->{G}->[$_][$_] + $u->{eps} } 0 .. $u->{K} - 1 };
            $vc{Residual} = mean(values %{ $job->{resid_by} });
        }
        if (my $ge = $job->{ge}) {
            die "blupf90+ returned no genotype x level variances\n" if !$ge->{G};
            $job->{ge_by} = { map { $ge->{labels}->[$_] => $ge->{G}->[$_][$_] } 0 .. $ge->{K} - 1 };
            $vc{'accession:trial'} = mean(values %{ $job->{ge_by} });
        }
        if (my $h = $job->{hetres}) {
            # log-linear residual model: log(var) = a0 + a_k (level k > 1)
            my ($nr) = grep { $out[$_] =~ /^\s*new R\s*$/ } reverse $fe .. $#out;
            ($nr) = grep { $out[$_] =~ /^\s*new R\s*$/ } reverse 0 .. $#out if !defined $nr;
            my @a;
            if (defined $nr) { for my $i ($nr + 1 .. $nr + $h->{n}) { push @a, $1 + 0 if ($out[$i] // '') =~ /coefficient\s*=\s*(\S+)/; } }
            die "blupf90+ returned no residual variances per level\n" if @a != $h->{n};
            my %rv = map { $h->{labels}->[$_] => exp($a[0] + ($_ ? $a[$_] : 0)) } 0 .. $h->{n} - 1;
            $job->{resid_by} = \%rv;
            $vc{Residual} = mean(values %rv);
        }
        if (my $rp = $job->{rr_plot}) {
            die "blupf90+ returned no covariance matrix of the plot effect\n" if !$rp->{G};
            # variance of the plot mean over its occasions (as the plot effect in h2)
            my $t = 0; for my $i (0 .. $rp->{K} - 1) { $t += $_ for @{ $rp->{G}->[$i] }; }
            $vc{ 'plot_u' } = $t / ($rp->{K} * $rp->{K});
        }
        my %chk = %vc;
        delete $chk{Residual} if $job->{rr_plot};    # an unstructured plot covariance can hold the residual
        foreach my $g (grep { $_ && $_->{G} } $job->{gxe}, $job->{rr_plot}, $job->{ge}, $job->{unit}) { $chk{"_g$_"} = $g->{G}->[$_][$_] for 0 .. $#{ $g->{G} }; }
        if (_diverged(\%chk, $job->{y})) {
            die "the variance estimates diverged (AI-REML with one residual variance per level, no EM-REML possible): the model is probably over-parameterised for these data\n" if $job->{hetres};
            if (!$job->{em_refit}) { $self->_refit_em($job); $job->{diverged_refit} = 1; delete $_->{G} for grep { $_ } $job->{gxe}, $job->{rr_plot}, $job->{ge}, $job->{unit}; return $self->read($job); }
            die "the variance estimates diverged (AI-REML and EM-REML): the model is probably over-parameterised for these data\n";
        }
        my $limit = $job->{em_refit} ? 2 * $self->max_rounds : $self->max_rounds;
        if ($rounds >= $limit) {
            my $note = $self->_round_limit($job, \@out);
            return $self->read($job) if !defined($note);    # refitted with EM-REML first
            push @notes, $note;
        }
        elsif ($job->{diverged_refit}) {
            push @notes, "AI-REML diverged from its starting values; refitted with $EM_ROUNDS EM-REML rounds first, which converged";
        }
        elsif ($job->{em_refit}) {
            push @notes, "AI-REML did not settle in " . $self->max_rounds . " rounds; refitted with $EM_ROUNDS EM-REML rounds first, which converged";
        }
    }
    else {
        # least squares: residual variance from the residuals, standard errors rescaled
        my @w = $job->{weights} ? @{$job->{weights}} : (1) x $n;
        my $df = $n - $job->{rank};
        die "no residual degrees of freedom\n" if $df < 1 || grep { !defined } @resid;
        my $sse = sum(map { $w[$_] * $resid[$_]**2 } 0 .. $n - 1);
        $vc{Residual} = $sse / $df;
        my $f = sqrt($vc{Residual});
        foreach my $e (values %sol) { foreach my $v (values %$e) { $v->[1] *= $f if defined $v->[1]; } }
    }
    # heterogeneous compound symmetry: how its EM-REML loop ended
    if ($job->{cs_het}) {
        my @c = -e "$wd/cs_het.txt" ? _read_lines("$wd/cs_het.txt") : ();
        my ($state, $it) = split /\s+/, ($c[0] // 'maxiter 0');
        push @notes, $state eq 'converged' ? () : "the heterogeneous compound symmetry did not settle in $it EM-REML iterations (change above $CSH_TOL of the total variance); its variance estimates are approximate";
        $self->log->("  heterogeneous compound symmetry: $it EM-REML iterations around blupf90+, " . ($c[1] // ''));
    }
    foreach my $k (keys %vc) { die "blupf90+ returned invalid variance components\n" if $vc{$k} !~ /^-?[\d.]+(?:[eE][-+]?\d+)?$/; }
    unlink(map { "$wd/$_" } qw(fspak90.ord AI_inv.mat yhat_residual binary_factor_ord));
    # genomic module (preGSf90 inside blupf90+): quality control and G
    my %gs;
    if ($job->{genomic}) {
        my $grab = sub { my $re = shift; my ($l) = grep { /$re/ } @out; return $l && $l =~ /:\s*(-?\d+)\s*$/ ? $1 + 0 : undef; };
        %gs = (
            n_genotyped => $grab->(qr/Number of Genotyped Animals/i),
            n_snps => $grab->(qr/^\s*Number of SNPs:/),
            n_snps_used => $grab->(qr/Number of effective SNPs \(after QC\)/),
            n_individuals_used => $grab->(qr/Number of effective Individuals \(after QC\)/),
            removed_callrate => $grab->(qr/SNPs with Call Rate < callrate/),
            removed_maf => $grab->(qr/SNPs with MAF < minfreq/),
            removed_monomorphic => $grab->(qr/Monomorphic SNPs will be removed/),
            removed_animals => $grab->(qr/Removed Animals with Call rate/),
            mendelian_conflicts => $grab->(qr/Number of Parent-Progeny Mendelian Conflicts/),
        );
        die "no marker passed the quality control of the genotypes\n" if defined($gs{n_snps_used}) && $gs{n_snps_used} == 0;
        # preGSf90 work files (large; the G matrix is rebuilt from the SNP file)
        unlink(map { "$wd/$_" } grep { -e "$wd/$_" } qw(freqdata.count freqdata.count.after.clean Gen_call_rate Gen_conflicts));
    }

    # fixed part of every record (estimable whatever generalized inverse
    # blupf90+ used for redundant equations)
    my @fixed = (0) x $n;
    foreach my $f (@{$job->{fx}}) {
        my $s = $sol{ $f->{effect} } || {};
        for my $i (0 .. $n - 1) {
            my $b = $s->{ $f->{code}->[$i] };
            $fixed[$i] += ($b ? $b->[0] : 0) * $f->{x}->[$i];
        }
    }
    my %random;
    foreach my $k (0 .. $#{$job->{rnames}}) {
        my $name = $job->{rnames}->[$k];
        my $u = $sol{ $job->{first_random} + $k } || {};
        my $labels = $job->{rcodes}->{$name}->{labels};
        $random{$name} = [ map { { level => $labels->[$_ - 1], solution => $u->{$_}->[0], se => $u->{$_}->[1] } } sort { $a <=> $b } keys %$u ];
    }
    my $gxe_out;
    if (my $gx = $job->{gxe}) {
        # genotype value L' u_i; exact standard error sqrt(L' C_i L) from the
        # prediction error covariances of the group (level + upper triangle)
        my $K = $gx->{K};
        my $L = $gx->{L};
        die "blupf90+ returned no covariance matrix of the structured genotype effect\n" if !$gx->{G};
        my %pec;
        if (open(my $P, '<', "$wd/pev_pec_bf90")) {
            while (my $l = <$P>) {
                $l =~ s/^\s+|\s+$//g;
                my ($lv, @v) = split /\s+/, $l;
                next if !defined($lv) || @v != $K * ($K + 1) / 2;
                my $p = 0; my $tot = 0;
                for my $i (0 .. $K - 1) { for my $j ($i .. $K - 1) { $tot += ($i == $j ? 1 : 2) * $L->[$i] * $L->[$j] * $v[$p++]; } }
                $pec{$lv} = $tot;
            }
            close($P);
        }
        # levels: the accessions, or with a relationship matrix every
        # individual of the pedigree (ancestors too)
        my $labels = $job->{ped} ? $job->{rcodes}->{accession}->{labels} : $job->{acc}->{labels};
        my %in_data = map { $_ => 1 } @{ $job->{acc}->{labels} };
        my @lv = sort { $a <=> $b } uniq_keys(map { keys %{ $sol{$_} || {} } } $gx->{first} .. $gx->{first} + $K - 1);
        $random{accession} = [ map { my $l = $_; my $g = 0; $g += $L->[$_ - $gx->{first}] * ($sol{$_}->{$l} ? $sol{$_}->{$l}->[0] : 0) for $gx->{first} .. $gx->{first} + $K - 1;
                                     +{ level => $labels->[$l - 1], solution => $g, se => (defined($pec{$l}) && $pec{$l} >= 0 ? sqrt($pec{$l}) : undef) } } @lv ];
        my $G = $gx->{G};
        my $vt = 0; for my $i (0 .. $K - 1) { $vt += $L->[$i] * $G->[$i][$_] * $L->[$_] for 0 .. $K - 1; }
        my @rel = map { 1 - $pec{$_} / $vt } grep { defined($pec{$_}) && $in_data{ $labels->[ $_ - 1 ] // '' } } @lv;
        $gxe_out = { kind => $gx->{kind}, labels => $gx->{labels}, G => $G, L => $L, var_value => $vt,
                     reliability => (@rel && $vt > 0 ? mean(map { $_ < 0 ? 0 : $_ } @rel) : undef) };
        unlink("$wd/pev_pec_bf90");
    }
    my ($m2l) = map { /-2logL\s*=\s*(\S+)/ ? $1 + 0 : () } reverse @out;
    my $mu;
    if ($job->{mean_by}) {
        my (%s, %c);
        for (0 .. $n - 1) { my $g = $job->{mean_by}->[$_] // ''; $s{$g} += $fixed[$_]; $c{$g}++; }
        $mu = mean(map { $s{$_} / $c{$_} } keys %s);
    }
    else { $mu = mean(@fixed) // 0; }

    my @values;
    my $acc = $job->{acc};
    if ($job->{grandom}) {
        my %u = map { $_->{level} => $_ } @{$random{accession} || []};
        @values = map { { accession => $_, value => (defined($u{$_}) ? $mu + $u{$_}->{solution} : undef), se => ($u{$_} ? $u{$_}->{se} : undef) } } @{$acc->{labels}};
    }
    else {
        my $e1 = $sol{1} || {};
        my $mf = mean(@fixed) // 0;
        my $exact = $job->{dense} || !$job->{n_fixed_other};
        @values = map { { accession => $acc->{labels}->[$_ - 1], value => $e1->{$_}->[0] + $mf, se => ($exact ? $e1->{$_}->[1] : undef) } } sort { $a <=> $b } keys %$e1;
        push @notes, "standard errors of the BLUEs are not reported: the fixed effects other than accession need more than $DENSE_MAX columns" if !$exact;
    }
    my $sec = -e "$wd/elapsed.txt" ? (_read_lines("$wd/elapsed.txt"))[0] + 0 : undef;
    $self->log->(sprintf("  blupf90+ %s: %d records, %s, %.1f s", $job->{label}, $n, $job->{cs_het} ? 'EM-REML by Breedbase (heterogeneous compound symmetry)' : $job->{vce} ? "$rounds AI-REML rounds" : 'least squares', $sec // 0));
    return { values => \@values, vc => \%vc, resid => \@resid, random => \%random, mu => $mu, notes => \@notes, (%gs ? (genomic => \%gs) : ()), ($job->{inbreeding} ? (inbreeding => $job->{inbreeding}) : ()), ($job->{inbreeding} ? (inbreeding => $job->{inbreeding}) : ()),
             ($gxe_out ? (structure => $gxe_out) : ()),
             ($job->{rr_plot} ? (plot_structure => { kind => $job->{rr_plot}->{kind}, labels => $job->{rr_plot}->{labels}, G => $job->{rr_plot}->{G} }) : ()),
             ($job->{resid_by} ? (resid_by => $job->{resid_by}) : ()), ($job->{ge_by} ? (ge_by => $job->{ge_by}) : ()), (defined($m2l) ? (m2logL => $m2l) : ()),
             rounds => $rounds, seconds => $sec, dir => $wd, engine => 'BLUPF90+', model => $job->{model} };
}

sub _read_lines {
    my $file = shift;
    open(my $F, '<', $file) or return ();
    my @l = <$F>;
    close($F);
    chomp(@l);
    return @l;
}

# ---------------------------------------------------------------------------
# multi-trait models
# ---------------------------------------------------------------------------
# K traits measured on the same records (one record per accession x trial):
#   y_k = trial_k + accession_k + e_k
#   Var(accession) = G0 (x) I, A (pedigree), G or H (genomic)
#   Var(e)         = R0 (x) I
# blupf90+ handles the Kronecker products itself. spec:
#   label, traits => [K names], y => [ [n values] x K ] (undef = missing),
#   accession => [n], trial => [n], ped / genomic (as for prepare())
# The prediction error (co)variances of every accession across the K traits
# come from OPTION store_pev_pec (exact standard errors of linear functions).
our $MT_START_CORR = 0.3;    # starting genetic / residual correlation (0 would stay 0)

sub prepare_mt {
    my ($self, $spec) = @_;
    my $K = @{ $spec->{traits} };
    my $n = @{ $spec->{accession} };
    die "a multi-trait model needs at least two traits\n" if $K < 2;
    die "not enough records\n" if $n < 3;
    my $ped = $spec->{ped};
    my $genomic = $spec->{genomic};
    my @notes;
    my $d = { trial => $spec->{trial}, accession => $spec->{accession} };
    my $tr = _codes($d, ['trial'], $n);
    my $acc;
    if ($ped) {
        my %pos; $pos{ $ped->{id}->[$_] } = $_ + 1 for 0 .. $#{ $ped->{id} };
        $acc = { code => [ map { defined($_) ? $pos{$_} // 0 : 0 } @{ $spec->{accession} } ], n => scalar(@{ $ped->{id} }), labels => $ped->{id} };
    }
    else { $acc = _codes($d, ['accession'], $n); }
    my @cols = map { my $k = $_; [ "y$k", [ map { _fmt($_) } @{ $spec->{y}->[$k - 1] } ] ] } 1 .. $K;
    push @cols, [ 'trial', $tr->{n} > 1 ? $tr->{code} : [ (1) x $n ] ], [ 'accession', $acc->{code} ];
    my ($tpos, $apos) = ($K + 1, $K + 2);

    $self->n_fits($self->n_fits + 1);
    (my $safe = $spec->{label} // 'mt') =~ s/[^A-Za-z0-9_.-]+/_/g;
    my $wd = sprintf("%s/%03d_%s", File::Spec->rel2abs($self->keep_dir), $self->n_fits, $safe);
    make_path($wd);
    open(my $D, '>', "$wd/data.txt") or die "Cannot write $wd/data.txt\n";
    for my $i (0 .. $n - 1) { print $D join(' ', map { $_->[1]->[$i] } @cols), "\n"; }
    close($D);
    _write_lines("$wd/data_columns.txt", map { $_->[0] } @cols);

    # starting values: half of each trait's variance, correlation MT_START_CORR
    my @v = map { my $y = [ grep { defined } @{ $spec->{y}->[$_] } ]; (var(@$y) || 1) / 2 } 0 .. $K - 1;
    my $start = sub { map { my $i = $_; join(' ', map { sprintf('%.8g', $i == $_ ? $v[$i] : $MT_START_CORR * sqrt($v[$i] * $v[$_])) } 0 .. $K - 1) } 0 .. $K - 1 };
    my $ntr = $tr->{n} > 1 ? $tr->{n} : 1;
    my @par = ('DATAFILE', 'data.txt', 'NUMBER_OF_TRAITS', $K, 'NUMBER_OF_EFFECTS', 2,
               'OBSERVATION(S)', join(' ', 1 .. $K), 'WEIGHT(S)', '',
               'EFFECTS: POSITIONS_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT[EFFECT NESTED]',
               join(' ', ($tpos) x $K) . " $ntr cross", join(' ', ($apos) x $K) . " $acc->{n} cross",
               'RANDOM_RESIDUAL VALUES', $start->(),
               'RANDOM_GROUP', 2, 'RANDOM_TYPE', ($ped ? 'add_an_upginb' : 'diagonal'), 'FILE', ($ped ? 'pedigree.txt' : ''),
               '(CO)VARIANCES', $start->(),
               'OPTION method VCE', 'OPTION sol se', 'OPTION missing -999999999', 'OPTION store_pev_pec 2',
               $self->_reml_options());
    push @par, 'OPTION use_yams' if $ped;
    if ($genomic) {
        my $snp = File::Spec->abs2rel(File::Spec->rel2abs($genomic->{snp_file}), $wd);
        push @par, "OPTION SNP_file $snp", sprintf('OPTION minfreq %.4g', $genomic->{minfreq} // 0.05), sprintf('OPTION callrate %.4g', $genomic->{callrate} // 0.90);
    }
    _write_lines("$wd/f90.par", @par);
    my $model = "multi-trait (" . join(', ', @{ $spec->{traits} }) . ") ~ trial + (1|accession)";
    _write_lines("$wd/README.txt", "# BLUPF90+ multi-trait parameter file written by the Breedbase Analysis Pipeline (BLUPF90+ engine)",
                 "# model: $model, Var(accession) = G0 (x) relationship, Var(e) = R0 (x) I", "# traits (columns y1..y$K): " . join(', ', @{ $spec->{traits} }), "# run: echo f90.par | blupf90+");
    my $inb = $ped ? _write_pedigree($wd, $ped, \@notes) : undef;
    _write_levels("$wd/levels_trial.txt", $tr->{labels});
    _write_levels("$wd/levels_accession.txt", $acc->{labels});
    return { mt => 1, dir => $wd, label => $spec->{label} // 'mt', n => $n, K => $K, traits => $spec->{traits}, model => $model, notes => \@notes,
             vce => 1, acc => $acc, trial => $tr, inbreeding => $inb, ped => $ped ? 1 : 0, genomic => $genomic ? 1 : 0 };
}

# K x K matrix printed by blupf90+ after a header line
sub _matrix_after {
    my ($out, $i, $K) = @_;
    my @m;
    for my $r (1 .. $K) {
        (my $l = $out->[$i + $r] // '') =~ s/^\s+|\s+$//g;
        my @v = map { $_ + 0 } split /\s+/, $l;
        die "blupf90+ returned an incomplete covariance matrix\n" if @v != $K;
        push @m, \@v;
    }
    return \@m;
}

# K x K matrix after a header line, rows possibly wrapped over several lines
# (blupf90+ prints at most 9 values per line)
sub _matrix_flow {
    my ($out, $i, $K) = @_;
    my @v;
    for (my $r = $i + 1; $r <= $#$out && @v < $K * $K; $r++) {
        (my $l = $out->[$r]) =~ s/^\s+|\s+$//g;
        last if $l eq '' || $l !~ /^-?[\d.]/;
        push @v, map { $_ + 0 } split /\s+/, $l;
    }
    die "blupf90+ returned an incomplete covariance matrix\n" if @v != $K * $K;
    return [ map { [ @v[ $_ * $K .. $_ * $K + $K - 1 ] ] } 0 .. $K - 1 ];
}

# Results of a multi-trait fit:
#   G0, R0       K x K genetic and residual covariance matrices
#   mu           per trait: mean of the trial solutions
#   values       { accession => { solution => [K], se => [K], pec => K x K } }
#   notes, rounds, dir, model
sub read_mt {
    my ($self, $job) = @_;
    my $wd = $job->{dir};
    my $K = $job->{K};
    my @out = -e "$wd/blupf90.out" ? _read_lines("$wd/blupf90.out") : ();
    $self->_note_version(\@out);
    my @notes = @{ $job->{notes} };
    my $tail = sub { join(' | ', grep { /\S/ } @out[ ($#out > 2 ? $#out - 1 : 0) .. $#out ]) };
    die "blupf90+ failed: " . $tail->() . "\n" if !-e "$wd/solutions";
    my ($fe) = grep { $out[$_] =~ /Final Estimates/ } reverse 0 .. $#out;
    die "blupf90+ did not converge: " . $tail->() . "\n" if !defined($fe);
    my ($G0, $R0);
    for my $i ($fe .. $#out) {
        $G0 = _matrix_after(\@out, $i, $K) if !$G0 && $out[$i] =~ /variance\(s\) for effect\s+2\b/;
        $R0 = _matrix_after(\@out, $i, $K) if !$R0 && $out[$i] =~ /Residual variance/;
    }
    die "blupf90+ returned no covariance matrices\n" if !$G0 || !$R0;
    my $rounds = scalar(grep { /In round/ } @out);
    my $limit = $job->{em_refit} ? 2 * $self->max_rounds : $self->max_rounds;
    if ($rounds >= $limit) {
        my $note = $self->_round_limit($job, \@out);
        return $self->read_mt($job) if !defined($note);
        push @notes, $note;
    }
    elsif ($job->{em_refit}) {
        push @notes, "AI-REML did not settle in " . $self->max_rounds . " rounds; refitted with $EM_ROUNDS EM-REML rounds first, which converged";
    }

    my (%tsol, %asol);
    open(my $S, '<', "$wd/solutions") or die "Cannot read the solutions\n";
    <$S>;
    while (my $l = <$S>) {
        $l =~ s/^\s+//;
        my ($t, $e, $lv, $s, $se) = split /\s+/, $l;
        next if !defined($s);
        if ($e == 1) { push @{ $tsol{$t} }, $s + 0; }
        else { $asol{$lv}->[$t - 1] = [ $s + 0, defined($se) ? $se + 0 : undef ]; }
    }
    close($S);
    my @mu = map { mean(@{ $tsol{$_} || [0] }) } 1 .. $K;
    my %pec;
    if (open(my $P, '<', "$wd/pev_pec_bf90")) {
        while (my $l = <$P>) {
            $l =~ s/^\s+|\s+$//g;
            my ($lv, @v) = split /\s+/, $l;
            next if @v != $K * ($K + 1) / 2;
            my @m = map { [ (0) x $K ] } 1 .. $K;
            my $p = 0;
            for my $i (0 .. $K - 1) { for my $j ($i .. $K - 1) { $m[$i][$j] = $m[$j][$i] = $v[$p++] + 0; } }
            $pec{$lv} = \@m;
        }
        close($P);
    }
    my %values;
    my $labels = $job->{acc}->{labels};
    foreach my $lv (keys %asol) {
        my $name = $labels->[$lv - 1] // next;
        $values{$name} = { solution => [ map { $_ ? $_->[0] : 0 } @{ $asol{$lv} } ], se => [ map { $_ ? $_->[1] : undef } @{ $asol{$lv} } ], pec => $pec{$lv} };
    }
    unlink(map { "$wd/$_" } qw(fspak90.ord AI_inv.mat binary_factor_ord));
    my ($sec) = map { /^([\d.]+)/ ? $1 : () } (-e "$wd/elapsed.txt" ? _read_lines("$wd/elapsed.txt") : ());
    $self->log->(sprintf("  blupf90+ %s: multi-trait, %d traits, %d records, %d AI-REML rounds, %.1f s", $job->{label}, $K, $job->{n}, $rounds, $sec // 0));
    return { G0 => $G0, R0 => $R0, mu => \@mu, values => \%values, notes => \@notes, rounds => $rounds, dir => $wd, model => $job->{model} };
}

sub fit_mt {
    my ($self, $spec) = @_;
    my $job = eval { $self->prepare_mt($spec) } or return { error => _clean($@ || 'model could not be prepared') };
    $self->run([$job]);
    return eval { $self->read_mt($job) } // { error => _clean($@) };
}

# prepare + run + read one model
sub fit {
    my ($self, $spec) = @_;
    my $job = $self->prepare($spec);
    $self->run([$job]);
    return $self->read($job);
}

# Fit independent models in parallel. Returns one result per spec, in order:
# the fit, or { error => message }.
sub fit_all {
    my ($self, $specs) = @_;
    my @jobs = map { my $s = $_; my $j = eval { $self->prepare($s) }; $j // { error => ($@ || 'model could not be prepared') } } @$specs;
    $self->run([ grep { !$_->{error} } @jobs ]);
    return [ map { my $j = $_; $j->{error} ? { error => _clean($j->{error}) } : (eval { $self->read($j) } // { error => _clean($@) }) } @jobs ];
}

sub uniq_keys { my %s; return grep { !$s{$_}++ } @_; }

sub _clean { my $m = shift // ''; $m =~ s/\s+$//; $m =~ s/ at \S+ line \d+\.?$//; return $m; }

1;
