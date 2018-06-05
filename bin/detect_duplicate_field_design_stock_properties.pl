#!/usr/bin/perl

=head1

detect_duplicate_field_design_stock_properties.pl - backend script for detecting and solving issue of plots with multiple plot_numbers

=head1 SYNOPSIS

    detect_duplicate_field_design_stock_properties.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -t [test]
=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -P database userpass (required)
 -t only show duplicates

=head1 DESCRIPTION

perl bin/detect_duplicate_field_design_stock_properties.pl -D cass -H localhost -U postgres -P postgres 

This script will detect and correct (if t is passed) the issue of plots having multiple plot_numbers associated.

=head1 AUTHOR

 Nicolas Morales (nm529@cornell.edu)

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use DateTime;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_t);

getopts('H:D:U:P:t:');

if (!$opt_H || !$opt_D || !$opt_U ||!$opt_P ) {
    die "Must provide options -H (hostname), -D (database name), -U (database user), -P (database password)\n";
}

my $schema = Bio::Chado::Schema->connect(
    "dbi:Pg:database=$opt_D;host=$opt_H", # DSN Line
    $opt_U,                    # Username
    $opt_P           # Password
);

my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
my $block_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
my $is_a_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
my $plant_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
my $subplot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_index_number', 'stock_property')->cvterm_id();
my $tissue_sample_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_index_number', 'stock_property')->cvterm_id();
my $replicate_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
my $range_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'range', 'stock_property')->cvterm_id();
my @type_ids_of_interest = ($plot_number_type_id, $block_type_id, $row_number_type_id, $col_number_type_id, $is_a_control_type_id, $plant_number_type_id, $subplot_number_type_id, $tissue_sample_number_type_id, $replicate_type_id, $range_type_id);

my $stockprops = $schema->resultset("Stock::Stockprop")->search(
    {'me.type_id' => {-in => \@type_ids_of_interest}},
    {
        'join' => ['type', {'stock' => {'nd_experiment_stocks'=>{'nd_experiment'=>{'nd_experiment_projects'=>'project'}}}}],
        '+select' => ['type.name', 'stock.uniquename', 'project.name'],
        '+as' => ['type', 'stock', 'project'],
        distinct => 1,
        order_by => 'me.stockprop_id'
    }
);
my %results;
while (my $r = $stockprops->next){
    push @{$results{$r->get_column('project')}->{$r->get_column('stock')}->{$r->get_column('type')}}, [$r->value, $r->stockprop_id];
}

my @all_but_last_values;
while (my ($p, $x) = each %results){
    while (my ($k, $v) = each %$x){
        while (my ($t, $z) = each %$v){
            if (scalar(@$z) > 1){
                my @z = @$z;
                my @values = map $_->[0], @z;
                my $values = join ',', @values;
                print STDERR "More than one for project $p for stock $k for type $t with $values\n";
                my @old_values = @z[0..$#z-1];
                my @old_Vals = map $_->[1], @old_values;
                push @all_but_last_values, @old_Vals;
            }
        }
    }
}

#print STDERR Dumper \@all_but_last_values;
if (!$opt_t){
    my $stockprops = $schema->resultset("Stock::Stockprop")->search({'me.stockprop_id' => {-in => \@all_but_last_values}});
    while (my $r = $stockprops->next){
        $r->delete();
    }
}

print STDERR "Script Complete.\n";
