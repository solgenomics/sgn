package CXGN::BLUPF90::Pipeline;

=head1 NAME

CXGN::BLUPF90::Pipeline - the Analysis Pipeline on the BLUPF90+ engine, without R

=head1 SYNOPSIS

  my $p = CXGN::BLUPF90::Pipeline->new({
      phenotype_file => 'dataset.phenotype.txt',    # Breedbase phenotype download (plot level)
      recipe => $recipe,                             # Analysis Pipeline recipe (hashref)
      output_file => 'run.results.json',
      exclusions_file => 'run.exclusions.json',      # optional
      output_prefix => 'run',                        # csv files, BLUPF90 files
      pedigree_file => 'dataset.pedigree.txt',       # optional
      repeated_file => 'dataset.repeated.txt',       # optional
  });
  $p->run();

or bin/script_factory_blupf90.pl (the command of an Analysis Pipeline job).

=head1 DESCRIPTION

Runs the recipe of the Analysis Pipeline (/tools/script_factory) when its
model engine is BLUPF90+: data preparation (plot level, treatments,
repeated measurements, covariates), design detection and factor support,
outlier rules, two-stage (stage 1 per trial, weighted stage 2) or
single-stage models, selection index and environmental zones. Every mixed
model and every least squares fit is solved by blupf90+ through
L<CXGN::BLUPF90>; independent models (trials, traits) run in parallel. The
results file has the same content as the one of the R pipeline
(R/script_factory/script_factory_pipeline.R), so the results page, the
store dialog and the logs work the same with both engines.

