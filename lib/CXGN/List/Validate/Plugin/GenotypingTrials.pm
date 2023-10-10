
package CXGN::List::Validate::Plugin::GenotypingTrials;

use Moose;
use Data::Dumper;

sub name {
    return "genotyping_plates";
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
            'projectprops.value' => 'genotyping_plate'
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
