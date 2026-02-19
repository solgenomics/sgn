#!/usr/bin/env perl

=head1

phenotype_properties_check.pl

=head1 SYNOPSIS

    \$phenotype_properties_check.pl -U [dbuser] -P [dbpass] -H [dbhost] -D [dbname]

=head1 COMMAND-LINE OPTIONS
 -U  db username (postgres)
 -P  db password
 -H  host name
 -D  database name
 -o  output directory
 -f  output filename
 -s  start date (YYYY-MM-DD)
 -e  end date (YYYY-MM-DD)

=head2 DESCRIPTION

Prints phenotype QC issues as JSON.

=head2 AUTHOR

chris simoes (ccs263@cornell.edu)

March 2025

=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;
use JSON;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Excel::Writer::XLSX;

our %opt;
getopts('H:D:U:P:o:f:s:e:', \%opt);

my $dbhost = $opt{H} // 'localhost';
my $dbname = $opt{D} // 'breedbase';
my $dbuser = $opt{U} // 'postgres';
my $dbpass = $opt{P} // '';
my $out_directory = $opt{o} // '';
my $filename = $opt{f} // '';
my $start_date = $opt{s} // '';
my $end_date  = $opt{e} // '';

warn "Parsed start_date: [$start_date]";
warn "Parsed end_date:   [$end_date]";

print STDERR "Connecting to database $dbname on $dbhost as $dbuser...\n";

my $dbh = DBI->connect(
    "dbi:Pg:dbname=$dbname;host=$dbhost",
    $dbuser,
    $dbpass,
    { AutoCommit => 0, RaiseError => 1 }
);

my $schema = Bio::Chado::Schema->connect(sub { $dbh });

my $rs = $schema->resultset("Project::Project")->search(
    {
        create_date => {
            -between => [ "$start_date 00:00:00", "$end_date 23:59:59" ]
        }
    },
    {
        select => ['project_id', 'create_date'],
        as     => ['project_id', 'create_date']
    }
);

my @trial_ids;
my %trial_create_dates;

while (my $row = $rs->next) {
    my $trial_id    = $row->get_column('project_id');
    my $create_date = $row->get_column('create_date');
    $create_date =~ s/\s.*$// if $create_date;

    push @trial_ids, $trial_id;
    $trial_create_dates{$trial_id} = $create_date;
}

my (%trial_data, %trial_cols);
foreach my $trial_id (@trial_ids) {
    my $t;
    eval { $t = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id }); };
    next if $@ || !defined $t;

    my $trial_name            = $t->get_name;
    my $location_name         = $t->get_location ? $t->get_location()->[1] : "Unknown";
    my $breeding_program_name = $t->get_breeding_program();
    my $year                  = $t->get_year();
    my $test_type             = $t->get_design_type();

    next unless defined $year;
    next if !defined($test_type) || $test_type eq "Analise";

    $trial_cols{$trial_id} = [ $year, $breeding_program_name, $trial_name, $location_name ];

    my $traits = $t->get_traits_assayed();
    my @trait_names = map { $_->[0] } @$traits;

    print("Running project $trial_name \n");

    my $sth = $dbh->prepare(qq{
        SELECT
            acc.uniquename AS accession_name,
            plot.uniquename AS plot_name,
            trait.name AS trait_name,
            ph.value AS observed_value
        FROM nd_experiment e
        JOIN nd_experiment_project ep ON (e.nd_experiment_id = ep.nd_experiment_id)
        JOIN nd_experiment_phenotype nep ON (nep.nd_experiment_id = ep.nd_experiment_id)
        JOIN phenotype ph ON (nep.phenotype_id = ph.phenotype_id)
        JOIN cvterm trait ON (ph.cvalue_id = trait.cvterm_id)
        JOIN nd_experiment_stock nes ON (e.nd_experiment_id = nes.nd_experiment_id)
        JOIN stock plot ON (nes.stock_id = plot.stock_id)
        LEFT JOIN stock_relationship rel ON (plot.stock_id = rel.object_id)
        LEFT JOIN stock acc ON (rel.subject_id = acc.stock_id)
        WHERE ep.project_id = ?
    });
    $sth->execute($trial_id);

    my @data;
    while (my ($accession, $plot, $trait, $value) = $sth->fetchrow_array) {
        $accession //= 'Unknown';
        push @data, [ $accession, $plot, $trait, $value ];
    }

    $trial_data{$trial_id} = \@data;
}


my $minimum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name => 'trait_minimum' })->cvterm_id;
my $maximum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name => 'trait_maximum' })->cvterm_id;

my @trial_ids = keys %trial_data;
my $total = scalar(@trial_ids);
my $counter = 0;

my @qc_issues;
foreach my $trial_id (@trial_ids) {

    $counter++;
    print("Getting data from trial_id=$trial_id  counter: $counter/$total\n");

    my ($year, $breeding_program_name, $trial_name, $location_name) = @{$trial_cols{$trial_id}};
    my $create_date = $trial_create_dates{$trial_id} || 'NULL';

    foreach my $row (@{$trial_data{$trial_id}}) {
        my ($accession, $plot, $trait_name, $observed_value) = @$row;

        my $trait_cvterm = $schema->resultset("Cv::Cvterm")->find({ name => $trait_name });
        next unless $trait_cvterm;
        my $trait_id = $trait_cvterm->cvterm_id;

        my $min_value_rs = $schema->resultset("Cv::Cvtermprop")->search({
            'cvterm_id' => $trait_id,
            'type_id'   => $minimum_cvterm_id
        });
        my $min_value = $min_value_rs->first ? $min_value_rs->first->value : undef;

        my $max_value_rs = $schema->resultset("Cv::Cvtermprop")->search({
            'cvterm_id' => $trait_id,
            'type_id'   => $maximum_cvterm_id
        });
        my $max_value = $max_value_rs->first ? $max_value_rs->first->value : undef;

        next unless defined $min_value && defined $max_value;
        next if $min_value eq $max_value;

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

        if ($qc_type) {
            push @qc_issues, {
                year                  => $year,
                breeding_program_name => $breeding_program_name,
                trial_name            => $trial_name,
                trial_location        => $location_name,
                create_date           => $create_date,
                accession             => $accession,
                plot                  => $plot,
                trait_name            => $trait_name,
                observed              => $observed_value,
                minimum               => $min_value,
                maximum               => $max_value,
                type                  => $qc_type
            };
        }
    }
}

# Create an Excel workbook
my $excel_file_path = $out_directory . $filename . '.xlsx';

my $workbook  = Excel::Writer::XLSX->new($excel_file_path)
    or die "Could not create Excel file $excel_file_path: $!";

my $worksheet = $workbook->add_worksheet('Phenotype QC');

# Write header row
my @columns = qw(
    year
    breeding_program_name
    trial_name
    trial_location
    create_date
    accession
    plot
    trait_name
    observed
    minimum
    maximum
    type
);
my $col_index = 0;
for my $col_name (@columns) {
    $worksheet->write(0, $col_index++, $col_name);
}

# Write data rows
my $row_index = 1;
for my $record (@qc_issues) {
    $col_index = 0;
    for my $col_name (@columns) {
        $worksheet->write($row_index, $col_index++, $record->{$col_name});
    }
    $row_index++;
}

print "Excel file saved in $excel_file_path\n\n";

$dbh->disconnect();
exit(0);