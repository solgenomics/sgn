#!/usr/bin/env perl

=head1 NAME

phenotype_properties_check.pl - Phenotype quality control

=head1 SYNOPSIS

    phenotype_properties_check.pl -U [dbuser] -P [dbpass] -H [dbhost] -D [dbname] -o [dir] -f [name]
        [-s start -e end] [-t trial_ids_file] [-a accession_ids_file] [-T trait_ids_file]

=head1 COMMAND-LINE OPTIONS

 -U  db username (postgres)
 -P  db password
 -H  host name
 -D  database name
 -o  output directory
 -f  output filename (without extension)
 -s  start date (YYYY-MM-DD): trials created from this date
 -e  end date (YYYY-MM-DD): trials created until this date
 -t  file with trial ids, one per line
 -a  file with accession ids, one per line
 -T  file with trait ids, one per line

Give the dates, a trial list or both (then only the trials of the list created
in the date range are checked). The accession and trait lists limit the check.

=head1 DESCRIPTION

Phenotypes outside their trait minimum and maximum, or not numeric.

Lists the values below the minimum or above the maximum set for their trait,
or that are not numbers, in the chosen trials.

Traits without both a minimum and a maximum (trait_minimum / trait_maximum
properties) are not checked. Writes <name>.xlsx and <name>.csv with one row per
issue, and <name>.results.json for the Report Factory page.

=head1 AUTHOR

chris simoes (ccs263@cornell.edu)

March 2025

=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use CXGN::Trial;
use CXGN::Report::Output;

our %opt;
getopts('H:D:U:P:o:f:s:e:t:a:T:', \%opt);

my $dbhost = $opt{H} // 'localhost';
my $dbname = $opt{D} // 'breedbase';
my $dbuser = $opt{U} // 'postgres';
my $dbpass = $opt{P} // '';
my $out_directory = $opt{o} // '';
my $filename = $opt{f} // 'phenotype_properties_check';
my $start_date = $opt{s} // '';
my $end_date  = $opt{e} // '';
my @list_trial_ids = CXGN::Report::Output::read_ids($opt{t});
my %accession_filter = map { $_ => 1 } CXGN::Report::Output::read_ids($opt{a});
my %trait_filter = map { $_ => 1 } CXGN::Report::Output::read_ids($opt{T});
my $use_dates = ($start_date ne '' && $end_date ne '');

die "Give a date range (-s, -e) or a file of trial ids (-t).\n" if !$use_dates && !@list_trial_ids && !$opt{t};

print STDERR "Connecting to database $dbname on $dbhost as $dbuser...\n";

my $dbh = DBI->connect(
    "dbi:Pg:dbname=$dbname;host=$dbhost",
    $dbuser,
    $dbpass,
    { AutoCommit => 0, RaiseError => 1 }
);

my $schema = Bio::Chado::Schema->connect(sub { $dbh });

# trials: those of the list, those created in the date range, or both
my %search;
$search{create_date} = { -between => [ "$start_date 00:00:00", "$end_date 23:59:59" ] } if $use_dates;
$search{project_id} = { -in => \@list_trial_ids } if @list_trial_ids;
%search = (project_id => { -in => [ -1 ] }) if $opt{t} && !@list_trial_ids;    # empty list given

my $rs = $schema->resultset("Project::Project")->search(\%search, { columns => [ 'project_id', 'create_date' ] });

my (@trial_ids, %trial_create_dates);
while (my $row = $rs->next) {
    my $create_date = $row->create_date // '';
    $create_date =~ s/\s.*$//;
    push @trial_ids, $row->project_id;
    $trial_create_dates{ $row->project_id } = $create_date;
}

# trait limits, read once
my %limits;
my $limit_sth = $dbh->prepare(q{
    SELECT p.cvterm_id, t.name, p.value
    FROM cvtermprop p
    JOIN cvterm t ON (t.cvterm_id = p.type_id)
    WHERE t.name IN ('trait_minimum', 'trait_maximum')
});
$limit_sth->execute();
while (my ($cvterm_id, $type, $value) = $limit_sth->fetchrow_array) {
    $limits{$cvterm_id}->{ $type eq 'trait_minimum' ? 'min' : 'max' } //= $value;
}

my $obs_sth = $dbh->prepare(q{
    SELECT
        acc.stock_id AS accession_id,
        acc.uniquename AS accession_name,
        plot.uniquename AS plot_name,
        trait.cvterm_id AS trait_id,
        trait.name AS trait_name,
        ph.value AS observed_value
    FROM nd_experiment_project ep
    JOIN nd_experiment_phenotype nep ON (nep.nd_experiment_id = ep.nd_experiment_id)
    JOIN phenotype ph ON (nep.phenotype_id = ph.phenotype_id)
    JOIN cvterm trait ON (ph.cvalue_id = trait.cvterm_id)
    JOIN nd_experiment_stock nes ON (ep.nd_experiment_id = nes.nd_experiment_id)
    JOIN stock plot ON (nes.stock_id = plot.stock_id)
    LEFT JOIN LATERAL (
        SELECT a.stock_id, a.uniquename
        FROM stock_relationship rel
        JOIN stock a ON (a.stock_id = rel.object_id)
        JOIN cvterm at ON (at.cvterm_id = a.type_id AND at.name = 'accession')
        WHERE rel.subject_id = plot.stock_id
        LIMIT 1
    ) acc ON (TRUE)
    WHERE ep.project_id = ?
});

