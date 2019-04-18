
=head1 NAME

CXGN::Trial - factory object for project entries (phenotyping trials, genotyping trials, crossing trials, and analyses

=head1 DESCRIPTION

my $trial = CXGN::Trial->new( { bcs_schema => $schema, ... , trial_id => $trial_id });

If $trial_id is a phenotyping trial, the type of object returned will be CXGN::PhenotypingTrial.

If $trial_id is a genotyping trial, the type of object returned will be CXGN::GenotypingTrial.

If $trial_id is a crossing trial, the type of object returned will be CXGN::CrossingTrial.

If $trial_id is an analysis, the type of object returned will be CXGN::Analysis.

(you get the idea).

Inheritance structure of Trial objects:

CXGN::Trial - Factory object (for backwards compatibility)

CXGN::Project
|
---CXGN::PhenotypingTrial
|  |
|  ---CXGN::GenotypingTrial
|  |
|  ---CXGN::CrossingTrial
|
---CXGN::Analysis

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

Based on work by the entire group :-)

=cut
    
package CXGN::Trial;

use CXGN::PhenotypingTrial;
use CXGN::GenotypingTrial;
use CXGN::CrossingTrial;

sub new {
    my $class = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $trial_id = $args->{trial_id};
    
    # check type of trial and return the correct object
    my $trial_rs = $schema->resultset("Project::Projectprop")->search( { project_id => $trial_id },{ join => 'type' });

    my $object;

    while (my $trial_row = $trial_rs->next()) { 
	print STDERR "Got a row...\n";
	print STDERR "Trial: ".$trial_row->value()."\n";
	my $name = $trial_row->type()->name();
	print STDERR "$trial_id, ".$trial_row->type()->name()."\n";

	if ($name eq "genotyping_trial") {
	    # create a genotyping trial object
	    $object = CXGN::GenotypingTrial->new({ bcs_schema=> $schema, trial_id => $trial_id });
	}
	elsif ($name eq "crossing_trial") {
	    # create a crossing trial
	    $object = CXGN::CrossingTrial->new( { bcs_schema=> $schema, trial_id => $trial_id });
	}
	# what about folders?
	else {
	    # create a phenotyping trial object
	    $object = CXGN::PhenotypingTrial->new({ bcs_schema=> $schema, trial_id => $trial_id });
	}
    }	   
    return $object;
}

1;

