 #!/usr/bin/perl

# basic script to load snp genotypes

# usage: load_snps.pl -H hostname D dbname  -i infile

# In General row headings are the accession name (or synonym) , which needs to be looked up in the stock table, and column headings are marker name, or alias.

# copy and edit this file as necessary
# common changes include the following:


=head1

 NAME

load_snps.pl - a script to load snp genotypes into the SGN database (see sgn.snp table) .

=head1 DESCRIPTION

usage: load_snps.pl

Options:

=over 5

=item -H

The hostname of the server hosting the database.

=item -D

the name of the database

=item -t

(optional) test mode. Rollback after the script terminates. Database should not be affected. Good for test runs.


=item -i

infile with the marker info

=item -o

outfile for catching errors and other messages

=back

The tab-delimited snp genotype file must have stocks and markers which already exist in the database.
Non-existing stocks or markers will be skipped.


=head1 AUTHORS

Naama Menda <nm249@cornell.edu>


=cut

use strict;
use warnings;

use CXGN::Tools::File::Spreadsheet;
use CXGN::Tools::Text;
use File::Slurp;
use Bio::Chado::Schema;

use CXGN::Marker;
use CXGN::Marker::Tools;
use CXGN::DB::Connection;
use CXGN::DB::InsertDBH;

use Data::Dumper;
use CXGN::DB::SQLWrappers;

use Getopt::Std;


our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_o);

getopts('H:D:ti:o:');



my $dbh = CXGN::DB::InsertDBH->new({
    dbname => $opt_D,
    dbhost => $opt_H,
    dbargs => {AutoCommit => 0,
               RaiseError => 1}
                                   });
my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } , );
              #                           { on_connect_do => ['SET search_path TO public'], }, );

my $sql=CXGN::DB::SQLWrappers->new($dbh);

eval {

    # make an object to give us the values from the spreadsheet
    my $ss = CXGN::Tools::File::Spreadsheet->new($opt_i);
    my @stocks = $ss->row_labels(); # row labels are the marker names
    my @markers = $ss->column_labels(); # column labels are the headings for the data columns

    for my $stock_name (@stocks) {
        print "stockname = $stock_name\n";
        my $stock_id = $schema->resultset("Cv::Cvterm")->search( {
            name => 'solcap number' } )->
                search_related('stockprops' , { value => $stock_name } )->
                first->stock_id or die("No stock found for solcap number $stock_name! \n\n");
        message( "*************Stock name = $stock_name, id = $stock_id\n" );
        for my $marker_name (@markers) {
            print "marker: $marker_name\n";
            my @marker_ids =  CXGN::Marker::Tools::marker_name_to_ids($dbh,$marker_name);
            if (@marker_ids>1) { die "Too many IDs found for marker '$marker_name'" }
            # just get the first ID in the list (if the list is longer than 1, we've already died)
            my $marker_id = $marker_ids[0];

            if(!$marker_id) {
                message("Marker $marker_name does not exist! Skipping!!\n");
                next;
            }
            else {  message( "Marker name : $marker_name, marker_id found: $marker_id\n" ) ; }

            my $genotype=$ss->value_at($stock_name,$marker_name)
                or message("No genotype found for stock $stock_name and marker $marker_name!");
            print "genotype: $genotype\n";
            if ($genotype !~ /[a-zA-Z]/ ) {
                message("non-snp genotype ($genotype) . Skipping!!");
                next;
            }
            my $snp_genotype =$sql->insert_unless_exists('snp',{marker_id=>$marker_id, snp_nucleotide => $genotype, stock_id=> $stock_id } );
        }
    }
};

if ($@) {
    print $@;
    print "Failed; rolling back.\n";
    $dbh->rollback();
}
else {
    print"Succeeded.\n";
    if ($opt_t) {
        print"Rolling back.\n";
        $dbh->rollback();
    }
    else  {
        print"Committing.\n";
        $dbh->commit();
    }
}

sub message {
    my $message = shift;
    print $message;
    write_file( $opt_o,  {append => 1 }, $message . "\n" )  if $opt_o;
}
