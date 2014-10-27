
package SGN::Controller::AJAX::Pedigrees;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub upload_pedigrees_file : Path('/ajax/pedigrees/upload') Args(0)  { 
    my $self = shift;
    my $c = shift;
    
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    
    my $upload = $c->req->upload('pedigrees_uploaded_file');
    my $uploader = CXGN::UploadFile->new();
    
      my $upload_original_name = $upload->filename();
  my $upload_tempfile = $upload->tempname;
  my $subdirectory = "pedigrees_upload";

      if (!$c->user()) { 
    print STDERR "User not logged in... not adding a crosses.\n";
    $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
    return;
  }

  $user_id = $c->user()->get_object()->get_sp_person_id();

  $user_name = $c->user()->get_object()->get_username();

  ## Store uploaded temporary file in archive
  $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
  $md5 = $uploader->get_md5($archived_filename_with_path);
  if (!$archived_filename_with_path) {
      $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
      return;
  }
  unlink $upload_tempfile;

  $upload_metadata{'archived_file'} = $archived_filename_with_path;
  $upload_metadata{'archived_file_type'}="trial upload file";
  $upload_metadata{'user_id'}=$user_id;
  $upload_metadata{'date'}="$timestamp";

  #parse uploaded file with appropriate plugin
  $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
  $parser->load_plugin('TrialExcelFormat');
  $parsed_data = $parser->parse();

  if (!$parsed_data) {
    my $return_error = '';

    if (! $parser->has_parse_errors() ){
      $return_error = "Could not get parsing errors";
      $c->stash->{rest} = {error_string => $return_error,};
    }

    else {
      $parse_errors = $parser->get_parse_errors();
      foreach my $error_string (@{$parse_errors}){
	$return_error=$return_error.$error_string."<br>";
      }
    }

    $c->stash->{rest} = {error_string => $return_error,};
    return;
  }


  my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $chado_schema,
	   phenome_schema => $phenome_schema,
	   dbh => $dbh,
	   trial_year => $trial_year,
	   trial_description => $trial_description,
	   trial_location => $trial_location,
	   trial_name => $trial_name,
	   user_name => $user_name, #not implemented
	   design_type => $trial_design_method,
	   design => $parsed_data,
	   program => $program,
	   upload_trial_file => $upload,
	  });

#  try {
    $trial_create->save_trial();
 # } catch {
#    $c->stash->{rest} = {error => "Error saving trial in the database $_"};
#    $error = 1;
#  };
  if ($error) {return;}
  $c->stash->{rest} = {success => "1",};
  return;
    

}
