package AddFeatureCvtermRank;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding rank column to feature_cvterm table';
    my @previous_requested_patches = (); #ADD HERE
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do( <<'' );
alter table public.feature_cvterm add rank integer not null default 0;
alter table public.feature_cvterm drop constraint feature_cvterm_c1;
alter table public.feature_cvterm add constraint feature_cvterm_c1 unique ( feature_id, cvterm_id, pub_id, rank );

    print "You're done!\n";

}


####
1; #
####

