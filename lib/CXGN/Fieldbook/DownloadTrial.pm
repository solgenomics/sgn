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

has 'treatment_project_id' => (
    isa => 'Maybe[Int]',
    is => 'rw'
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
    
    my $treatment = $self->treatment_project_id();
    my $treatment_trial;
    my $treatment_name = "";
    if ($treatment){
        $treatment_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $treatment});
        $treatment_name = $treatment_trial->get_name();
    }

    my $trial_name =  $trial_layout->get_trial_name();

    my %treatment_stock_hash;
    if ($self->data_level eq 'plots') {
        $ws->write(0, 0, 'plot_name');
        $ws->write(0, 1, 'block_number');
        $ws->write(0, 2, 'plot_number');
        $ws->write(0, 3, 'rep_number');
        $ws->write(0, 4, 'row_number');
        $ws->write(0, 5, 'col_number');
        $ws->write(0, 6, 'accession_name');
        $ws->write(0, 7, 'is_a_control');

        if($treatment_trial){
            $ws->write(0, 8, "Treatment:".$treatment_name);
            my $treatment_plots = $treatment_trial->get_plots();
            foreach (@$treatment_plots){
                $treatment_stock_hash{$_->[1]}++;
            }
        }

    } elsif ($self->data_level eq 'plants') {
        $ws->write(0, 0, 'plant_name');
        $ws->write(0, 1, 'plot_name');
        $ws->write(0, 2, 'block_number');
        $ws->write(0, 3, 'plant_number');
        $ws->write(0, 4, 'plot_number');
        $ws->write(0, 5, 'rep_number');
        $ws->write(0, 6, 'row_number');
        $ws->write(0, 7, 'col_number');
        $ws->write(0, 8, 'accession_name');
        $ws->write(0, 9, 'is_a_control');

        if($treatment_trial){
            $ws->write(0, 10, "Treatment:".$treatment_name);
            my $treatment_plots = $treatment_trial->get_plants();
            foreach (@$treatment_plots){
                $treatment_stock_hash{$_->[1]}++;
            }
        }
    } elsif ($self->data_level eq 'subplots') {
        $ws->write(0, 0, 'subplot_name');
        $ws->write(0, 1, 'plot_name');
        $ws->write(0, 2, 'block_number');
        $ws->write(0, 3, 'subplot_number');
        $ws->write(0, 4, 'plot_number');
        $ws->write(0, 5, 'rep_number');
        $ws->write(0, 6, 'row_number');
        $ws->write(0, 7, 'col_number');
        $ws->write(0, 8, 'accession_name');
        $ws->write(0, 9, 'is_a_control');

        if($treatment_trial){
            $ws->write(0, 10, "Treatment:".$treatment_name);
            my $treatment_subplots = $treatment_trial->get_subplots();
            foreach (@$treatment_subplots){
                $treatment_stock_hash{$_->[1]}++;
            }
        }
    } elsif ($self->data_level eq 'plants_subplots') {
        $ws->write(0, 0, 'plant_name');
        $ws->write(0, 1, 'subplot_name');
        $ws->write(0, 2, 'plot_name');
        $ws->write(0, 3, 'block_number');
        $ws->write(0, 4, 'subplot_number');
        $ws->write(0, 5, 'plant_number');
        $ws->write(0, 6, 'plot_number');
        $ws->write(0, 7, 'rep_number');
        $ws->write(0, 8, 'row_number');
        $ws->write(0, 9, 'col_number');
        $ws->write(0, 10, 'accession_name');
        $ws->write(0, 11, 'is_a_control');

        if($treatment_trial){
            $ws->write(0, 12, "Treatment:".$treatment_name);
            my $treatment_plants = $treatment_trial->get_plants();
            foreach (@$treatment_plants){
                $treatment_stock_hash{$_->[1]}++;
            }
        }
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
            $ws->write($row_num,4,$design_info{'row_number'});
            $ws->write($row_num,5,$design_info{'col_number'});
            $ws->write($row_num,6,$design_info{'accession_name'});
            $ws->write($row_num,7,$design_info{'is_a_control'});

            if(exists($treatment_stock_hash{$design_info{'plot_name'}})){
                $ws->write($row_num,8,1);
            }

            $row_num++;
        } elsif ($self->data_level eq 'plants'){
            my $plant_names = $design_info{'plant_names'};
            my $plant_num = 1;
            foreach (sort @$plant_names) {
                $ws->write($row_num,0,$_);
                $ws->write($row_num,1,$design_info{'plot_name'});
                $ws->write($row_num,2,$design_info{'block_number'});
                $ws->write($row_num,3,$plant_num);
                $ws->write($row_num,4,$design_info{'plot_number'});
                $ws->write($row_num,5,$design_info{'rep_number'});
                $ws->write($row_num,6,$design_info{'row_number'});
                $ws->write($row_num,7,$design_info{'col_number'});
                $ws->write($row_num,8,$design_info{'accession_name'});
                $ws->write($row_num,9,$design_info{'is_a_control'});

                if(exists($treatment_stock_hash{$_})){
                    $ws->write($row_num,10,1);
                }

                $plant_num++;
                $row_num++;
            }
        } elsif ($self->data_level eq 'subplots'){
            my $subplot_names = $design_info{'subplot_names'};
            my $subplot_num = 1;
            foreach (sort @$subplot_names) {
                $ws->write($row_num,0,$_);
                $ws->write($row_num,1,$design_info{'plot_name'});
                $ws->write($row_num,2,$design_info{'block_number'});
                $ws->write($row_num,3,$subplot_num);
                $ws->write($row_num,4,$design_info{'plot_number'});
                $ws->write($row_num,5,$design_info{'rep_number'});
                $ws->write($row_num,6,$design_info{'row_number'});
                $ws->write($row_num,7,$design_info{'col_number'});
                $ws->write($row_num,8,$design_info{'accession_name'});
                $ws->write($row_num,9,$design_info{'is_a_control'});

                if(exists($treatment_stock_hash{$_})){
                    $ws->write($row_num,10,1);
                }

                $subplot_num++;
                $row_num++;
            }
        } elsif ($self->data_level eq 'plants_subplots'){
            my $subplot_plant_names = $design_info{'subplots_plant_names'};
            my $subplot_num = 1;
            foreach my $s (sort keys %$subplot_plant_names) {
                my $plants = $subplot_plant_names->{$s};
                my $plant_num = 1;
                foreach my $p (sort @$plants){
                    $ws->write($row_num,0,$p);
                    $ws->write($row_num,1,$s);
                    $ws->write($row_num,2,$design_info{'plot_name'});
                    $ws->write($row_num,3,$design_info{'block_number'});
                    $ws->write($row_num,4,$subplot_num);
                    $ws->write($row_num,5,$plant_num);
                    $ws->write($row_num,6,$design_info{'plot_number'});
                    $ws->write($row_num,7,$design_info{'rep_number'});
                    $ws->write($row_num,8,$design_info{'row_number'});
                    $ws->write($row_num,9,$design_info{'col_number'});
                    $ws->write($row_num,10,$design_info{'accession_name'});
                    $ws->write($row_num,11,$design_info{'is_a_control'});

                    if(exists($treatment_stock_hash{$p})){
                        $ws->write($row_num,12,1);
                    }
                    $plant_num++;
                    $row_num++;
                }
                $subplot_num++;
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
