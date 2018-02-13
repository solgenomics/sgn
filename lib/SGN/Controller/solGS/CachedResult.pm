=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 Name

SGN::Controller::solGS::CachedResult - a controller related to cached result.
 
=cut


package SGN::Controller::solGS::CachedResult;

use Moose;
use namespace::autoclean;

#use File::Slurp qw /write_file read_file/;
use JSON;

#use File::Basename;
use File::Spec::Functions;



BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 
		   'text/html' => 'JSON' },
    );


sub check_cached_result :Path('/solgs/check/cached/result') Args(0) {
    my ($self, $c) = @_;

    my $req_page = $c->req->param('page');
  
    my $args = $c->req->param('args');
    my $json = JSON->new();
    $args = $json->decode($args);
        
    $self->_check_cached_output($c, $req_page, $args);
    
}


sub _check_cached_output {
    my ($self, $c, $req_page, $args) = @_;

    $c->stash->{rest}{cached} = undef;
    
    if ($req_page =~ /solgs\/population\//)
    { 
	my $pop_id = $args->{training_pop_id}[0];
	if ($pop_id !~ /uploaded/)
	{
	    $c->stash->{rest}{cached} = $self->check_training_pop_data($c, $pop_id);
	}
    } 
    elsif ($req_page =~ /solgs\/trait\//)
    {
	my $pop_id = $args->{training_pop_id}[0];
	my $trait_id = $args->{trait_id}[0];

	my $cached_pop_data  = $self->check_training_pop_data($c, $pop_id);

	if ($cached_pop_data)
	{
	   $c->stash->{rest}{cached} =  $self->check_model_output($c, $pop_id, $trait_id);
	}	
    }
    elsif ($req_page =~ /solgs\/model\//)
    {
	my $tr_pop_id  = $args->{training_pop_id}[0];
	my $sel_pop_id = $args->{selection_pop_id}[0];
	my $trait_id   = $args->{trait_id}[0];

	my $cached_pop_data = $self->check_training_pop_data($c, $tr_pop_id);

	if ($cached_pop_data)
	{
	    my $cached_model_out = $self->check_model_output($c, $tr_pop_id, $trait_id);
  
	    if ($cached_model_out) 
	    {
		$c->stash->{rest}{cached} = $self->check_selection_pop_output($c, $tr_pop_id, $sel_pop_id, $trait_id);		
	    }	    
	}		
    }   
}


sub check_training_pop_data {
    my ($self, $c, $pop_id) = @_;

    $c->controller('solGS::solGS')->phenotype_file_name($c, $pop_id);
    my $cached_pheno = -s $c->stash->{phenotype_file_name};
  
    $c->controller('solGS::solGS')->genotype_file_name($c, $pop_id);
    my $cached_geno = -s $c->stash->{genotype_file_name};
  
    if ($cached_pheno && $cached_geno)
    {
	return  1;
    }
    else
    {
	return 0;
    }
	
    
}


sub check_model_output {
    my ($self, $c, $pop_id, $trait_id) = @_;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    $c->stash->{trait_abbr} = $trait_abbr;
    $c->stash->{pop_id}     = $pop_id;  
 
    $c->controller('solGS::solGS')->gebv_kinship_file($c);
    my $cached_gebv = -s $c->stash->{gebv_kinship_file};
   
    if ($cached_gebv)
    {
	return  1;
    }
    else
    {
	return 0;
    }	
    
}


sub check_selection_pop_output {
    my ($self, $c, $tr_pop_id, $sel_pop_id, $trait_id) = @_;
    
    my $identifier = $tr_pop_id . '_' . $sel_pop_id;
    $c->controller('solGS::solGS')->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    
    my $cached_gebv = -s $c->stash->{prediction_pop_gebvs_file};

    if ($cached_gebv)
    {
	return  1;
    }
    else
    {
	return 0;
    }	
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}


#####
1;###
####
