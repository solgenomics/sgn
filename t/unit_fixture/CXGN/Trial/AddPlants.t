
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;

my $f = SGN::Test::Fixture->new();

my $trial_id = 137;

my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id });

my $d = $tl->get_design();
#print STDERR Dumper($d);

my @plot_nums;
my @accessions;
my @plant_names;
my @rep_nums;
my @plot_names;
foreach my $plot_num (keys %$d) {
    push @plot_nums, $plot_num;
    push @accessions, $d->{$plot_num}->{'accession_name'};
    push @plant_names, $d->{$plot_num}->{'plant_names'};
    push @rep_nums, $d->{$plot_num}->{'rep_number'};
    push @plot_names, $d->{$plot_num}->{'plot_name'};
}
@plot_nums = sort @plot_nums;
@accessions = sort @accessions;
@plant_names = sort @plant_names;
@rep_nums = sort @rep_nums;
@plot_names = sort @plot_names;

#print STDERR Dumper \@plot_nums;
#print STDERR Dumper \@accessions;
#print STDERR Dumper \@plant_names;
#print STDERR Dumper \@rep_nums;
#print STDERR Dumper \@plot_names;

is_deeply(\@plot_nums, [
          '1',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9'
        ], 'check design plot_nums');

is_deeply(\@accessions, [
          'test_accession1',
          'test_accession1',
          'test_accession1',
          'test_accession2',
          'test_accession2',
          'test_accession2',
          'test_accession3',
          'test_accession3',
          'test_accession3',
          'test_accession4',
          'test_accession4',
          'test_accession4',
          'test_accession5',
          'test_accession5',
          'test_accession5'
        ], 'check design accessions');

is_deeply(\@plant_names, [
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          [],
          []
        ], "check design plant_names");

is_deeply(\@rep_nums, [
          '1',
          '1',
          '1',
          '1',
          '1',
          '2',
          '2',
          '2',
          '2',
          '2',
          '3',
          '3',
          '3',
          '3',
          '3'
        ], "check design rep_nums");

is_deeply(\@plot_names, [
          'test_trial21',
          'test_trial210',
          'test_trial211',
          'test_trial212',
          'test_trial213',
          'test_trial214',
          'test_trial215',
          'test_trial22',
          'test_trial23',
          'test_trial24',
          'test_trial25',
          'test_trial26',
          'test_trial27',
          'test_trial28',
          'test_trial29'
        ], "check design plot_names");


my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
$trial->create_plant_entities('2');

my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id });
$d = $tl->get_design();
#print STDERR Dumper($d);

@plot_nums = ();
@accessions = ();
@plant_names = ();
@rep_nums = ();
@plot_names = ();
my @plant_names_flat;
foreach my $plot_num (keys %$d) {
    push @plot_nums, $plot_num;
    push @accessions, $d->{$plot_num}->{'accession_name'};
    push @plant_names, $d->{$plot_num}->{'plant_names'};
    push @rep_nums, $d->{$plot_num}->{'rep_number'};
    push @plot_names, $d->{$plot_num}->{'plot_name'};
}
@plot_nums = sort @plot_nums;
@accessions = sort @accessions;
@rep_nums = sort @rep_nums;
@plot_names = sort @plot_names;

foreach my $plant_name_arr_ref (@plant_names) {
    foreach (@$plant_name_arr_ref) {
        push @plant_names_flat, $_;
    }
}
@plant_names_flat = sort @plant_names_flat;

#print STDERR Dumper \@plot_nums;
#print STDERR Dumper \@accessions;
#print STDERR Dumper \@plant_names_flat;
#print STDERR Dumper \@rep_nums;
#print STDERR Dumper \@plot_names;

is_deeply(\@plot_nums, [
          '1',
          '10',
          '11',
          '12',
          '13',
          '14',
          '15',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9'
        ], "check plot_nums after plant addition");

is_deeply(\@accessions, [
          'test_accession1',
          'test_accession1',
          'test_accession1',
          'test_accession2',
          'test_accession2',
          'test_accession2',
          'test_accession3',
          'test_accession3',
          'test_accession3',
          'test_accession4',
          'test_accession4',
          'test_accession4',
          'test_accession5',
          'test_accession5',
          'test_accession5'
        ], "check accessions after plant addition");

is_deeply(\@plant_names_flat, [
          'test_trial210_plant_1',
          'test_trial210_plant_2',
          'test_trial211_plant_1',
          'test_trial211_plant_2',
          'test_trial212_plant_1',
          'test_trial212_plant_2',
          'test_trial213_plant_1',
          'test_trial213_plant_2',
          'test_trial214_plant_1',
          'test_trial214_plant_2',
          'test_trial215_plant_1',
          'test_trial215_plant_2',
          'test_trial21_plant_1',
          'test_trial21_plant_2',
          'test_trial22_plant_1',
          'test_trial22_plant_2',
          'test_trial23_plant_1',
          'test_trial23_plant_2',
          'test_trial24_plant_1',
          'test_trial24_plant_2',
          'test_trial25_plant_1',
          'test_trial25_plant_2',
          'test_trial26_plant_1',
          'test_trial26_plant_2',
          'test_trial27_plant_1',
          'test_trial27_plant_2',
          'test_trial28_plant_1',
          'test_trial28_plant_2',
          'test_trial29_plant_1',
          'test_trial29_plant_2'
        ], "check plant names");

is_deeply(\@rep_nums, [
          '1',
          '1',
          '1',
          '1',
          '1',
          '2',
          '2',
          '2',
          '2',
          '2',
          '3',
          '3',
          '3',
          '3',
          '3'
        ],"check rep nums after plant addition");

is_deeply(\@plot_names, [
          'test_trial21',
          'test_trial210',
          'test_trial211',
          'test_trial212',
          'test_trial213',
          'test_trial214',
          'test_trial215',
          'test_trial22',
          'test_trial23',
          'test_trial24',
          'test_trial25',
          'test_trial26',
          'test_trial27',
          'test_trial28',
          'test_trial29'
        ],"check plot_names after plant addition");

done_testing();



