package AddForumPageTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

sub init_patch {

    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding needed page types to sgn.forum_topic';
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

    $self->dbh->do( <<EOF );
    ALTER TABLE sgn_people.forum_topic DROP CONSTRAINT chk_forum_topic_page_type;
    ALTER TABLE sgn_people.forum_topic ADD CONSTRAINT chk_forum_topic_page_type CHECK (page_type::text = 'BAC'::text OR page_type::text = 'EST'::text OR page_type::text = 'unigene'::text OR page_type::text = 'marker'::text OR page_type::text = 'map'::text OR page_type::text = 'bac_end'::text OR page_type::text = ''::text OR page_type IS NULL OR page_type::text = 'locus'::text OR page_type::text = 'individual'::text OR page_type::text = 'pub'::text OR page_type::text = 'allele'::text OR page_type::text = 'stock'::text OR page_type::text = 'sample'::text) ;

EOF

    print "You're done!\n";
}


####
1; #
####

