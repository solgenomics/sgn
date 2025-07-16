
package CXGN::List::Validate::Plugin::GenotypingProjects;

use Moose;
use Data::Dumper;

sub name {
    return "genotyping_projects";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();

    my @missing = ();

    my $rs = $schema->resultset("Project::Project")->search(
        {
            'me.name' => { -in => $list },
            'projectprops.type_id' => $design_cvterm_id,
            'projectprops.value' => 'genotype_data_project'
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
