package CXGN::Fieldbook::DownloadTrial;

=head1 NAME

CXGN::Fieldbook::DownloadTrial - an object to handle creating a Fieldbook Trial Layout xls file.

=head1 SYNOPSIS

this module is used to create a Fieldbook layout file that can be imported into Fieldbook App. it stores the file on fileserver and saves the file to a user, allowing them to access it later on.

my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $trial_id,
    tempfile => '/tmp/fieldbook_file1.xls',
    archive_path => /archive/path/,
    user_id => $c->user()->get_object()->get_sp_person_id(),
    user_name => $c->user()->get_object()->get_username(),
    data_level => 'plots',
    treatment_project_ids => [1],
    selected_columns => {"plot_name"=>1,"block_number"=>1,"plot_number"=>1},
    include_measured => 1,
    selected_trait_ids => [2,3],
});

my $create_fieldbook_return = $create_fieldbook->download();
my $error;
if ($create_fieldbook_return->{'error_messages'}){
    $error = join ',', @{$create_fieldbook_return->{'error_messages'}};
}
my $file_name = $create_fieldbook_return->{'file'};
my $file_id = $create_fieldbook_return->{'file_id'};

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

has 'data_level' => (
    is => 'ro',
    isa => 'Str',
    default => 'plots',
);

has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');

has 'treatment_project_ids' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'selected_columns' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {"plot_name"=>1, "plot_number"=>1} }
);

has 'include_measured'=> (
    is => 'rw',
    isa => 'Str',
    default => 'true',
);

has 'all_stats'=> (
    is => 'rw',
    isa => 'Str',
    default => 'true',
);

has 'use_synonyms'=> (
    is => 'rw',
    isa => 'Str',
    default => 'true',
);

has 'selected_trait_ids'=> (
    is => 'ro',
    isa => 'ArrayRef[Int]|Undef',
);

has 'trial_stock_type'=> (
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => 'accession'
);

sub download {
    my $self = shift;
    my %errors;
    my @error_messages;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my $tempfile = $self->tempfile();
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    if (!$wb) {
        push @error_messages, "Could not create file.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $ws = $wb->add_worksheet();
    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $schema,
        trial_id => $trial_id,
        data_level => $self->data_level,
        treatment_project_ids => $self->treatment_project_ids,
        selected_columns => $self->selected_columns,
        include_measured => $self->include_measured,
        all_stats => $self->all_stats,
        use_synonyms => $self->use_synonyms,
        selected_trait_ids => $self->selected_trait_ids,
        trial_stock_type => $self->trial_stock_type
    });
    my $output = $trial_layout_download->get_layout_output();
    if ($output->{error_messages}){
        return $output;
    }
    my @output_array = @{$output->{output}};
    my $row_num = 0;
    foreach my $l (@output_array){
        my $col_num = 0;
        foreach my $c (@$l){
            $ws->write($row_num, $col_num, $c);
            $col_num++;
        }
        $row_num++;
    }
    $wb->close();

    my $user_id = $self->user_id();
    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
        binmode $F;
        my $md5 = Digest::MD5->new();
        $md5->addfile($F);
    close($F);

    my $selected_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
    my $trial_name = $selected_trial->get_name();

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_name = $self->user_name();
    my $subdirectory_name = "tablet_field_layout";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$trial_name.".xls");
    my $archive_path = $self->archive_path();
    my $file_destination =  catfile($archive_path, $archived_file_name);

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $metadata_schema = $self->metadata_schema();
    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
        create_person_id => $user_id,
    });
    $md_row->insert();

    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($file_destination),
        dirname => dirname($file_destination),
        filetype => 'tablet field layout xls',
        md5checksum => $md5->hexdigest(),
        metadata_id => $md_row->metadata_id(),
    });
    $file_row->insert();

    my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type' );

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
    print STDERR "FIeldbook file generated $file_destination ".localtime()."\n";
    return {result => $result, file => $file_destination, file_id=>$file_row->file_id() };
}

1;
