
=head1 NAME

delete_trials.pl - script to delete trials

=head1 DESCRIPTION

perl delete_trials.pl -i trial_ids [ -t trial_names ] [ -F file_with_trial_names ] [ -f file_with_trial_ids ] -H host -D dbname -U dbuser -P dbpass -b basepath -r temp_file_nd_experiment_id [ -n ]

Options:

=over 5 

=item -H

hostname for database 

=item -D

database name

=item -i

comma separated list of trial ids

=item -t

comma separated list of trial names

=item -b

basebath is the install path of the software, most commonly /home/production/cxgn/sgn which is the default. 

=item -r

Specifies the temp file used to track nd_experiment_ids to delete. Defaults to /tmp/temp_nd_experiment_id_[date_and_time].

=item -F

a file with trial names, one per line

=item -f

file with trial ids, one per line

=item -n

non-interactive mode. Will not prompt for confirmation of each trial to delete

=back

First, it deletes metadata, then trial layouts, then phenotypes, and finally the trial entry in the project table. All deletes are hard deletes. There is no way of bringing the trial back, except from a backup. So be careful!

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_b, $opt_i, $opt_t, $opt_n, $opt_r, $opt_F, $opt_f);

getopts('H:D:U:P:b:i:t:r:nf:F:');

my $dt = DateTime->now();
my $date_string = $dt->ymd()."T".$dt->hms();
my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $trial_ids = $opt_i;
my $trial_names = $opt_t;
my $trial_names_file = $opt_F;
my $trial_ids_file = $opt_f;
my $non_interactive = $opt_n;
my $basepath = $opt_b || '/home/production/cxgn/sgn';
my $tempfile = $opt_r || "/tmp/temp_nd_experiment_id_$date_string";

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
				      RaiseError => 1}
				    }
    );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });

my @trial_ids = split ",", $trial_ids;
my @trial_names = split ",", $trial_names;

if ($trial_names_file) {
    open(my $F, "<", $trial_names_file) || die "Can't open the file $trial_names_file";
    while (<$F>) {
	chomp;
	push @trial_names, $_;
    }
    close($F);
}

if ($trial_ids_file) {
    open(my $F, "<", $trial_ids_file) || die "Can't open the file $trial_ids_file";
    while(<$F>) {
	chomp;
	push @trial_ids, $_;
    }
    close($F);
}
	
foreach my $name (@trial_names) { 
    my $trial = $schema->resultset("Project::Project")->find( { name => $name });
    if (!$trial) { print STDERR "Trial $name not found. Skipping...\n"; next; }
    push @trial_ids, $trial->project_id();
}

eval {
    $dbh->do("set search_path to public,sgn,phenome,sgn_people,metadata");
    my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() });

    my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
    my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });
    
    foreach my $trial_id (@trial_ids) { 
	print STDERR "Retrieving trial information for trial $trial_id...\n";
	
	my $t = CXGN::Trial->new({
	    bcs_schema => $schema,
	    metadata_schema => $metadata_schema,
	    phenome_schema => $phenome_schema,
	    trial_id => $trial_id
				 });
	
	my $answer = "";
	if (!$non_interactive) { 
	    print $t->get_name().", ".$t->get_description().". Delete? ";
	    $answer = <>;
	}
	if ($non_interactive || $answer =~ m/^y/i) { 
	    
	    delete_trial($metadata_schema, $phenome_schema, $t);
	    
	}
    }
};

if ($@) { 
    print STDERR "ERROR: $@\n";
    $dbh->rollback();
}
else { 
    $dbh->commit();
    print STDERR "Trials successfully deleted\n";
}




$dbh->disconnect();
print STDERR "Done with everything (though nd_experiment entry deletion may still be occuring asynchronously).\n";

sub delete_trial { 
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $t = shift;

    print STDERR "Deleting trial ".$t->get_name()."\n";
    print STDERR "Delete metadata...\n";
    $t->delete_metadata();
    print STDERR "Deleting phenotypes... (using $dbhost, $dbuser, $dbname)\n";
    $t->delete_phenotype_data($opt_b, $dbhost, $dbname, $dbuser, $dbpass, $opt_r);
    print STDERR "Deleting layout...\n";
    $t->delete_field_layout();
    print STDERR "Delete project entry...\n";
    $t->delete_project_entry();
}
    
