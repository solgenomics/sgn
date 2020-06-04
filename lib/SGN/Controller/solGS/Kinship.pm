package SGN::Controller::solGS::Kinship;


use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;


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
  
    my $ret->{data_exists} = undef;

    if (-s $kinship_file)
    {
        $ret->{data_exists} = 1; 
	$ret->{data} = read_file($kinship_file);


	
    } 
   
    $c->stash->{rest} = $ret;

}


sub download_kinship :Path('/solgs/download/kinship/population') Args() {
    my ($self, $c, $pop_id, $gp, $protocol_id) = @_;   
   
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;
     print STDERR "\nkinship pop id: $pop_id -- gp: $protocol_id \n";
    $c->controller('solGS::Files')->relationship_matrix_file($c);
    my $kinship_file = $c->stash->{relationship_matrix_file};
    print STDERR "\nkinship pop id: $pop_id -- gp: $protocol_id -- file: $kinship_file\n";
    unless (!-s $kinship_file) 
    {
        my @kinship =  map { [ split(/\t/) ] }  read_file($kinship_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @kinship);
    }
 
}


sub download_ave_kinship :Path('/solgs/download/ave/kinship/population') Args() {
    my ($self, $c, $pop_id, $gp, $protocol_id) = @_;   
   
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;
    
    $c->controller('solGS::Files')->average_kinship_file($c);
    my $ave_kinship_file = $c->stash->{average_kinship_file};
    print STDERR "\nave kinship pop id: $pop_id -- gp: $protocol_id -- file: $ave_kinship_file\n";
    unless (!-s $ave_kinship_file) 
    {
        my @ave_kinships =  map { [ split(/\t/) ] }  read_file($ave_kinship_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @ave_kinships);
    }
 
}


sub download_inbreeding :Path('/solgs/download/inbreeding/population') Args() {
    my ($self, $c, $pop_id, $gp, $protocol_id) = @_;   
   
    $c->stash->{pop_id} = $pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;
    
    $c->controller('solGS::Files')->inbreeding_coefficients_file($c);
    my $inbreeding_file = $c->stash->{inbreeding_coefficients_file};
    print STDERR "\ninbreeding pop id: $pop_id -- gp: $protocol_id -- file: $inbreeding_file\n";
    unless (!-s $inbreeding_file) 
    {
        my @inbreeding =  map { [ split(/\t/) ] }  read_file($inbreeding_file);
    
        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @inbreeding);
    }
 
}


sub stash_kinship_output {
    my ($self, $c) = @_;
    
    $self->prep_download_kinship_files($c);
      
    $c->stash->{rest}{kinship_table_file} = $c->stash->{download_kinship_table}
    $c->stash->{rest}{kinship_averages_file} = $c->stash->{download_kinship_averages};
    $c->stash->{rest}{inbreeding_coefficients_file} = $c->stash->{download_inbreeding};
    
}


sub prep_download_kinship_files {
  my ($self, $c) = @_; 
  
  my $tmp_dir      = catfile($c->config->{tempfiles_subdir}, 'kinship');
  my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);
   
  mkpath ([$base_tmp_dir], 0, 0755);  

  $c->controller('solGS::Files')->relationship_matrix_file($c);  
  my $kinship_txt_file  = $c->stash->{relationship_matrix_table_file};
  my $kinship_json_file = $c->stash->{relationship_matrix_json_file};

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