my @qc_issues;
my (%by_type, %by_trait, %trials_with_issues);
my ($n_trials, $n_checked, $n_unchecked) = (0, 0, 0);
my $total = scalar(@trial_ids);
my $counter = 0;

foreach my $trial_id (@trial_ids) {
    $counter++;
    my $t = eval { CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id }) };
    next if $@ || !defined $t;

    my $year = $t->get_year();
    my $test_type = $t->get_design_type();
    next unless defined $year;
    # analysis "trials" (design type written in Portuguese) have no field observations to check
    next if !defined($test_type) || $test_type =~ /^Anal[i]se$/;

    my $trial_name = $t->get_name;
    my $location_name = $t->get_location ? $t->get_location()->[1] : "Unknown";
    my $breeding_program_name = $t->get_breeding_program();
    my $create_date = $trial_create_dates{$trial_id} || 'NULL';
    $n_trials++;

    print STDERR "Checking trial $trial_name ($counter/$total)\n";

    $obs_sth->execute($trial_id);
    while (my ($accession_id, $accession, $plot, $trait_id, $trait_name, $observed_value) = $obs_sth->fetchrow_array) {
        next if %accession_filter && !(defined($accession_id) && $accession_filter{$accession_id});
        next if %trait_filter && !$trait_filter{$trait_id};
        $accession //= 'Unknown';

        my $min_value = $limits{$trait_id}->{min};
        my $max_value = $limits{$trait_id}->{max};
        if (!defined($min_value) || !defined($max_value) || $min_value eq $max_value) {
            $n_unchecked++;
            next;
        }
        $n_checked++;

        my $qc_type;
        if (defined $observed_value && $observed_value !~ /^-?\d+(\.\d+)?$/) {
            $qc_type = "invalid numeric format";
        }
        elsif (defined $observed_value && $observed_value < $min_value) {
            $qc_type = "below minimum";
        }
        elsif (defined $observed_value && $observed_value > $max_value) {
            $qc_type = "above maximum";
        }
        next if !$qc_type;

        $by_type{$qc_type}++;
        $by_trait{$trait_name}++;
        $trials_with_issues{$trial_name}++;
        push @qc_issues, [ $year, $breeding_program_name, $trial_name, $location_name, $create_date, $accession, $plot, $trait_name, $observed_value, $min_value, $max_value, $qc_type ];
    }
}

my @columns = qw( year breeding_program_name trial_name trial_location create_date accession plot trait_name observed minimum maximum type );

my $out = CXGN::Report::Output->new({ directory => $out_directory, basename => $filename, title => 'Phenotype quality control' });
$out->add_summary('Trials checked', $n_trials);
$out->add_summary('Values checked', $n_checked);
$out->add_summary('Issues found', scalar(@qc_issues), $n_checked ? sprintf('%.1f%% of the values checked', 100 * @qc_issues / $n_checked) : undef);
$out->add_summary('Trials with issues', scalar(keys %trials_with_issues));
my @types = ('below minimum', 'above maximum', 'invalid numeric format');
$out->add_chart({ title => 'Issues by type', labels => \@types, values => [ map { $by_type{$_} // 0 } @types ] }) if @qc_issues;
my @top_traits = (sort { $by_trait{$b} <=> $by_trait{$a} || $a cmp $b } keys %by_trait)[0 .. 14];
@top_traits = grep { defined } @top_traits;
$out->add_chart({ title => 'Issues by trait' . (keys(%by_trait) > 15 ? ' (top 15)' : ''), labels => \@top_traits, values => [ map { $by_trait{$_} } @top_traits ] }) if @top_traits;
my @top_trials = grep { defined } (sort { $trials_with_issues{$b} <=> $trials_with_issues{$a} || $a cmp $b } keys %trials_with_issues)[0 .. 14];
$out->add_chart({ title => 'Issues by trial' . (keys(%trials_with_issues) > 15 ? ' (top 15)' : ''), labels => \@top_trials, values => [ map { $trials_with_issues{$_} } @top_trials ] }) if @top_trials;
$out->add_note("$n_unchecked values were not checked because their trait has no minimum and maximum.") if $n_unchecked;
$out->add_note('No trial matched the inputs.') if !$n_trials;
$out->add_note('No value outside the trait limits was found.') if $n_trials && !@qc_issues;
$out->add_table({ name => 'Phenotype QC', columns => \@columns, rows => \@qc_issues });
my $files = $out->write();

print STDERR "Files written: @$files\n";

$dbh->disconnect();
exit(0);
