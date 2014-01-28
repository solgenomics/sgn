
package SGN::Controller::FieldBook;

use Moose;
use URI::FromHash 'uri';
use Spreadsheet::WriteExcel;
use File::Slurp qw | read_file |;
use File::Temp;
use Data::Dumper;
use CXGN::Trial::TrialLayout;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Spec::Functions;
use CXGN::BreedersToolbox::Projects;

BEGIN { extends 'Catalyst::Controller'; }

sub field_book :Path("/fieldbook") Args(0) { 
    my ($self , $c) = @_;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    if (!$c->user()) { 
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @rows = $schema->resultset('Project::Project')->all();
    #limit to owner 
    my @projects = ();
    my $bp = CXGN::BreedersToolbox::Projects->new( { schema=>$schema });
    my $breeding_programs = $bp->get_breeding_programs();
    my @layout_files = ();
    my @phenotype_files = ();
    my @removed_phenotype_files = ();

    my $field_layout_cvterm = $schema->resultset('Cv::Cvterm')
      ->create_with({
		     name   => 'field layout',
		     cv     => 'experiment type',
		     db     => 'null',
		     dbxref => 'field layout',
		    });

    foreach my $row (@rows) {
      my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->find({
										   'nd_experiment_projects.project_id' => $row->project_id,
										   type_id => $field_layout_cvterm->cvterm_id(),
										  },
										  {
										   join => 'nd_experiment_projects',
										  });
      if (!$experiment) {
	next;
      }
      my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->search({nd_experiment_id => $experiment->nd_experiment_id(),});
      while (my $experiment_file = $experiment_files->next) {
	my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $experiment_file->file_id});
	if ($file_row->filetype eq 'tablet field layout xls') {
	  #my $file_metadata = $file_row->search_related('md_metadata')->find({create_person_id => $user_id,});
	  my $metadata_id = $file_row->metadata_id->metadata_id;
	  if ($metadata_id) {
	    my $file_metadata = $metadata_schema->resultset("MdMetadata")->find({metadata_id => $metadata_id});
	    if ( $file_metadata->create_person_id() eq $user_id) {
	      my $file_destination =  catfile($file_row->dirname, $file_row->basename);
	      push @projects, [ $row->project_id, $row->name, $row->description, $file_row->dirname,$file_row->basename, $file_row->file_id];
	      push @layout_files, $file_destination;
	    }
	  }
	}
      }
    }

    my @trait_files = ();
    #limit to those owned by user
    my $md_files = $metadata_schema->resultset("MdFiles")->search({filetype=>'tablet trait file'});
    while (my $md_file = $md_files->next) {
      my $metadata_id = $md_file->metadata_id->metadata_id;
      my $file_metadata = $metadata_schema->resultset("MdMetadata")->find({metadata_id => $metadata_id});
      if ( $file_metadata->create_person_id() eq $user_id) {
	push @trait_files, [$md_file->basename,$md_file->file_id];
      }
    }
    
    my $uploaded_md_files = $metadata_schema->resultset("MdFiles")->search({filetype=>'tablet phenotype file'});
    while (my $md_file = $uploaded_md_files->next) {
	my $metadata_id = $md_file->metadata_id->metadata_id;
	my $file_metadata = $metadata_schema->resultset("MdMetadata")->find({metadata_id => $metadata_id });
	if ( ($file_metadata->obsolete==0) && ($file_metadata->create_person_id() eq $user_id)) {
	    push @phenotype_files, [$md_file->basename,$md_file->file_id];
	}
	elsif ( ($file_metadata->obsolete==1) && ($file_metadata->create_person_id() eq $user_id)) { 
	  push @removed_phenotype_files, [$md_file->basename, $md_file->file_id];
	}
    }

    $c->stash->{projects} = \@projects;
    $c->stash->{programs} = $breeding_programs;
    $c->stash->{layout_files} = \@projects;
    $c->stash->{trait_files} = \@trait_files;
    $c->stash->{phenotype_files} = \@phenotype_files;
    $c->stash->{removed_phenotype_files} = \@removed_phenotype_files;

    # get roles
    my @roles = $c->user->roles();
    $c->stash->{roles}=\@roles;
    $c->stash->{template} = '/fieldbook/home.mas';
}


sub trial_field_book_download : Path('/fieldbook/trial_download/') Args(1) { 
    my $self  =shift;
    my $c = shift;
    my $file_id = shift;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    print STDERR "\n\n\nfile name:".$file_row->basename."\n";
    my $contents = read_file($file_destination);
    my $file_name = $file_row->basename;
    $c->res->content_type('Application/xls');
    $c->res->header('Content-Disposition', qq[attachment; filename="fieldbook_layout_$file_name"]);
    $c->res->body($contents);
}


sub tablet_trait_file_download : Path('/fieldbook/trait_file_download/') Args(1) { 
    my $self  =shift;
    my $c = shift;
    my $file_id = shift;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    print STDERR "\n\n\nfile name:".$file_row->basename."\n";
    my $contents = read_file($file_destination);
    my $file_name = $file_row->basename;
    $c->res->content_type('Application/trt');
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
    $c->res->body($contents);
}

sub trial_field_book_download_old : Path('/fieldbook/trial_download_old/') Args(1) { 
    my $self  =shift;
    my $c = shift;
    my $trial_id = shift;
    die "No trial id supplied" if !$trial_id;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial = $schema->resultset('Project::Project')->find({project_id => $trial_id});
    die "Trial does not exist with id $trial_id" if !$trial;
    my $dir = $c->tempfiles_subdir('/other');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    die "Could not create excel file " if !$wb;
    my $ws = $wb->add_worksheet();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    my $trial_name =  $trial_layout->get_trial_name();

    $ws->write(0, 0, 'plot_id');
    $ws->write(0, 1, 'range');
    $ws->write(0, 2, 'plot');
    $ws->write(0, 3, 'rep');
    $ws->write(0, 4, 'accession');
    $ws->write(0, 5, 'is_a_control');

    my %design = %{$trial_layout->get_design()};
    my $row_num = 1;
    foreach my $key (sort { $a <=> $b} keys %design) {
      my %design_info = %{$design{$key}};
      $ws->write($row_num,0,$design_info{'plot_name'});
      $ws->write($row_num,1,$design_info{'block_number'});
      $ws->write($row_num,2,$design_info{'plot_number'});
      $ws->write($row_num,3,$design_info{'rep_number'});
      $ws->write($row_num,4,$design_info{'accession_name'});
      $ws->write($row_num,5,$design_info{'is_a_control'});
      $row_num++;
    }
    $wb->close();
    my $contents = read_file($tempfile);
    $c->res->content_type('Application/xls');
    $c->res->header('Content-Disposition', qq[attachment; filename="fieldbook_layout_$trial_name.xls"]);
    $c->res->body($contents);
}

1;
