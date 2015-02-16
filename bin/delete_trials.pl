
=head1 NAME

delete_trials.pl - script to delete trials

=head1 DESCRIPTION

perl delete_trials.pl -i trial_id -H host -D dbname 

It currently only deletes one trial at a time, with the -i trial_id provided.
First, it deletes metadata, then trial layouts, then phenotypes, and finally the trial entry in the project table. All deletes are hard deletes. There is no way of bringing the trial back, except from a backup. So be careful!

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial;

our ($opt_H, $opt_D, $opt_i, $opt_n);

getopts('H:i:D:n');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $trial_id = $opt_i;
my $non_interactive = $opt_n;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
				      RaiseError => 1}
				    }
    );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });
print STDERR "Retrieving trial information...\n";
my $t = CXGN::Trial->new( { bcs_schema => $schema , trial_id => $trial_id } );

my $answer = "";
if (!$non_interactive) { 
    print $t->get_name().", ".$t->get_description().". Delete? ";
    $answer = <>;
}
if ($non_interactive || $answer =~ m/^y/i) { 
    print STDERR "Delete metadata...\n";
    $t->delete_metadata($metadata_schema, $phenome_schema);
    print STDERR "Deleting phenotypes...\n";
    $t->delete_phenotype_data();
    print STDERR "Deleting layout...\n";
    $t->delete_field_layout();
    print STDERR "Delete project entry...\n";
    $t->delete_project_entry();
}

print STDERR "Done.\n";
