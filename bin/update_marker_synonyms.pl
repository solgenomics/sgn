 #!/usr/bin/perl

=head1

 NAME

load_solcap_markers.pl

=head1 DESCRIPTION

basic script to add marker synonyms (aliased)
usage: update_marker_synonyms.pl -H hostname D dbname  -i infile


Options:

=over 5

=item -H

The hostname of the server hosting the database.

=item -D

the name of the database

=item -t

(optional) test mode. Rollback after the script terminates. Database should not be affected. Good for test runs.


=item -i

infile with the marker synonyms

=item -u

update existing markers to new one.
BE CAREFUL with this option. It will DELETE existing marker id and will update it to
the new marker (as designated in the file row header. This was introduced since we loaded the Yellow Stuffer map with SNP markers, which were late used for the solcap chip, but loaded as new markers with different name. The old name will be kept as a marker alias)

=back

The tab-delimited file

Row headers should be the marker name
subsequenct columns should have as many synonyms as wanted.
Synonyms can also be "|" delimited

=head1 AUTHORS

Naama Menda <nm249@cornell.edu>


=cut

use strict;
use warnings;
use Carp;

use CXGN::Tools::File::Spreadsheet;
use CXGN::Tools::Text;
use CXGN::Marker;
use CXGN::Marker::Modifiable;
use CXGN::Marker::Tools;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use CXGN::DB::SQLWrappers;

use Getopt::Std;


our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_u);

getopts('H:D:tui:');

my $dbh = CXGN::DB::InsertDBH->new({
    dbname => $opt_D,
    dbhost => $opt_H,
    dbargs => {AutoCommit => 0,
               RaiseError => 1}
                                   });
$dbh->do("SET search_path TO  sgn");

my $sql=CXGN::DB::SQLWrappers->new($dbh);

eval {
    # make an object to give us the values from the spreadsheet
    my $ss = CXGN::Tools::File::Spreadsheet->new($opt_i);
    my @markers = $ss->row_labels(); # row labels are the marker names
    my @columns = $ss->column_labels(); # column labels are the headings for the data columns

    # make sure the spreadsheet is how we expect it to be
    for my $marker_name (@markers) {

	print STDERR "\n\nMARKER: $marker_name\n";

        my @marker_ids =  CXGN::Marker::Tools::marker_name_to_ids($dbh,$marker_name);
        if (@marker_ids>1) { die "Too many IDs found for marker '$marker_name'" }
	# just get the first ID in the list (if the list is longer than 1, we've already died)
        my $marker_id = $marker_ids[0];

	if(!$marker_id) {
	    print STDERR "Marker $marker_name does not exist in database. SKIPPING!\n";
	    next();
        }
	else {  print STDERR  "marker_id found: $marker_id\n" }
        my @non_unique_aliases;
        foreach my $column (@columns) {
            my $alias_names = $ss->value_at($marker_name, $column);
            push (@non_unique_aliases , (split('\|', $alias_names)) ) unless $alias_names eq '0';
	}
        my %seen =() ;
        my @aliases = grep { ! $seen{$_}++ } @non_unique_aliases ;

        #see if all our aliases exist. if not, enter them.
        SYNONYM: for my $alias(@aliases) {
            my $q = $dbh->prepare('select marker_id from marker_alias where alias ilike ?');
            $q->execute($alias);
            if(my($id)=$q->fetchrow_array()) {
                unless($id==$marker_id) {
                    if ($opt_u) { #update marker $id to $marker_id
                        #check if the marker is a SNP marker
                        my $protocol_q = $dbh->prepare("SELECT distinct protocol FROM sgn.marker_experiment WHERE marker_id = ?" ) ;
                        $protocol_q->execute($id);
                        my ($protocol) = $protocol_q->fetchrow_array;
                        if ($protocol eq 'SNP') {
                            print STDERR "UPDATING marker_id $id to new marker $marker_id!\n";
                            $dbh->do("update marker_experiment set marker_id = $marker_id where marker_id = $id");
                            $dbh->do("update pcr_experiment set marker_id = $marker_id where marker_id = $id");
                            $dbh->do("update snp set marker_id = $marker_id where marker_id = $id");
                            $dbh->do("delete from marker_alias where marker_id = $id");
                            $dbh->do("delete from marker where marker_id = $id");
                        } else { print STDERR "PROTOCOL for marker $id is $protocol! Not updating to marker_id $marker_id!!\n"; }
                    } else {
                        warn "Alias '$alias' found, but associated with marker ID '$id' instead of our ID ($marker_id). SKIPPING\n\n";
                        next SYNONYM;
                    }
                }
            }
            else {
                my $alias_id=$sql->insert("marker_alias",{alias=>$alias,marker_id=>$marker_id,preferred=>'f'});
                print STDERR "INSERTING other alias '$alias'.\n";
            }
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
