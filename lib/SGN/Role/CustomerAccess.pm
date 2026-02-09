package SGN::Role::CustomerAccess;

# Workflow: /feature — Customer RBAC via Breeding Programs
#
# Provides helper functions to check whether a user with the "customer"
# role has access to specific trials, accessions, and plots based on
# their Breeding Program (BP) roles.
#
# Design: Breeding Program names match role names in sp_roles.
# A customer with role "CornSQ" sees only trials belonging to the
# CornSQ breeding program.

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    is_customer
    get_user_bp_project_ids
    user_can_access_trial
    user_can_access_stock
);


# Check if the current Catalyst user has the 'customer' role.
sub is_customer {
    my ($c) = @_;
    return 0 unless $c->user();
    return $c->user->check_roles('customer');
}


# Return arrayref of Breeding Program project IDs for this user's BP roles.
# BP roles have the same name as the project. We join sp_roles -> project
# via the 'breeding_program' projectprop type.
sub get_user_bp_project_ids {
    my ($c) = @_;

    my $dbh = $c->dbc->dbh;
    my $user_id = $c->user->get_object->get_sp_person_id();

    my $q = q{
        SELECT DISTINCT p.project_id
        FROM sgn_people.sp_person_roles pr
        JOIN sgn_people.sp_roles r USING(sp_role_id)
        JOIN project p ON p.name = r.name
        JOIN projectprop pp ON p.project_id = pp.project_id
        JOIN cvterm c ON pp.type_id = c.cvterm_id
        WHERE pr.sp_person_id = ?
          AND c.name = 'breeding_program'
    };
    my $sth = $dbh->prepare($q);
    $sth->execute($user_id);

    my @bp_ids;
    while (my ($bp_id) = $sth->fetchrow_array) {
        push @bp_ids, $bp_id;
    }
    return \@bp_ids;
}


# Check if the customer user can access the given trial.
# Returns 1 if the trial belongs to one of the user's BPs, 0 otherwise.
# Non-customer users always return 1 (full access).
sub user_can_access_trial {
    my ($c, $trial_project_id) = @_;

    # Non-customers have full access
    return 1 unless is_customer($c);

    my $bp_ids = get_user_bp_project_ids($c);
    return 1 unless @$bp_ids;  # No BP roles = fallback to full access

    my $dbh = $c->dbc->dbh;

    # Check if this trial is linked to one of the user's BPs
    my $placeholders = join(',', map { '?' } @$bp_ids);
    my $q = qq{
        SELECT 1
        FROM project_relationship pr
        WHERE pr.subject_project_id = ?
          AND pr.object_project_id IN ($placeholders)
          AND pr.type_id = (
              SELECT cvterm_id FROM cvterm
              WHERE name = 'breeding_program_trial_relationship'
              LIMIT 1
          )
        LIMIT 1
    };
    my $sth = $dbh->prepare($q);
    $sth->execute($trial_project_id, @$bp_ids);

    my ($found) = $sth->fetchrow_array;
    return $found ? 1 : 0;
}


# Check if the customer user can access the given stock (accession/plot).
# An accession is accessible if it appears in any trial belonging to the
# user's BPs. A plot is accessible if its parent trial is accessible.
# Non-customer users always return 1.
sub user_can_access_stock {
    my ($c, $stock_id) = @_;

    # Non-customers have full access
    return 1 unless is_customer($c);

    my $bp_ids = get_user_bp_project_ids($c);
    return 1 unless @$bp_ids;

    my $dbh = $c->dbc->dbh;

    # Check if the stock is used in any trial of the user's BPs
    my $placeholders = join(',', map { '?' } @$bp_ids);
    my $q = qq{
        SELECT 1
        FROM nd_experiment_stock nes
        JOIN nd_experiment_project nep USING(nd_experiment_id)
        JOIN project_relationship pr ON nep.project_id = pr.subject_project_id
        WHERE nes.stock_id = ?
          AND pr.object_project_id IN ($placeholders)
          AND pr.type_id = (
              SELECT cvterm_id FROM cvterm
              WHERE name = 'breeding_program_trial_relationship'
              LIMIT 1
          )
        LIMIT 1
    };
    my $sth = $dbh->prepare($q);
    $sth->execute($stock_id, @$bp_ids);

    my ($found) = $sth->fetchrow_array;
    return $found ? 1 : 0;
}


1;
