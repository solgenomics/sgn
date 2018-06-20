package CXGN::BrAPI::ArchiveFile;

=head1 NAME

CXGN::BrAPI::ArchiveFile - an object to handle creating and archiving files for BrAPI calls that store data .

=head1 SYNOPSIS

this module is used to create and archive files for BrAPI uploads. it stores the file on fileserver and saves the file to a user, allowing them to access it later on.

=head1 AUTHORS

=cut

use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Spec::Functions;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial::TrialLayout;
use Spreadsheet::WriteExcel;
use CXGN::Trait;
use CXGN::List::Transform;
use CXGN::People::Person;
use DateTime;
use CXGN::Stock::Accession;
use CXGN::Stock;
use CXGN::Phenotypes::Summary;
use CXGN::Trial::TrialLayoutDownload;

has 'bcs_schema' => (
    isa => "Bio::Chado::Schema",
    is => 'ro',
    required => 1,
);

has 'metadata_schema' => (
    isa => "CXGN::Metadata::Schema",
    is => 'ro',
    required => 1,
);

has 'phenome_schema' => (
    isa => "CXGN::Phenome::Schema",
    is => 'ro',
    required => 1,
);

has 'trial_id'   => (
    isa => "Int",
    is => 'ro',
    required => 1,
);

has 'tempfile' => (isa => 'Str', is => 'ro',
    predicate => 'has_tempfile',
    required => 1,
);

has 'archive_path' => (isa => 'Str', is => 'ro',
    predicate => 'has_archive_path',
    required => 1,
);

has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'user_name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


sub archive {
    my $self = shift;
    my %errors;
    my @error_messages;

    my $schema = $self->bcs_schema();
    my $tempfile = $self->tempfile();

    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->find(
        {
            'nd_experiment_projects.project_id' => $trial_id,
            type_id => $field_layout_cvterm->cvterm_id(),
        },
        {
            join => 'nd_experiment_projects',
        }
    );

    my $phenome_schema = $self->phenome_schema();
    my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
        nd_experiment_id => $experiment->nd_experiment_id(),
        file_id => $file_row->file_id(),
    });
    $experiment_files->insert();

    move($tempfile,$file_destination);
    unlink $tempfile;

    my $result = $file_row->file_id;
    print STDERR "File generated $file_destination ".localtime()."\n";
    return {result => $result, file => $file_destination, file_id=>$file_row->file_id() };
}

1;
