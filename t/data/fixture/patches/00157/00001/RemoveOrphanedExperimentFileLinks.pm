package RemoveOrphanedExperimentFileLinks;

=head1 NAME

RemoveOrphanedExperimentFileLinks - repair fixture file links before adding foreign keys

=head1 DESCRIPTION

The fixture contains experiment links to file IDs 2, 3, and 4, whose
metadata.md_files rows are absent. Remove these invalid links before
AddCascadeDeletes adds the file foreign key in database patch 00158.
Links to existing files are retained.

=cut

use Moose;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => (
    default => 'Remove fixture experiment file links whose file records are absent',
);

sub patch {
    my $self = shift;
    $self->dbh->do(q{
        DELETE FROM phenome.nd_experiment_md_files AS link
        WHERE NOT EXISTS (
            SELECT 1 FROM metadata.md_files AS file
            WHERE file.file_id = link.file_id
        )
    });
    return 1;
}

1;
