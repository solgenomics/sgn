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

has 'bin_dir' => (is => 'rw', isa => 'Maybe[Str]');
has 'keep_dir' => (is => 'rw', isa => 'Str', default => sub { File::Spec->tmpdir() . "/blupf90_$$" });
has 'log' => (is => 'rw', isa => 'CodeRef', default => sub { sub { } });
has 'max_parallel' => (is => 'rw', isa => 'Int', lazy => 1, builder => '_default_parallel');
has 'n_fits' => (is => 'rw', isa => 'Int', default => 0);
has 'numeric' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });

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
        push @rnames, 'accession';
    }
    # random effects with a supplied covariance (user_cov: name -> {file,
    # levels, key}: covariance over 'levels', the level key of every record)
    my $ucov = $spec->{user_cov} || {};
    foreach my $rt (@{ $spec->{random} || [] }) {
        next if $rt eq 'accession' || $rcodes{$rt};
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

    $self->n_fits($self->n_fits + 1);
    (my $safe = $spec->{label} // 'model') =~ s/[^A-Za-z0-9_.-]+/_/g;
    my $wd = sprintf("%s/%03d_%s", File::Spec->rel2abs($self->keep_dir), $self->n_fits, $safe);
    make_path($wd);

    open(my $D, '>', "$wd/data.txt") or die "Cannot write $wd/data.txt\n";
    for my $i (0 .. $n - 1) { print $D join(' ', map { $_->[1]->[$i] } @cols), "\n"; }
    close($D);
    _write_lines("$wd/data_columns.txt", map { $_->[0] } @cols);

    my $vce = @rnames ? 1 : 0;
    my $v0 = $vce ? (var(@{$d->{y}}) || 1e-6) / (@rnames + 1) : 1;
    $v0 = 1e-6 if $v0 < 1e-6;
    my $model = "y ~ " . join(' + ', ($grandom ? '(1|accession)' : 'accession'), @labs, map { "(1|$_)" } grep { $_ ne 'accession' } @rnames);
    my @par = ('DATAFILE', 'data.txt', 'NUMBER_OF_TRAITS', 1, 'NUMBER_OF_EFFECTS', scalar(@eff),
               'OBSERVATION(S)', 1, 'WEIGHT(S)', ($spec->{weights} ? 2 : ''),
               'EFFECTS: POSITIONS_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT[EFFECT NESTED]', @eff,
               'RANDOM_RESIDUAL VALUES', sprintf('%.10g', $v0));
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
    push @par, 'OPTION method VCE' if $vce;
    # YAMS (sparse supernodal factorization) pays off on large and pedigree models only
    push @par, 'OPTION use_yams' if $vce && ($ped || $n > 20000);
    if ($genomic) {
        # path relative to the fit folder, so the folders can be re-run elsewhere
        my $snp = File::Spec->abs2rel(File::Spec->rel2abs($genomic->{snp_file}), $wd);
        push @par, "OPTION SNP_file $snp", sprintf('OPTION minfreq %.4g', $genomic->{minfreq} // 0.05), sprintf('OPTION callrate %.4g', $genomic->{callrate} // 0.90);
    }
    push @par, 'OPTION sol se', 'OPTION missing -999999999', 'OPTION residual';
    push @par, 'OPTION conv_crit 1e-9', "OPTION maxrounds $MAX_ROUNDS" if $vce;
    _write_lines("$wd/f90.par", @par);
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
        system('bash', '-c', $cmd);
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
    my $prog = shift;
    # blupf90+ keeps large arrays on the stack (segfaults with the 8 MB default)
    return "ulimit -s unlimited 2>/dev/null || ulimit -s \$(ulimit -H -s) 2>/dev/null; export OMP_STACKSIZE=64M OMP_NUM_THREADS=1; echo f90.par | '$prog' > blupf90.out 2>&1";
}

# convergence value of blupf90+ (the one compared with conv_crit 1e-9) below
# which AI-REML estimates count as settled when the round limit is reached
our $STABLE_DELTA = 1e-6;
our $EM_ROUNDS = 50;    # EM-REML rounds before AI-REML when a fit is refitted

# A fit that reached the round limit: settled (only the strict criterion was
# missed), or refitted once with EM-REML rounds first (steadier near zero
# variances), in the same folder. Returns the convergence note, or undef when
# the fit was refitted (the caller reads it again).
sub _round_limit {
    my ($self, $job, $out) = @_;
    my @delta = map { /In round\s+\d+\s+convergence=\s*(\S+)/ ? $1 + 0 : () } @$out;
    my $last = @delta ? $delta[-1] : undef;
    if (defined($last) && $last < $STABLE_DELTA) {
        return sprintf("AI-REML reached the %d-round limit with the estimates already settled (last convergence value %.1e); the results are reliable", $MAX_ROUNDS, $last);
    }
    if (!$job->{em_refit}) {
        my $wd = $job->{dir};
        my @par = grep { !/^OPTION (maxrounds|EM-REML)\b/ } _read_lines("$wd/f90.par");
        _write_lines("$wd/f90.par", @par, "OPTION EM-REML $EM_ROUNDS", 'OPTION maxrounds ' . (2 * $MAX_ROUNDS));
        rename("$wd/blupf90.out", "$wd/blupf90_ai-reml.out");
        unlink("$wd/solutions");
        my $prog = $self->program() or return;
        my $cwd = File::Spec->rel2abs('.');
        chdir($wd);
        system('bash', '-c', _command($prog));
        chdir($cwd);
        $job->{em_refit} = 1;
        return;
    }
    return sprintf("estimates still changing after a refit with %d EM-REML rounds first (%d rounds in all, last convergence value %s); a variance component is probably close to zero, so the variance estimates of this fit are approximate",
                   $EM_ROUNDS, 2 * $MAX_ROUNDS, defined($last) ? sprintf('%.1e', $last) : 'unknown');
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
                my $k = $1 - $job->{first_random};
                ($vc{ $job->{rnames}->[$k] } = $out[$i + 1]) =~ s/^\s+|\s+$//g;
            }
            if ($out[$i] =~ /Residual variance/ && !defined($vc{Residual})) { ($vc{Residual} = $out[$i + 1]) =~ s/^\s+|\s+$//g; }
        }
        $vc{$_} += 0 for keys %vc;
        my $limit = $job->{em_refit} ? 2 * $MAX_ROUNDS : $MAX_ROUNDS;
        if ($rounds >= $limit) {
            my $note = $self->_round_limit($job, \@out);
            return $self->read($job) if !defined($note);    # refitted with EM-REML first
            push @notes, $note;
        }
        elsif ($job->{em_refit}) {
            push @notes, "AI-REML did not settle in $MAX_ROUNDS rounds; refitted with $EM_ROUNDS EM-REML rounds first, which converged";
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
    $self->log->(sprintf("  blupf90+ %s: %d records, %s, %.1f s", $job->{label}, $n, $job->{vce} ? "$rounds AI-REML rounds" : 'least squares', $sec // 0));
    return { values => \@values, vc => \%vc, resid => \@resid, random => \%random, mu => $mu, notes => \@notes, (%gs ? (genomic => \%gs) : ()), ($job->{inbreeding} ? (inbreeding => $job->{inbreeding}) : ()), ($job->{inbreeding} ? (inbreeding => $job->{inbreeding}) : ()),
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
               'OPTION conv_crit 1e-9', "OPTION maxrounds $MAX_ROUNDS");
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
    my $limit = $job->{em_refit} ? 2 * $MAX_ROUNDS : $MAX_ROUNDS;
    if ($rounds >= $limit) {
        my $note = $self->_round_limit($job, \@out);
        return $self->read_mt($job) if !defined($note);
        push @notes, $note;
    }
    elsif ($job->{em_refit}) {
        push @notes, "AI-REML did not settle in $MAX_ROUNDS rounds; refitted with $EM_ROUNDS EM-REML rounds first, which converged";
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

sub _clean { my $m = shift // ''; $m =~ s/\s+$//; $m =~ s/ at \S+ line \d+\.?$//; return $m; }

1;
