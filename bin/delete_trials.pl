
=head1 NAME

delete_trials.pl - script to delete trials

=head1 DESCRIPTION

perl delete_trials.pl -i trial_id -H host -D dbname -U dbuser -P dbpass -b basepath

Deletes trials that whose ids are provided as a comma separated list for the -i parameter.
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

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_b, $opt_i, $opt_n, $opt_t);

getopts('H:D:U:P:b:i:t:n');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $trial_ids = $opt_i;
my $trial_names = $opt_t;
my $non_interactive = $opt_n;

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

foreach my $name (@trial_names) { 
    my $trial = $schema->resultset("Project::Project")->find( { name => $name });
    if (!$trial) { print STDERR "Trial $name not found. Skipping...\n"; next; }
    push @trial_ids, $trial->project_id();
}

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
	eval { 
	    delete_trial($metadata_schema, $phenome_schema, $t);
	};
	if ($@) { 
	    print STDERR "An error occurred trying to delete trial ".$t->get_name()." ($@)\n";
	    $dbh->rollback();
	}
	else { 
	    $dbh->commit();
	    print STDERR "Trial ".$t->get_name()." successfully deleted\n";
	}

    }

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
    print STDERR "Deleting phenotypes...\n";
    $t->delete_phenotype_data($opt_b, $dbhost, $dbname, $dbuser, $dbpass);
    print STDERR "Deleting layout...\n";
    $t->delete_field_layout();
    print STDERR "Delete project entry...\n";
    $t->delete_project_entry();
}
    