Differences with the R engine: SpATS (an R package) is not available;
trials with a row x column layout get a SpATS-like 2D P-spline surface
(CXGN::BLUPF90::Spatial: one smoothing variance instead of SpATS's separate
row and column smoothing), linear row / column trends and random row and
column effects within replicate in stage 1 (on real trials its stage-1
BLUEs correlate 0.98-1.00 with SpATS's). Custom formulas
are limited to the terms BLUPF90+ fits (fixed terms, (1|a) and (1|a:b)).

Progress lines start with "[script_factory]" and warnings with "WARNING: ",
on STDERR, as in the R pipeline; a fatal error prints "Error: ..." and
"Execution halted".

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
# missing value (undef), returned by functions that are used in scalar and list context
use constant NA => undef;
use Moose;
use JSON::XS;
use File::Basename qw(basename dirname);
use File::Path qw(remove_tree make_path);
use Time::Local qw(timegm);
use List::Util qw(sum min max first);
use CXGN::BLUPF90;
use CXGN::BLUPF90::Spatial;
use CXGN::BLUPF90::Stats qw(mean var sd median quantile7 mad holm harmonic_mean pnorm_upper pf_upper cor
                            hclust_average cutree_height backfit n_levels uniq);

our $VERSION_TAG = '1.7';

has 'phenotype_file' => (is => 'rw', isa => 'Str', required => 1);
has 'recipe' => (is => 'rw', isa => 'HashRef', required => 1);
has 'output_file' => (is => 'rw', isa => 'Str', required => 1);
has 'exclusions_file' => (is => 'rw', isa => 'Maybe[Str]');
has 'output_prefix' => (is => 'rw', isa => 'Maybe[Str]');
has 'pedigree_file' => (is => 'rw', isa => 'Maybe[Str]');
has 'repeated_file' => (is => 'rw', isa => 'Maybe[Str]');
# marker dosages of the genotyping protocol (Breedbase dosage matrix: header
# 'Marker' + marker names, one line per accession), for the G and H models
has 'genotypes_file' => (is => 'rw', isa => 'Maybe[Str]');
has 'bin_dir' => (is => 'rw', isa => 'Maybe[Str]');

my $TRUE = JSON::XS::true;
my $FALSE = JSON::XS::false;
my %FACTOR_LABEL = (rep => 'Replicate', block => 'Block', row => 'Row', col => 'Column');
my @FACTORS = qw(rep block row col);
my %DESIGN_LABEL = (row_column => 'Row-column', augmented => 'Augmented', alpha_lattice => 'Alpha-lattice', rcbd => 'RCBD', crd => 'CRD', unreplicated => 'Unreplicated');
my @REP_SUMMARIES = qw(mean first last max min sum auc slope all multi);
our $COV_DAYS = 3;  # largest distance (days) between a measurement and the covariate value it takes
my %REP_LABEL = (mean => 'mean', first => 'first measurement', last => 'last measurement', max => 'maximum', min => 'minimum',
                 sum => 'sum', auc => 'area under the curve', slope => 'slope per day', all => 'all measurements (repeated-measures model)', multi => 'multi-trait (each date a trait)');
my @FORMULA_VARS = qw(accession trial location year rep block row col rowN colN mother father check);

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
sub short_trait { my $x = shift // ''; $x =~ s/\|.*$//; return $x; }
sub cov_name { my $x = short_trait(shift); $x =~ s/[^A-Za-z0-9]+/_/g; return "cov_$x"; }
sub is_num { my $v = shift; return defined($v) && $v =~ /^\s*-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?\s*$/ ? 1 : 0; }
sub num { my $v = shift; return is_num($v) ? $v + 0 : undef; }
sub opt { my ($h, $k, $def) = @_; return $def if ref($h) ne 'HASH' || !defined($h->{$k}); my $v = $h->{$k}; return $def if ref($v) eq 'ARRAY' && !@$v; return $v; }
sub list { my $v = shift; return () if !defined($v); return ref($v) eq 'ARRAY' ? @$v : ($v); }
sub pretty_model {
    my $x = shift // '';
    $x =~ s/\btr_date\b/date/g; $x =~ s/\bdate_f\b/date/g; $x =~ s/\bplot_u\b/plot/g; $x =~ s/\bmday\b/days/g;
    $x =~ s/\(1\|surface\)/PSpline(col, row)/g; $x =~ s/\brcN\b/rowN:colN/g;
    return $x;
}
sub sig { my $v = shift; return NA if !defined($v) || $v !~ /\d/ || $v =~ /nan|inf/i; return 0 + sprintf('%.8g', $v); }

sub warn_msg {
    my ($self, @m) = @_;
    my $msg = pretty_model(join('', map { $_ // '' } @m));
    push @{$self->{warnings}}, $msg;
    print STDERR "WARNING: $msg\n";
}

# notes of a fit as log messages: convergence notes (AI-REML / EM-REML) each
# on their own line, so the analysis log files them under "Convergence
# notes"; the other notes of the fit together
sub fit_notes {
    my ($self, $where, $notes) = @_;
    my @conv = grep { /AI-REML|EM-REML/ } @{ $notes || [] };
    my @other = grep { !/AI-REML|EM-REML/ } @{ $notes || [] };
    $self->warn_msg("$where: ", join('; ', @other), ".") if @other;
    $self->warn_msg("$where: $_.") for @conv;
}

# P-spline surface covariance of a trial, over the positions of all its plots
# (built once, shared by every trait and fit of the trial); undef when the
# field is too small (the reason is kept in surface_error)
sub _trial_surface {
    my ($self, $trial) = @_;
    return $self->{surface}->{$trial} if exists $self->{surface}->{$trial};
    my $d = $self->{dat};
    my @ii = @{ $self->{rows_of}->{$trial} || [] };
    (my $safe = $trial) =~ s/[^A-Za-z0-9_.-]+/_/g;
    my $dir = $self->output_prefix . '_blupf90';
    make_path($dir) if !-d $dir;
    my $file = "$dir/surface_$safe.txt";
    my $s = eval {
        CXGN::BLUPF90::Spatial::surface_covariance({ row => [ map { $d->{row}->[$_] } @ii ], col => [ map { $d->{col}->[$_] } @ii ], file => $file });
    };
    if (!$s) { ($self->{surface_error}->{$trial} = $@ // 'unknown error') =~ s/\s+$//; return $self->{surface}->{$trial} = undef; }
    $s->{file} = $file;
    return $self->{surface}->{$trial} = $s;
}
sub step { my ($self, @m) = @_; print STDERR "[script_factory] ", join('', map { $_ // '' } @m), "\n"; }
sub warn_once { my ($self, $key, @m) = @_; return if $self->{warned}->{$key}++; $self->warn_msg(@m); }

# frames: { column => [values] } (all columns the same length)
sub nrow { my $d = shift; return scalar(@{ $d->{unit} || $d->{y} || [] }); }
sub subset {
    my ($d, $idx) = @_;
    my %s;
    foreach my $k (keys %$d) { $s{$k} = [ @{$d->{$k}}[@$idx] ]; }
    return \%s;
}
sub which { my ($d, $f) = @_; return [ grep { $f->($_) } 0 .. nrow($d) - 1 ]; }

# ---------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------
sub run {
    my $self = shift;
    my $ok = eval { $self->_run(); 1 };
    if (!$ok) {
        my $e = $@ || 'unknown error';
        $e =~ s/\s+$//;
        print STDERR "Error: $e\nExecution halted\n";
        return 0;
    }
    return 1;
}

sub _run {
    my $self = shift;
    $self->{warnings} = [];
    my $recipe = $self->recipe;
    $self->output_prefix($self->output_file =~ s/\.json$//r) if !$self->output_prefix;
    $self->{f90} = CXGN::BLUPF90->new({ keep_dir => $self->output_prefix . '_blupf90', bin_dir => $self->bin_dir, log => sub { $self->step(@_) } });
    die "BLUPF90+ is not installed on the analysis server (blupf90+ not found); choose the R engine.\n" if !$self->{f90}->program();
    $self->step("BLUPF90+ engine (", $self->{f90}->program(), "), up to ", $self->{f90}->max_parallel, " models in parallel");

    $self->_read_data();
    $self->_treatments();
    $self->_select_traits();
    $self->_pedigree();
    $self->_repeated();
    $self->_trait_columns();
    $self->_covariates();
    $self->_designs();
    $self->_outliers();
    if ((opt($recipe, 'stop_after', '') // '') eq 'outliers') {
        $self->_write_json({ outliers => $self->{outliers}, outlier_summary => $self->{outlier_summary}, warnings => $self->{warnings} });
        return;
    }
    $self->_genetic_model();
    $self->_multi_trait_setup();
    $self->{variance_components} = [];
    $self->{residuals} = {};
    $self->{ancestor_values} = [];
    $self->_stage1();
    if ($self->{strategy} eq 'two_stage') { $self->_stage2(); } else { $self->_single_stage(); }
    die "No model could be fitted. Check the warnings and the trait data.\n" if !@{$self->{genotype_values}};
    $self->_wide();
    $self->_index();
    $self->_zones();
    $self->_output();
}

# ---------------------------------------------------------------------------
# data
# ---------------------------------------------------------------------------
sub _read_data {
    my $self = shift;
    $self->step("Reading ", $self->phenotype_file);
    open(my $F, '<', $self->phenotype_file) or die "Cannot open the phenotype file " . $self->phenotype_file . "\n";
    my $h = <$F>;
    $h =~ s/\r?\n$//;
    my @keys = split /\t/, $h, -1;
    my @rows;
    while (my $l = <$F>) {
        $l =~ s/\r?\n$//;
        next if $l eq '';
        my @f = split /\t/, $l, -1;
        push @f, ('') x (@keys - @f) if @f < @keys;
        push @rows, [ map { (!defined($_) || $_ eq '' || $_ eq 'NA' || $_ eq 'NaN' || $_ eq '.') ? undef : $_ } @f ];
    }
    close($F);
    my %idx; $idx{$keys[$_]} //= $_ for 0 .. $#keys;
    foreach my $req (qw(studyName germplasmName)) { die "Phenotype file is missing required column(s): $req\n" if !defined $idx{$req}; }

    if (defined $idx{observationLevel}) {
        my $i = $idx{observationLevel};
        my @plot = grep { lc($_->[$i] // '') eq 'plot' } @rows;
        if (@plot) {
            my $other = grep { defined($_->[$i]) && lc($_->[$i]) ne 'plot' } @rows;
            $self->warn_msg("Only plot-level observations were used; $other non-plot rows were ignored.") if $other;
            @rows = @plot;
        }
    }
    $self->{keys} = \@keys;
    $self->{idx} = \%idx;
    $self->{rows} = \@rows;
    my $col = sub { my @c = @_; foreach my $c (@c) { if (defined $idx{$c}) { my $i = $idx{$c}; return [ map { $_->[$i] } @rows ]; } } return [ (undef) x @rows ]; };
    $self->{pheno_col} = sub { my $name = shift; my $i = $idx{$name}; return defined($i) ? [ map { $_->[$i] } @rows ] : undef; };

    my %d = (
        unit => $col->('observationUnitName', 'plotName'), trial => $col->('studyName'), year => $col->('studyYear', 'year'),
        location => $col->('locationName', 'location'), design_raw => $col->('studyDesign', 'design'), accession => $col->('germplasmName'),
        rep => $col->('replicate', 'rep_number'), block => $col->('blockNumber', 'block_number'),
        row => [ map { num($_) } @{$col->('rowNumber', 'row_number')} ], col => [ map { num($_) } @{$col->('colNumber', 'col_number')} ],
        entry_type => [ map { $_ // 'test' } @{$col->('entryType')} ],
    );
    my $n = scalar(@rows);
    for my $i (0 .. $n - 1) {
        $d{unit}->[$i] //= "row_" . ($i + 1);
        $d{location}->[$i] //= 'unknown location';
        $d{year}->[$i] //= '';
        $d{trial}->[$i] //= 'unknown';
    }
    $self->{dat} = \%d;
    $self->{n} = $n;

    my %meta = map { $_ => 1 } qw(studyYear programDbId programName programDescription studyDbId studyName studyDescription studyDesign
        plotWidth plotLength fieldSize fieldTrialIsPlannedToBeGenotyped fieldTrialIsPlannedToCross plantingDate harvestDate locationDbId
        locationName germplasmDbId germplasmName germplasmSynonyms observationLevel observationUnitDbId observationUnitName replicate
        blockNumber plotNumber rowNumber colNumber entryType plantNumber notes);
    $self->{available_traits} = [ grep { !$meta{$_} && !/^plantedSeedlot|^availableGermplasm/ } @keys ];
}

sub _treatments {
    my $self = shift;
    my $trt_cfg = opt($self->recipe, 'treatments', {});
    my @types = list(opt($trt_cfg, 'types', []));
    @types = ('Fertilizer', 'Fungicide', 'Irrigation', 'Drought', 'Herbicide', 'Weeding', 'Pruning', 'Hormone treatment', 'Light treatment') if !@types;
    my @keys = @{$self->{keys}};
    my $notes_i = first { $keys[$_] eq 'notes' } 0 .. $#keys;
    my @legacy = defined($notes_i) && $notes_i < $#keys ? @keys[ $notes_i + 1 .. $#keys ] : ();
    my @onto = grep { /\|(EXPERIMENT_TREATMENT|COMP_EXP_TREATMENT):/ } @keys;
    my %not_trait = map { $_ => 1 } (@legacy, @onto);
    $self->{treatment_cols} = \%not_trait;
    $self->{available_traits} = [ grep { !$not_trait{$_} } @{$self->{available_traits}} ];

    my $var_name = sub { my $x = shift; $x =~ s/[^A-Za-z0-9]+/_/g; $x =~ s/^_+|_+$//g; return "trt_$x"; };
    my $applied = sub { my $v = shift; return 0 if !defined $v; $v =~ s/^\s+|\s+$//g; return ($v ne '' && $v ne '0' && $v ne 'NA') ? 1 : 0; };
    my $legacy_factor = sub {
        my $col = shift;
        foreach my $ty (@types) {
            (my $t = quotemeta($ty)) =~ s/(?:\\ |_)+/[_ ]/g;
            if ($col =~ /(^|[_ ])($t)([_ ]|$)/i) {
                my $rest = substr($col, $+[0]);
                (my $level = $rest) =~ s/[_ ]+/ /g;
                $level =~ s/^\s+|\s+$//g;
                return ($ty, $level ne '' ? $level : $col);
            }
        }
        return ($col, 'applied');
    };
    my (%tf, @order);
    my $n = $self->{n};
    foreach my $col (@legacy) {
        my ($factor, $level) = $legacy_factor->($col);
        my $var = $var_name->($factor);
        my $vals = $self->{pheno_col}->($col);
        my @on = grep { $applied->($vals->[$_]) } 0 .. $n - 1;
        next if !@on;
        if (!$tf{$var}) { $tf{$var} = { name => $factor, var => $var, source => 'management factor', values => [ (undef) x $n ] }; push @order, $var; }
        my $cur = $tf{$var}->{values};
        foreach my $i (@on) { $cur->[$i] = (!defined($cur->[$i]) || $cur->[$i] eq $level) ? $level : "$cur->[$i] + $level"; }
    }
    foreach my $col (@onto) {
        my $var = $var_name->(short_trait($col));
        my @v = map { my $x = $_; $applied->($x) ? ($x =~ s/^\s+|\s+$//gr) : undef } @{$self->{pheno_col}->($col)};
        next if !grep { defined } @v;
        push @order, $var if !$tf{$var};
        $tf{$var} = { name => short_trait($col), var => $var, source => 'treatment variable', values => \@v };
    }
    foreach my $k (@order) { $_ //= 'none' for @{$tf{$k}->{values}}; $self->{dat}->{$k} = $tf{$k}->{values}; }
    $self->{tf} = \%tf;
    $self->{tf_order} = \@order;
    my $pick = sub { my %want = map { $_ => 1 } @_; return grep { $want{$_} || $want{$tf{$_}->{name}} } @order; };
    $self->{trt_use} = [ $pick->(list(opt($trt_cfg, 'use', []))) ];
    $self->{trt_gxt} = [ $pick->(list(opt($trt_cfg, 'gxt', []))) ];
    my %known = map { ($_ => 1, $tf{$_}->{name} => 1) } @order;
    foreach my $x (list(opt($trt_cfg, 'use', [])), list(opt($trt_cfg, 'gxt', []))) {
        $self->warn_msg("Treatment '$x' is not in this dataset and was skipped.") if !$known{$x};
    }
    if (@order) {
        $self->step("Treatments: ", join(', ', map { "$tf{$_}->{name} (" . scalar(uniq(@{$tf{$_}->{values}})) . " levels)" } @order),
                    "; in the models: ", (join(', ', uniq(@{$self->{trt_use}}, @{$self->{trt_gxt}})) || 'none'));
    }
}

sub match_trait {
    my ($self, $x) = @_;
    return $x if defined $self->{idx}->{$x};
    my @m = grep { short_trait($_) eq short_trait($x) } @{$self->{available_traits}};
    return @m ? $m[0] : undef;
}

sub _select_traits {
    my $self = shift;
    my @req = list(opt($self->recipe, 'traits', []));
    my @traits;
    if (!@req) { @traits = @{$self->{available_traits}}; }
    else {
        foreach my $t (@req) {
            if ($self->{treatment_cols}->{$t}) { $self->warn_msg("'", short_trait($t), "' is a treatment, not a trait; it is not analysed (it can be used as a model factor)."); next; }
            my $m = $self->match_trait($t);
            if ($m) { push @traits, $m; } else { $self->warn_msg("Trait '$t' is not in this dataset and was skipped."); }
        }
    }
    $self->{traits} = [ uniq(@traits) ];
    my $d = $self->{dat};
    $d->{check} = [ map { /^(check|control|checks)$/i ? 'check' : 'test' } @{$d->{entry_type}} ];
}

sub _pedigree {
    my $self = shift;
    my $d = $self->{dat};
    my %ped;
    my $f = $self->pedigree_file;
    if ($f && -s $f && open(my $P, '<', $f)) {
        <$P>;
        while (my $l = <$P>) {
            $l =~ s/\r?\n$//;
            my ($a, $m, $fa) = split /\t/, $l, -1;
            next if !defined($a) || $a eq '' || $ped{$a};
            foreach my $p ($m, $fa) { $p = undef if !defined($p) || $p =~ /^(|0|NA|unknown)$/ || $p eq $a; }
            $ped{$a} = [ $m, $fa ];
        }
        close($P);
        $self->step("Pedigree: ", scalar(keys %ped), " individuals, ", scalar(grep { defined($_->[0]) || defined($_->[1]) } values %ped), " with known parent(s)");
    }
    $self->{pedigree} = %ped ? \%ped : undef;
    $d->{mother} = [ map { $ped{$_} ? $ped{$_}->[0] : undef } @{$d->{accession}} ];
    $d->{father} = [ map { $ped{$_} ? $ped{$_}->[1] : undef } @{$d->{accession}} ];
}

sub _day_of {
    my $s = shift;
    return NA if !defined($s) || $s !~ /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2}))?/;
    my $t = eval { timegm($6 // 0, $5 // 0, $4 // 0, $3, $2 - 1, $1) };
    return defined($t) ? $t / 86400 : undef;
}

sub _repeated {
    my $self = shift;
    my $cfg = opt($self->recipe, 'repeated', {});
    $self->{rep_time} = opt($cfg, 'time', 'date') eq 'linear' ? 'linear' : 'date';
    $self->{rep_gxtime} = opt($cfg, 'gxtime', 0) ? 1 : 0;
    $self->{rep_mode} = {};
    $self->{repeated_info} = [];
    my %long;    # trait -> [ {unit, value, date, day, mdate} ] sorted by unit and day
    my $f = $self->repeated_file;
    if ($f && -s $f && open(my $R, '<', $f)) {
        <$R>;
        my $nv = 0;
        while (my $l = <$R>) {
            $l =~ s/\r?\n$//;
            my ($u, $t, $v, $date) = split /\t/, $l, -1;
            next if !defined($u) || $u eq '' || !is_num($v);
            my $day = _day_of($date);
            push @{$long{$t}}, { unit => $u, value => $v + 0, date => $date, day => $day, mdate => defined($day) ? substr($date, 0, 10) : '(no date)' };
            $nv++;
        }
        close($R);
        foreach my $t (keys %long) {
            $long{$t} = [ sort { $a->{unit} cmp $b->{unit} || (defined($a->{day}) ? 0 : 1) <=> (defined($b->{day}) ? 0 : 1) || ($a->{day} // 0) <=> ($b->{day} // 0) } @{$long{$t}} ];
        }
        $self->step("Repeated measurements: $nv values of ", join(', ', uniq(map { short_trait($_) } sort keys %long))) if $nv;
    }
    $self->{rep_long} = \%long;
    my $unit = $self->{dat}->{unit};
    my $summ = sub {
        my ($ms, $how) = @_;
        my @v = map { $_->{value} } @$ms;
        my @dated = grep { defined $_->{day} } @$ms;
        my %ud = map { $_->{day} => 1 } @dated;
        return mean(@v) if $how eq 'mean';
        return $v[0] if $how eq 'first';
        return $v[-1] if $how eq 'last';
        return max(@v) if $how eq 'max';
        return min(@v) if $how eq 'min';
        return sum(@v) if $how eq 'sum';
        return NA if @dated < 2 || keys(%ud) < 2;
        my @s = sort { $a->{day} <=> $b->{day} } @dated;
        if ($how eq 'auc') {
            my $a = 0;
            $a += ($s[$_]->{day} - $s[$_ - 1]->{day}) * ($s[$_]->{value} + $s[$_ - 1]->{value}) / 2 for 1 .. $#s;
            return $a;
        }
        my $mx = mean(map { $_->{day} } @s); my $my = mean(map { $_->{value} } @s);
        my ($sxy, $sxx) = (0, 0);
        foreach (@s) { $sxy += ($_->{day} - $mx) * ($_->{value} - $my); $sxx += ($_->{day} - $mx)**2; }
        return $sxx > 0 ? $sxy / $sxx : undef;
    };
    $self->{rep_summ} = $summ;    # also used by the outlier rules (outliers.view)
    my $info = sub {
        my ($full, $how) = @_;
        my $ms = $long{$full};
        my %per; $per{$_->{unit}}++ for @$ms;
        return { trait => short_trait($full), summary => $how, label => $REP_LABEL{$how}, n_plots => scalar(keys %per),
                 n_repeated_plots => scalar(grep { $_ > 1 } values %per), n_measurements => scalar(@$ms),
                 n_dates => n_levels(map { $_->{mdate} eq '(no date)' ? undef : $_->{mdate} } @$ms), n_missing_summary => 0 };
    };
    my $tr = opt($cfg, 'traits', {});
    $tr = {} if ref($tr) ne 'HASH';
    foreach my $key (sort keys %$tr) {
        my $how = (list($tr->{$key}))[0] // '';
        if (!grep { $_ eq $how } @REP_SUMMARIES) { $self->warn_msg("Repeated measurements of '", short_trait($key), "': unknown summary '$how'; the plot mean was used."); next; }
        my $full = $self->match_trait($key);
        next if !$full;
        if (!$long{$full} || !@{$long{$full}}) {
            $self->warn_msg(short_trait($full), " has a single measurement per plot in this dataset, so the '$REP_LABEL{$how}' setting for repeated measurements was not needed.") if $how ne 'mean';
            next;
        }
        my $inf = $info->($full, $how);
        if ($how eq 'all' || $how eq 'multi') { $self->{rep_mode}->{$full} = $how; }
        elsif ($how ne 'mean') {
            my %by; push @{$by{$_->{unit}}}, $_ for @{$long{$full}};
            my %val = map { $_ => $summ->($by{$_}, $how) } keys %by;
            my $col = $self->{pheno_col}->($full);
            my $miss = 0;
            my @new;
            for my $i (0 .. $#$unit) {
                my $v = $val{ $unit->[$i] };
                $miss++ if is_num($col->[$i]) && !defined($v);
                push @new, $v;
            }
            $inf->{n_missing_summary} = $miss;
            $self->warn_msg(short_trait($full), ": $miss plot(s) have fewer than two dated measurements, so no $REP_LABEL{$how} could be computed; they were left out for this trait.") if $miss;
            $self->{override_col}->{$full} = \@new;
        }
        $self->step("Repeated measurements of ", short_trait($full), ": $REP_LABEL{$how} ($inf->{n_measurements} measurements on $inf->{n_plots} plots)");
        push @{$self->{repeated_info}}, $inf;
    }
    my %done = map { $_->{trait} => 1 } @{$self->{repeated_info}};
    my %sel = map { $_ => 1 } @{$self->{traits}};
    foreach my $full (sort keys %long) {
        next if $done{ short_trait($full) } || !$sel{$full};
        push @{$self->{repeated_info}}, $info->($full, 'mean');
    }
}

# numeric values of a phenotype column (with its repeated-measurement summary)
sub trait_values {
    my ($self, $full) = @_;
    return $self->{override_col}->{$full} if $self->{override_col}->{$full};
    my $c = $self->{pheno_col}->($full) or return [ (undef) x $self->{n} ];
    return [ map { num($_) } @$c ];
}

sub _trait_columns {
    my $self = shift;
    my $d = $self->{dat};
    $d->{$_} = $self->trait_values($_) for @{$self->{traits}};
    $self->{traits} = [ grep { my $t = $_; grep { defined } @{$d->{$t}} } @{$self->{traits}} ];
    die "None of the selected traits has numeric data in this dataset. Available traits: " . join(', ', map { short_trait($_) } @{$self->{available_traits}}) . "\n" if !@{$self->{traits}};
    $self->step("Traits: ", join(', ', map { short_trait($_) } @{$self->{traits}}));
}

sub _covariates {
    my $self = shift;
    my @cv = list(opt($self->recipe, 'covariates', opt(opt($self->recipe, 'single', {}), 'covariates', [])));
    my (@vars, %label);
    foreach my $c (uniq(@cv)) {
        my $full = $self->match_trait($c);
        if (!$full) { $self->warn_msg("Covariate '", short_trait($c), "' is not in this dataset and was skipped."); next; }
        my $vn = cov_name($full);
        $self->{dat}->{$vn} = $self->trait_values($full);
        if (!grep { defined } @{$self->{dat}->{$vn}}) { $self->warn_msg("Covariate '", short_trait($c), "' has no numeric values and was skipped."); next; }
        push @vars, $vn;
        $label{$vn} = short_trait($full);
        $self->{cov_full}->{$vn} = $full;
    }
    $self->{cov_vars} = \@vars;
    $self->{cov_label} = \%label;
    $self->step("Covariates: ", join(', ', map { $label{$_} } @vars)) if @vars;
}

# ---------------------------------------------------------------------------
# designs and factor support
# ---------------------------------------------------------------------------
sub _effective_rep {
    my $d = shift;
    return [ map { $_ // '' } @{$d->{rep}} ] if n_levels(@{$d->{rep}}) > 1;
    return [ map { $_ // '' } @{$d->{block}} ] if n_levels(@{$d->{block}}) > 1;
    return [ ('1') x nrow($d) ];
}

sub _detect_design {
    my ($d, $sp) = @_;
    my $txt = lc(join(' ', uniq(@{$d->{design_raw}})));
    my $n = nrow($d);
    my $n_rep = n_levels(@{$d->{rep}});
    my $n_block = n_levels(@{$d->{block}});
    my $rc = grep { defined($d->{row}->[$_]) && defined($d->{col}->[$_]) } 0 .. $n - 1;
    my $has_rowcol = ($rc >= 0.9 * $n && n_levels(@{$d->{row}}) > 1 && n_levels(@{$d->{col}}) > 1) ? 1 : 0;
    my $block_ne_rep = $n_rep > 0 && $n_block > 0 && (grep { defined($d->{block}->[$_]) && defined($d->{rep}->[$_]) && $d->{block}->[$_] ne $d->{rep}->[$_] } 0 .. $n - 1) ? 1 : 0;
    my %cnt; $cnt{$_}++ for grep { defined } @{$d->{accession}};
    my $replicated = (grep { $_ > 1 } values %cnt) ? 1 : 0;
    my $rep_ok = $sp ? $sp->{rep}->{ok} : $n_rep > 1;
    my $block_ok = $sp ? $sp->{block}->{ok} : $n_block > 1;
    my $entries_rep = $sp ? $sp->{entries_replicated} : $replicated;
    my $design = $txt =~ /row.?col|rowcol|spatial|p-rep|prep/ ? 'row_column'
        : ($txt =~ /augmented|madii|\bmad\b|aug/ || (!$entries_rep && $replicated && $block_ok)) ? 'augmented'
        : ($txt =~ /alpha|lattice|incomplete/ || ($rep_ok && $block_ok && $n_block > $n_rep && $block_ne_rep)) ? 'alpha_lattice'
        : ($txt =~ /rcbd|randomized complete block|randomised complete block/ || $rep_ok) ? 'rcbd'
        : ($txt =~ /crd|completely random/ || $replicated) ? 'crd' : 'unreplicated';
    $design = 'unreplicated' if !$replicated && $design ne 'augmented';
    return { design => $design, has_rowcol => $has_rowcol, n_rep => $n_rep, n_block => $n_block, design_label => $DESIGN_LABEL{$design} };
}

sub _same_grouping {
    my ($a, $b) = @_;
    my @k = grep { defined($a->[$_]) && defined($b->[$_]) } 0 .. $#$a;
    return 0 if !@k;
    my $na = n_levels(map { $a->[$_] } @k);
    return $na == n_levels(map { $b->[$_] } @k) && n_levels(map { "$a->[$_]\t$b->[$_]" } @k) == $na ? 1 : 0;
}

sub _factor_support {
    my $d = shift;
    my $n = nrow($d);
    my $yes = { ok => 1, why => '' };
    my $no = sub { { ok => 0, why => shift } };
    my @test = grep { $d->{check}->[$_] ne 'check' } 0 .. $n - 1;
    @test = (0 .. $n - 1) if !@test;
    my %is_test = map { $_ => 1 } @test;
    my (%reps, %copies, %chk);
    foreach my $i (@test) { $reps{ $d->{accession}->[$i] }->{ $d->{rep_eff}->[$i] } = 1; $copies{ $d->{accession}->[$i] }++; }
    $chk{ $d->{accession}->[$_] }++ for grep { !$is_test{$_} } 0 .. $n - 1;
    my $checks_repeated = (grep { $_ > 1 } values %chk) ? 1 : 0;
    my %sp = (entries_replicated => (median(values %copies) // 0) >= 2 ? 1 : 0);
    $sp{rep} = n_levels(@{$d->{rep_eff}}) < 2 ? $no->('one replicate')
        : median(map { scalar(keys %$_) } values %reps) < 2 ? $no->('the test entries are in one replicate only' . ($checks_repeated ? ', only the checks are repeated' : '')) : $yes;
    my @rep_used = $sp{rep}->{ok} ? @{$d->{rep_eff}} : ('1') x $n;
    my @has_b = map { defined($d->{block}->[$_]) && $d->{block}->[$_] ne '' ? 1 : 0 } 0 .. $n - 1;
    my @bid = map { $has_b[$_] ? "$rep_used[$_] $d->{block}->[$_]" : undef } 0 .. $n - 1;
    my $n_bid = n_levels(@bid);
    my %acc_blocks;
    $acc_blocks{ $d->{accession}->[$_] }->{ $bid[$_] } = 1 for grep { $has_b[$_] } 0 .. $n - 1;
    $sp{block} = n_levels(@{$d->{block}}) < 2 ? $no->('one block')
        : $n_bid <= n_levels(@rep_used) ? $no->('the blocks are the replicates')
        : (sum(@has_b) / $n_bid) < 2 ? $no->('one plot per block')
        : !(grep { keys(%$_) > 1 } values %acc_blocks) ? $no->('no entry is in more than one block, so block effects cannot be separated from the genotypes') : $yes;
    my @blk_used = $sp{block}->{ok} ? @bid : (undef) x $n;
    my $rc = (grep { defined($d->{row}->[$_]) && defined($d->{col}->[$_]) } 0 .. $n - 1) >= 0.9 * $n;
    foreach my $f (['row', 'row'], ['col', 'column']) {
        my ($k, $nm) = @$f;
        my $x = $d->{$k};
        my $nl = n_levels(@$x);
        my @in = map { defined($x->[$_]) ? "$rep_used[$_]\t$x->[$_]" : undef } 0 .. $n - 1;
        $sp{$k} = (!$rc || $nl < 2) ? $no->("no $nm numbers")
            : (scalar(grep { defined } @$x) / $nl) < 2 ? $no->("one plot per $nm")
            : ($sp{rep}->{ok} && _same_grouping(\@in, \@rep_used)) ? $no->("each $nm is a replicate")
            : ($sp{block}->{ok} && _same_grouping(\@in, \@blk_used)) ? $no->("each $nm is a block") : $yes;
    }
    return \%sp;
}

sub _routine_off { my $why = shift; return $why =~ /^(one replicate|one block|no row|no column|the blocks are the replicates)/ ? 1 : 0; }

sub _designs {
    my $self = shift;
    my $d = $self->{dat};
    my @trials = sort(uniq(@{$d->{trial}}));
    $self->{trials} = \@trials;
    my %rows_of; push @{$rows_of{ $d->{trial}->[$_] }}, $_ for 0 .. $self->{n} - 1;
    $self->{rows_of} = \%rows_of;
    my $ov = opt(opt($self->recipe, 'stage1', {}), 'design_overrides', {});
    $ov = {} if ref($ov) ne 'HASH';

    my $zc = opt($self->recipe, 'zones', {});
    $self->{env_unit} = opt($zc, 'unit', 'trial');
    $d->{env} = [ map { $self->{env_unit} eq 'location' ? $d->{location}->[$_] : $self->{env_unit} eq 'location_year' ? "$d->{location}->[$_] $d->{year}->[$_]" : $d->{trial}->[$_] } 0 .. $self->{n} - 1 ];
    $d->{rep_eff} = [ ('') x $self->{n} ];
    $d->{row_off} = [ (0) x $self->{n} ];
    $d->{col_off} = [ (0) x $self->{n} ];
    my %info;
    foreach my $tr (@trials) {
        my $ii = $rows_of{$tr};
        my $s = subset($d, $ii);
        my $er = _effective_rep($s);
        $d->{rep_eff}->[ $ii->[$_] ] = $er->[$_] for 0 .. $#$ii;
        $s->{rep_eff} = $er;
        my $sp = _factor_support($s);
        my $di = _detect_design($s, $sp);
        my $o = $ov->{$tr};
        if (defined($o) && $o ne '' && $o ne 'auto' && $DESIGN_LABEL{$o}) { $di->{design} = $o; $di->{design_label} = $DESIGN_LABEL{$o}; }
        $di->{trial} = $tr; $di->{location} = $s->{location}->[0]; $di->{year} = $s->{year}->[0];
        $di->{n_plots} = scalar(@$ii); $di->{n_accessions} = n_levels(@{$s->{accession}});
        $di->{support} = $sp;
        $info{$tr} = $di;
        foreach my $i (@$ii) {
            $d->{rep_eff}->[$i] = '1' if !$sp->{rep}->{ok};
            $d->{block}->[$i] = '0' if !$sp->{block}->{ok};
            $d->{row_off}->[$i] = 1 if !$sp->{row}->{ok};
            $d->{col_off}->[$i] = 1 if !$sp->{col}->{ok};
        }
        my @off = grep { !$sp->{$_}->{ok} && !_routine_off($sp->{$_}->{why}) } @FACTORS;
        $self->warn_msg("$tr: not used as model factor(s): ", join('; ', map { lc($FACTOR_LABEL{$_}) . " ($sp->{$_}->{why})" } @off), ".") if @off;
    }
    $self->{trial_info} = \%info;
}

# ---------------------------------------------------------------------------
# outliers
# ---------------------------------------------------------------------------
sub _outliers {
    my $self = shift;
    my $d = $self->{dat};
    my $cfg = opt($self->recipe, 'outliers', {});
    my $method = opt($cfg, 'method', 'none');
    my $group = opt($cfg, 'group_by', 'trial');
    my $k = opt($cfg, 'k', 1.5) + 0;
    my $alpha = opt($cfg, 'alpha', 0.05) + 0;
    my @rows;
    my $flag = sub {
        my ($idx, $t, $reason, $vals) = @_;
        foreach my $i (@$idx) {
            push @rows, { unit => $d->{unit}->[$i], trial => $d->{trial}->[$i], accession => $d->{accession}->[$i], trait => $t,
                          value => $vals ? $vals->[$i] : $d->{$t}->[$i], reason => $reason };
            $d->{$t}->[$i] = undef;
        }
    };
    my %n_before = map { my $t = $_; $t => scalar(grep { defined } @{$d->{$t}}) } @{$self->{traits}};
    my $n = $self->{n};

    # per trait: the side the rules flag (outliers.side: high | low, default
    # both) and, for traits measured several times per plot, the value per plot
    # the rules judge (outliers.view: mean | sum | first | last, default mean),
    # which may differ from the value the model uses (repeated.traits)
    my (%side, %view);
    foreach my $pair ([ \%side, 'side', qr/^(high|low)$/ ], [ \%view, 'view', qr/^(mean|sum|first|last|max|min)$/ ]) {
        my $h = opt($cfg, $pair->[1], {});
        next if ref($h) ne 'HASH';
        foreach my $key (keys %$h) {
            my $full = $self->match_trait($key) or next;
            my $v = (list($h->{$key}))[0] // '';
            $pair->[0]->{$full} = $v if $v =~ $pair->[2];
        }
    }
    my $is_rep = sub { my $l = ($self->{rep_long} || {})->{ $_[0] }; return $l && @$l ? 1 : 0 };
    my $judged = sub {    # values the rules judge, aligned with the rows of $d
        my $t = shift;
        return $d->{$t} if !$is_rep->($t);
        my %by; push @{$by{$_->{unit}}}, $_ for @{ $self->{rep_long}->{$t} };
        my $how = $view{$t} // 'mean';
        my %val = map { $_ => $self->{rep_summ}->($by{$_}, $how) } keys %by;
        return [ map { defined($d->{$t}->[$_]) ? ($val{ $d->{unit}->[$_] } // $d->{$t}->[$_]) : undef } 0 .. $n - 1 ];
    };
    my $keep_side = sub { my ($t, $high) = @_; my $s = $side{$t} // ''; return $s eq 'high' ? $high : $s eq 'low' ? !$high : 1 };
    my $how_text = sub {
        my $t = shift;
        my @w;
        push @w, "$side{$t} values only" if $side{$t};
        push @w, 'judged on the ' . (($view{$t} // 'mean') eq 'mean' ? 'plot mean' : $REP_LABEL{ $view{$t} }) . ' of the repeated measurements' if $is_rep->($t);
        return @w ? ', ' . join(', ', @w) : '';
    };
    if ($method eq 'iqr') {
        my @g = map { $group eq 'trial_rep' ? "$d->{trial}->[$_] $d->{rep_eff}->[$_]" : $group eq 'trial_accession' ? "$d->{trial}->[$_] $d->{accession}->[$_]" : $group eq 'all' ? 'all' : $d->{trial}->[$_] } 0 .. $n - 1;
        (my $gl = $group) =~ s/_/ x /g;
        foreach my $t (@{$self->{traits}}) {
            my $y = $judged->($t);
            my %by; push @{$by{$g[$_]}}, $_ for grep { defined $y->[$_] } 0 .. $n - 1;
            foreach my $lvl (uniq(@g)) {
                my $ii = $by{$lvl} or next;
                next if @$ii < 4;
                my @v = map { $y->[$_] } @$ii;
                my ($q1, $q3) = (quantile7(0.25, @v), quantile7(0.75, @v));
                my ($lo, $hi) = ($q1 - $k * ($q3 - $q1), $q3 + $k * ($q3 - $q1));
                $flag->([ grep { ($y->[$_] > $hi && $keep_side->($t, 1)) || ($y->[$_] < $lo && $keep_side->($t, 0)) } @$ii ], $t,
                        sprintf("IQR (k = %s) within %s", 0 + sprintf('%.2g', $k), $gl) . $how_text->($t), $y);
            }
        }
    }
    elsif ($method eq 'madr') {
        # Bernal-Vasquez, Utz & Piepho (2016): Bonferroni-Holm test on residuals
        # re-scaled by the median absolute deviation (BH-MADR); residuals of
        # y ~ accession (+ replicate) by least squares
        foreach my $t (@{$self->{traits}}) {
            my $y = $judged->($t);
            foreach my $tr (@{$self->{trials}}) {
                my @ii = grep { defined $y->[$_] } @{$self->{rows_of}->{$tr}};
                my @acc = map { $d->{accession}->[$_] } @ii;
                next if @ii < 6 || n_levels(@acc) < 2;
                my @rep = map { $d->{rep_eff}->[$_] } @ii;
                my @f = (\@acc);
                push @f, \@rep if n_levels(@rep) > 1;
                my $df = @ii - n_levels(@acc) - (n_levels(@rep) > 1 ? n_levels(@rep) - 1 : 0);
                next if $df < 2;
                my $r = backfit([ map { $y->[$_] } @ii ], \@f);
                # entries with a single plot have a residual of zero by construction:
                # they neither enter the MAD nor can be tested
                my %na; $na{$_}++ for @acc;
                my @inf = grep { $na{ $acc[$_] } > 1 } 0 .. $#ii;
                next if @inf < 3;
                my $m = mad(map { $r->[$_] } @inf);
                next if !$m || $m <= 1e-8 * (sd(map { $y->[$_] } @ii) || 1);
                my @p = map { 2 * pnorm_upper(abs($r->[$_] / $m)) } @inf;
                my @adj = holm(@p);
                # the side of a value: above (positive residual) or below what the model expects
                $flag->([ map { $ii[ $inf[$_] ] } grep { $adj[$_] < $alpha && $keep_side->($t, $r->[ $inf[$_] ] > 0) } 0 .. $#inf ], $t,
                        sprintf("BH-MADR (alpha = %s)", 0 + sprintf('%.2g', $alpha)) . $how_text->($t), $y);
            }
        }
    }
    # individual exclusions chosen in the interface
    my $ef = $self->exclusions_file;
    if ($ef && -s $ef) {
        my $ex = eval { open(my $E, '<', $ef) or die; local $/; my $j = <$E>; close($E); decode_json($j) } || [];
        my %by_unit; push @{$by_unit{ $d->{unit}->[$_] }}, $_ for 0 .. $n - 1;
        my %reason = (dataset => 'Marked as dataset outlier in Breedbase', database => 'Marked as database outlier in Breedbase', both => 'Marked as dataset and database outlier in Breedbase');
        foreach my $e (ref($ex) eq 'ARRAY' ? @$ex : ()) {
            next if ref($e) ne 'HASH';
            my @tt = (!defined($e->{trait}) || $e->{trait} eq '') ? @{$self->{traits}} : grep { $_ eq $e->{trait} } @{$self->{traits}};
            my $ii = $by_unit{ $e->{unit} // '' } or next;
            foreach my $t (@tt) { $flag->([ grep { defined $d->{$t}->[$_] } @$ii ], $t, $reason{ $e->{source} // '' } // 'Excluded individually'); }
        }
    }
    my %n_out; $n_out{$_->{trait}}++ for @rows;
    $self->{outlier_summary} = [ map { my $t = $_; +{ trait => short_trait($t), n_observations => $n_before{$t}, n_removed => $n_out{$t} // 0,
        pct_removed => 0 + sprintf('%.2f', 100 * ($n_out{$t} // 0) / ($n_before{$t} || 1)) } } @{$self->{traits}} ];
    $_->{trait} = short_trait($_->{trait}) for @rows;
    $self->{outliers} = \@rows;
}

# ---------------------------------------------------------------------------
# models
# ---------------------------------------------------------------------------
sub _genetic_model {
    my $self = shift;
    my $g = opt($self->recipe, 'genetic', {});
    my $m = opt($g, 'model', 'iid');
    $m = 'iid' if !grep { $_ eq $m } qw(iid parents pedigree genomic single_step);
    $self->{check_opt} = opt($g, 'check', 'auto');
    my $d = $self->{dat};
    $m = $self->_genomic_setup($g, $m) if $m eq 'genomic' || $m eq 'single_step';
    if ($m eq 'parents' || $m eq 'pedigree') {
        my $ped = $self->{pedigree} || {};
        my $known = grep { $ped->{$_} && (defined($ped->{$_}->[0]) || defined($ped->{$_}->[1])) } uniq(@{$d->{accession}});
        if (!$known) {
            $self->warn_msg("No accession of this dataset has known parents, so the ", ($m eq 'pedigree' ? 'pedigree (A matrix)' : 'mother / father'), " model could not be used; accessions were treated as unrelated.");
            $m = 'iid';
        }
        else { $self->step("Genetic model: $m ($known accessions with known parents)"); }
    }
    $self->{gen_model} = $m;
    my %chk; $chk{ $d->{accession}->[$_] } ||= ($d->{check}->[$_] eq 'check') for 0 .. $self->{n} - 1;
    $self->{acc_is_check} = \%chk;
    $self->{strategy} = opt($self->recipe, 'strategy', 'two_stage') eq 'single_stage' ? 'single_stage' : 'two_stage';
    my $gcfg = $self->{strategy} eq 'two_stage' ? opt($self->recipe, 'stage2', {}) : opt($self->recipe, 'single', {});
    $self->{genotype_random} = opt($gcfg, 'genotype', 'random') eq 'random' ? 1 : 0;
}

# Genomic relationships (G: GBLUP; H: single-step, pedigree + genomic). Reads
# the dosages, codes the accessions of the dataset (and, for H, their
# ancestors) once for every fit, and writes the SNP file in the BLUPF90
# format (id, then one 0/1/2 digit per marker, 5 = missing). Returns the
# model actually used: a model the data cannot support falls back (H without
# known parents -> G; no genotypes -> pedigree or unrelated) with a warning.
sub _genomic_setup {
    my ($self, $g, $m) = @_;
    my $d = $self->{dat};
    my $label = $m eq 'genomic' ? 'genomic (G matrix)' : 'single-step (H matrix)';
    my $pname = opt($g, 'protocol_name', '') || ('protocol ' . (opt($g, 'protocol_id', '') // ''));
    my @acc = sort(uniq(@{$d->{accession}}));
    my %in = map { $_ => 1 } @acc;
    my $ped = $self->{pedigree} || {};
    my $n_parents = grep { $ped->{$_} && (defined($ped->{$_}->[0]) || defined($ped->{$_}->[1])) } @acc;
    my $fallback = sub {
        my $why = shift;
        my $to = $n_parents ? 'pedigree' : 'iid';
        $self->warn_msg("The $label model could not be used ($why); ", ($to eq 'pedigree' ? 'the pedigree (A matrix) model was used instead.' : 'accessions were treated as unrelated.'));
        return $to;
    };
    my $f = $self->genotypes_file;
    return $fallback->("no genotypes of the genotyping protocol were retrieved") if !$f || !-s $f;

    # dosages of the accessions of the dataset
    open(my $G, '<', $f) or return $fallback->("the genotype file cannot be read");
    my $h = <$G>;
    $h =~ s/\r?\n$//;
    my @markers = grep { $_ ne '' } split /\t/, $h;
    shift @markers;
    my %geno;
    while (my $l = <$G>) {
        $l =~ s/\r?\n$//;
        my ($name, @v) = split /\t/, $l, -1;
        next if !defined($name) || !$in{$name} || $geno{$name};
        my $str = join('', map { my $x = $v[$_]; (defined($x) && $x =~ /^\s*-?[\d.]+(?:[eE][-+]?\d+)?\s*$/) ? do { my $r = int($x + 0.5); $r < 0 ? 0 : $r > 2 ? 2 : $r } : 5 } 0 .. $#markers);
        $geno{$name} = $str;
    }
    close($G);
    my $ng = scalar(keys %geno);
    return $fallback->("only $ng accession(s) of the dataset are genotyped in $pname") if $ng < 3;
    return $fallback->("the genotypes of $pname have no markers") if !@markers;

    if ($m eq 'single_step' && !$n_parents) {
        $self->warn_msg("No accession of this dataset has known parents, so the single-step (H matrix) model is the genomic (G matrix) model here.");
        $m = 'genomic';
        $label = 'genomic (G matrix)';
    }
    # one coding for every fit: accessions (genotyped or not), then ancestors (H)
    my $codes = $m eq 'single_step' ? $self->_ped_codes(\@acc) : { id => \@acc, s => [ (0) x @acc ], d => [ (0) x @acc ] };
    my $snp = $self->{f90}->keep_dir . '/genotypes_snp.txt';
    make_path($self->{f90}->keep_dir);
    my $w = length(scalar(@{$codes->{id}})) + 1;
    open(my $S, '>', $snp) or die "Cannot write the SNP file\n";
    open(my $X, '>', "${snp}_XrefID") or die "Cannot write the SNP cross-reference file\n";
    for my $i (0 .. $#{$codes->{id}}) {
        my $str = $geno{ $codes->{id}->[$i] } // next;
        printf $S "%-${w}d %s\n", $i + 1, $str;
        print $X $i + 1, ' ', $i + 1, "\n";
    }
    close($S); close($X);
    _write_text($self->{f90}->keep_dir . '/genotypes_ids.txt', join("\n", "code\taccession\tgenotyped", map { ($_ + 1) . "\t$codes->{id}->[$_]\t" . ($geno{ $codes->{id}->[$_] } ? 1 : 0) } 0 .. $#{$codes->{id}}) . "\n");
    $self->{rel_codes} = $codes;
    $self->{genomic_spec} = { snp_file => $snp, minfreq => (opt($g, 'minfreq', 0.05) + 0), callrate => (opt($g, 'callrate', 0.90) + 0) };
    my $n_without = @acc - $ng;
    $self->{genomic_info} = { matrix => ($m eq 'genomic' ? 'G' : 'H'), protocol_id => opt($g, 'protocol_id', undef), protocol_name => $pname,
                              n_accessions => scalar(@acc), n_genotyped => $ng, n_markers => scalar(@markers),
                              minfreq => $self->{genomic_spec}->{minfreq}, callrate => $self->{genomic_spec}->{callrate} };
    $self->step("Genetic model: $label, $ng of " . scalar(@acc) . " accessions genotyped in $pname (" . scalar(@markers) . " markers)");
    if ($n_without) {
        $self->warn_msg($m eq 'genomic'
            ? "$n_without of " . scalar(@acc) . " accessions have no genotypes in $pname: in the genomic (G matrix) model they are treated as unrelated (the single-step H model links them through the pedigree)."
            : "$n_without of " . scalar(@acc) . " accessions have no genotypes in $pname: in the single-step (H matrix) model they are related to the others through the pedigree only.");
    }
    return $m;
}

sub _write_text { my ($f, $t) = @_; open(my $F, '>', $f) or return; print $F $t; close($F); return 1; }

# pedigree of a set of accessions: the accessions first, then all known ancestors
sub _ped_codes {
    my ($self, $acc) = @_;
    my $P = $self->{pedigree} || {};
    my (%keep, @ids);
    my @todo = @$acc;
    while (@todo) {
        my @next;
        foreach my $a (@todo) {
            next if $keep{$a}++;
            push @ids, $a;
            push @next, grep { defined && !$keep{$_} } @{ $P->{$a} || [] };
        }
        @todo = @next;
    }
    my %acc = map { $_ => 1 } @$acc;
    @ids = (@$acc, grep { !$acc{$_} } @ids[ scalar(@$acc) .. $#ids ]);
    my %pos; $pos{$ids[$_]} = $_ + 1 for 0 .. $#ids;
    return { id => \@ids, s => [ map { my $p = $P->{$_}; $p && defined($p->[0]) ? $pos{$p->[0]} // 0 : 0 } @ids ],
             d => [ map { my $p = $P->{$_}; $p && defined($p->[1]) ? $pos{$p->[1]} // 0 : 0 } @ids ] };
}

# right-hand side of a lme4 formula -> fixed terms, random grouping terms
# ((1|a), (1|a:b), (1|a/b)) and terms BLUPF90+ cannot fit
sub split_terms {
    my $rhs = shift;
    $rhs =~ s/\s+//g;
    my (@random, @unsup);
    while ($rhs =~ /\(([^()]*)\|([^()]*)\)/g) {
        my ($lhs, $grp) = ($1, $2);
        if ($lhs ne '1' || $grp =~ /[^A-Za-z0-9_.:\/]/) { push @unsup, "($lhs|$grp)"; next; }
        my @p = split /\//, $grp;
        push @random, join(':', @p[0 .. $_]) for 0 .. $#p;
    }
    (my $fx = $rhs) =~ s/\([^()]*\|[^()]*\)//g;
    $fx =~ s/-/+-/g;
    my @fixed = grep { $_ ne '' && $_ ne '0' && $_ ne '1' && $_ ne '-1' } split /\+/, $fx;
    push @unsup, grep { /^-/ } @fixed;
    @fixed = grep { !/^-/ } @fixed;
    return { fixed => [ uniq(@fixed) ], random => [ uniq(@random) ], unsupported => \@unsup };
}

# spec of fit_model(): y ~ <rhs> with the genetic model of the recipe
sub model_spec {
    my ($self, $d, $fml, $grandom, $w, $label) = @_;
    (my $rhs = $fml) =~ s/^\s*y\s*~//;
    my $sp = split_terms($rhs);
    die "BLUPF90+ cannot fit " . join(', ', @{$sp->{unsupported}}) . " (random slopes or removed terms); use the R engine for this formula\n" if @{$sp->{unsupported}};
    my $rel = $self->{gen_model} eq 'pedigree' ? 'A' : $self->{gen_model} eq 'genomic' ? 'G' : $self->{gen_model} eq 'single_step' ? 'H' : '';
    my $ped_on = $rel && $grandom && grep { $_ eq 'accession' } @{$sp->{random}};
    return {
        data => $d, fixed => [ grep { $_ ne 'accession' } @{$sp->{fixed}} ], random => [ grep { $_ ne 'accession' } @{$sp->{random}} ],
        genotype_random => $grandom, weights => $w, fixed_mean_by => 'trial', label => $label,
        ($ped_on ? (ped => ($rel eq 'A' ? $self->_ped_codes([ sort(uniq(@{$d->{accession}})) ]) : $self->{rel_codes})) : ()),
        ($ped_on && $rel ne 'A' ? (genomic => $self->{genomic_spec}) : ()),
        _ped_on => $ped_on ? 1 : 0, _rel => $ped_on ? $rel : '',
    };
}

# genetic value of the accessions (mother / father effects added) and
# ancestors' breeding values, after a fit of model_spec()
sub finish_fit {
    my ($self, $spec, $fit, $d) = @_;
    $fit->{pedigree} = $spec->{_ped_on};
    $fit->{relationship} = $spec->{_rel};
    $self->{genomic_info}->{qc} //= $fit->{genomic} if $fit->{genomic} && $self->{genomic_info};
    return $fit if !$spec->{genotype_random};
    my @gv = @{$fit->{values}};
    foreach my $k (grep { $fit->{random}->{$_} } qw(mother father)) {
        my %r = map { $_->{level} => $_ } @{$fit->{random}->{$k}};
        my %par; $par{ $d->{accession}->[$_] } = $d->{$k}->[$_] for 0 .. $#{$d->{accession}};
        foreach my $g (@gv) {
            my $p = $par{ $g->{accession} };
            my $e = defined($p) ? $r{$p} : undef;
            next if !$e;
            $g->{value} += $e->{solution} if defined $g->{value};
            $g->{se} = sqrt(($g->{se} // 0)**2 + ($e->{se} // 0)**2) if defined $g->{se};
        }
    }
    $fit->{values} = \@gv;
    if ($spec->{_ped_on} && $fit->{random}->{accession}) {
        # ancestors only: with G / H every accession of the dataset is coded in
        # every fit, and an accession of the dataset is never an ancestor
        my %in = map { $_->{accession} => 1 } @gv;
        if ($spec->{_rel} ne 'A') { $in{$_} = 1 for @{$self->{dat}->{accession}}; }
        my @a = grep { !$in{ $_->{level} } } @{$fit->{random}->{accession}};
        $fit->{ancestors} = [ map { +{ accession => $_->{level}, value => $fit->{mu} + $_->{solution}, se => $_->{se} } } @a ] if @a;
    }
    # random terms estimated with no variance
    my $tot = sum(values %{$fit->{vc}}) || 1;
    foreach my $k (sort keys %{$fit->{vc}}) {
        next if $k eq 'Residual' || $k =~ /(^|:|_)(rep|block|row|col)(_f|_eff)?$/;
        push @{$fit->{notes}}, "random term $k was estimated with zero variance, so it has no effect on the results" if $fit->{vc}->{$k} <= 1e-8 * $tot;
    }
    return $fit;
}

# Fit independent model specs in parallel; returns results in order.
sub fit_many { my ($self, $specs) = @_; return @$specs ? $self->{f90}->fit_all($specs) : []; }

sub _design_terms {
    my ($design, $d) = @_;
    my $has_rep = n_levels(@{$d->{rep_eff}}) > 1;
    my $row_on = n_levels(@{$d->{row}}) > 1 && !grep { $_ } @{$d->{row_off}};
    my $col_on = n_levels(@{$d->{col}}) > 1 && !grep { $_ } @{$d->{col_off}};
    return $has_rep ? ('rep_eff') : () if $design eq 'rcbd';
    return (($has_rep ? 'rep_eff' : ()), (n_levels(@{$d->{block}}) > 1 ? 'rep_eff:block' : ())) if $design eq 'alpha_lattice';
    return n_levels(@{$d->{block}}) > 1 ? ('block') : () if $design eq 'augmented';
    return (($has_rep ? 'rep_eff' : ()), ($row_on ? 'rep_eff:row_f' : ()), ($col_on ? 'rep_eff:col_f' : ())) if $design eq 'row_column';
    return ();
}

sub _rel_text {
    my $f = shift;
    my $r = $f->{relationship} || '';
    return $r eq 'A' ? ', accession ~ N(0, A s2a)' : $r eq 'G' ? ', accession ~ N(0, G s2g) (GBLUP)' : $r eq 'H' ? ', accession ~ N(0, H s2g) (single-step)' : '';
}

sub _model_text {
    my ($grandom, $fixed, $random) = @_;
    return "y ~ " . join(' + ', ($grandom ? '(1|accession)' : 'accession'), @$fixed, map { "(1|$_)" } @$random);
}

# one row per measurement of the plots of d (plots without a value keep none)
# notes after expand_repeated(): covariates matched to the measurement dates
sub _report_expand {
    my ($self, $where, $trait) = @_;
    my $x = $self->{expand_info} or return;
    return if !@{ $x->{covariates} };
    $self->warn_once("tvcov $trait", short_trait($trait), ": covariate(s) ", join(', ', @{ $x->{covariates} }),
                     " measured on several dates follow the measurements: each measurement uses the covariate value of its plot on the nearest date (within $COV_DAYS days).");
    $self->warn_msg("$where: $x->{dropped} measurement(s) without a covariate value within $COV_DAYS days were left out.") if $x->{dropped};
}

sub expand_repeated {
    my ($self, $d, $trait) = @_;
    my @keep = grep { defined $d->{y}->[$_] } 0 .. nrow($d) - 1;
    my %row_of; $row_of{ $d->{unit}->[$_] } = $_ for @keep;
    my @idx; my (@y, @mdate, @day);
    my %has;
    foreach my $m (@{ $self->{rep_long}->{$trait} || [] }) {
        my $i = $row_of{ $m->{unit} };
        next if !defined $i;
        push @idx, $i; push @y, $m->{value}; push @mdate, $m->{mdate}; push @day, $m->{day};
        $has{ $m->{unit} } = 1;
    }
    foreach my $i (@keep) {
        next if $has{ $d->{unit}->[$i] };
        push @idx, $i; push @y, $d->{y}->[$i]; push @mdate, '(no date)'; push @day, undef;
    }
    my $e = subset($d, \@idx);
    $e->{y} = \@y; $e->{mdate} = \@mdate;
    my (%first_day, %first_date);
    for my $i (0 .. $#idx) {
        my $t = $e->{trial}->[$i];
        $first_day{$t} = $day[$i] if defined($day[$i]) && (!defined($first_day{$t}) || $day[$i] < $first_day{$t});
        $first_date{$t} = $mdate[$i] if !defined($first_date{$t}) || $mdate[$i] lt $first_date{$t};
    }
    $e->{mday} = [ map { defined($day[$_]) && defined($first_day{ $e->{trial}->[$_] }) ? $day[$_] - $first_day{ $e->{trial}->[$_] } : undef } 0 .. $#idx ];
    $e->{tr_date} = [ map { $mdate[$_] eq $first_date{ $e->{trial}->[$_] } ? '(first date)' : "$e->{trial}->[$_] $mdate[$_]" } 0 .. $#idx ];
    $e->{date_f} = [ @mdate ];
    $e->{plot_u} = [ @{$e->{unit}} ];
    # a covariate measured on several dates follows the measurements: each
    # one takes the covariate value of its plot on the nearest date (within
    # COV_DAYS days); measurements without one are left out (counted)
    my (@drop, @tv);
    foreach my $vn (@{ $self->{cov_vars} || [] }) {
        my $cf = $self->{cov_full}->{$vn} or next;
        my $cl = $self->{rep_long}->{$cf};
        next if !$cl || !@$cl || !defined($e->{$vn});
        my %by; push @{ $by{ $_->{unit} } }, $_ for grep { defined $_->{day} } @$cl;
        my @v = @{ $e->{$vn} };
        for my $i (0 .. $#idx) {
            next if !defined $day[$i];    # undated measurement: plot value of the covariate
            my ($best, $dist);
            foreach my $m (@{ $by{ $e->{unit}->[$i] } || [] }) {
                my $dd = abs($m->{day} - $day[$i]);
                ($best, $dist) = ($m->{value}, $dd) if $dd <= $COV_DAYS && (!defined($dist) || $dd < $dist);
            }
            $v[$i] = $best;
            $drop[$i] = 1 if !defined $best;
        }
        $e->{$vn} = \@v;
        push @tv, $self->{cov_label}->{$vn};
    }
    my @k = grep { !$drop[$_] } 0 .. $#idx;
    $e = subset($e, \@k) if @k < @idx;
    # what the caller reports: time-varying covariates, measurements left out
    $self->{expand_info} = { covariates => \@tv, dropped => @idx - @k };
    return $e;
}

sub rep_time_effect {
    my ($self, $e) = @_;
    my $n_tr = n_levels(@{$e->{trial}});
    my $all_days = !grep { !defined } @{$e->{mday}};
    return 'linear' if $self->{rep_time} eq 'linear' && $all_days && n_levels(@{$e->{mday}}) > $n_tr;
    return 'date' if n_levels(@{$e->{tr_date}}) > 1;
    return 'none';
}

sub plots_per_acc { my $d = shift; my %u; $u{ $d->{accession}->[$_] }->{ $d->{unit}->[$_] } = 1 for 0 .. nrow($d) - 1; return harmonic_mean(map { scalar(keys %$_) } values %u); }
sub meas_per_plot { my $d = shift; my %c; $c{$_}++ for @{$d->{unit}}; return harmonic_mean(values %c); }

sub add_residuals {
    my ($self, $units, $trait, $r) = @_;
    return if !$r || @$r != @$units;
    my (%s, %c);
    for (0 .. $#$units) { next if !defined $r->[$_]; $s{ $units->[$_] } += $r->[$_]; $c{ $units->[$_] }++; }
    $self->{residuals}->{$trait}->{$_} = $s{$_} / $c{$_} for keys %s;
}

# ---------------------------------------------------------------------------
# stage 1: one trial, one trait (all trials and traits fitted in parallel)
# ---------------------------------------------------------------------------
sub _stage1_plan {
    my ($self, $d, $info, $trait) = @_;
    my @keep = grep { defined $d->{y}->[$_] } 0 .. nrow($d) - 1;
    $d = subset($d, \@keep);
    my @cv = grep { my $c = $_; $c ne cov_name($trait) && !$self->{mt_skip_cov}->{$trait}->{$c} && (grep { defined } @{$d->{$c}}) > 0.5 * nrow($d) && n_levels(@{$d->{$c}}) > 1 } @{$self->{cov_vars}};
    if (@cv) {
        my @cc = grep { my $i = $_; !grep { !defined $d->{$_}->[$i] } @cv } 0 .. nrow($d) - 1;
        $self->warn_msg("Stage 1, $info->{trial} / ", short_trait($trait), ": ", nrow($d) - @cc, " plot(s) without a covariate value were left out.") if @cc < nrow($d);
        $d = subset($d, \@cc);
    }
    foreach my $c (grep { my $x = $_; $x ne cov_name($trait) && !$self->{mt_skip_cov}->{$trait}->{$x} && !grep { $_ eq $x } @cv } @{$self->{cov_vars}}) {
        $self->warn_once("cov $info->{trial} $c", "Stage 1, $info->{trial}: covariate $self->{cov_label}->{$c} is missing or constant in this trial and was not used there.");
    }
    my $rep_all = ($self->{rep_mode}->{$trait} // '') eq 'all';
    my $n = nrow($d);
    my %res = (trial => $info->{trial}, trait => short_trait($trait), design => $info->{design_label}, n => $n, n_measurements => $n,
               n_accessions => n_levels(@{$d->{accession}}), mean => mean(@{$d->{y}}), cv => undef, h2 => undef, var_g => undef, var_e => undef, model => '', message => 'OK');
    return { summary => { %res, message => 'Not enough data' } } if $n < 3 || n_levels(@{$d->{accession}}) < 2;
    my @trt = grep { n_levels(@{$d->{$_}}) > 1 } @{$self->{trt_use}};
    my $trt_df = sum(0, map { n_levels(@{$d->{$_}}) - 1 } @trt);

    my $raw = sub {
        my ($model, $msg) = @_;
        my (%s, %c);
        for (0 .. $n - 1) { $s{ $d->{accession}->[$_] } += $d->{y}->[$_]; $c{ $d->{accession}->[$_] }++; }
        return { summary => { %res, model => $model, message => $msg }, means => [ map { +{ accession => $_, value => $s{$_} / $c{$_}, se => undef } } sort keys %s ] };
    };
    my $design = $info->{design};
    return $raw->('Unreplicated: raw values (no error estimate)', 'Trial is unreplicated; values are raw observations.') if $design eq 'unreplicated';
    my $df = $n - n_levels(@{$d->{accession}}) - max(0, n_levels(@{$d->{rep_eff}}) - 1) - $trt_df - @cv;
    my (%s, %c, %ss);
    for (0 .. $n - 1) { $s{ $d->{accession}->[$_] } += $d->{y}->[$_]; $c{ $d->{accession}->[$_] }++; }
    $ss{ $d->{accession}->[$_] } += ($d->{y}->[$_] - $s{ $d->{accession}->[$_] } / $c{ $d->{accession}->[$_] })**2 for 0 .. $n - 1;
    my $m = mean(@{$d->{y}});
    my $tot = sum(map { ($_ - $m)**2 } @{$d->{y}});
    if ($df < 2 || sum(values %ss) <= 1e-10 * max(1, $tot)) {
        my $why = $df < 2 ? sprintf("only %d residual degree(s) of freedom", max(0, $df)) : "the replicated plots have identical values";
        $self->warn_msg("$info->{trial} / ", short_trait($trait), ": no error variance can be estimated ($why); accession means were used without standard errors.");
        return $raw->("Accession means (no error estimate: $why)", "No error variance: $why.");
    }

    $d->{row_f} = [ map { defined($_) ? $_ : undef } @{$d->{row}} ];
    $d->{col_f} = [ map { defined($_) ? $_ : undef } @{$d->{col}} ];
    $d->{rowN} = [ @{$d->{row}} ];
    $d->{colN} = [ @{$d->{col}} ];
    my $s1 = opt(opt($self->recipe, 'stage1', {}), 'model', 'auto');
    my $spatial = ($s1 eq 'spats' || ($s1 eq 'auto' && $info->{has_rowcol})) && $info->{has_rowcol};
    my (@rep_fx, @rep_rnd);
    if ($rep_all) {
        $d = $self->expand_repeated($d, $trait);
        $self->_report_expand("Stage 1, $info->{trial} / " . short_trait($trait), $trait);
        $res{n_measurements} = nrow($d);
        my $time_eff = $self->rep_time_effect($d);
        @rep_fx = $time_eff eq 'date' ? ('date_f') : $time_eff eq 'linear' ? ('mday') : ();
        my %c2; $c2{$_}++ for @{$d->{unit}};
        push @rep_rnd, 'plot_u' if grep { $_ > 1 } values %c2;
        push @rep_rnd, 'accession:date_f' if $self->{rep_gxtime} && $time_eff eq 'date';
    }
    my @terms = _design_terms($spatial ? 'row_column' : $design, $d);
    my @fx = (@trt, @cv, @rep_fx);
    my $label_design = $info->{design_label};
    my %ucov;
    if ($spatial) {
        # SpATS-like field trend: a 2D P-spline surface (one smoothing variance,
        # CXGN::BLUPF90::Spatial) with its unpenalised part as fixed linear
        # trends (rowN, colN, rowN:colN), plus row and column effects within
        # replicate. Falls back to the trends alone when the field is too
        # small for a surface.
        my @lin = grep { n_levels(@{$d->{$_ eq 'rowN' ? 'row' : 'col'}}) > 2 } qw(rowN colN);
        push @fx, @lin;
        my $surf = $self->_trial_surface($info->{trial});
        if ($surf && @lin == 2) {
            my ($mr, $mc) = (mean(grep { defined } @{$d->{rowN}}) // 0, mean(grep { defined } @{$d->{colN}}) // 0);
            $d->{rcN} = [ map { defined($d->{rowN}->[$_]) && defined($d->{colN}->[$_]) ? ($d->{rowN}->[$_] - $mr) * ($d->{colN}->[$_] - $mc) : undef } 0 .. nrow($d) - 1 ];
            push @fx, 'rcN';
            my %lv = map { $_ => 1 } @{ $surf->{levels} };
            my @key = map { defined($d->{rowN}->[$_]) && defined($d->{colN}->[$_]) && $lv{ ($d->{rowN}->[$_] + 0) . ':' . ($d->{colN}->[$_] + 0) } ? ($d->{rowN}->[$_] + 0) . ':' . ($d->{colN}->[$_] + 0) : undef } 0 .. nrow($d) - 1;
            $ucov{surface} = { file => $surf->{file}, levels => $surf->{levels}, key => \@key };
            push @terms, 'surface';
            $self->warn_once('spats', "Trials with rows and columns: the BLUPF90+ engine models the field trend with a 2D P-spline surface (SpATS-like: one smoothing variance instead of SpATS's separate row and column smoothing), linear row and column trends and random row and column effects within replicate.");
            $label_design = 'Row-column (P-spline surface)';
        }
        else {
            $self->warn_msg("$info->{trial}: the field is too small for a P-spline surface (" . ($surf ? 'no row and column trend' : $self->{surface_error}->{ $info->{trial} } // 'fewer than three rows or columns') . "); random row and column effects and linear trends were used.");
            $label_design = 'Row-column (spatial)';
        }
    }
    push @terms, @rep_rnd;
    $res{design} = $label_design if $spatial;

    my $lab = "stage1_$info->{trial}_" . short_trait($trait);
    my $blue = { data => $d, fixed => \@fx, random => \@terms, genotype_random => 0, label => "${lab}_blue", user_cov => \%ucov };
    my $blup = { data => $d, fixed => \@fx, random => \@terms, genotype_random => 1, label => "${lab}_blup", user_cov => \%ucov };
    my $h2_of = sub {
        my ($vg, $vc) = @_;
        my ($r, $mm) = (plots_per_acc($d), meas_per_plot($d));
        my $vp = $vc->{plot_u} // 0;
        my $vgt = defined($vc->{'accession:date_f'}) ? $vc->{'accession:date_f'} / max(1, n_levels(@{$d->{date_f}})) : 0;
        my $den = $vg + $vgt + ($vp + $vc->{Residual} / $mm) / $r;
        return $den > 0 ? $vg / $den : undef;
    };
    return {
        specs => [ $blue, $blup ],
        done => sub {
            my ($fb, $fr) = @_;
            if ($fb->{error}) {
                $self->warn_msg("Stage 1, $info->{trial} / ", short_trait($trait), ": the $label_design model could not be fitted by BLUPF90+ ($fb->{error}); a simpler model was used.");
                my @simple = grep { $_ eq 'plot_u' } @terms;
                my $spec = { data => $d, fixed => [], random => \@simple, genotype_random => 0, label => "${lab}_simple" };
                return {
                    specs => [ $spec ],
                    done => sub {
                        my $f = shift;
                        return { summary => { %res, message => $f->{error} } } if $f->{error};
                        return { summary => { %res, model => pretty_model("BLUPF90+: " . _model_text(0, [], \@simple)), message => "Design model failed; fitted " . pretty_model(_model_text(0, [], \@simple)) . ".",
                                              var_e => $f->{vc}->{Residual}, cv => 100 * sqrt($f->{vc}->{Residual}) / abs($res{mean} || 1) },
                                 means => $f->{values}, resid => [ $d->{unit}, $f->{resid} ] };
                    } };
            }
            my %r = (%res, model => pretty_model("BLUPF90+: " . _model_text(0, \@fx, \@terms)), var_e => $fb->{vc}->{Residual});
            $self->fit_notes("Stage 1, $info->{trial} / " . short_trait($trait), $fb->{notes});
            if (!$fr->{error}) {
                $r{var_g} = $fr->{vc}->{accession};
                $r{h2} = $h2_of->($r{var_g}, $fr->{vc});
                my $tot = sum(values %{$fr->{vc}}) || 1;
                my @zero = grep { $_ ne 'Residual' && $_ ne 'accession' && !/rep|block|row|col/ && $fr->{vc}->{$_} <= 1e-8 * $tot } sort keys %{$fr->{vc}};
                $self->warn_msg("Stage 1, $info->{trial} / ", short_trait($trait), ": ", join('; ', map { "random term $_ was estimated with zero variance, so it has no effect on the results" } @zero), ".") if @zero;
            }
            $r{cv} = 100 * sqrt($r{var_e}) / abs($r{mean}) if $r{mean};
            return { summary => \%r, means => $fb->{values}, resid => [ $d->{unit}, $fb->{resid} ] };
        },
    };
}

# run plans (specs + done callbacks, possibly with follow-up plans) in parallel
sub _run_plans {
    my ($self, $plans) = @_;
    while (my @pending = grep { $_->{specs} } @$plans) {
        my @specs = map { @{$_->{specs}} } @pending;
        my $fits = $self->fit_many(\@specs);
        my $k = 0;
        foreach my $p (@pending) {
            my @f = @{$fits}[ $k .. $k + @{$p->{specs}} - 1 ];
            $k += @{$p->{specs}};
            my $next = $p->{done}->(@f);
            my %keep = map { $_ => $p->{$_} } grep { /^_/ } keys %$p;
            %$p = (%keep, %$next);
        }
    }
}

sub _stage1 {
    my $self = shift;
    my $d = $self->{dat};
    my (@summary, @means, @plans);
    foreach my $t (@{$self->{traits}}) {
        foreach my $tr (@{$self->{trials}}) {
            my $s = subset($d, $self->{rows_of}->{$tr});
            $s->{y} = $s->{$t};
            next if !grep { defined } @{$s->{y}};
            my $env = $s->{env}->[0];
            if ($self->{strategy} eq 'two_stage') {
                $self->step("Stage 1: $tr / ", short_trait($t));
                my $p = eval { $self->_stage1_plan($s, $self->{trial_info}->{$tr}, $t) };
                if (!$p) {
                    (my $e = $@ // '') =~ s/\s+$//;
                    $self->warn_msg("Stage 1, $tr / ", short_trait($t), ": the model failed ($e); this trial was left out for this trait.");
                    next;
                }
                $p->{_trial} = $tr; $p->{_trait} = $t; $p->{_env} = $env;
                push @plans, $p;
            }
            else {
                # single stage: cell means of each trial (zones, dashboard)
                my (%sm, %c);
                for (0 .. nrow($s) - 1) { next if !defined $s->{y}->[$_]; $sm{ $s->{accession}->[$_] } += $s->{y}->[$_]; $c{ $s->{accession}->[$_] }++; }
                push @means, map { +{ accession => $_, value => $sm{$_} / $c{$_}, se => undef, trial => $tr, env => $env, trait => $t } } sort keys %sm;
            }
        }
    }
    if (@plans) {
        $self->step("Stage 1: fitting ", scalar(@plans), " trial x trait models with BLUPF90+");
        $self->_run_plans(\@plans);
        foreach my $p (@plans) {
            push @summary, $p->{summary} if $p->{summary};
            $self->add_residuals($p->{resid}->[0], $p->{_trait}, $p->{resid}->[1]) if $p->{resid};
            push @means, map { +{ %$_, trial => $p->{_trial}, env => $p->{_env}, trait => $p->{_trait} } } grep { defined $_->{value} } @{ $p->{means} || [] };
        }
    }
    $self->{stage1_summary} = \@summary;
    $self->{stage1_means} = \@means;
}

# ---------------------------------------------------------------------------
# stage 2
# ---------------------------------------------------------------------------
sub _stage2 {
    my $self = shift;
    my $d = $self->{dat};
    my $grandom = $self->{genotype_random};
    my $weighting = opt(opt($self->recipe, 'stage2', {}), 'weighting', 'inverse_se2');
    my (@specs, @ctx);
    my @summary;
    my @gv;
    my %occasion = map { $_ => 1 } map { (@{ $_->{y} }, @{ $_->{c} }) } @{ $self->{mt_groups} || [] };
    foreach my $g (@{ $self->{mt_groups} || [] }) {
        my $r = $self->_stage2_multi($g);
        push @summary, $r->{summary} if $r->{summary};
        push @gv, @{ $r->{values} || [] };
    }
    foreach my $t (grep { !$occasion{$_} } @{$self->{traits}}) {
        my @m = grep { $_->{trait} eq $t && defined $_->{value} } @{$self->{stage1_means}};
        next if !@m;
        my $n_tr = n_levels(map { $_->{trial} } @m);
        my %res = (trait => short_trait($t), n_trials => $n_tr, n_accessions => n_levels(map { $_->{accession} } @m), mean => mean(map { $_->{value} } @m),
                   var_g => undef, var_ge => undef, h2 => undef, model => '', message => 'OK', engine_used => undef, pedigree_used => $FALSE);
        my $chk = $self->{acc_is_check};
        my $check_on = $grandom && $self->{check_opt} ne 'none' && ($self->{check_opt} eq 'fixed' || n_levels(map { $chk->{ $_->{accession} } ? 1 : 0 } @m) > 1);
        if ($n_tr == 1 && $self->{gen_model} eq 'iid' && !$check_on) {
            my ($s1) = grep { $_->{trait} eq short_trait($t) } @{$self->{stage1_summary}};
            push @summary, { %res, model => 'Single trial: stage 1 means', h2 => $s1 ? $s1->{h2} : undef, var_g => $s1 ? $s1->{var_g} : undef };
            push @gv, map { +{ accession => $_->{accession}, value => $_->{value}, se => $_->{se}, trait => $t } } @m;
            next;
        }
        my @se = map { $_->{se} } @m;
        my @w = ($weighting eq 'inverse_se2' && !grep { !defined($_) || $_ <= 0 } @se) ? map { 1 / $_**2 } @se : (1) x @m;
        my $mw = mean(@w);
        my %md = (accession => [ map { $_->{accession} } @m ], trial => [ map { $_->{trial} } @m ], y => [ map { $_->{value} } @m ],
                  check => [ map { $chk->{ $_->{accession} } ? 'check' : 'test' } @m ]);
        my (%mo, %fa); for (0 .. $self->{n} - 1) { $mo{ $d->{accession}->[$_] } //= $d->{mother}->[$_]; $fa{ $d->{accession}->[$_] } //= $d->{father}->[$_]; }
        $md{mother} = [ map { $mo{$_} } @{$md{accession}} ];
        $md{father} = [ map { $fa{$_} } @{$md{accession}} ];
        $md{unit} = [ map { "$_->{trial}|$_->{accession}" } @m ];
        my @terms = (($grandom ? '(1|accession)' : 'accession'), ($n_tr > 1 ? 'trial' : ()), ($check_on ? 'check' : ()),
                     ($grandom && $self->{gen_model} eq 'parents' ? ('(1|mother)', '(1|father)') : ()));
        foreach my $v (@{$self->{trt_gxt}}) {
            my %lv;
            $lv{ $d->{trial}->[$_] }->{ $d->{$v}->[$_] } = 1 for 0 .. $self->{n} - 1;
            my %val = map { my @u = keys %{$lv{$_}}; $_ => (@u == 1 ? $u[0] : '(mixed)') } keys %lv;
            $md{$v} = [ map { $val{$_} } @{$md{trial}} ];
            my $nm = $self->{tf}->{$v}->{name};
            my @mixed = sort grep { $val{$_} eq '(mixed)' } keys %val;
            $self->warn_msg("Stage 2, ", short_trait($t), ": $nm varies within trial(s) ", join(', ', @mixed), "; those trials count as level '(mixed)' of the genotype x $nm term (within a trial the treatment is a fixed effect of stage 1).") if grep { $_ eq '(mixed)' } @{$md{$v}};
            my $nl = n_levels(@{$md{$v}});
            if ($nl > 1 && $nl < $n_tr) { push @terms, "(1|accession:$v)"; }
            else { $self->warn_msg("Stage 2, ", short_trait($t), ": genotype x $nm left out (", ($nl < 2 ? "all trials have the same $nm" : "each $nm level has a single trial, so it cannot be separated from genotype x trial"), ")."); }
        }
        my $fml = "y ~ " . join(' + ', @terms);
        my $spec = eval { $self->model_spec(\%md, $fml, $grandom, [ map { $_ / $mw } @w ], "stage2_" . short_trait($t)) };
        if (!$spec) {
            (my $e = $@) =~ s/\s+$//;
            $self->warn_msg("Stage 2, ", short_trait($t), ": the model could not be fitted ($e).");
            push @summary, { %res, message => $e };
            next;
        }
        push @specs, $spec;
        push @ctx, { t => $t, res => \%res, md => \%md, fml => $fml, n_tr => $n_tr, weighting => $weighting };
    }
    $self->step("Stage 2: fitting ", scalar(@specs), " model(s) with BLUPF90+") if @specs;
    my $fits = $self->fit_many(\@specs);
    for my $k (0 .. $#specs) {
        my ($c, $f) = ($ctx[$k], $fits->[$k]);
        my ($t, $res, $md) = ($c->{t}, $c->{res}, $c->{md});
        if ($f->{error}) {
            $self->warn_msg("Stage 2, ", short_trait($t), ": the model could not be fitted ($f->{error}).");
            push @summary, { %$res, message => $f->{error} };
            next;
        }
        $f = $self->finish_fit($specs[$k], $f, $md);
        $self->fit_notes("Stage 2, " . short_trait($t), $f->{notes});
        my $vc = $f->{vc};
        if ($grandom) {
            $res->{var_g} = sum(0, map { $vc->{$_} // 0 } qw(accession mother father));
            my %ta; $ta{ $md->{accession}->[$_] }->{ $md->{trial}->[$_] } = 1 for 0 .. $#{$md->{y}};
            my $e_bar = harmonic_mean(map { scalar(keys %$_) } values %ta);
            my $gxt_part = 0;
            my @gxt = grep { defined $vc->{$_} } map { "accession:$_" } @{$self->{trt_gxt}};
            foreach my $kk (@gxt) {
                (my $v = $kk) =~ s/^accession://;
                my %al; $al{ $md->{accession}->[$_] }->{ $md->{$v}->[$_] } = 1 for 0 .. $#{$md->{y}};
                $gxt_part += $vc->{$kk} * mean(map { 1 / scalar(keys %$_) } values %al);
            }
            $res->{var_ge} = $vc->{Residual} + sum(0, map { $vc->{$_} } @gxt);
            my $den = $res->{var_g} + $gxt_part + $vc->{Residual} / $e_bar;
            $res->{h2} = $den > 0 ? $res->{var_g} / $den : undef;
        }
        else { $res->{var_ge} = $vc->{Residual}; }
        foreach my $kk (sort keys %$vc) {
            my $comp = $kk eq 'Residual' ? 'accession:trial + error' : $kk;
            $comp =~ s/\Q$_\E/$self->{tf}->{$_}->{name}/ for @{$self->{trt_gxt}};
            push @{$self->{variance_components}}, { trait => short_trait($t), component => $comp, variance => $vc->{$kk} };
        }
        $res->{engine_used} = 'BLUPF90+';
        $res->{pedigree_used} = $f->{pedigree} ? $TRUE : $FALSE;
        $res->{relationship} = $f->{relationship} || 'I';
        (my $m = $c->{fml}) =~ s/^y ~/BLUE ~/;
        $res->{model} = "BLUPF90+: $m" . _rel_text($f) . ($c->{weighting} eq 'inverse_se2' ? ', weights = 1/SE^2' : '');
        push @{$self->{ancestor_values}}, map { +{ %$_, trait => $t } } @{ $f->{ancestors} || [] };
        push @gv, map { +{ %$_, trait => $t } } grep { defined $_->{value} } @{$f->{values}};
        push @summary, $res;
    }
    # the occasion traits of multi-trait groups give way to their trait again
    if ($self->{mt_groups}) {
        my %first; my @t;
        foreach my $x (@{$self->{traits}}) {
            my $g = $self->{mt_group_of}->{$x};
            if ($g) { push @t, $g->{trait} if !$first{ $g->{trait} }++; }
            elsif (!$occasion{$x}) { push @t, $x; }
        }
        $self->{traits} = \@t;
    }
    my %order; @order{ map { short_trait($_) } @{$self->{traits}} } = 0 .. $#{$self->{traits}};
    $self->{stage2_summary} = [ sort { ($order{$a->{trait}} // 99) <=> ($order{$b->{trait}} // 99) } @summary ];
    $self->{genotype_values} = \@gv;
}

# ---------------------------------------------------------------------------
# multi-trait repeated measurements (recipe.repeated.traits: multi)
# ---------------------------------------------------------------------------
# Every measurement occasion of a trait (1st, 2nd ... date of each trial)
# becomes a trait: stage 1 fits each trial x occasion, stage 2 one multi-
# trait model across the occasions, Var(g) = G0 (x) I | A | G | H, Var(e) =
# R0 (x) I. A covariate measured on several dates enters the same model with
# its occasions as more traits (not as a stage-1 covariate): the genotype
# values are then adjusted genetically, g_y - G_yc G_cc^-1 g_c, which keeps
# the genetic part a fixed covariate would remove. The value of an accession
# is the mean over the occasions; its standard error comes from the
# prediction error covariances (exact for the linear function).
our $MT_MAX = 6;    # traits of one multi-trait model (occasions + covariate occasions)

sub _occasions {
    my ($self, $full) = @_;
    my %trial_of; $trial_of{ $self->{dat}->{unit}->[$_] } = $self->{dat}->{trial}->[$_] for 0 .. $self->{n} - 1;
    my %dates;
    foreach my $m (@{ $self->{rep_long}->{$full} || [] }) {
        next if $m->{mdate} eq '(no date)';
        my $t = $trial_of{ $m->{unit} } // next;
        $dates{$t}->{ $m->{mdate} } = 1;
    }
    my (%occ, $n);    # trial -> date -> occasion
    foreach my $t (keys %dates) {
        my @d = sort keys %{ $dates{$t} };
        $occ{$t}->{ $d[$_] } = $_ + 1 for 0 .. $#d;
        $n = @d if !$n || @d > $n;
    }
    return { of => \%occ, n => $n // 0, trial_of => \%trial_of };
}

# plot columns of every occasion of a trait; plots whose value was removed
# as an outlier (the trait column is empty) stay empty
sub _occasion_columns {
    my ($self, $full, $occ, $blank_from) = @_;
    my $d = $self->{dat};
    my (%sum, %cnt);
    foreach my $m (@{ $self->{rep_long}->{$full} || [] }) {
        my $t = $occ->{trial_of}->{ $m->{unit} } // next;
        my $k = $occ->{of}->{$t}->{ $m->{mdate} } // next;
        $sum{$k}->{ $m->{unit} } += $m->{value}; $cnt{$k}->{ $m->{unit} }++;
    }
    my ($short, $rest) = split /\|/, $full, 2;
    my @names;
    for my $k (1 .. $occ->{n}) {
        my $nm = $short . '@o' . $k . (defined($rest) ? "|$rest" : '');
        $d->{$nm} = [ map { my $u = $d->{unit}->[$_];
                            ($cnt{$k}->{$u} && (!$blank_from || defined($d->{$blank_from}->[$_]))) ? $sum{$k}->{$u} / $cnt{$k}->{$u} : undef } 0 .. $self->{n} - 1 ];
        push @names, $nm;
    }
    return \@names;
}

sub _multi_trait_setup {
    my $self = shift;
    my @multi = grep { ($self->{rep_mode}->{$_} // '') eq 'multi' } @{$self->{traits}};
    return if !@multi;
    my $back = sub { my ($t, $why) = @_; $self->{rep_mode}->{$t} = 'all'; $self->warn_msg(short_trait($t), ": $why; its measurements were modelled with the repeated-measures model (all measurements) instead."); };
    if ($self->{strategy} ne 'two_stage' || !$self->{genotype_random}) {
        $back->($_, 'the multi-trait model needs two stages with the genotype as a random effect') for @multi;
        return;
    }
    $self->warn_msg("The multi-trait model uses no mother / father effects; accessions are treated as unrelated in it.") if $self->{gen_model} eq 'parents';
    # covariates measured on several dates join the multi-trait model
    my @rep_cov = grep { my $f = $self->{cov_full}->{$_}; $f && $self->{rep_long}->{$f} && @{ $self->{rep_long}->{$f} } } @{ $self->{cov_vars} || [] };
    my (@groups, %group_of, @new_traits);
    my %is_multi = map { $_ => 1 } @multi;
    foreach my $t (@{$self->{traits}}) {
        if (!$is_multi{$t}) { push @new_traits, $t; next; }
        my $occ = $self->_occasions($t);
        if ($occ->{n} < 2) { $back->($t, 'it has one measurement date per trial, so there is nothing to model as several traits'); push @new_traits, $t; next; }
        my @cy;
        foreach my $vn (@rep_cov) {
            my $cf = $self->{cov_full}->{$vn};
            next if $cf eq $t;
            my $co = $self->_occasions($cf);
            next if $co->{n} < 1;
            push @cy, { vn => $vn, full => $cf, occ => $co };
        }
        my $K = $occ->{n} + sum(0, map { $_->{occ}->{n} } @cy);
        if ($K > $MT_MAX) {
            $back->($t, "$occ->{n} occasions" . (@cy ? ' plus ' . join(' + ', map { "$_->{occ}->{n} of covariate " . short_trait($_->{full}) } @cy) : '') . " make $K traits, more than the $MT_MAX a multi-trait model estimates reliably");
            push @new_traits, $t;
            next;
        }
        my $y = $self->_occasion_columns($t, $occ, $t);
        my @c;
        foreach my $cv (@cy) { push @c, @{ $self->_occasion_columns($cv->{full}, $cv->{occ}) }; }
        my $g = { trait => $t, y => $y, c => \@c, n_y => scalar(@$y), covariates => [ map { short_trait($_->{full}) } @cy ],
                  labels => [ (map { short_trait($t) . " occasion $_" } 1 .. @$y), (map { my $cv = $_; map { short_trait($cv->{full}) . " occasion $_" } 1 .. $cv->{occ}->{n} } @cy) ] };
        foreach my $x (@$y, @c) { $self->{mt_skip_cov}->{$x}->{ $_->{vn} } = 1 for @cy; $group_of{$x} = $g; }
        push @groups, $g;
        push @new_traits, @$y, @c;
        $self->step("Multi-trait: ", short_trait($t), " as ", scalar(@$y), " occasion traits", (@cy ? ' + ' . scalar(@c) . ' covariate occasion traits (' . join(', ', @{ $g->{covariates} }) . ')' : ''));
    }
    $self->{mt_groups} = \@groups;
    $self->{mt_group_of} = \%group_of;
    $self->{traits} = \@new_traits;
}

# software of the run, with versions, what each program did in this run and
# the reference to cite (results overview and dashboard)
sub _software {
    my $self = shift;
    my $plural = sub { my ($n, $w) = @_; return "$n " . ($n == 1 ? $w : "${w}s"); };
    my @s1 = grep { ($_->{model} // '') =~ /^BLUPF90\+/ } @{ $self->{stage1_summary} || [] };
    my $nt = sub { n_levels(map { $_->{trial} } @_) };
    my $nr = sub { n_levels(map { $_->{trait} } @_) };
    my @surf = grep { ($_->{model} // '') =~ /PSpline/ } @s1;
    my @s2 = grep { ($_->{model} // '') =~ /^BLUPF90\+/ } @{ $self->{stage2_summary} || [] };
    my @mt = grep { ($_->{model} // '') =~ /multi-trait/ } @s2;
    my @uni = grep { ($_->{model} // '') !~ /multi-trait/ } @s2;
    my $g = $self->{genotype_random} ? 'genotype random, BLUPs' : 'genotype fixed, BLUEs';
    my $gi = $self->{genomic_info} || {};
    my $qc = $gi->{qc} || {};
    my $markers = defined($qc->{n_snps_used}) ? "$qc->{n_snps_used} of " . ($qc->{n_snps} // $gi->{n_markers} // '?') . ' markers after its quality control' : ($gi->{n_markers} // '?') . ' markers';
    # individuals of the pedigree: those listed and parents listed only as parents
    my $P = $self->{pedigree} || {};
    my $n_ped = scalar(uniq(keys %$P, grep { defined } map { @{ $P->{$_} || [] } } keys %$P));
    my $rel = { pedigree => "the pedigree relationship matrix A (with inbreeding)",
                genomic => "the genomic relationship matrix G built by its genomic module from $gi->{n_genotyped} of $gi->{n_accessions} accessions ($markers)" .
                           (($gi->{n_accessions} // 0) > ($gi->{n_genotyped} // 0) ? '; accessions without genotypes are unrelated' : ''),
                single_step => "the single-step relationship matrix H (pedigree" . ($n_ped ? " of $n_ped individuals" : '') . " + genomic: $gi->{n_genotyped} genotyped accessions, $markers)" }->{ $self->{gen_model} // '' };
    my @parts;
    push @parts, "the stage-1 models of " . $plural->($nt->(@s1), 'trial') . " x " . $plural->($nr->(@s1), 'trait') . " (" . $plural->(scalar(@s1), 'model') . ")" .
                 (@surf ? ", " . $plural->($nt->(@surf), 'trial') . " with a SpATS-like 2D P-spline surface (covariance built by Breedbase)" : '') if @s1;
    push @parts, ($self->{strategy} eq 'two_stage' ? "the stage-2 models of " : "the single-stage models of ") . $plural->(scalar(@uni), 'trait') . " ($g" . ($rel ? ", $rel" : '') . ")" if @uni;
    push @parts, "the multi-trait model" . (@mt > 1 ? 's' : '') . " of " . join('; ', map { my $m = $self->{multi_trait}->{ $_->{trait} } || {};
                 "$_->{trait} (" . $plural->($m->{n_occasions} // 0, 'date') . (@{ $m->{covariates} || [] } ? ' + dates of ' . join(', ', @{ $m->{covariates} }) : '') . ")" } @mt) .
                 " (G0 (x) " . ({ pedigree => 'A', genomic => 'G', single_step => 'H' }->{ $self->{gen_model} // '' } // 'I') . ", R0 (x) I)" if @mt;
    return [
        @parts ? { name => 'BLUPF90+', version => $self->{f90}->program_version // '', used_for => 'Fitted ' . join(' and ', @parts) . ' by sparse AI-REML.',
                   reference => 'Misztal I, Tsuruta S, Lourenco D, Masuda Y, Aguilar I, Legarra A, Vitezica Z (2018). Manual for BLUPF90 family of programs. University of Georgia, Athens, USA.' } : (),
    ];
}

# small dense helpers
sub _mat_inv {
    my $A = [ map { [@$_] } @{ $_[0] } ];
    my $n = @$A;
    my $I = [ map { my $i = $_; [ map { $_ == $i ? 1 : 0 } 0 .. $n - 1 ] } 0 .. $n - 1 ];
    for my $c (0 .. $n - 1) {
        my ($p) = sort { abs($A->[$b][$c]) <=> abs($A->[$a][$c]) } $c .. $n - 1;
        die "singular covariance matrix\n" if abs($A->[$p][$c]) < 1e-12;
        @$A[$c, $p] = @$A[$p, $c]; @$I[$c, $p] = @$I[$p, $c];
        my $f = $A->[$c][$c];
        $_ /= $f for @{ $A->[$c] }; $_ /= $f for @{ $I->[$c] };
        for my $r (0 .. $n - 1) {
            next if $r == $c;
            my $g = $A->[$r][$c];
            next if !$g;
            $A->[$r][$_] -= $g * $A->[$c][$_] for 0 .. $n - 1;
            $I->[$r][$_] -= $g * $I->[$c][$_] for 0 .. $n - 1;
        }
    }
    return $I;
}
sub _quad { my ($l, $M) = @_; my $s = 0; for my $i (0 .. $#$l) { for my $j (0 .. $#$l) { $s += $l->[$i] * $M->[$i][$j] * $l->[$j]; } } return $s; }

sub _stage2_multi {
    my ($self, $g) = @_;
    my @names = (@{ $g->{y} }, @{ $g->{c} });
    my %idx; $idx{ $names[$_] } = $_ for 0 .. $#names;
    my (%rec, %s1);
    foreach my $m (@{$self->{stage1_means}}) {
        my $k = $idx{ $m->{trait} } // next;
        next if !defined $m->{value};
        $rec{"$m->{trial}\t$m->{accession}"}->[$k] = $m->{value};
        push @{ $s1{$k} }, $m->{value};
    }
    my $short = short_trait($g->{trait});
    my @keep = grep { $s1{$_} } 0 .. $#names;    # occasions with stage-1 means
    my @ky = grep { $_ < $g->{n_y} } @keep;
    my @recs = sort keys %rec;
    my %res = (trait => $short, n_trials => n_levels(map { (split /\t/)[0] } @recs), n_accessions => n_levels(map { (split /\t/)[1] } @recs),
               mean => mean(map { @{ $s1{$_} } } @ky), var_g => undef, var_ge => undef, h2 => undef, model => '', message => 'OK',
               engine_used => 'BLUPF90+', pedigree_used => $FALSE);
    if (@ky < 1 || @keep < 2) {
        $self->warn_msg("Stage 2, $short: too few occasions with stage-1 results for the multi-trait model.");
        return { summary => { %res, message => 'too few occasions' } };
    }
    my @acc = map { (split /\t/)[1] } @recs;
    my @tr = map { (split /\t/)[0] } @recs;
    my @y = map { my $k = $_; [ map { $rec{$_}->[$k] } @recs ] } @keep;
    my $rel = $self->{gen_model} eq 'pedigree' ? 'A' : $self->{gen_model} eq 'genomic' ? 'G' : $self->{gen_model} eq 'single_step' ? 'H' : '';
    my $spec = { label => "stage2_multi_$short", traits => [ map { $names[$_] } @keep ], y => \@y, accession => \@acc, trial => \@tr,
                 ($rel ? (ped => ($rel eq 'A' ? $self->_ped_codes([ sort(uniq(@acc)) ]) : $self->{rel_codes})) : ()),
                 ($rel && $rel ne 'A' ? (genomic => $self->{genomic_spec}) : ()) };
    $self->step("Stage 2: multi-trait model for $short (", scalar(@keep), " traits) with BLUPF90+");
    my $f = $self->{f90}->fit_mt($spec);
    if ($f->{error}) {
        $self->warn_msg("Stage 2, $short: the multi-trait model could not be fitted ($f->{error}).");
        return { summary => { %res, message => $f->{error} } };
    }
    $self->fit_notes("Stage 2, $short (multi-trait)", $f->{notes});
    my $K = @keep;
    my @py = grep { $keep[$_] < $g->{n_y} } 0 .. $K - 1;    # positions in the fit
    my @pc = grep { $keep[$_] >= $g->{n_y} } 0 .. $K - 1;
    # value: mean of the occasions, adjusted genetically for the covariate traits
    my @L = (0) x $K;
    $L[$_] = 1 / @py for @py;
    my $B;
    if (@pc) {
        my $G = $f->{G0};
        my $Gcc_inv = eval { _mat_inv([ map { my $i = $_; [ map { $G->[$i][$_] } @pc ] } @pc ]) };
        if ($Gcc_inv) {
            # B = G_yc G_cc^-1; covariate part of the weights: -w' B
            $B = [ map { my $i = $_; [ map { my $j = $_; sum(map { $G->[$py[$i]][$pc[$_]] * $Gcc_inv->[$_][$j] } 0 .. $#pc) } 0 .. $#pc ] } 0 .. $#py ];
            for my $j (0 .. $#pc) { $L[ $pc[$j] ] = -sum(map { $B->[$_][$j] / @py } 0 .. $#py); }
        }
        else { $self->warn_msg("Stage 2, $short: the genetic covariance of the covariate occasions is singular, so the values were not adjusted for the covariate."); }
    }
    my $vg = _quad(\@L, $f->{G0});
    my $mu = sum(map { $f->{mu}->[$_] / @py } @py);
    my %in = map { $_ => 1 } @acc;
    my (@values, @rel);
    foreach my $a (sort keys %in) {
        my $v = $f->{values}->{$a} or next;
        my $val = $mu + sum(map { $L[$_] * $v->{solution}->[$_] } 0 .. $K - 1);
        my $pev = $v->{pec} ? _quad(\@L, $v->{pec}) : undef;
        push @values, { accession => $a, value => $val, se => defined($pev) && $pev >= 0 ? sqrt($pev) : undef, trait => $g->{trait} };
        push @rel, 1 - $pev / $vg if defined($pev) && $vg > 0;
    }
    $res{var_g} = $vg;
    # residual variance of the mean of the occasions
    $res{var_ge} = _quad([ map { my $p = $_; (grep { $_ == $p } @py) ? 1 / @py : 0 } 0 .. $K - 1 ], $f->{R0});
    $res{h2} = @rel ? mean(map { $_ < 0 ? 0 : $_ } @rel) : undef;
    $res{pedigree_used} = $rel ? $TRUE : $FALSE;
    $res{relationship} = $rel || 'I';
    $res{model} = "BLUPF90+ multi-trait: " . scalar(@py) . " occasions" . (@pc ? ' + ' . scalar(@pc) . ' covariate occasions (' . join(', ', @{ $g->{covariates} }) . ')' : '') .
                  " ~ trial + (1|accession), G0 (x) " . ($rel || 'I') . ", R0 (x) I; value = mean of the occasions" .
                  ($B ? ', adjusted genetically for the covariate (g_y - G_yc G_cc^-1 g_c)' : '') . "; H2 = mean reliability";
    my $sd = sub { my $x = shift; return $x > 0 ? sqrt($x) : 0 };
    my @gcor = map { my $i = $_; [ map { my $den = $sd->($f->{G0}->[$i][$i]) * $sd->($f->{G0}->[$_][$_]); $den > 0 ? $f->{G0}->[$i][$_] / $den : undef } 0 .. $K - 1 ] } 0 .. $K - 1;
    my @labels = map { $g->{labels}->[$_] } @keep;
    foreach my $i (0 .. $K - 1) {
        push @{$self->{variance_components}}, { trait => $short, component => "genetic, $labels[$i]", variance => $f->{G0}->[$i][$i] },
                                              { trait => $short, component => "residual, $labels[$i]", variance => $f->{R0}->[$i][$i] };
    }
    $self->{multi_trait}->{$short} = { occasions => \@labels, n_occasions => scalar(@py), covariates => $g->{covariates},
                                        G0 => $f->{G0}, R0 => $f->{R0}, genetic_correlations => \@gcor, weights => \@L, adjusted => $B ? $TRUE : $FALSE };
    return { summary => \%res, values => \@values };
}


# ---------------------------------------------------------------------------
# single stage
# ---------------------------------------------------------------------------
sub _model_factors {
    my $d = shift;
    my $n = nrow($d);
    $d->{rowN} = [ @{$d->{row}} ]; $d->{colN} = [ @{$d->{col}} ];
    $d->{rep} = [ @{$d->{rep_eff}} ];
    $d->{tr_rep} = [ map { "$d->{trial}->[$_] $d->{rep_eff}->[$_]" } 0 .. $n - 1 ];
    $d->{tr_block} = [ map { "$d->{trial}->[$_] $d->{rep_eff}->[$_] " . ($d->{block}->[$_] // '') } 0 .. $n - 1 ];
    $d->{tr_row} = [ map { defined($d->{rowN}->[$_]) ? "$d->{trial}->[$_] " . ($d->{row_off}->[$_] ? 'off' : $d->{rowN}->[$_]) : undef } 0 .. $n - 1 ];
    $d->{tr_col} = [ map { defined($d->{colN}->[$_]) ? "$d->{trial}->[$_] " . ($d->{col_off}->[$_] ? 'off' : $d->{colN}->[$_]) : undef } 0 .. $n - 1 ];
    $d->{row} = [ map { $d->{row_off}->[$_] && defined($d->{rowN}->[$_]) ? 0 : $d->{rowN}->[$_] } 0 .. $n - 1 ];
    $d->{col} = [ map { $d->{col_off}->[$_] && defined($d->{colN}->[$_]) ? 0 : $d->{colN}->[$_] } 0 .. $n - 1 ];
    return $d;
}

sub parse_custom_formula {
    my ($txt, $extra) = @_;
    $txt =~ s/[\r\n\t]+/ /g;
    $txt =~ s/^\s*y\s*~//;
    die "The custom model formula is empty.\n" if $txt !~ /\S/;
    my %allowed = map { $_ => 1 } (@FORMULA_VARS, @$extra);
    my @toks = $txt =~ /([A-Za-z_][A-Za-z0-9_.]*|[0-9]+(?:\.[0-9]+)?|\s+|.)/g;
    my %vars;
    for my $i (0 .. $#toks) {
        my $tk = $toks[$i];
        next if $tk =~ /^\s+$/ || $tk =~ m{^[-+*/:|()]$};
        if ($tk =~ /^[0-9]/) { next if $tk eq '0' || $tk eq '1'; die "Custom formula: only the numbers 0 and 1 are allowed (found '$tk').\n"; }
        if ($tk =~ /^[A-Za-z_]/) {
            my ($nx) = grep { $_ !~ /^\s+$/ } @toks[ $i + 1 .. $#toks ];
            die "Custom formula: functions are not allowed ('$tk(').\n" if defined($nx) && $nx eq '(';
            die "Custom formula: unknown variable '$tk'. Allowed: " . join(', ', @FORMULA_VARS, @$extra) . ".\n" if !$allowed{$tk};
            $vars{$tk} = 1;
            next;
        }
        die "Custom formula: character '$tk' is not allowed.\n";
    }
    (my $rhs = $txt) =~ s/^\s+|\s+$//g;
    my $rg = $rhs =~ /\(\s*1\s*\|\s*accession\s*\)/ ? 1 : 0;
    (my $fp = $rhs) =~ s/\([^()]*\|[^()]*\)//g;
    my $fg = (grep { s/^\s+|\s+$//gr eq 'accession' } split /\+/, $fp) ? 1 : 0;
    die "Custom formula: include the genotype exactly once, either as a fixed effect 'accession' or as a random effect '(1|accession)'.\n" if $rg == $fg;
    return { text => "y ~ $rhs", genotype_random => $rg, vars => [ sort keys %vars ] };
}

sub _single_stage {
    my $self = shift;
    my $dat = $self->{dat};
    my $ss = opt($self->recipe, 'single', {});
    my $mode = opt($ss, 'mode', 'builder');
    my $env = opt($ss, 'env', 'fixed');
    my $srep = opt($ss, 'rep', 'auto');
    my $sblock = opt($ss, 'block', 'auto');
    my $src = opt($ss, 'rowcol', 'auto');
    my $trend = opt($ss, 'trend', 'none');
    my @gxe = exists($ss->{gxe}) ? list($ss->{gxe}) : ((defined($ss->{include_gxe}) && !$ss->{include_gxe}) ? () : ('trial'));
    my $grandom = $self->{genotype_random};
    my $custom;
    if ($mode eq 'custom') {
        $custom = parse_custom_formula(opt($ss, 'formula', ''), [ @{$self->{cov_vars}}, @{$self->{tf_order}} ]);
        $grandom = $self->{genotype_random} = $custom->{genotype_random};
    }
    my $info = $self->{trial_info};
    my (@specs, @ctx, @summary, @gv);
    foreach my $t (@{$self->{traits}}) {
        my $d = subset($dat, [ grep { defined $dat->{$t}->[$_] } 0 .. $self->{n} - 1 ]);
        $d->{y} = $d->{$t};
        next if nrow($d) < 3;
        $self->step("Single stage: ", short_trait($t));
        my $rep_all = ($self->{rep_mode}->{$t} // '') eq 'all';
        if ($rep_all) { $d = $self->expand_repeated($d, $t); $self->_report_expand(short_trait($t), $t); }
        $d = _model_factors($d);
        my $n_tr = n_levels(@{$d->{trial}});
        my @trials = uniq(@{$d->{trial}});
        my (@dropped, @terms);
        my %used = (y => 1, accession => 1);
        my $rep_terms = sub {
            my @out;
            my $time_eff = $self->rep_time_effect($d);
            push @out, 'tr_date' if $time_eff eq 'date';
            push @out, $n_tr > 1 ? 'trial:mday' : 'mday' if $time_eff eq 'linear';
            push @dropped, 'measurement date (one date per trial or no dates recorded)' if $time_eff eq 'none';
            my %c; $c{$_}++ for @{$d->{unit}};
            push @out, '(1|plot_u)' if grep { $_ > 1 } values %c;
            if ($self->{rep_gxtime}) {
                if ($time_eff eq 'date') { push @out, '(1|accession:trial:date_f)'; }
                else { push @dropped, 'accession x date (needs several measurement dates and the date effect)'; }
            }
            $used{$_} = 1 for ('plot_u', ($time_eff eq 'date' ? ('tr_date', 'date_f') : ()), ($time_eff eq 'linear' ? ('trial', 'mday') : ()));
            return @out;
        };
        my $fml;
        if ($custom) {
            if (grep { $_ eq cov_name($t) } @{$custom->{vars}}) { $self->warn_msg(short_trait($t), " is a covariate of the custom formula; it cannot be analysed with its own value as covariate and was skipped."); next; }
            $fml = $custom->{text};
            my @off = grep { my $v = $_; $FACTOR_LABEL{$v} && !grep { $info->{$_}->{support}->{$v}->{ok} } @trials } @{$custom->{vars}};
            if (@off) {
                $self->warn_msg(short_trait($t), ": the custom formula uses ", join(', ', map { "'$_'" } @off), " but the data do not support ", (@off > 1 ? 'these factors' : 'this factor'),
                                " in any trial (", join('; ', map { my $v = $_; "$v: " . join(', ', uniq(map { $info->{$_}->{support}->{$v}->{why} } @trials)) } @off), "); remove ", (@off > 1 ? 'them' : 'it'), " from the formula.");
                next;
            }
            my @one = grep { my $v = $_; (grep { $_ eq $v } qw(trial location year check rep block)) && n_levels(@{$d->{$v}}) < 2 } @{$custom->{vars}};
            if (@one) {
                $self->warn_msg(short_trait($t), ": the custom formula uses ", join(', ', map { "'$_'" } @one), " but ", (@one > 1 ? 'these variables have' : 'it has'),
                                " a single level in the data", ((grep { $_ eq 'check' } @one) ? ' (no entry is marked as check)' : ''), "; remove ", (@one > 1 ? 'them' : 'it'), " from the formula.");
                next;
            }
            $used{$_} = 1 for grep { $_ ne 'mother' && $_ ne 'father' } @{$custom->{vars}};
            if ($rep_all) {
                my @rt = $rep_terms->();
                if (@rt) {
                    $fml .= " + " . join(' + ', @rt);
                    $self->warn_once("custom $t", short_trait($t), ": all its repeated measurements are modelled; ", join(' + ', map { pretty_model($_) } @rt), " was added to the custom formula.");
                }
            }
        }
        else {
            my @designs = map { $info->{$_}->{design} } @trials;
            my $all_rc = !grep { !$info->{$_}->{has_rowcol} } @trials;
            my $add = sub { my ($term, $ok, $label, @vars) = @_; if ($ok) { push @terms, $term; $used{$_} = 1 for @vars; } else { push @dropped, $label; } };
            my $why_off = sub { my $f = shift; join(', ', uniq(map { $info->{$_}->{support}->{$f}->{why} } @trials)) };
            $add->($env eq 'random' ? '(1|trial)' : 'trial', $n_tr > 1, 'trial (only one trial)', 'trial') if $env ne 'none';
            push @terms, $rep_terms->() if $rep_all;
            my $n_trrep = n_levels(@{$d->{tr_rep}});
            my $rep_on = $srep eq 'auto' ? $n_trrep > $n_tr : $srep ne 'none';
            $add->($srep eq 'fixed' ? 'tr_rep' : '(1|tr_rep)', $n_trrep > $n_tr, "replicate within trial (" . $why_off->('rep') . ")", 'tr_rep') if $rep_on;
            my $n_trblock = n_levels(@{$d->{tr_block}});
            my $block_on = $sblock eq 'auto' ? ((grep { $_ eq 'alpha_lattice' || $_ eq 'augmented' } @designs) && $n_trblock > $n_trrep) : $sblock ne 'none';
            $add->($sblock eq 'fixed' ? 'tr_block' : '(1|tr_block)', $n_trblock > $n_trrep, "block within replicate (" . $why_off->('block') . ")", 'tr_block') if $block_on;
            my $rc_on = $src eq 'auto' ? ((grep { $_ eq 'row_column' } @designs) || $all_rc) : $src ne 'none';
            if ($rc_on) {
                my $has_r = grep { defined } @{$d->{rowN}};
                my $has_c = grep { defined } @{$d->{colN}};
                $add->('(1|tr_row)', n_levels(@{$d->{tr_row}}) > $n_tr && $has_r, "row within trial (" . $why_off->('row') . ")", 'tr_row');
                $add->('(1|tr_col)', n_levels(@{$d->{tr_col}}) > $n_tr && $has_c, "column within trial (" . $why_off->('col') . ")", 'tr_col');
            }
            if ($trend eq 'linear') {
                my $rc = grep { defined($d->{rowN}->[$_]) && defined($d->{colN}->[$_]) } 0 .. nrow($d) - 1;
                $add->($n_tr > 1 ? 'trial:rowN + trial:colN' : 'rowN + colN', $rc >= 0.9 * nrow($d) && n_levels(@{$d->{rowN}}) > 1, 'linear row/column trend (row and column numbers missing)', 'trial', 'rowN', 'colN');
            }
            foreach my $gx (@gxe) {
                next if !$d->{$gx};
                my $nl = n_levels(@{$d->{$gx}});
                if ($gx ne 'trial' && (grep { $_ eq 'trial' } @gxe) && $nl > 1 && _same_grouping($d->{$gx}, $d->{trial})) {
                    push @dropped, "accession x $gx (each $gx has one trial: the same as accession x trial)";
                    next;
                }
                $add->("(1|accession:$gx)", $nl > 1, "accession x $gx (only one $gx)", $gx);
            }
            foreach my $v (@{$self->{trt_use}}) {
                my $nm = $self->{tf}->{$v}->{name};
                my %lv; $lv{ $d->{trial}->[$_] }->{ $d->{$v}->[$_] } = 1 for 0 .. nrow($d) - 1;
                my $within = grep { keys(%$_) > 1 } values %lv;
                if (n_levels(@{$d->{$v}}) < 2) { push @dropped, "treatment $nm (one level in the data)"; next; }
                if ($env eq 'fixed' && $n_tr > 1 && !$within) { push @dropped, "treatment $nm main effect (constant within each trial: held by the trial effect)"; next; }
                $add->($v, 1, '', $v);
            }
            foreach my $v (@{$self->{trt_gxt}}) {
                $add->("(1|accession:$v)", n_levels(@{$d->{$v}}) > 1, "accession x $self->{tf}->{$v}->{name} (one level in the data)", $v);
            }
            foreach my $cv (@{$self->{cov_vars}}) {
                next if $cv eq cov_name($t);
                my $ok = (grep { defined } @{$d->{$cv}}) > 0.5 * nrow($d) && n_levels(@{$d->{$cv}}) > 1;
                my %lv; $lv{ $d->{trial}->[$_] }->{ $d->{$cv}->[$_] // '' } = 1 for 0 .. nrow($d) - 1;
                my $held = $ok && $env eq 'fixed' && $n_tr > 1 && !grep { keys(%$_) > 1 } values %lv;
                $add->($cv, $ok && !$held, "covariate $self->{cov_label}->{$cv}" . ($held ? ' (constant within each trial: held by the trial effect)' : ' (missing or constant)'), $cv);
            }
            if ($grandom && $self->{check_opt} ne 'none') {
                my $both = n_levels(@{$d->{check}}) > 1;
                $add->('check', $both, 'check vs test entries (no checks in the data)', 'check') if $self->{check_opt} eq 'fixed' || $both;
            }
            if ($self->{gen_model} eq 'parents') {
                if ($grandom) { push @terms, '(1|mother)', '(1|father)'; }
                else { push @dropped, 'mother / father effects (need the genotype as random effect)'; }
            }
            $fml = "y ~ " . join(' + ', ($grandom ? '(1|accession)' : 'accession'), @terms);
        }
        push @dropped, ($self->{gen_model} eq 'pedigree' ? 'pedigree' : 'genomic') . ' relationship (needs the genotype as random effect)' if $self->{gen_model} =~ /^(pedigree|genomic|single_step)$/ && !$grandom;

        my @uv = grep { exists $d->{$_} } sort keys %used;
        my @cc = grep { my $i = $_; !grep { !defined($d->{$_}->[$i]) || $d->{$_}->[$i] eq '' } @uv } 0 .. nrow($d) - 1;
        $self->warn_msg(short_trait($t), ": ", nrow($d) - @cc, " plot(s) without values for all model terms were left out of the single-stage model.") if @cc < nrow($d);
        $d = subset($d, \@cc);
        $self->warn_msg(short_trait($t), ": term(s) not supported by the data were left out of the model: ", join('; ', @dropped), ".") if @dropped;
        my %res = (trait => short_trait($t), n_trials => n_levels(@{$d->{trial}}), n_accessions => n_levels(@{$d->{accession}}), mean => mean(@{$d->{y}}),
                   var_g => undef, var_ge => undef, var_e => undef, h2 => undef, model => '', dropped_terms => join('; ', @dropped), message => 'OK',
                   engine_used => undef, pedigree_used => $FALSE);
        my $spec = eval { $self->model_spec($d, $fml, $grandom, undef, "single_" . short_trait($t)) };
        if (!$spec) {
            (my $e = $@) =~ s/\s+$//;
            $self->warn_msg(short_trait($t), ": the model could not be fitted ($e).");
            push @summary, { %res, message => $e };
            next;
        }
        push @specs, $spec;
        push @ctx, { t => $t, d => $d, res => \%res, fml => $fml, rep_all => $rep_all };
    }
    $self->step("Single stage: fitting ", scalar(@specs), " model(s) with BLUPF90+") if @specs;
    my $fits = $self->fit_many(\@specs);
    for my $k (0 .. $#specs) {
        my ($c, $f) = ($ctx[$k], $fits->[$k]);
        my ($t, $d, $res) = ($c->{t}, $c->{d}, $c->{res});
        if ($f->{error}) {
            $self->warn_msg(short_trait($t), ": the model could not be fitted ($f->{error}).");
            push @summary, { %$res, message => $f->{error} };
            next;
        }
        $f = $self->finish_fit($specs[$k], $f, $d);
        $self->fit_notes(short_trait($t), $f->{notes});
        my $vc = $f->{vc};
        $res->{engine_used} = 'BLUPF90+';
        $res->{pedigree_used} = $f->{pedigree} ? $TRUE : $FALSE;
        $res->{relationship} = $f->{relationship} || 'I';
        $res->{model} = pretty_model("BLUPF90+: $c->{fml}" . _rel_text($f));
        $res->{var_e} = $vc->{Residual};
        push @{$self->{ancestor_values}}, map { +{ %$_, trait => $t } } @{ $f->{ancestors} || [] };
        foreach my $kk (sort keys %$vc) {
            my $lab = $kk;
            $lab =~ s/\Q$_\E/$self->{tf}->{$_}->{name}/ for @{$self->{tf_order}};
            push @{$self->{variance_components}}, { trait => short_trait($t), component => pretty_model($lab), variance => $vc->{$kk} };
        }
        my @gxe_names = grep { /(^|:)accession(:|$)/ && $_ ne 'accession' } keys %$vc;
        my $gxe_part = 0;
        if (@gxe_names) {
            $res->{var_ge} = sum(map { $vc->{$_} } @gxe_names);
            foreach my $kk (@gxe_names) {
                my @other = grep { $_ ne 'accession' && exists $d->{$_} } split /:/, $kk;
                my $nk = 1;
                if (@other) {
                    my %u;
                    for my $i (0 .. nrow($d) - 1) { $u{ $d->{accession}->[$i] }->{ join("\t", map { $d->{$_}->[$i] // '' } @other) } = 1; }
                    $nk = harmonic_mean(map { scalar(keys %$_) } values %u) || 1;
                }
                $gxe_part += $vc->{$kk} / $nk;
            }
        }
        if ($grandom) {
            $res->{var_g} = sum(0, map { $vc->{$_} // 0 } qw(accession mother father));
            my $vp = $vc->{plot_u} // 0;
            my $den = $res->{var_g} + $gxe_part + ($vp + $res->{var_e} / meas_per_plot($d)) / plots_per_acc($d);
            $res->{h2} = $den > 0 ? $res->{var_g} / $den : undef;
        }
        $self->add_residuals($d->{unit}, $t, $f->{resid});
        push @gv, map { +{ %$_, trait => $t } } grep { defined $_->{value} } @{$f->{values}};
        push @summary, $res;
    }
    my %order; @order{ map { short_trait($_) } @{$self->{traits}} } = 0 .. $#{$self->{traits}};
    $self->{stage2_summary} = [ sort { $order{$a->{trait}} <=> $order{$b->{trait}} } @summary ];
    $self->{genotype_values} = \@gv;
}

# ---------------------------------------------------------------------------
# index, zones
# ---------------------------------------------------------------------------
sub _wide {
    my $self = shift;
    my @traits = uniq(map { $_->{trait} } @{$self->{genotype_values}});
    my %w;
    $w{ $_->{accession} }->{ $_->{trait} } = $_->{value} for @{$self->{genotype_values}};
    $self->{traits_ok} = \@traits;
    $self->{wide} = [ map { my $a = $_; +{ accession => $a, map { $_ => $w{$a}->{$_} } @traits } } sort keys %w ];
}

sub _rank_avg {
    my @x = @_;
    my @o = sort { $x[$a] <=> $x[$b] } grep { defined $x[$_] } 0 .. $#x;
    my @r = (undef) x @x;
    my $i = 0;
    while ($i < @o) {
        my $j = $i;
        $j++ while $j + 1 < @o && $x[$o[$j + 1]] == $x[$o[$i]];
        my $avg = ($i + $j) / 2 + 1;
        $r[$o[$_]] = $avg for $i .. $j;
        $i = $j + 1;
    }
    return @r;
}

sub compute_index {
    my ($rows, $cfg, $method) = @_;
    my @score = (0) x @$rows;
    foreach my $t (sort keys %$cfg) {
        my $w = opt($cfg->{$t}, 'weight', 1) + 0;
        my $dir = opt($cfg->{$t}, 'direction', 'increase') eq 'decrease' ? -1 : 1;
        my @x = map { $_->{$t} } @$rows;
        if ($method eq 'rank_sum') {
            my @rk = _rank_avg(map { defined($_) ? -$dir * $_ : undef } @x);
            $score[$_] -= $w * ($rk[$_] // 0) for 0 .. $#x;
        }
        else {
            my ($m, $s) = (mean(@x), sd(@x));
            $score[$_] += ($s && $s > 0 && defined $x[$_]) ? $w * $dir * ($x[$_] - $m) / $s : 0 for 0 .. $#x;
        }
    }
    return @score;
}

sub _index {
    my $self = shift;
    my $cfg = opt($self->recipe, 'index', {});
    $self->{idx_traits} = {};
    return if !opt($cfg, 'enabled', 0);
    my %tc;
    my $ct = opt($cfg, 'traits', {});
    foreach my $nm (keys %{ ref($ct) eq 'HASH' ? $ct : {} }) {
        my ($full) = grep { $_ eq $nm } @{$self->{traits_ok}};
        ($full) = grep { short_trait($_) eq short_trait($nm) } @{$self->{traits_ok}} if !$full;
        $tc{$full} = $ct->{$nm} if $full && (opt($ct->{$nm}, 'weight', 0) + 0) != 0;
    }
    $self->{idx_traits} = \%tc;
    if (!%tc) { $self->warn_msg("Selection index enabled but no trait has a non-zero weight; index skipped."); return; }
    my $method = opt($cfg, 'method', 'zscore');
    my $pct = opt($cfg, 'selection_pct', 10) + 0;
    my @rows = grep { my $r = $_; !grep { !defined $r->{$_} } keys %tc } @{$self->{wide}};
    my $out = @{$self->{wide}} - @rows;
    $self->warn_msg("$out accession(s) without values for all index traits were left out of the index.") if $out;
    my @sc = compute_index(\@rows, \%tc, $method);
    my @t = map { +{ %{$rows[$_]}, index => $sc[$_] } } 0 .. $#rows;
    @t = sort { $b->{index} <=> $a->{index} } @t;
    $t[$_]->{rank} = $_ + 1 for 0 .. $#t;
    my $nsel = max(1, int(@t * $pct / 100 + 0.5));
    $_->{selected} = $_->{rank} <= $nsel ? $TRUE : $FALSE for @t;
    my %h2 = map { $_->{trait} => $_->{h2} } @{$self->{stage2_summary} || []};
    my %vg = map { $_->{trait} => $_->{var_g} } @{$self->{stage2_summary} || []};
    my $grandom = $self->{genotype_random};
    # selection accuracy: mean over the accessions of sqrt(1 - PEV / var_g)
    # (genotype random, from the standard errors of the BLUPs), otherwise
    # sqrt(H2) (accuracy of selection on entry means)
    my %se_of;
    push @{ $se_of{ $_->{trait} } }, $_->{se} for grep { defined($_->{se}) && $_->{se} =~ /\d/ } @{$self->{genotype_values}};
    my $accuracy = sub {
        my $tr = shift;
        my ($v, $h2) = ($vg{ short_trait($tr) }, $h2{ short_trait($tr) });
        if ($grandom && defined($v) && $v > 0 && $se_of{$tr} && @{ $se_of{$tr} }) {
            return ({ value => mean(map { sqrt(max(0, 1 - $_ * $_ / $v)) } @{ $se_of{$tr} }), basis => 'pev' });
        }
        return defined($h2) ? { value => sqrt(max(0, $h2)), basis => 'h2' } : { value => undef, basis => '' };
    };
    my @gains;
    foreach my $tr (@{$self->{traits_ok}}) {
        my @x = map { $_->{$tr} } @t;
        my @xs = map { $_->{$tr} } grep { $_->{selected} } @t;
        my ($mp, $ms) = (mean(@x), mean(@xs));
        my $s = defined($mp) && defined($ms) ? $ms - $mp : undef;
        my $h2 = $h2{ short_trait($tr) };
        my $in = $tc{$tr} ? 1 : 0;
        push @gains, { trait => short_trait($tr), in_index => $in ? $TRUE : $FALSE, weight => $in ? opt($tc{$tr}, 'weight', 0) + 0 : 0,
                       direction => $in ? opt($tc{$tr}, 'direction', 'increase') : '', mean_population => $mp, mean_selected => $ms,
                       selection_differential => $s, selection_differential_pct => (defined($s) && $mp) ? 100 * $s / abs($mp) : undef,
                       h2 => $h2, expected_gain => (!$grandom && defined($h2) && defined($s)) ? $h2 * $s : $s,
                       accuracy => $accuracy->($tr)->{value}, accuracy_basis => $accuracy->($tr)->{basis} };
    }
    # accuracy of the index: mean of its traits' accuracies, weighted by |weight|
    my @acc = grep { $_->{in_index} && defined($_->{accuracy}) } @gains;
    my $wsum = sum(map { abs($_->{weight}) } @acc) || 0;
    my $ix_acc = !@acc ? undef : $wsum > 0 ? sum(map { abs($_->{weight}) * $_->{accuracy} } @acc) / $wsum : mean(map { $_->{accuracy} } @acc);
    foreach my $r (@t) { foreach my $k (keys %$r) { next if $k !~ /\|/; $r->{ short_trait($k) } = delete $r->{$k}; } }
    $self->{index} = { method => $method, selection_pct => $pct, n_selected => $nsel, n_ranked => scalar(@t), table => \@t, gains => \@gains, accuracy => $ix_acc,
                       note => $grandom ? 'Values are BLUPs (already shrunk by heritability): the expected gain equals the selection differential on BLUPs.' : 'Expected gain = h2 x selection differential on BLUEs.' };
}

# Lin (1982) test of genotype x environment interaction for a group of environments
sub _lin_test {
    my ($self, $d, $envs) = @_;
    my %in = map { $_ => 1 } @$envs;
    my @ii = grep { $in{ $d->{env}->[$_] } } 0 .. nrow($d) - 1;
    my %ae; $ae{ $d->{accession}->[$_] }->{ $d->{env}->[$_] } = 1 for @ii;
    my @common = sort grep { keys(%{$ae{$_}}) == @$envs } keys %ae;
    my %c = map { $_ => 1 } @common;
    @ii = grep { $c{ $d->{accession}->[$_] } } @ii;
    my ($ng, $ne) = (scalar(@common), scalar(@$envs));
    return { ss => undef, df => undef, f => undef, p => undef, n_g => $ng } if $ng < 2 || $ne < 2;
    my (%s, %n);
    foreach my $i (@ii) { my $k = "$d->{accession}->[$i]\t$d->{env}->[$i]"; $s{$k} += $d->{y}->[$i]; $n{$k}++; }
    my %cm = map { $_ => $s{$_} / $n{$_} } keys %s;
    my (%rm, %cmn);
    foreach my $a (@common) { $rm{$a} = mean(map { $cm{"$a\t$_"} } @$envs); }
    foreach my $e (@$envs) { $cmn{$e} = mean(map { $cm{"$_\t$e"} } @common); }
    my $gm = mean(values %cm);
    my $r_eff = harmonic_mean(values %n);
    my $ss = 0;
    foreach my $a (@common) { foreach my $e (@$envs) { $ss += ($cm{"$a\t$e"} - $rm{$a} - $cmn{$e} + $gm)**2; } }
    $ss *= $r_eff;
    my $df = ($ng - 1) * ($ne - 1);
    # residual of y ~ env + env:rep + accession + env:accession (least squares)
    my @cell = map { "$d->{accession}->[$_]\t$d->{env}->[$_]" } @ii;
    my @er = map { "$d->{env}->[$_]\t$d->{trial}->[$_]\t$d->{rep_eff}->[$_]" } @ii;
    my $n_er = n_levels(@er);
    my @f = (\@cell);
    push @f, \@er if $n_er > $ne;
    my $rank = n_levels(@cell) + ($n_er > $ne ? $n_er - $ne : 0);
    my $dfr = @ii - $rank;
    return { ss => $ss, df => $df, f => undef, p => undef, n_g => $ng } if $dfr < 1;
    my $r = backfit([ map { $d->{y}->[$_] } @ii ], \@f);
    my $mse = sum(map { $_**2 } @$r) / $dfr;
    return { ss => $ss, df => $df, f => undef, p => undef, n_g => $ng } if $mse <= 0;
    my $f = ($ss / $df) / $mse;
    return { ss => $ss, df => $df, f => $f, p => pf_upper($f, $df, $dfr), n_g => $ng };
}

sub _lin_zones {
    my ($self, $d, $alpha) = @_;
    my @envs = sort(uniq(@{$d->{env}}));
    return NA if @envs < 2;
    my @pw;
    for my $i (0 .. $#envs) {
        for my $j ($i + 1 .. $#envs) {
            my $r = $self->_lin_test($d, [ $envs[$i], $envs[$j] ]);
            push @pw, { env1 => $envs[$i], env2 => $envs[$j], ss => $r->{ss}, f => $r->{f}, p_value => $r->{p}, n_genotypes => $r->{n_g},
                        compatible => (defined($r->{p}) && $r->{p} >= $alpha) ? $TRUE : $FALSE };
        }
    }
    my %rem = map { $_ => 1 } @envs;
    my @groups;
    while (keys(%rem) >= 2) {
        my @cand = sort { $a->{ss} <=> $b->{ss} } grep { $rem{$_->{env1}} && $rem{$_->{env2}} && $_->{compatible} } @pw;
        last if !@cand;
        my @grp = ($cand[0]->{env1}, $cand[0]->{env2});
        while (1) {
            my %g = map { $_ => 1 } @grp;
            my @add = grep { !$g{$_} } sort keys %rem;
            last if !@add;
            my @tests = grep { defined($_->{p}) && $_->{p} >= $alpha } map { my $r = $self->_lin_test($d, [ @grp, $_ ]); +{ env => $_, ss => $r->{ss}, p => $r->{p} } } @add;
            last if !@tests;
            @tests = sort { $a->{ss} <=> $b->{ss} } @tests;
            push @grp, $tests[0]->{env};
        }
        push @groups, \@grp;
        delete $rem{$_} for @grp;
    }
    push @groups, [$_] for sort keys %rem;
    return { groups => \@groups, pairwise => \@pw };
}

sub _cor_zones {
    my ($self, $m, $envs, $thr, $min_common) = @_;
    return NA if @$envs < 2;
    my @acc = sort keys %$m;
    my (@cm, @dist);
    for my $i (0 .. $#$envs) {
        for my $j (0 .. $#$envs) {
            my @x = map { $m->{$_}->{ $envs->[$i] } } @acc;
            my @y = map { $m->{$_}->{ $envs->[$j] } } @acc;
            my $nc = grep { defined($x[$_]) && defined($y[$_]) } 0 .. $#acc;
            $cm[$i][$j] = $nc >= $min_common ? cor(\@x, \@y) : undef;
            $dist[$i][$j] = $i == $j ? 0 : defined($cm[$i][$j]) ? 1 - $cm[$i][$j] : 2;
        }
    }
    my $hc = hclust_average(\@dist);
    my $cl = cutree_height(scalar(@$envs), $hc, 1 - $thr);
    my @groups = map { [ map { $envs->[$_] } @$_ ] } sort { @$b <=> @$a } @$cl;
    my @o = @{$hc->{order}};
    return { groups => \@groups, correlation => { environments => [ map { $envs->[$_] } @o ],
             matrix => [ map { my $i = $_; [ map { defined($cm[$i][$_]) ? 0 + sprintf('%.4f', $cm[$i][$_]) : undef } @o ] } @o ] } };
}

sub _zones {
    my $self = shift;
    my $zc = opt($self->recipe, 'zones', {});
    $self->{zone_results} = [];
    return if !opt($zc, 'enabled', 0) || !@{$self->{stage1_means}};
    my $d = $self->{dat};
    my $method = opt($zc, 'method', 'correlation');
    my $alpha = opt($zc, 'alpha', 0.05) + 0;
    my $thr = opt($zc, 'threshold', 0.5) + 0;
    my $top = opt($zc, 'top_n', 10) + 0;
    my @targets = list(opt($zc, 'targets', ['index']));
    my $min_common = max(5, opt($zc, 'min_common', 5) + 0);
    my $min_env = max(1, int(opt($zc, 'min_env', 1) || 1));
    my $ac = opt($zc, 'accessions', {});
    my $set = opt($ac, 'set', 'all');
    my $acc_label = 'all accessions';
    my $zacc;
    if ($set eq 'checks' || $set eq 'list') {
        my @all = uniq(@{$d->{accession}});
        my (@want, $what);
        if ($set eq 'checks') { @want = grep { $self->{acc_is_check}->{$_} } keys %{$self->{acc_is_check}}; $what = 'check accessions'; }
        else {
            @want = map { s/^\s+|\s+$//gr } list(opt($ac, 'items', []));
            my $ln = opt($ac, 'list_name', '');
            $what = "accessions of the list" . ($ln ne '' ? " '$ln'" : '');
            my %a = map { $_ => 1 } @all;
            my $out = grep { !$a{$_} } uniq(@want);
            my $inn = grep { $a{$_} } uniq(@want);
            $self->warn_msg("Zoning: $out of the " . scalar(uniq(@want)) . " $what are not in the dataset and were ignored.") if $out && $inn >= 3;
        }
        $acc_label = $what;
        my %w = map { $_ => 1 } @want;
        my @z = grep { $w{$_} } @all;
        if (@z < 3) {
            $self->warn_msg("Zoning: only " . scalar(@z) . " $what in the dataset (at least 3 are needed to group environments); all accessions were used instead.");
            $acc_label = 'all accessions';
        }
        else {
            if (@z < $min_common) { $self->warn_msg("Zoning: the zones rest on only " . scalar(@z) . " $what; correlations between environments on so few accessions are unreliable."); $min_common = scalar(@z); }
            $zacc = { map { $_ => 1 } @z };
        }
    }
    # environment-level values (mean of the trial means of an environment)
    my (%ev, %en);
    foreach my $m (@{$self->{stage1_means}}) { my $k = "$m->{accession}\t$m->{env}\t$m->{trait}"; $ev{$k} += $m->{value}; $en{$k}++; }
    my %env_vals;    # trait -> accession -> env -> value
    foreach my $k (keys %ev) { my ($a, $e, $t) = split /\t/, $k; $env_vals{$t}->{$a}->{$e} = $ev{$k} / $en{$k}; }
    my %meta;
    for my $i (0 .. $self->{n} - 1) {
        my $e = $d->{env}->[$i];
        $meta{$e}->{location}->{ $d->{location}->[$i] } = 1; $meta{$e}->{year}->{ $d->{year}->[$i] } = 1; $meta{$e}->{trial}->{ $d->{trial}->[$i] } = 1;
    }
    my @envs_all = sort keys %meta;
    my %idx = %{$self->{idx_traits}};
    my (@tlist);
    foreach my $tg (@targets) {
        if ($tg eq 'index') {
            if (!%idx) { $self->warn_msg("Zoning on the index requires an enabled selection index."); next; }
            my %vals;
            foreach my $e (@envs_all) {
                next if grep { !$env_vals{$_} } keys %idx;
                my @acc = sort grep { my $a = $_; !grep { !defined $env_vals{$_}->{$a}->{$e} } keys %idx } uniq(map { keys %{$env_vals{$_}} } keys %idx);
                next if @acc < 3;
                my @rows = map { my $a = $_; +{ map { $_ => $env_vals{$_}->{$a}->{$e} } keys %idx } } @acc;
                my @s = compute_index(\@rows, \%idx, opt(opt($self->recipe, 'index', {}), 'method', 'zscore'));
                $vals{ $acc[$_] }->{$e} = $s[$_] for 0 .. $#acc;
            }
            next if !%vals;
            push @tlist, [ 'Selection index', \%vals, undef ];
        }
        else {
            my ($full) = grep { $_ eq $tg } @{$self->{traits_ok}};
            ($full) = grep { short_trait($_) eq short_trait($tg) } @{$self->{traits_ok}} if !$full;
            next if !$full || !$env_vals{$full};
            push @tlist, [ short_trait($full), $env_vals{$full}, $full ];
        }
    }
    my %decr = map { short_trait($_) => 1 } grep { opt($idx{$_}, 'direction', 'increase') eq 'decrease' } keys %idx;
    foreach my $tv (@tlist) {
        my ($name, $m, $full) = @$tv;
        my %mz = $zacc ? map { $_ => $m->{$_} } grep { $zacc->{$_} } keys %$m : %$m;
        my @envs = sort(uniq(map { keys %{$m->{$_}} } keys %$m));
        my $used = $method;
        my $zr;
        if ($method eq 'lin' && $full) {
            my @ii = grep { defined($d->{$full}->[$_]) && (!$zacc || $zacc->{ $d->{accession}->[$_] }) } 0 .. $self->{n} - 1;
            my $s = subset($d, \@ii);
            $s->{y} = $s->{$full};
            $zr = $self->_lin_zones($s, $alpha);
        }
        else {
            $used = 'correlation';
            $zr = $self->_cor_zones(\%mz, \@envs, $thr, $min_common);
        }
        if (!$zr) { $self->warn_msg("Zoning for $name needs at least two environments."); next; }
        my $higher = $decr{$name} ? 0 : 1;
        my (@membership, @top, @gz);
        foreach my $k (0 .. $#{$zr->{groups}}) {
            my $zone = "Zone " . ($k + 1);
            my @ge = @{$zr->{groups}->[$k]};
            push @membership, map { my $e = $_; +{ zone => $zone, env => $e, map { my $f = $_; $f => join(', ', sort keys %{ $meta{$e}->{$f} || {} }) } qw(location year trial) } } sort @ge;
            my $need = min($min_env, scalar(@ge));
            my %v; my %ne;
            foreach my $a (keys %$m) {
                my @x = grep { defined } map { $m->{$a}->{$_} } @ge;
                next if @x < $need || !@x;
                $v{$a} = mean(@x); $ne{$a} = scalar(@x);
            }
            next if !%v;
            my @ord = sort { $higher ? $v{$b} <=> $v{$a} : $v{$a} <=> $v{$b} } sort keys %v;
            my @first = @ord[ 0 .. min($top, scalar(@ord)) - 1 ];
            push @top, map { +{ zone => $zone, rank => $_ + 1, accession => $first[$_], value => $v{ $first[$_] }, n_env => $ne{ $first[$_] } } } 0 .. $#first;
            my $nr = scalar(@ord);
            # rank with ties at the minimum
            my %rk; my $prev; my $r = 0;
            foreach my $i (0 .. $#ord) { $r = $i + 1 if !defined($prev) || $v{ $ord[$i] } != $prev; $rk{ $ord[$i] } = $r; $prev = $v{ $ord[$i] }; }
            push @gz, map { +{ zone => $zone, accession => $_, value => $v{$_}, n_env => $ne{$_}, rank => $rk{$_}, n_ranked => $nr } } sort keys %v;
        }
        @membership = sort { $a->{zone} cmp $b->{zone} || $a->{env} cmp $b->{env} } @membership;
        push @{$self->{zone_results}}, { target => $name, method => $used, n_zones => scalar(@{$zr->{groups}}), higher_is_better => $higher ? $TRUE : $FALSE,
            accessions_used => $acc_label, n_accessions_used => scalar(keys %mz), min_env => $min_env, membership => \@membership,
            pairwise => $zr->{pairwise}, correlation => $zr->{correlation}, top => \@top, genotype_zones => \@gz };
    }
}

# ---------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------
sub _write_csv {
    my ($self, $rows, $cols, $suffix) = @_;
    return NA if !$rows || !@$rows;
    my $f = $self->output_prefix . "_$suffix.csv";
    open(my $F, '>', $f) or return NA;
    my $q = sub { my $v = shift; return '' if !defined $v; return (ref($v) && JSON::XS::is_bool($v)) ? ($v ? 'TRUE' : 'FALSE') : $v =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?$/ && !(ref(\$v) eq 'SCALAR' && $v =~ /^0\d/) ? $v : '"' . ($v =~ s/"/""/gr) . '"'; };
    print $F join(',', map { '"' . $_ . '"' } @$cols), "\n";
    foreach my $r (@$rows) { print $F join(',', map { $q->($r->{$_}) } @$cols), "\n"; }
    close($F);
    return basename($f);
}

sub _clean_numbers {
    my $x = shift;
    if (ref($x) eq 'HASH') { $x->{$_} = _clean_numbers($x->{$_}) for keys %$x; return $x; }
    if (ref($x) eq 'ARRAY') { $_ = _clean_numbers($_) for @$x; return $x; }
    return $x if !defined($x) || ref($x);
    my $b = B::svref_2object(\$x);
    my $flags = $b->FLAGS;
    # numbers (also numbers that were printed), never strings read from a file
    my $numeric = ($flags & (B::SVf_IOK() | B::SVf_NOK())) ? 1 : 0;    ## no critic (ProhibitBitwiseOperators)
    my $string = ($flags & B::SVf_POK()) ? 1 : 0;                       ## no critic (ProhibitBitwiseOperators)
    if ($numeric && (!$string || "$x" =~ /^-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?$/)) { return sig($x); }
    return $x;
}

sub _write_json {
    my ($self, $obj) = @_;
    require B;
    _clean_numbers($obj);
    open(my $F, '>', $self->output_file) or die "Cannot write " . $self->output_file . "\n";
    print $F JSON::XS->new->utf8->allow_nonref->encode($obj);
    close($F);
}

sub _output {
    my $self = shift;
    my $d = $self->{dat};
    my @traits = @{$self->{traits}};
    my $ped = $self->{pedigree};
    my @wide = map { my $r = $_; my %o = (accession => $r->{accession}); $o{ short_trait($_) } = $r->{$_} for @{$self->{traits_ok}};
                     if ($ped) { $o{mother} = $ped->{ $r->{accession} } ? $ped->{ $r->{accession} }->[0] : undef; $o{father} = $ped->{ $r->{accession} } ? $ped->{ $r->{accession} }->[1] : undef; } \%o } @{$self->{wide}};
    my @wide_cols = ('accession', (map { short_trait($_) } @{$self->{traits_ok}}), ($ped ? ('mother', 'father') : ()));
    my @s1 = map { +{ %$_, trait => short_trait($_->{trait}) } } @{$self->{stage1_means}};
    my @gv = map { +{ accession => $_->{accession}, value => $_->{value}, se => $_->{se}, trait => short_trait($_->{trait}), trait_full => $_->{trait} } } @{$self->{genotype_values}};
    my @ancestors = map { +{ %$_, trait => short_trait($_->{trait}) } } @{$self->{ancestor_values}};

    my %files = (
        genotype_values => $self->_write_csv(\@wide, \@wide_cols, 'genotype_values'),
        stage1_means => $self->_write_csv(\@s1, [qw(accession value se trial env trait)], 'stage1_means'),
        outliers => $self->_write_csv($self->{outliers}, [qw(unit trial accession trait value reason)], 'outliers'),
        ancestors => $self->_write_csv(\@ancestors, [qw(accession value se trait)], 'ancestor_breeding_values'),
    );
    if ($self->{index}) {
        my @ic = ('accession', (map { short_trait($_) } @{$self->{traits_ok}}), 'index', 'rank', 'selected');
        $files{index} = $self->_write_csv($self->{index}->{table}, \@ic, 'selection_index');
    }
    if (@{$self->{zone_results}}) {
        my @zr = map { my $z = $_; map { +{ target => $z->{target}, %$_ } } @{$z->{membership}} } @{$self->{zone_results}};
        $files{zones} = $self->_write_csv(\@zr, [qw(target env zone location year trial)], 'zones');
    }
    # BLUPF90+ parameter and data files of every model, to inspect or re-run them
    my $keep = $self->output_prefix . '_blupf90';
    if (-d $keep) {
        my $tgz = $self->output_prefix . '_blupf90.tar.gz';
        my $ok = system('tar', '-czf', $tgz, '-C', dirname($keep), basename($keep)) == 0;
        if ($ok) { $files{blupf90} = basename($tgz); remove_tree($keep); }
        else { $self->warn_msg("The BLUPF90+ files could not be packed."); }
    }
    delete $files{$_} for grep { !defined $files{$_} } keys %files;

    my @plots;
    for my $i (0 .. $self->{n} - 1) {
        my %p = (unit => $d->{unit}->[$i], trial => $d->{trial}->[$i], location => $d->{location}->[$i], year => $d->{year}->[$i], accession => $d->{accession}->[$i],
                 rep => $d->{rep_eff}->[$i], block => $d->{block}->[$i], row => $d->{row}->[$i], col => $d->{col}->[$i]);
        foreach my $t (@traits) {
            my $st = short_trait($t);
            $p{$st} = $d->{$t}->[$i];
            $p{"resid:$st"} = $self->{residuals}->{$t}->{ $d->{unit}->[$i] } if $self->{residuals}->{$t};
        }
        push @plots, \%p;
    }
    my $info = $self->{trial_info};
    my @trials = map { my $x = $info->{$_}; {
        trial => $x->{trial}, location => $x->{location}, year => $x->{year}, design => $x->{design_label}, spatial_layout => $x->{has_rowcol} ? $TRUE : $FALSE,
        n_plots => $x->{n_plots}, n_accessions => $x->{n_accessions},
        factors_not_used => join('; ', map { lc($FACTOR_LABEL{$_}) . " ($x->{support}->{$_}->{why})" } grep { !$x->{support}->{$_}->{ok} && !_routine_off($x->{support}->{$_}->{why}) } @FACTORS) } } @{$self->{trials}};
    my @trt = map { my $f = $self->{tf}->{$_}; my %bt; $bt{ $d->{trial}->[$_] }->{ $f->{values}->[$_] } = 1 for 0 .. $self->{n} - 1;
        { name => $f->{name}, variable => $f->{var}, source => $f->{source}, levels => [ sort(uniq(@{$f->{values}})) ],
          used => (grep { $_ eq $f->{var} } @{$self->{trt_use}}) ? $TRUE : $FALSE, gxt => (grep { $_ eq $f->{var} } @{$self->{trt_gxt}}) ? $TRUE : $FALSE,
          by_trial => [ map { +{ trial => $_, levels => join(', ', sort keys %{$bt{$_}}) } } sort keys %bt ] } } @{$self->{tf_order}};
    my $gr = $self->{genotype_random};
    my %result = (
        version => $VERSION_TAG,
        strategy => $self->{strategy},
        engine => 'blupf90',
        engine_runtime => 'perl',
        genetic_model => $self->{gen_model},
        genotype_effect => $gr ? 'random' : 'fixed',
        value_label => !$gr ? 'BLUE' : $self->{gen_model} eq 'pedigree' ? 'EBV' : $self->{gen_model} =~ /^(genomic|single_step)$/ ? 'GEBV' : 'BLUP',
        genomic => $self->{genomic_info},
        summary => { n_plots => $self->{n}, n_accessions => n_levels(@{$d->{accession}}), n_trials => scalar(@{$self->{trials}}),
                     n_environments => n_levels(@{$d->{env}}), traits => [ map { short_trait($_) } @traits ], traits_full => \@traits, environment_unit => $self->{env_unit} },
        trials => \@trials,
        treatments => \@trt,
        repeated => { time => $self->{rep_time}, gxtime => $self->{rep_gxtime} ? $TRUE : $FALSE, traits => $self->{repeated_info} },
        covariates => [ map { $self->{cov_label}->{$_} } @{$self->{cov_vars}} ],
        multi_trait => $self->{multi_trait},
        software => $self->_software(),
        outliers => $self->{outliers},
        outlier_summary => $self->{outlier_summary},
        stage1 => @{$self->{stage1_summary}} ? $self->{stage1_summary} : undef,
        stage2 => $self->{stage2_summary},
        genotype_values => \@wide,
        genotype_values_long => \@gv,
        ancestor_values => @ancestors ? \@ancestors : undef,
        stage1_means => @s1 ? \@s1 : undef,
        variance_components => @{$self->{variance_components}} ? $self->{variance_components} : undef,
        plots => \@plots,
        recipe => $self->recipe,
        index => $self->{index},
        zones => $self->{zone_results},
        files => \%files,
        warnings => $self->{warnings},
    );
    $self->_write_json(\%result);
    $self->step("Done. Results written to ", $self->output_file);
}

1;
