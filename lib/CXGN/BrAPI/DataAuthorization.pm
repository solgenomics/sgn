package CXGN::BrAPI::DataAuthorization;

use strict;
use warnings;
use CXGN::People::Person;
use CXGN::BreedersToolbox::Projects;

=head1 NAME

CXGN::BrAPI::DataAuthorization - standard breeding-program authorization for data writes

=head1 DESCRIPTION

These functions use the same curator or submitter-plus-program policy as the
native phenotype recording screen. Target memberships come from stored layout
relationships, never from a caller-supplied study name.

=cut

sub _roles {
    my ($schema, $user_id) = @_;
    return ({}, {code => 401, error => 'You must be logged in to change breeding data.'})
        if !defined($user_id) || $user_id !~ /^[1-9]\d*$/;
    my %roles = map { $_ => 1 } CXGN::People::Person->new($schema->storage->dbh, $user_id)->get_roles;
    return (\%roles, undef);
}

sub projects_error {
    my ($schema, $user_id, $project_ids) = @_;
    my ($roles, $error) = _roles($schema, $user_id);
    return $error if $error;
    return {code => 403, error => 'You must be a curator or a submitter of the breeding program to change its data.'}
        if !$roles->{curator} && !$roles->{submitter};
    return {code => 400, error => 'No target study was supplied.'} if ref($project_ids) ne 'ARRAY' || !@$project_ids;
    my $projects = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my %seen;
    foreach my $id (@$project_ids) {
        return {code => 400, error => 'A study identifier must be a positive integer.'}
            if !defined($id) || ref($id) || $id !~ /^[1-9]\d*$/;
        next if $seen{$id}++;
        return {code => 404, error => "Study $id does not exist."}
            if !$schema->resultset('Project::Project')->find({project_id => $id});
        next if $roles->{curator};
        my $programs = $projects->get_breeding_programs_by_trial($id) || [];
        return {code => 403, error => "Study $id has no breeding program; a curator must correct its membership."} if !@$programs;
        foreach my $program (@$programs) {
            my $name = $program->[1];
            return {code => 403, error => 'You must be a submitter associated with breeding program '.($name // '(unknown)').' to change this study.'}
                if !defined($name) || !$roles->{$name};
        }
    }
    return undef;
}

sub observation_units_error {
    my ($schema, $user_id, $stock_ids) = @_;
    my (undef, $error) = _roles($schema, $user_id);
    return $error if $error;
    return {code => 400, error => 'No target observation units were supplied.'}
        if ref($stock_ids) ne 'ARRAY' || !@$stock_ids;
    my %ids;
    foreach my $id (@$stock_ids) {
        return {code => 400, error => 'An observation unit identifier must be a positive integer.'}
            if !defined($id) || ref($id) || $id !~ /^[1-9]\d*$/;
        $ids{$id} = 1;
    }
    my $dbh = $schema->storage->dbh;
    my $found = $dbh->selectcol_arrayref('SELECT stock_id FROM stock WHERE stock_id = ANY(?)', undef, [keys %ids]);
    my %found = map {$_ => 1} @$found;
    foreach my $id (sort {$a <=> $b} keys %ids) {
        return {code => 404, error => "Observation unit $id does not exist."} if !$found{$id};
    }
    my $rows = $dbh->selectall_arrayref(q{
        SELECT DISTINCT nes.stock_id, nep.project_id
        FROM nd_experiment_stock nes
        JOIN nd_experiment ne USING(nd_experiment_id)
        JOIN cvterm et ON et.cvterm_id = ne.type_id
        JOIN cv ON cv.cv_id = et.cv_id AND cv.name = 'experiment_type'
        JOIN nd_experiment_project nep USING(nd_experiment_id)
        WHERE nes.stock_id = ANY(?) AND et.name IN ('field_layout', 'genotyping_layout', 'sampling_layout')
    }, undef, [keys %ids]);
    my (%members, %projects);
    foreach my $row (@$rows) { $members{$row->[0]} = 1; $projects{$row->[1]} = 1; }
    foreach my $id (sort {$a <=> $b} keys %ids) {
        return {code => 400, error => "Observation unit $id is not assigned to a supported study layout."} if !$members{$id};
    }
    return projects_error($schema, $user_id, [sort {$a <=> $b} keys %projects]);
}

1;
