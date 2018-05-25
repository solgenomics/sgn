=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 DESCRIPTION

SGN::Controller::solGS::gebvsComparison - Controller for comparing GEBVs of training and selection populations

=cut


package SGN::Controller::solGS::gebvsComparison;

use Moose;
use namespace::autoclean;

use JSON;


BEGIN { extends 'Catalyst::Controller' }



sub get_training_pop_gebvs :Path('/solgs/get/gebvs/training/population/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{training_pop_id} = $c->req->param('training_pop_id');
    $c->stash->{trait_id}        = $c->req->param('trait_id');
    $c->stash->{population_type} = 'training_population';

    my $ret->{gebv_exists} = undef;

    $self->get_training_pop_gebv_file($c);
    my $gebv_file = $c->stash->{training_gebv_file};
   
    if (-s $gebv_file)
    {
	$c->stash->{gebv_file} = $gebv_file;
	$self->get_gebv_arrayref($c);
	my $gebv_arrayref = $c->stash->{gebv_arrayref};
	
	$ret->{gebv_exists} = 1;
	$ret->{gebv_arrayref} = $gebv_arrayref;
    }
    
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub get_selection_pop_gebvs :Path('/solgs/get/gebvs/selection/population/') Args(0) {
    my ($self, $c) = @_;

    $c->stash->{selection_pop_id} = $c->req->param('selection_pop_id');
    $c->stash->{training_pop_id}  = $c->req->param('training_pop_id');
    $c->stash->{trait_id}         = $c->req->param('trait_id');
    $c->stash->{population_type}  = 'selection_population';
 
    my $ret->{gebv_exists} = undef;

    $self->get_selection_pop_gebv_file($c);
    my $gebv_file = $c->stash->{selection_gebv_file};
    
    if (-s $gebv_file)
    {
	$c->stash->{gebv_file} = $gebv_file;
	$self->get_gebv_arrayref($c);
	my $gebv_arrayref = $c->stash->{gebv_arrayref};
	
	$ret->{gebv_exists} = 1;
	$ret->{gebv_arrayref} = $gebv_arrayref;
    }
    
    $ret = to_json($ret);
       
    $c->res->content_type('application/json');
    $c->res->body($ret);    

}


sub get_training_pop_gebv_file {
    my ($self, $c) = @_;

    my $pop_id   = $c->stash->{training_pop_id};
    my $trait_id = $c->stash->{trait_id};
    
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $gebv_file;
    
    if ($pop_id && $trait_id) 
    {
	my $dir  = $c->stash->{solgs_cache_dir};
	my $file = "rrblup_gebvs_${trait_abbr}_${pop_id}";
       
	$gebv_file = $c->controller('solGS::Files')->grep_file($dir, $file);

    }

    $c->stash->{training_gebv_file} = $gebv_file;

}


sub get_selection_pop_gebv_file {
    my ($self, $c) = @_;

    my $selection_pop_id   = $c->stash->{selection_pop_id};
    my $training_pop_id    = $c->stash->{training_pop_id};
    my $trait_id           = $c->stash->{trait_id};
      
    my $gebv_file;
    
    if ($selection_pop_id && $trait_id && $training_pop_id) 
    {
	my $dir  = $c->stash->{solgs_cache_dir};
	my $identifier = $training_pop_id . "_" . $selection_pop_id;
	my $file = "prediction_pop_gebvs_${identifier}_${trait_id}";
	$gebv_file = $c->controller('solGS::Files')->grep_file($dir, $file);
    }

    $c->stash->{selection_gebv_file} = $gebv_file;

}


sub get_gebv_arrayref {
    my ($self, $c) = @_;

    my $file = $c->stash->{gebv_file};
    my $gebv_arrayref = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $file);

    $c->stash->{gebv_arrayref} = $gebv_arrayref;
}


sub check_population_type {
    my ($self, $c, $pop_id) = @_;

    my $type = $c->model('solGS::solGS')->get_population_type($pop_id);

    $c->stash->{population_type} = $type;
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}


####
1;
####
