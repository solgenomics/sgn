
package CXGN::List::Validate::Plugin::CrossingExperiments;

use Moose;
use Data::Dumper;

sub name {
    return "crossing_experiments";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    ##need to clean up about project_type vs project_property
    my $crossing_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial', 'project_type')->cvterm_id();

    my @missing = ();

    my $rs = $schema->resultset("Project::Project")->search(
        {
            'me.name' => { -in => $list },
            'projectprops.type_id' => $crossing_experiment_cvterm_id,
        },
        {
            join => 'projectprops'
        }
    );
    my %found_names;
    while (my $r=$rs->next){
        $found_names{$r->name}++;
    }

    foreach (@$list){
        if (!$found_names{$_}){
            push @missing, $_;
        }
    }
    return { missing => \@missing };
}

1;
