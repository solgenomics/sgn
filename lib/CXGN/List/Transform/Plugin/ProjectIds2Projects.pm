
package CXGN::List::Transform::Plugin::ProjectIds2Projects;

use Moose;
use Data::Dumper;

sub name { 
    return "project_ids_2_projects";
}

sub display_name { 
    return "Projects IDs to project";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2= shift;

    if ((($type1 eq "project_ids") and ($type2 eq "projects")) or (($type1 eq "trial_ids")  and ($type2 eq "trials"))) { 
        print STDERR "ProjectIds2Projects: can transform $type1 to $type2\n";
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
        my $rs = $schema->resultset("Project::Project")->search({
            project_id => $l,
        });
        if ($rs->count() == 0) { 
            push @missing, $l;
        }
        else { 
            push @transform, $rs->first()->name();
        }
    }
    print STDERR " transform array = " . Dumper(@transform);
    print STDERR " missing array = " . Dumper(@missing);
    return {
        transform => \@transform,
        missing   => \@missing,
    };
}

1;
