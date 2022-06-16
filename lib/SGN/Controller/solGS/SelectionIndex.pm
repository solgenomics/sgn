package SGN::Controller::solGS::SelectionIndex;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Path qw / mkpath  /;
use File::Slurp qw /write_file read_file/;
use File::Spec::Functions qw / catfile catdir/;
use List::MoreUtils qw /uniq/;

use JSON;


BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON'},
    );


sub selection_index_form :Path('/solgs/selection/index/form') Args(0) {
    my ($self, $c) = @_;


    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);
    my $selection_pop_id = $c->stash->{'selection_pop_id'};
    my $training_pop_id  = $c->stash->{'training_pop_id'};

    my $traits;
    if ($selection_pop_id)
    {
	    $c->controller('solGS::solGS')->selection_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        $traits = $c->stash->{selection_pop_analyzed_traits};
    }
    else
    {
	    $c->controller('solGS::Gebvs')->training_pop_analyzed_traits($c);
        $traits = $c->stash->{selection_index_traits};
    }

    my $ret->{status} = 'success';
    $ret->{traits} = $traits;

    $c->stash->{rest} = $ret;

}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $values = $self->check_si_form_wts($c);

    my $ret->{status} = 'Selection index failed.';
    if ($values->[0])
    {
        $self->save_rel_weights($c);
        $self->calc_selection_index($c);

        $self->prep_download_si_files($c);
        my $sindex_file = $c->stash->{download_sindex};
        my $gebvs_sindex_file = $c->stash->{download_gebvs_sindex};

        my $index_file = $c->stash->{selection_index_only_file};
        my $si_data = $c->controller("solGS::Utils")->read_file_data($index_file);

        my $sindex_name  = $c->controller('solGS::Files')->create_file_id($c);

        $ret->{status} = 'No GEBV values to rank.';

        if (@$si_data)
        {
            $ret->{status} = 'success';
            $ret->{indices} = $si_data;
            $ret->{index_file} = $index_file;
	        $ret->{sindex_name} = $sindex_name;
            $ret->{sindex_file}  =  $sindex_file;
            $ret->{gebvs_sindex_file}  =  $gebvs_sindex_file;
        }
    }
    else
    {
	    $ret->{status} = 'No relative weights submitted';
    }

    $c->stash->{rest} = $ret;
}


sub download_selection_index :Path('/solgs/download/selection/index') Args(1) {
    my ($self, $c, $sindex_name) = @_;

    $c->stash->{sindex_name} = $sindex_name;

    $self->prep_download_si_files($c);
	my $sindex_file = $c->stash->{download_sindex};
    my $gebvs_sindex_file = $c->stash->{download_gebvs_sindex};

	$c->stash->{rest}{sindex_file}  =  $sindex_file;
    $c->stash->{rest}{sindex_file}  =  $gebvs_sindex_file;

    # $c->stash->{sindex_name} = $sindex_name;
    # $self->selection_index_file($c);
    # my $sindex_file = $c->stash->{selection_index_only_file};
    #
    # if (-s $sindex_file)
    # {
    #     my @sindex =  map { [ split(/\t/) ] }  read_file($sindex_file, {binmode => ':utf8'});
    #
    #     $c->res->content_type("text/plain");
    #     $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @sindex);
    # }

}

sub prep_download_si_files {
    my ($self, $c) = @_;

    my $tmp_dir = catfile($c->config->{tempfiles_subdir}, 'selectionindex');
    my $base_tmp_dir = catfile($c->config->{basepath}, $tmp_dir);

    mkpath ([$base_tmp_dir], 0, 0755);

    $self->selection_index_file($c);
    my $sindex_file = $c->stash->{selection_index_only_file};

    $self->gebvs_selection_index_file($c);
    my $gebvs_sindex_file = $c->stash->{gebvs_selection_index_file};

    $c->controller('solGS::Files')->copy_file($sindex_file, $base_tmp_dir);
    $c->controller('solGS::Files')->copy_file($gebvs_sindex_file, $base_tmp_dir);

    $sindex_file = fileparse($sindex_file);
    $sindex_file = catfile($tmp_dir, $sindex_file);

    $gebvs_sindex_file = fileparse($gebvs_sindex_file);
    $gebvs_sindex_file = catfile($tmp_dir, $gebvs_sindex_file);

    $c->stash->{download_sindex} = $sindex_file;
    $c->stash->{download_gebvs_sindex} = $gebvs_sindex_file;

}

sub check_si_form_wts {
    my ($self, $c) = @_;

    my $rel_wts = $self->get_rel_wts_hash($c);
    my @traits = keys (%$rel_wts);
    @traits    = grep {$_ ne 'rank'} @traits;

    my @values;
    foreach my $tr (@traits)
    {
        push @values, $rel_wts->{$tr};
    }

    return \@values;

}


