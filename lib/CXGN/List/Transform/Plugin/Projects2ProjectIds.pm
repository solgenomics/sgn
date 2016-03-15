
package CXGN::List::Transform::Plugin::Projects2ProjectIds;

use Moose;
use Data::Dumper;

sub name { 
    return "projects_2_project_ids";
}

sub display_name { 
    return "Projects to project IDs";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2= shift;

    if ((($type1 eq "projects") and ($type2 eq "project_ids"))
	or
	(($type1 eq "trials")  and ($type2 eq "trial_ids"))) { 

	print STDERR "Projects2ProjectIds: can transform $type1 to $type2\n";
	return 1;

    }
    return 0;
}

sub transform { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();
    my @missing = ();

    foreach my $l (@$list) { 
	print STDERR "project_name = $l \n";
	my $rs = $schema->resultset("Project::Project")->search(
	    {
		name => $l,
	    });
	if ($rs->count() == 0) { 
	    push @missing, $l;
	}
	else { 
	    push @transform, $rs->first()->project_id();
	}
	    

    }
    print STDERR " transform array = " . Dumper(@transform);
    print STDERR " missing array = " . Dumper(@missing);
    return { transform => \@transform,
	     missing   => \@missing,
    };
}

1;
