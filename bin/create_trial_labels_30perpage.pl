#!/usr/bin/perl

=head1

create_trial_labels_30perpage.pl - create a variable number of plot labels for a given trial

=head1 SYNOPSIS

    create_trial_labels_30perpage.pl -H localhost -D cxgn -T trial_name -O outfile -n number per plot (defaults to 3)

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H localhost
  -D database
  -T trial name
  -O outfile name
  -n number of identical labels to print per plot
=head1 DESCRIPTION

=head1 AUTHOR

Bryan Ellerbrock bje24@cornell.edu

=cut

use Getopt::Std;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use Data::Dumper;
use CXGN::Trial::TrialLayout;

our ($opt_H, $opt_D, $opt_T, $opt_O, $opt_n);

getopts('H:D:T:O:n:');

if (!$opt_H || !$opt_D || !$opt_T || !$opt_O) {
    pod2usage(-verbose => 2, -message => "Must provide options -H, -D, -T, and -O \n");
}

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    } );

my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

my $trial_rs = $schema->resultset("Project::Project")->search({name=> $opt_T });
my $trial_id = $trial_rs->project_id();
my $year_cvterm = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' });
my $year = $trial_rs->search_related('projectprops', { type_id => $year_cvterm } )->first->value();
my ($trial_layout, %errors, @error_messages);
try {
    $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
};
if (!$trial_layout) {
    push @error_messages, "Trial does not have valid field design.";
    $errors{'error_messages'} = \@error_messages;
    return \%errors;
}

open(my $F, ">", $opt_O) || die "Can't open file ".$opt_O;
#print $F

# Zebra design params
my $starting_x = 20;
my $x_increment = 600;
my $starting_y = 80;
my $y_increment = 220;
my $page_break_after = 2060;
# ^XA
# ^FO10,10^AB,33^FD05-0198_G2^FS
# ^FO10,60^BQ,,4^FD   4*05-0198_G2*KELYT*2017*1^FS
# ^FO200,70^AD^FDPlot: 1^AF4^FS
# ^FO200,100^AD^FDRep: 1^AF1^FS
# ^FO200, 140^AD^FDKIN-ELYT^FS
# ^FO200,160^AD^FD2017^FS
# ^FO400,60^BQ,,4^FD   4*05-0198_G2*KELYT*2017*1^FS
# ^XZ


my $trial_name =  $trial_layout->get_trial_name();
my %design = %{$trial_layout->get_design()};
my $row_num = 1;
foreach my $key (sort { $a <=> $b} keys %design) {
    my %design_info = %{$design{$key}};
    $design_info{'plot_name'});
    #$design_info{'block_number'});
    $design_info{'plot_number'});
    $design_info{'rep_number'});
    $design_info{'accession_name'});
    $design_info{'is_a_control'});
    $row_num++;
} 
close($F);
