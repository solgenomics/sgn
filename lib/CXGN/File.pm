=head1 NAME

CXGN::File - a class to do functions with archived files

=head1 DESCRIPTION

CXGN::File is a class for managing the behaviors of archived files. Archived files are stored in the database with a unique ID 
and a file path. Not to be confused with CXGN::UploadFile, which is used when saving a file for the first time. 

=head1 SYNOPSIS

my $file = CXGN::File->new({
    file_id => $file_id
});

my $file_type = $file->type();

$file->type("multi_trial_upload");

$file->store();

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 

package CXGN::File;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use DateTime::Format::ISO8601;
use Data::Dumper;
use File::Slurp qw( write_file read_file );
use File::Path qw( make_path );
use JSON::Any;
use CXGN::Metadata::Schema;

=head1 ACCESSORS

=head2 metadata_schema()

Accessor for metadata schema

=cut 

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1
);

=head2 file_id()

Database ID for file

=cut 

has 'file_id' => (
    isa => 'Int',
    is => 'ro',
    required => 1
);

=head2 basename()

Database file basename. Concatenation of timestamp and file name. 

=cut 

has 'basename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 timestamp()

The time at which the file was archived. Used to differentiate it from files with the same name. 

=cut

has 'timestamp' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 filename()

The name of the file.

=cut

has 'filename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 dirname()

Parent directories of archived file. Should be combined with a config key for file archive location for complete file path. 

=cut

has 'dirname' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 filetype()

Optional file type. Used for determining upload/parse type for archived files. Loosely correlates to background job types. 

=cut

has 'filetype' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 alt_filename()

md_files.alt_filename

=cut

has 'alt_filename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 comment()

md_files.comment

=cut

has 'comment' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 md5checksum()

md_files.md5checksum

=cut

has 'md5checksum' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 metadata_id()

ID linking to metadata table

=cut

has 'metadata_id' => (
    isa => 'Maybe[Int]',
    is => 'rw'
);

=head2 urlsource

md_files.urlsource

=cut

has 'urlsource' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 urlsource_md5checksum()

md_files.urlsource_md5checksum

=cut

has 'urlsource_md5checksum' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head1 INSTANCE METHODS

=cut

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $metadata_schema = $self->metadata_schema();
    my $file_id = $self->file_id();

    if (!$file_id) {
        die "Need a file ID. Creating new file entries is handled with CXGN::UploadFile.\n";
    }

    my $file_rs = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});

    if (!$file_rs) {
        die "File not found. Is the file ID valid?";
    }

    my $basename = $file_rs->basename();
    $basename =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
    $self->basename($basename);
    $self->filename($+{FILENAME});
    $self->timestamp($+{TIMESTAMP});
    $self->dirname($file_rs->dirname());
    $self->filetype($file_rs->filetype());
    $self->comment($file_rs->comment());
    $self->alt_filename($file_rs->alt_filename());
    $self->md5checksum($file_rs->md5checksum());
    $self->metadata_id($file_rs->metadata_id());
    $self->urlsource($file_rs->urlsource());
    $self->urlsource_md5checksum($file_rs->urlsource_md5checksum());
}

sub store {
    my $self = shift;
    my $metadata_schema = $self->metadata_schema();

    eval {
        $metadata_schema->resultset("MdFiles")->update({
            file_id => $self->file_id(),
            basename => $self->basename(),
            dirname => $self->dirname(),
            filetype => $self->filetype(),
            alt_filename => $self->alt_filename(),
            comment => $self->comment(),
            md5checksum => $self->md5checksum(),
            metadata_id => $self->metadata_id(),
            urlsource => $self->urlsource(),
            urlsource_md5checksum => $self->urlsource_md5checksum()
        });
    };
    if ($@) {
        die "An error occurred trying to update file information: $@\n";
    }
}

=head2 set_file_type($type)

Save a new file type in association with the file

=cut

sub set_file_type {
    my $self = shift;
    my $new_type = shift;

    $self->filetype($new_type);
    $self->store();
}

=head1 CLASS METHODS

=head2 get_user_archived_files($bcs_schema, $user_id)

Retrieves all files uploaded by a user.

=cut

sub get_user_archived_files {
    my $class = shift;
    my $schema = shift;
    my $user_id = shift;

    my $q = "SELECT file_id, basename, filetype FROM metadata.md_files 
        JOIN metadata.md_metadata ON (md_files.metadata_id=md_metadata.metadata_id) 
        JOIN sgn_people.sp_person ON (sp_person.sp_person_id=md_metadata.create_person_id)
        WHERE sp_person_id=? AND basename != 'none'";
    
    my $h = $schema->storage()->dbh()->prepare($q);
    $h->execute($user_id);

    my @data;

    while (my ($file_id, $file_name, $filetype) = $h->fetchrow_array()){
        $file_name =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
        push @data, {
            file_id => $file_id,
            timestamp => $+{TIMESTAMP},
            filename => $+{FILENAME},
            type => $filetype
        };
    }

    return \@data;
}

=head2 get_all_archived_files($bcs_schema)

Retrieves all archived files. Typically used by a curator. 

=cut

sub get_all_archived_files {
    my $class = shift;
    my $schema = shift;

    my $q = "SELECT file_id, basename, sp_person_id, first_name, last_name, filetype FROM metadata.md_files 
        JOIN metadata.md_metadata ON (md_files.metadata_id=md_metadata.metadata_id) 
        JOIN sgn_people.sp_person ON (sp_person.sp_person_id=md_metadata.create_person_id)
        WHERE basename != 'none'";

    my $h = $schema->storage()->dbh()->prepare($q);
    $h->execute();

    my @data;

    while (my ($file_id, $file_name, $user_id, $first_name, $last_name, $filetype) = $h->fetchrow_array()){
        $file_name =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
        push @data, {
            file_id => $file_id,
            timestamp => $+{TIMESTAMP},
            filename => $+{FILENAME},
            user_id => $user_id,
            user_name => "$first_name $last_name",
            type => $filetype
        };
    }

    return \@data;
}

1;