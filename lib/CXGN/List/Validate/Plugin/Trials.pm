
package CXGN::List::Validate::Plugin::Trials;

use Moose;
use SGN::Model::Cvterm;

sub name {
    return "trials";
}

sub validate {
    my $self   = shift;
    my $schema = shift;
    my $list   = shift;

    my %seen;
    my @unique = grep { defined && length && !$seen{$_}++ } @$list;
    return { missing => [] } unless @unique;

    # projectprop / stock_type cvterms that mean "this project is NOT a trial"
    my @not_trial_type_ids = map {
        SGN::Model::Cvterm->get_cvterm_row($schema, $_->[0], $_->[1])->cvterm_id()
    } (
        [ 'breeding_program',       'project_property' ],
        [ 'trial_folder',           'project_property' ],
        [ 'cross',                  'stock_type'       ],  # crossing experiment
        [ 'analysis_metadata_json', 'project_property' ],
    );

    # candidate projects carrying one of the requested names
    my $project_rs = $schema->resultset("Project::Project")->search(
        { name => { -in => \@unique } },
        { columns => [qw/ project_id name /] },
    );
    my %name_by_id;
    while ( my $p = $project_rs->next ) {
        $name_by_id{ $p->project_id } = $p->name;
    }

    # drop the ones that are breeding programs / folders / crossing experiments / analyses
    if (%name_by_id) {
        my $dq_rs = $schema->resultset("Project::Projectprop")->search({
            project_id => { -in => [ keys %name_by_id ] },
            type_id    => { -in => \@not_trial_type_ids },
        });
        while ( my $r = $dq_rs->next ) {
            delete $name_by_id{ $r->project_id };
        }
    }

    my %found = map { $_ => 1 } values %name_by_id;
    my @missing = grep { !$found{$_} } @unique;

    return { missing => \@missing };
}

1;
