package SGN::Controller::solGS::Kinship;


use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use File::Spec::Functions;
use File::Path qw / mkpath  /;


BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 
		   'text/html' => 'JSON' },
    );



sub kinship_data :Path('/solgs/kinship/data/') Args() {
    my ($self, $c) = @_;   

    my $pop_id = $c->req->param('kinship_pop_id');
    my $protocol_id = $c->req->param('genotyping_protocol_id');

    $c->stash->{training_pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;
        
    $c->controller('solGS::Files')->relationship_matrix_file($c);
    my $kinship_file = $c->stash->{relationship_matrix_json_file};
  

    if (-s $kinship_file)
    {
        $c->stash->{rest}{data_exists} = 1; 
	$c->stash->{rest}{data} = read_file($kinship_file);

	$self->stash_kinship_output($c);
	
    } 

}


sub stash_kinship_output {
    my ($self, $c) = @_;
    
    $self->prep_download_kinship_files($c);
      
    $c->stash->{rest}{kinship_table_file} = $c->stash->{download_kinship_table};
    $c->stash->{rest}{kinship_averages_file} = $c->stash->{download_kinship_averages};
    $c->stash->{rest}{inbreeding_file} = $c->stash->{download_inbreeding};
    
}


sub prep_download_kinship_files {
  my ($self, $c) = @_; 
  
  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'kinship');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);
   
  mkpath ([$base_tmp_dir], 0, 0755);  

  $c->controller('solGS::Files')->relationship_matrix_file($c);  
  my $kinship_txt_file  = $c->stash->{relationship_matrix_file};
  #my $kinship_json_file = $c->stash->{relationship_matrix_json_file};

  $c->controller('solGS::Files')->inbreeding_coefficients_file($c); 
  my $inbreeding_file = $c->stash->{inbreeding_coefficients_file};

  $c->controller('solGS::Files')->average_kinship_file($c);
  my $ave_kinship_file = $c->stash->{average_kinship_file};
  
  $c->controller('solGS::Files')->copy_file($kinship_txt_file, $base_tmp_dir);					     
  $c->controller('solGS::Files')->copy_file($inbreeding_file, $base_tmp_dir); 
  $c->controller('solGS::Files')->copy_file($ave_kinship_file, $base_tmp_dir);  
										     
  $kinship_txt_file = fileparse($kinship_txt_file);
  $kinship_txt_file = catfile($tmp_dir, $kinship_txt_file);

  $inbreeding_file = fileparse($inbreeding_file);
  $inbreeding_file = catfile($tmp_dir, $inbreeding_file);

  $ave_kinship_file = fileparse($ave_kinship_file);
  $ave_kinship_file = catfile($tmp_dir, $ave_kinship_file);
  
  $c->stash->{download_kinship_table} = $kinship_txt_file;
  $c->stash->{download_kinship_averages}   = $ave_kinship_file;
  $c->stash->{download_inbreeding}    = $inbreeding_file;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}

#####
1;
#####
