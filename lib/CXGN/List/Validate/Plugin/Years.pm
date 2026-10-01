
package CXGN::List::Validate::Plugin::Years;

use Moose;
use Data::Dumper;

sub name {
    return "years";
}

sub validate {
    my $self   = shift;
    my $schema = shift;
    my $list   = shift || [];

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

    # Drop undef/blank entries and de-duplicate before querying
    my %seen;
    my @terms = grep { defined && $_ ne '' && !$seen{$_}++ } @$list;

    return { missing => [] } unless @terms;

    # Only projectprops of the 'project year' type count as a valid year;
    # without this filter a bare number like "2020" could match unrelated
    # projectprops (e.g. project_sp_person_id, breeding_program, project location).
    my $year_type_id = SGN::Model::Cvterm
        ->get_cvterm_row($schema, 'project year', 'project_property')
        ->cvterm_id();

    my $rs = $schema->resultset("Project::Projectprop")->search(
        {
            type_id => $year_type_id,
            value   => { -in => \@terms },
        },
        { columns => ['value'], distinct => 1 }
    );

    my %found = map { $_ => 1 } $rs->get_column('value')->all();

    # Report against the original list so blank/duplicate entries are still surfaced
    my @missing = grep { !defined($_) || $_ eq '' || !$found{$_} } @$list;

    return { missing => \@missing };
}

1;
