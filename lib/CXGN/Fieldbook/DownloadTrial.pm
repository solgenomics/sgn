package CXGN::Fieldbook::DownloadTrial;

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
    my $trial_layout;
    print STDERR "\n\nTrial id: ($trial_id)\n\n";
    try {
        $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    };
    if (!$trial_layout) {
        push @error_messages, "Trial does not have valid field design.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $trial_name =  $trial_layout->get_trial_name();

    if ($self->data_level eq 'plots') {
        $ws->write(0, 0, 'plot_id');
        $ws->write(0, 1, 'range');
        $ws->write(0, 2, 'plot');
        $ws->write(0, 3, 'rep');
        $ws->write(0, 4, 'accession');
        $ws->write(0, 5, 'is_a_control');
    } elsif ($self->data_level eq 'plants') {
        $ws->write(0, 0, 'plot_id');
        $ws->write(0, 1, 'range');
        $ws->write(0, 2, 'plant');
        $ws->write(0, 3, 'plot');
        $ws->write(0, 4, 'rep');
        $ws->write(0, 5, 'accession');
        $ws->write(0, 6, 'is_a_control');
    }

    my %design = %{$trial_layout->get_design()};
    my $row_num = 1;
    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};
        if ($self->data_level eq 'plots') {
            $ws->write($row_num,0,$design_info{'plot_name'});
            $ws->write($row_num,1,$design_info{'block_number'});
            $ws->write($row_num,2,$design_info{'plot_number'});
            $ws->write($row_num,3,$design_info{'rep_number'});
            $ws->write($row_num,4,$design_info{'accession_name'});
            $ws->write($row_num,5,$design_info{'is_a_control'});
            $row_num++;
        } elsif ($self->data_level eq 'plants'){
            my $plant_names = $design_info{'plant_names'};
            my $plant_num = 1;
            foreach (@$plant_names) {
                $ws->write($row_num,0,$_);
                $ws->write($row_num,1,$design_info{'block_number'});
                $ws->write($row_num,2,$plant_num);
                $ws->write($row_num,3,$design_info{'plot_number'});
                $ws->write($row_num,4,$design_info{'rep_number'});
                $ws->write($row_num,5,$design_info{'accession_name'});
                $ws->write($row_num,6,$design_info{'is_a_control'});
                $plant_num++;
                $row_num++;
            }
        }
    }
    $wb->close();

    my $user_id = $self->user_id();
    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
        binmode $F;
        my $md5 = Digest::MD5->new();
        $md5->addfile($F);
    close($F);

    my $project = $trial_layout->get_project;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_name = $self->user_name();
    my $subdirectory_name = "tablet_field_layout";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$project->name.".xls");
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
            'nd_experiment_projects.project_id' => $project->project_id,
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
    return {result => $result, file => $file_destination};
}

1;