sub si_input_files {
    my ($self, $c) = @_;

    $c->controller('solGS::Gebvs')->get_gebv_files_of_traits($c);
    $self->rel_weights_file($c);

    my $input_files = join("\t",
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    my $temp_dir = $c->stash->{selection_index_temp_dir};

    my $in_name = "input_files_selection_index_${file_id}";
    my $input_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $in_name);
    write_file($input_file, {binmode => ':utf8'}, $input_files);

    return $input_file;

}


sub si_output_files {
    my ($self, $c) = @_;

    $self->gebvs_selection_index_file($c);
    $self->selection_index_file($c);

    my $output_files = join("\t",
                            $c->stash->{gebvs_selection_index_file},
                            $c->stash->{selection_index_only_file}
        );

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    my $out_name = "output_files_selection_index_${file_id}";
    my $temp_dir = $c->stash->{selection_index_temp_dir};
    my $output_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $out_name);
    write_file($output_file, {binmode => ':utf8'}, $output_files);

    return $output_file;

}


sub calc_selection_index {
    my ($self, $c) = @_;

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    $c->stash->{analysis_tempfiles_dir} = $c->stash->{selection_index_temp_dir};
    $c->stash->{output_files} = $self->si_output_files($c);
    $c->stash->{input_files}  = $self->si_input_files($c);
    $c->stash->{r_temp_file}  = "selection_index_${file_id}";
    $c->stash->{r_script}     = 'R/solGS/selection_index.r';

    $c->controller('solGS::AsyncJob')->run_r_script($c);

}


sub get_top_10_selection_indices {
    my ($self, $c) = @_;

    my $si_file = $c->stash->{selection_index_only_file};
    my $top_10 = $c->controller('solGS::Utils')->top_10($si_file);

    $c->stash->{top_10_selection_indices} = $top_10;
}


sub download_sindex_url {
    my ($self, $c) = @_;


    my $sindex_name = $c->controller('solGS::Files')->create_file_id($c);
    my $url = qq | <a href="/solgs/download/selection/index/$sindex_name">Download selection indices</a> |;

    $c->stash->{selection_index_download_url} = $url;

}


sub get_rel_wts_hash {
    my ($self, $c) = @_;

    my $traits_wts = $c->stash->{rel_wts};
    my $json = JSON->new();
    my $rel_wts = $json->decode($traits_wts);

    return $rel_wts;

}

sub save_rel_weights {
    my ($self, $c) = @_;

    my $rel_wts = $self->get_rel_wts_hash($c);

    my @si_wts;
    my $rel_wts_txt = "trait" . "\t" . 'relative_weight' . "\n";

    foreach my $tr (sort keys %$rel_wts)
    {
        my $wt = $rel_wts->{$tr};
        unless ($tr eq 'rank')
        {
            $rel_wts_txt .= $tr . "\t" . $wt;
            $rel_wts_txt .= "\n";
	        push @si_wts, $tr, $wt;
        }
    }

    my $si_wts = join('-', @si_wts);
    $c->stash->{sindex_weigths} = $si_wts;

    $self->rel_weights_file($c);
    my $file = $c->stash->{rel_weights_file};
    write_file($file, {binmode => ':utf8'}, $rel_wts_txt);

}


sub gebvs_selection_index_file {
    my ($self, $c) = @_;

   my $file_id = $c->stash->{sindex_name};
   if (!$file_id)
   {
       $file_id = $c->controller('solGS::Files')->create_file_id($c);
   }

    my $name = "gebvs_selection_index_${file_id}";
    my $dir = $c->stash->{selection_index_cache_dir};

    my $cache_data = { key       => $name,
		       file      => $name . '.txt',
		       stash_key => 'gebvs_selection_index_file',
		       cache_dir => $dir
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub selection_index_file {
    my ($self, $c) = @_;

    my $file_id = $c->stash->{sindex_name};
    if (!$file_id)
    {
	    $file_id = $c->controller('solGS::Files')->create_file_id($c);
    }

    my $name = "selection_index_only_${file_id}";
    my $dir = $c->stash->{selection_index_cache_dir};

    my $cache_data = { key       => $name,
		       file      => $name . '.txt',
		       stash_key => 'selection_index_only_file',
		       cache_dir => $dir
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub rel_weights_file {
    my ($self, $c) = @_;

    my $file_id = $c->controller('solGS::Files')->create_file_id($c);

    my $dir = $c->stash->{selection_index_cache_dir};
    my $name =  "rel_weights_${file_id}";

    my $cache_data = { key       => $name,
    		       file      => $name . '.txt',
    		       stash_key => 'rel_weights_file',
    		       cache_dir => $dir
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);
}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}



####
1;
#
