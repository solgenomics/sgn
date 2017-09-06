#!/usr/bin/perl

=head1

create_trial_labels_30perpage.pl - create a variable number of plot labels in 3x10 label format for a given trial

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
use Try::Tiny;
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
my $trial_id = $trial_rs->first->project_id();
print STDERR "Trial id is $trial_id\n";

my ($trial_layout, %errors, @error_messages);
try {
    $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
};
if (!$trial_layout) {
    print STDERR "Trial does not have a valid field design. Can't create labels.\n";
}

my $zpl_file = "label_zpl.tmp";
open(my $F, ">", $zpl_file) || die "Can't open temp zpl file ".$zpl_file;

# Zebra design params
my $starting_x = 20;
my $x_increment = 600;
my $starting_y = 80;
my $y_increment = 212;
my $number_of_columns = 2; #zero index
my $number_of_rows = 9; #zero index
my $labels_per_plot = $opt_n || 3;

#fixed data
my $trial_name =  $trial_layout->get_trial_name();
# print STDERR "Trial name is $trial_name\n";
my $year_cvterm_id = $schema->resultset("Cv::Cvterm")->search({name=> 'project year' })->first->cvterm_id();
my $year = $trial_rs->search_related('projectprops', { type_id => $year_cvterm_id } )->first->value();
# print STDERR "Year is $year\n";
my %design = %{$trial_layout->get_design()};

#loop through plot data, creating and saving zpl to file
my $col_num = 0;
my $row_num = 0;
print $F "^XA\n";
foreach my $key (sort { $a <=> $b} keys %design) {
    my %design_info = %{$design{$key}};
    
    my $plot_name = $design_info{'plot_name'};
    my $plot_number = $design_info{'plot_number'};
    my $rep_number = $design_info{'rep_number'};
    my $accession_name = $design_info{'accession_name'};
    
    for (my $i=0; $i < $labels_per_plot; $i++) {
        # print STDERR "Working on label num $i\n";     
        my $x = $starting_x + ($col_num * $x_increment);
        my $y = $starting_y + ($row_num * $y_increment);
        
        my $label_zpl = "^LH$x,$y
        ^FO10,10^AB,33^FD$accession_name^FS
        ^FO10,60^BQ,,4^FD   $plot_name^FS
        ^FO200,70^AD^FDPlot: $plot_number^AF4^FS
        ^FO200,100^AD^FDRep: $rep_number^AF1^FS
        ^FO200, 140^AD^FD$trial_name^FS
        ^FO200,160^AD^FD$year^FS
        ^FO400,60^BQ,,4^FD   $plot_name^FS";
        # print STDERR "ZPL is $label_zpl\n";
        print $F $label_zpl;
        
        if ($col_num < $number_of_columns) { #next column
            $col_num++;
        } else { #new row, reset col num
            $col_num = 0;
            $row_num++;
        }
        
        if ($row_num > $number_of_rows) { #new oage, reset row and col num
            print $F "\n^XZ\n^XA";
            $col_num = 0;
            $row_num = 0;
        }
    }
}
print $F "\n^XZ"; # end file
close($F);

#convert zpl to pdf
`curl --request POST http://api.labelary.com/v1/printers/8dpmm/labels/8.5x11/ --form file=\@$zpl_file --header "Accept: application/pdf" > $opt_O`;

print STDERR "Label file $opt_O for trial $opt_T created!\n";
