package SGN::Controller::solGS::SelectionIndex;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file :edit prepend_file append_file/;
use List::MoreUtils qw /uniq/;

use JSON;

BEGIN { extends 'Catalyst::Controller' }



sub selection_index_form :Path('/solgs/selection/index/form') Args(0) {
    my ($self, $c) = @_;
    
    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');
    my @traits_ids  = $c->req->param('training_traits_ids[]');
   
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{selection_pop_id} = $selection_pop_id;
    $c->stash->{training_traits_ids} = \@traits_ids;
    
    my @traits;
    if (!$selection_pop_id) 
    {    
        $c->controller('solGS::solGS')->analyzed_traits($c);
        @traits = @{ $c->stash->{selection_index_traits} }; 
    }
    else  
    {
        $c->controller('solGS::solGS')->prediction_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        @traits = @{ $c->stash->{prediction_pop_analyzed_traits} };
    }

    my $ret->{status} = 'success';
    $ret->{traits} = \@traits;
     
    $ret = to_json($ret);       
    $c->res->content_type('application/json');
    $c->res->body($ret);
    
}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args() {
    my ($self, $c) = @_;

    my $selection_pop_id = $c->req->param('selection_pop_id');
    my $training_pop_id = $c->req->param('training_pop_id');   
    
    my $traits_wts = $c->req->param('rel_wts');
    my $json = JSON->new();
    my $rel_wts = $json->decode($traits_wts);
  
    $c->stash->{pop_id} = $training_pop_id;
    $c->stash->{model_id} = $training_pop_id;
    $c->stash->{training_pop_id} = $training_pop_id;

    if ($selection_pop_id =~ /\d+/ && $training_pop_id != $selection_pop_id)
    {
        $c->stash->{selection_pop_id} = $selection_pop_id;       
    }
    else
    {
        $selection_pop_id = undef;
        $c->stash->{selection_pop_id} = $selection_pop_id;
    }

    my @traits = keys (%$rel_wts);    
    @traits    = grep {$_ ne 'rank'} @traits;
   
    my @values;
    foreach my $tr (@traits)
    {
        push @values, $rel_wts->{$tr};
    }
    
    my $ret->{status} = 'Selection index failed.';
    if (@values) 
    {
        $c->controller('solGS::TraitsGebvs')->get_gebv_files_of_traits($c);
    
        $self->gebv_rel_weights($c, $rel_wts);         
        $self->calc_selection_index($c);
         
        my $geno = $c->controller('solGS::solGS')->tohtml_genotypes($c);
        
        my $link         = $c->stash->{ranked_genotypes_download_url};             
        my $ranked_genos = $c->stash->{top_10_selection_indices};
        my $index_file   = $c->stash->{selection_index_only_file};
       
        $ret->{status} = 'No GEBV values to rank.';

        if (@$ranked_genos) 
        {
            $ret->{status}     = 'success';
            $ret->{genotypes}  = $geno;
            $ret->{link}       = $link;
            $ret->{index_file} = $index_file;
        }                     
    }  
    else
    {
	$ret->{status} = 'No relative weights submitted';
    }

    $ret = to_json($ret);
        
    $c->res->content_type('application/json');
    $c->res->body($ret);
}


sub calc_selection_index {
    my ($self, $c) = @_;

    my $training_pop_id      = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};

    my $input_files = join("\t", 
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );
   
    $c->controller('solGS::Files')->gebvs_selection_index_file($c, $selection_pop_id);
    $c->controller('solGS::Files')->selection_index_file($c, $selection_pop_id);

    my $output_files = join("\t",
                            $c->stash->{gebvs_selection_index_file},
                            $c->stash->{selection_index_only_file}
        );
    
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $selection_pop_id  if $selection_pop_id;
    
    my $name = "output_selection_index_${training_pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $output_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
    write_file($output_file, $output_files);
       
    $name = "input_selection_index_${training_pop_id}${pred_file_suffix}";
    my $input_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
    write_file($input_file, $input_files);
    
    $c->stash->{output_files} = $output_file;
    $c->stash->{input_files}  = $input_file;   
    $c->stash->{r_temp_file}  = "selection_index_${training_pop_id}${pred_file_suffix}";  
    $c->stash->{r_script}     = 'R/solGS/selection_index.r';
    
    $c->controller('solGS::solGS')->run_r_script($c);
    $c->controller('solGS::solGS')->download_urls($c);
    $self->get_top_10_selection_indices($c);
}


sub get_top_10_selection_indices {
    my ($self, $c) = @_;
    
    my $si_file = $c->stash->{selection_index_only_file};
  
    my $si_data = $c->controller('solGS::solGS')->convert_to_arrayref_of_arrays($c, $si_file);
    my @top_genotypes = @$si_data[0..9];
    
    $c->stash->{top_10_selection_indices} = \@top_genotypes;
}


sub gebv_rel_weights {
    my ($self, $c, $rel_wts) = @_;
    
    my $training_pop_id = $c->stash->{training_pop_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};
  
    my $rel_wts_txt = "trait" . "\t" . 'relative_weight' . "\n";
    foreach my $tr (keys %$rel_wts)
    {      
        my $wt = $rel_wts->{$tr};
        unless ($tr eq 'rank')
        {
            $rel_wts_txt .= $tr . "\t" . $wt;
            $rel_wts_txt .= "\n";
        }
    }
  
    my $pred_file_suffix;
    $pred_file_suffix = '_' . $selection_pop_id  if $selection_pop_id; 
    
    my $name = "rel_weights_${training_pop_id}${pred_file_suffix}";
    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
    write_file($file, $rel_wts_txt);
    
    $c->stash->{rel_weights_file} = $file;
    
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);
  
}



####
1;
#
