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

my $schema           = Bio::Chado::Schema->connect(sub { $dbh });
my $metadata_schema  = CXGN::Metadata::Schema->connect(sub { $dbh });
my $phenome_schema   = CXGN::Phenome::Schema->connect(sub { $dbh });

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
    next if $test_type eq "Analise";

    $trial_cols{$trial_id} = [ $year, $breeding_program_name, $trial_name, $location_name ];

    my $traits = $t->get_traits_assayed();
    my @trait_names = map { $_->[0] } @$traits;

    my $data = $t->get_stock_phenotypes_for_traits(
        \@trait_names, 'all', ['plot_of', 'plant_of'], 'accession', 'subject'
    );

    $trial_data{$trial_id} = $data;
}

my (%obs, %traits);
foreach my $trial_id (keys %trial_data) {
    foreach my $line (@{$trial_data{$trial_id}}) {
        $obs{$trial_id}->{$line->[9]}->{$line->[1]}->{$line->[3]} = $line->[7];
        $traits{$line->[3]}++;
    }
}

my $minimum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name => 'trait_minimum' })->cvterm_id;
my $maximum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name => 'trait_maximum' })->cvterm_id;

my @qc_issues;
foreach my $trial_id (keys %obs) {
    my ($year, $breeding_program_name, $trial_name, $location_name) = @{$trial_cols{$trial_id}};
    my $create_date = $trial_create_dates{$trial_id} || 'NULL';

    foreach my $accession (keys %{$obs{$trial_id}}) {
        foreach my $plot (keys %{$obs{$trial_id}->{$accession}}) {
            foreach my $trait_original (keys %{$obs{$trial_id}->{$accession}->{$plot}}) {
                my $trait_name = $trait_original;
                $trait_name =~ s/\|.*//;

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

                my $observed_value = $obs{$trial_id}->{$accession}->{$plot}->{$trait_original};
                my $qc_type;

                if (defined $observed_value && $observed_value < $min_value) {
                    $qc_type = "below minimum";
                }
                elsif (defined $observed_value && $observed_value > $max_value) {
                    $qc_type = "above maximum";
                }

                if ($qc_type) {
                    push @qc_issues, {
                        year                   => $year,
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
    }
}

my $json = encode_json(\@qc_issues), "\n";
print $json;

my $json_file_path = $out_directory . $filename;
print("File saved in $json_file_path \n\n");

open(my $fh, '>', $json_file_path) or die "Could not write to $json_file_path: $!";
print $fh $json;
close($fh);

$dbh->disconnect();