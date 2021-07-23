package SGN::Controller::solGS::SelectionIndex;

use Moose;
use namespace::autoclean;

use File::Basename;
use File::Slurp qw /write_file read_file/;
use File::Spec::Functions qw / catfile catdir/;
use List::MoreUtils qw /uniq/;

use JSON;

BEGIN { extends 'Catalyst::Controller' }



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

    $ret = to_json($ret);
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub calculate_selection_index :Path('/solgs/calculate/selection/index') Args() {
    my ($self, $c) = @_;

    my $args = $c->req->param('arguments');
    $c->controller('solGS::Utils')->stash_json_args($c, $args);

    my $traits_wts = $c->stash->{rel_wts};
    my $json = JSON->new();
    my $rel_wts = $json->decode($traits_wts);
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
        $c->controller('solGS::Gebvs')->get_gebv_files_of_traits($c);

        $self->gebv_rel_weights($c, $rel_wts);
        $self->calc_selection_index($c);

	my $top_10_si = $c->stash->{top_10_selection_indices};
        my $top_10_genos = $c->controller('solGS::Utils')->convert_arrayref_to_hashref($top_10_si);

        my $link       = $c->stash->{selection_index_download_url};
        my $index_file = $c->stash->{selection_index_only_file};
	my $sindex_name = $c->stash->{file_id};

        $ret->{status} = 'No GEBV values to rank.';

        if (@$top_10_si)
        {
            $ret->{status} = 'success';
            $ret->{top_10_genotypes} = $top_10_genos;
            $ret->{download_link} = $link;
            $ret->{index_file} = $index_file;
	    $ret->{sindex_name} = $sindex_name;
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


sub download_selection_index :Path('/solgs/download/selection/index') Args(1) {
    my ($self, $c, $sindex_name) = @_;

    $c->stash->{sindex_name} = $sindex_name;
    $self->selection_index_file($c);
    my $sindex_file = $c->stash->{selection_index_only_file};

    if (-s $sindex_file)
    {
        my @sindex =  map { [ split(/\t/) ] }  read_file($sindex_file, {binmode => ':utf8'});

        $c->res->content_type("text/plain");
        $c->res->body(join "", map { $_->[0] . "\t" . $_->[1] }  @sindex);
    }

}


sub calc_selection_index {
    my ($self, $c) = @_;

    my $input_files = join("\t",
                           $c->stash->{rel_weights_file},
                           $c->stash->{gebv_files_of_traits}
        );

    $self->gebvs_selection_index_file($c);
    $self->selection_index_file($c);

    my $output_files = join("\t",
                            $c->stash->{gebvs_selection_index_file},
                            $c->stash->{selection_index_only_file}
        );


    my $file_id = $c->controller('solGS::Files')->create_file_id($c);
    $c->stash->{file_id} = $file_id;

    my $out_name = "output_files_selection_index_${file_id}";
    my $temp_dir = $c->stash->{selection_index_temp_dir};
    my $output_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $out_name);
    write_file($output_file, {binmode => ':utf8'}, $output_files);

    my $in_name = "input_files_selection_index_${file_id}";
    my $input_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, $in_name);
    write_file($input_file, {binmode => ':utf8'}, $input_files);

    $c->stash->{analysis_tempfiles_dir} = $c->stash->{selection_index_temp_dir};
    $c->stash->{output_files} = $output_file;
    $c->stash->{input_files}  = $input_file;
    $c->stash->{r_temp_file}  = "selection_index_${file_id}";
    $c->stash->{r_script}     = 'R/solGS/selection_index.r';

    $c->controller('solGS::AsyncJob')->run_r_script($c);
    $self->download_sindex_url($c);
    $self->get_top_10_selection_indices($c);
}


sub get_top_10_selection_indices {
    my ($self, $c) = @_;

    my $si_file = $c->stash->{selection_index_only_file};
    my $top_10 = $c->controller('solGS::Utils')->top_10($si_file);

    $c->stash->{top_10_selection_indices} = $top_10;
}


sub download_sindex_url {
    my ($self, $c) = @_;

    my $sindex_name = $c->stash->{file_id};
    my $url = qq | <a href="/solgs/download/selection/index/$sindex_name">Download selection indices</a> |;

    $c->stash->{selection_index_download_url} = $url;

}

sub gebv_rel_weights {
    my ($self, $c, $rel_wts) = @_;

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

   my $file_id = $c->controller('solGS::Files')->create_file_id($c);
   # my $file_id = $c->stash->{file_id};

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
	#$file_id = $c->stash->{file_id};
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
    ###my $file_id = $c->stash->{file_id};

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
