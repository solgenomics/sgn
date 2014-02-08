
package SGN::Controller::VigsTool;

use Moose;
use File::Basename;

BEGIN { extends 'Catalyst::Controller'; }

# this function read the database files (Bowtie2) and
# send the list of databases to the view input.mas
sub input :Path('/tools/vigs/')  :Args(0) { 
	my ($self, $c) = @_;

	# get databases path from the configuration file
	my $db_path = $c->config->{vigs_db_path};
	
	# get database names from the files in the path
	my @databases;
	my @tpm_dbs = glob("$db_path/*.rev.1.bt2");
	foreach my $full_name (@tpm_dbs) {
		push(@databases, basename($full_name, ".rev.1.bt2"));
	}
	# print STDERR "DATABASE ID: ".join(", ", @databases)."\n";
	
	# send the database names to the view file input.mas
	$c->stash->{template} = '/tools/vigs/input.mas';
	$c->stash->{databases} = \@databases;    
}


1;
