package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;


use Algorithm::Combinatorics qw /combinations/;
use Array::Utils qw(:all);
use Cache::File;
use Carp qw/ carp confess croak /;
use CXGN::Tools::Run;
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use JSON;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Storable qw/ nstore retrieve /;
use String::CRC;
use Try::Tiny;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller' }


sub get_combined_pops_id :Path('/solgs/get/combined/populations/id') Args() {
    my ($self, $c) = @_;

    my @pops_ids = $c->req->param('trials[]');

    @pops_ids = uniq(@pops_ids);

    my $protocol_id = $c->req->param('genotyping_protocol_id');

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    my $combo_pops_id;
    my $ret->{status} = 0;

    if (@pops_ids > 1)
    {
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	my $combo_pops_id = $c->stash->{combo_pops_id};

        $self->catalogue_combined_pops($c, \@pops_ids);
	$ret->{combo_pops_id} = $combo_pops_id;
	$ret->{status} = 1;
	$ret->{genotyping_protocol_id} = $c->stash->{genotyping_protocol_id};
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;

    my @pops_ids = $c->req->param('trials[]');
    my $protocol_id  = $c->req->param('genotyping_protocol_id');

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $protocol_id = $c->stash->{genotyping_protocol_id};

    my $combo_pops_id;
    my $ret->{status} = 0;

    my $not_matching_pops;
    my @g_files;

    if (scalar(@pops_ids) > 1)
    {
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	$combo_pops_id = $c->stash->{combo_pops_id};
	$c->stash->{training_pop_id} = $combo_pops_id;

        $self->catalogue_combined_pops($c, \@pops_ids);

	$c->controller('solGS::solGS')->submit_cluster_training_pop_data_query($c, \@pops_ids);

	$self->multi_pops_geno_files($c, \@pops_ids);
        my $geno_files = $c->stash->{multi_pops_geno_files};
        @g_files = split(/\t/, $geno_files);

        $c->controller('solGS::solGS')->compare_genotyping_platforms($c, \@g_files);
        $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};

        if (!$not_matching_pops)
        {
            $self->save_common_traits_acronyms($c);
        }
        else
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }

        $ret->{combined_pops_id} = $combo_pops_id;
	$ret->{genotyping_protocol_id} = $protocol_id;
    }
    else
    {
        my $pop_id = $pops_ids[0];
	$c->stash->{training_pop_id} = $pop_id;
        $c->controller('solGS::solGS')->submit_cluster_training_pop_data_query($c, \@pops_ids);
        $ret->{redirect_url} = "/solgs/population/$pop_id/gp/$protocol_id";
	$ret->{pop_id} = $pop_id;
	$ret->{genotyping_protocol_id} = $protocol_id;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub combined_trials_page :Path('/solgs/populations/combined') Args() {
    my ($self, $c, $combo_pops_id, $gp, $protocol_id) = @_;

    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{training_pop_id} = $combo_pops_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
    $self->get_combined_pops_list($c, $combo_pops_id);
    my $pops_list =  $c->stash->{combined_pops_list};

    my $cached;

    if ($pops_list)
    {
	$cached = $c->controller('solGS::CachedResult')->check_multi_trials_training_data($c, $pops_list, $protocol_id);
    }

    if (!$cached)
    {
    	my $msg = "Cached output for this training population  does not exist anymore.\n"
    	    . "Please go to <a href=\"/solgs/search/\">the search page</a>"
    	    . " and create the training population data.";

	$c->controller('solGS::Utils')->generic_message($c, $msg);
    }
    else
    {
	$self->save_common_traits_acronyms($c);

	$c->controller('solGS::solGS')->get_all_traits($c, $combo_pops_id);
	$c->controller('solGS::solGS')->get_acronym_pairs($c, $combo_pops_id);


	$self->combined_pops_summary($c);
	$c->stash->{template} = $c->controller('solGS::Files')->template('/population/combined/combined.mas');
    }
}


# sub model_combined_trials_trait :Path('/solgs/model/combined/trials') Args() {
#     my ($self, $c, $combo_pops_id, $trait_txt, $trait_id, $gp, $protocol_id) = @_;
#
#     $c->stash->{combo_pops_id} = $combo_pops_id;
#     $c->stash->{trait_id}      = $trait_id;
#
#     $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);
#
#     $c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $combo_pops_id, $trait_id);
#     my $gebv_file = $c->stash->{rrblup_training_gebvs_file};
#
#     if ( -s $gebv_file )
#     {
#         $c->res->redirect("/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id/gp/$protocol_id");
#         $c->detach();
#     }
#     else
#     {
# ###	$self->combine_trait_data($c);
# 	$self->build_model_combined_trials_trait($c);
#     }
# }


sub models_combined_trials :Path('/solgs/models/combined/trials') Args() {
    my ($self, $c, $combo_pops_id, $tr_txt, $traits_selection_id, $gp, $protocol_id) = @_;

    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{model_id} = $combo_pops_id;
    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{data_set_type} = 'combined populations';

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    my @traits_ids;

    if ($traits_selection_id =~ /^\d+$/)
    {
	$c->controller('solGS::TraitsGebvs')->get_traits_selection_list($c, $traits_selection_id);
	@traits_ids = @{$c->stash->{traits_selection_list}} if $c->stash->{traits_selection_list};
    }

	$self->combined_pops_summary($c);
    my $training_pop_name = $c->stash->{training_pop_name};
    my $training_pop_desc = $c->stash->{training_pop_desc};
    my $training_pop_page = $c->stash->{training_pop_page};

    my @select_analysed_traits;

    if (!@traits_ids)
    {
	my $msg = "Cached output for this page does not exist anymore.\n"
	    . " Please go to $training_pop_page and run the analysis.";

	$c->controller('solGS::Utils')->generic_message($c, $msg);
    }
    else
    {
	my @traits_pages;
	if (scalar(@traits_ids) == 1)
	{
	    my $trait_id = $traits_ids[0];
	    $c->res->redirect("/solgs/model/combined/trials/$combo_pops_id/trait/$trait_id/gp/$protocol_id");
	    $c->detach();
	}
	else
	{
	    foreach my $trait_id (@traits_ids)
	    {
		#$self->combine_trait_data($c);
		#$self->build_model_combined_trials_trait($c);
		$c->stash->{trait_id} = $trait_id;

		$c->controller('solGS::modelAccuracy')->create_model_summary($c, $combo_pops_id, $trait_id);
		my $model_summary = $c->stash->{model_summary};

		push @traits_pages, $model_summary;
	    }
	}

	$c->stash->{training_pop_id} = $combo_pops_id;
	$c->stash->{training_pop_name} = $training_pop_name;
	$c->stash->{training_pop_desc} = $training_pop_desc;
	$c->stash->{training_pop_page} = $training_pop_page;
	$c->stash->{training_traits_ids} = \@traits_ids;

	$c->controller('solGS::solGS')->analyzed_traits($c);
	my $analyzed_traits = $c->stash->{analyzed_traits_ids};

	$c->stash->{trait_pages} = \@traits_pages;

	my @training_pop_data = ([$training_pop_page, $training_pop_desc, \@traits_pages]);

	$c->stash->{model_data} = \@training_pop_data;

	$c->controller('solGS::solGS')->get_acronym_pairs($c, $combo_pops_id);


	#$c->stash->{template} = '/solgs/population/combined/multiple_traits_output.mas';
	$c->stash->{template} = '/solgs/population/multiple_traits_output.mas';
    }
}


sub display_combined_pops_result :Path('/solgs/model/combined/trials/') Args() {
    my ($self, $c,  $combo_pops_id, $trait_key,  $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{data_set_type} = 'combined populations';
    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{training_pop_id} = $combo_pops_id;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

	my $cached = $c->controller('solGS::CachedResult')->check_single_trial_model_output($c, $combo_pops_id, $trait_id, $protocol_id);

	if (!$cached)
	{
	    my $training_pop_page = qq | <a href="/solgs/populations/combined/$combo_pops_id/gp/$protocol_id">here</a> |;

	    my $msg = "Cached output for this model does not exist anymore.\n"
		. " Please go to $training_pop_page and run the analysis.";

	    $c->controller('solGS::Utils')->generic_message($c, $msg);

	}
	else
	{

	    my $pops_cvs = $c->req->param('combined_populations');

	    if ($pops_cvs)
	    {
		my @pops = split(',', $pops_cvs);
	        $c->stash->{trait_combo_pops} = \@pops;
	    }
	    else
	    {
	        $self->get_combined_pops_list($c, $combo_pops_id);
	        $c->stash->{trait_combo_pops} = $c->stash->{combined_pops_list};
	    }

	    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

	    $self->combined_pops_summary($c);

	    $c->controller('solGS::solGS')->model_phenotype_stat($c);
	    $c->controller('solGS::Files')->validation_file($c);
	    $c->controller('solGS::modelAccuracy')->model_accuracy_report($c);
	    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
	    $c->controller('solGS::solGS')->top_blups($c,  $c->stash->{rrblup_training_gebvs_file});
	    $c->controller('solGS::Download')->training_prediction_download_urls($c);
	    $c->controller('solGS::Files')->marker_effects_file($c);
	    $c->controller('solGS::solGS')->top_markers($c, $c->stash->{marker_effects_file});
	    $c->controller('solGS::solGS')->model_parameters($c);

	    #$c->stash->{template} = $c->controller('solGS::Files')->template('/model/combined/populations/trait.mas');
		$c->stash->{template} = $c->controller('solGS::Files')->template('/population/trait.mas');
	}
}


sub selection_combined_pops_trait :Path('/solgs/combined/model/') Args() {
    my ($self, $c, $model_id, $sel_key, $selection_pop_id,
        $trait_key, $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{combo_pops_id}        = $model_id;
	$c->stash->{training_pop_id}        = $model_id;
    $c->stash->{trait_id}             = $trait_id;
    $c->stash->{selection_pop_id}     = $selection_pop_id;
    $c->stash->{data_set_type}        = 'combined populations';
    $c->stash->{combined_populations} = 1;

    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
	my $trait_abbr = $c->stash->{trait_abbr};

    if ($selection_pop_id =~ /list/)
    {
	$c->stash->{list_id} = $selection_pop_id =~ s/\w+_//r;
	$c->controller('solGS::List')->list_population_summary($c, $selection_pop_id);
	$c->stash->{selection_pop_id} = $c->stash->{project_id};
	$c->stash->{selection_pop_name} = $c->stash->{project_name};
	$c->stash->{selection_pop_desc} = $c->stash->{project_desc};
	$c->stash->{selection_pop_owner} = $c->stash->{owner};
    }
     elsif ($selection_pop_id =~ /dataset/)
    {
	$c->stash->{dataset_id} = $selection_pop_id =~ s/\w+_//r;
	$c->controller('solGS::Dataset')->dataset_population_summary($c);
	$c->stash->{selection_pop_id} = $c->stash->{project_id};
	$c->stash->{selection_pop_name} = $c->stash->{project_name};
	$c->stash->{selection_pop_desc} = $c->stash->{project_desc};
	$c->stash->{selection_pop_owner} = $c->stash->{owner};
    }
    else
    {
	$c->controller('solGS::solGS')->get_project_details($c, $selection_pop_id);
	$c->stash->{selection_pop_id} = $c->stash->{project_id};
	$c->stash->{selection_pop_name} = $c->stash->{project_name};
	$c->stash->{selection_pop_desc} = $c->stash->{project_desc};

        $c->controller('solGS::solGS')->get_project_owners($c, $selection_pop_id);
        $c->stash->{selection_pop_owner} = $c->stash->{project_owners};
    }

    my $mr_cnt_args = {'selection_pop' => 1,  'selection_pop_id' => $selection_pop_id};
    my $sel_pop_mr_cnt = $c->controller('solGS::solGS')->get_markers_count($c, $mr_cnt_args);
    $c->stash->{selection_markers_cnt} = $sel_pop_mr_cnt;

    my $protocol = $c->controller('solGS::genotypingProtocol')->create_protocol_url($c);
    $c->stash->{protocol_url} = $protocol;

    my $training_pop = "Training population $model_id";
    my $model_link   = qq | <a href="/solgs/model/combined/trials/$model_id/trait/$trait_id/gp/$protocol_id">$training_pop -- $trait_abbr</a>|;
    $c->stash->{model_page_url} = $model_link;
    $c->stash->{training_pop_name} = $training_pop;

    # my $identifier    = $model_id . '_' . $selection_pop_id;
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $model_id, $selection_pop_id, $trait_id);
    my $gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

    my @stock_rows = read_file($gebvs_file, {binmode => ':utf8'});
    $c->stash->{selection_stocks_cnt} = scalar(@stock_rows) - 1;

    $c->controller('solGS::solGS')->top_blups($c, $gebvs_file);

    $c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$model_id/prediction/$selection_pop_id/$trait_id/gp/$protocol_id">Download all GEBVs</a>|;

    #$c->stash->{template} = $c->controller('solGS::Files')->template('/selection/combined/selection_trait.mas');
    $c->stash->{template} = $c->controller('solGS::Files')->template('/population/selection_trait.mas');

}


sub combine_populations :Path('/solgs/combine/populations/trait') Args(1) {
    my ($self, $c, $trait_id) = @_;

    my (@pop_ids, $ids);

    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param($trait_id);
        @pop_ids = split(/,/, $ids);

        $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    }

    my $combo_pops_id;
    my $ret->{status} = 0;

    if (scalar(@pop_ids) > 1 )
    {
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
        $c->stash->{trait_combo_pops} = $ids;

        $c->stash->{trait_combine_populations} = \@pop_ids;

        $self->multi_pops_phenotype_data($c, \@pop_ids);
        $self->multi_pops_genotype_data($c, \@pop_ids);
	$self->multi_pops_geno_files($c, \@pop_ids);
	$self->multi_pops_pheno_files($c, \@pop_ids);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        my @g_files = split(/\t/, $geno_files);

        $c->controller('solGS::solGS')->compare_genotyping_platforms($c, \@g_files);
        my $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};

        if (!$not_matching_pops)
        {
            $self->cache_combined_pops_data($c);

            my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
            my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};

            unless (-s $combined_pops_geno_file  && -s $combined_pops_pheno_file )
            {
                $self->r_combine_populations($c);

                $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
                $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
            }

            if (-s $combined_pops_pheno_file && -s $combined_pops_geno_file )
            {
                my $tr_abbr = $c->stash->{trait_abbr};
                $c->stash->{data_set_type} = 'combined populations';
                $c->controller('solGS::solGS')->get_rrblup_output($c);
                my $analysis_result = $c->stash->{combo_pops_analysis_result};

                $ret->{pop_ids}       = $ids;
                $ret->{combo_pops_id} = $combo_pops_id;
                $ret->{status}        = $analysis_result;

                $self->catalogue_combined_pops($c, $ids);
              }
        }
        else
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }
    }
    else
    {
        my $pop_id = $pop_ids[0];
	$ret->{pop_id} = $pop_id;
        $ret->{redirect_url} = "/solgs/trait/$trait_id/population/$pop_id";
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub combine_populations_confrim  :Path('/solgs/combine/populations/trait/confirm') Args(1) {
    my ($self, $c, $trait_id) = @_;

    my (@pop_ids, $ids);

    if ($trait_id =~ /\d+/)
    {
        $ids = $c->req->param('confirm_populations');
        @pop_ids = split(/,/, $ids);
        if (!@pop_ids) {@pop_ids = $ids;}

        $c->stash->{trait_id} = $trait_id;
    }

    my $pop_links;
    my @selected_pops_details;

    foreach my $pop_id (@pop_ids)
    {
        my $markers     = $c->model("solGS::solGS")->get_project_genotyping_markers($pop_id);
        my @markers     = split(/\t/, $markers);
        my $markers_num = scalar(@markers);

        $c->controller('solGS::solGS')->trial_compatibility_table($c, $markers_num);
        my $match_code = $c->stash->{trial_compatibility_code};

        my $pop_rs = $c->model('solGS::solGS')->project_details($pop_id);

	$c->controller('solGS::solGS')->get_projects_details($c, $pop_rs);
	#my $pop_details  = $self->get_projects_details($c, $pop_rs);
	my $pop_details  = $c->stash->{projects_details};
        my $pop_name     = $pop_details->{$pop_id}{project_name};
        my $pop_desc     = $pop_details->{$pop_id}{project_desc};
        my $pop_year     = $pop_details->{$pop_id}{project_year};
        my $pop_location = $pop_details->{$pop_id}{project_location};

        my $checkbox = qq |<form> <input style="background-color: $match_code;" type="checkbox" checked="checked" name="project" value="$pop_id" /> </form> |;

        $match_code = qq | <div class=trial_code style="color: $match_code; background-color: $match_code; height: 100%; width:100%">code</div> |;
    push @selected_pops_details, [$checkbox,  qq|<a href="/solgs/trait/$trait_id/population/$pop_id/" onclick="solGS.waitPage()">$pop_name</a>|,
                               $pop_desc, $pop_location, $pop_year, $match_code
        ];

    }

    $c->stash->{selected_pops_details} = \@selected_pops_details;
    $c->stash->{template} = $c->controller('solGS::Files')->template('/search/result/confirm/populations.mas');

}

sub multi_pops_pheno_files {
    my ($self, $c, $pop_ids) = @_;

    $pop_ids = $c->stash->{pops_ids_list} if !$pop_ids;

    my $trait_id = $c->stash->{trait_id};
    my $files;

    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids)
        {
	    $c->controller('solGS::Files')->phenotype_file_name($c, $pop_id);
	    $files .= $c->stash->{phenotype_file_name};
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);
        }

        $c->stash->{multi_pops_pheno_files} = $files;
    }
    else
    {
	  $c->controller('solGS::Files')->phenotype_file_name($c, $pop_ids);
	  $files = $c->stash->{phenotype_file_name};
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_pheno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
        write_file($tempfile, {binmode => ':utf8'}, $files);
    }

}


sub multi_pops_geno_files {
    my ($self, $c, $pop_ids) = @_;

    $pop_ids = $c->stash->{pops_ids_list} if !$pop_ids;

    my $trait_id = $c->stash->{trait_id};
    my $files;

    if (defined reftype($pop_ids) && reftype($pop_ids) eq 'ARRAY')
    {
        foreach my $pop_id (@$pop_ids)
        {
	    $c->controller('solGS::Files')->genotype_file_name($c, $pop_id);
	    $files .= $c->stash->{genotype_file_name};
            $files .= "\t" unless (@$pop_ids[-1] eq $pop_id);
        }

        $c->stash->{multi_pops_geno_files} = $files;
    }
    else
    {
	$c->controller('solGS::Files')->genotype_file_name($c, $pop_ids);
	$files = $c->stash->{genotype_file_name};
    }

    if ($trait_id)
    {
        my $name = "trait_${trait_id}_multi_geno_files";
	my $temp_dir = $c->stash->{solgs_tempfiles_dir};
        my $tempfile = $c->controller('solGS::Files')->create_tempfile($temp_dir, $name);
        write_file($tempfile, {binmode => ':utf8'}, $files);
    }

}


sub multi_pops_phenotype_data {
    my ($self, $c, $pop_ids) = @_;

    $pop_ids = $c->stash->{pops_ids_list} if !$pop_ids;

    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)
        {
            $c->stash->{pop_id} = $pop_id;
            $c->controller('solGS::solGS')->phenotype_file($c, $pop_id);
	    push @job_ids, $c->stash->{r_job_id};
        }

	if (@job_ids)
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_pheno_jobs_ids} = \@job_ids;
	}
    }


  #  $self->multi_pops_pheno_files($c, $pop_ids);

}


sub multi_pops_genotype_data {
    my ($self, $c, $pop_ids) = @_;

    $pop_ids = $c->stash->{pops_ids_list} if !$pop_ids;

    no warnings 'uninitialized';
    my @job_ids;
    if (@$pop_ids)
    {
        foreach my $pop_id (@$pop_ids)
        {
            $c->stash->{pop_id} = $pop_id;
            $c->controller('solGS::solGS')->genotype_file($c, $pop_id);
	    push @job_ids, $c->stash->{r_job_id};
        }

	if (@job_ids)
	{
	    @job_ids = uniq(@job_ids);
	    $c->stash->{multi_pops_geno_jobs_ids} = \@job_ids;
	}
    }
#  $self->multi_pops_geno_files($c, $pop_ids);

}


sub combined_pops_catalogue_file {
    my ($self, $c) = @_;

    my $cache_data = {key       => 'combined_pops_catalogue_file',
                      file      => 'combined_pops_catalogue_file',
                      stash_key => 'combined_pops_catalogue_file',
		      cache_dir => $c->stash->{solgs_cache_dir}
    };

    $c->controller('solGS::Files')->cache_file($c, $cache_data);

}


sub catalogue_combined_pops {
    my ($self, $c, $trials_ids) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};

    if (!$combo_pops_id) {
	$c->stash->{pops_ids_list} = $trials_ids;
	$self->create_combined_pops_id($c);
	$combo_pops_id = $c->stash->{combo_pops_id};
    }

    my $entry = join(',', @$trials_ids);

    $entry  = $combo_pops_id . "\t" .  $entry;
    my @entry = ($entry);

    $self->combined_pops_catalogue_file($c);
    my $file = $c->stash->{combined_pops_catalogue_file};

    if (! -s $file)
    {
        my $header = 'combo_pops_id' . "\t" . 'trials_ids' . "\n";
        write_file($file, {binmode => ':utf8'}, ($header, $entry));
    }
    else
    {
        my (@entries) = map{ $_ =~ s/\n// ? $_ : undef } read_file($file, {binmode => ':utf8'});
        my @intersect = intersect(@entry, @entries);
        unless( @intersect )
        {
            write_file($file, {append => 1, binmode => ':utf8'}, "\n" . $entry);
        }
    }

}


sub get_combined_pops_list {
    my ($self, $c, $id) = @_;

    $id = $c->stash->{combo_pops_id} if !$id;

    $self->combined_pops_catalogue_file($c);
    my $combo_pops_catalogue_file = $c->stash->{combined_pops_catalogue_file};

    my @combos = uniq(read_file($combo_pops_catalogue_file, {binmode => ':utf8'}));

	my @pops_list;
    foreach my $entry (@combos)
    {
        if ($entry =~ m/$id/)
        {
		    chomp($entry);
	            my ($combo_pops_id, $pops)  = split(/\t/, $entry);

		    if ($id == $combo_pops_id)
		    {
				@pops_list = split(',', $pops);
				$c->stash->{combined_pops_list} = \@pops_list;
				$c->stash->{trait_combo_pops} = \@pops_list;
		    }
        }
    }

	return \@pops_list;
}


sub combined_pops_summary {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    $self->get_combined_pops_list($c, $combo_pops_id);
    my @pops_ids = @{$c->stash->{trait_combo_pops}};

    my $desc = 'This training population is a combination of ';
    my $projects_owners;

    foreach my $pop_id (@pops_ids)
    {
        $c->controller('solGS::solGS')->get_project_details($c, $pop_id);
        my $pr_name = $c->stash->{project_name};
		my $href = '/solgs/population/' . $pop_id . '/gp/' . 1;
        $desc .= '<a href=' . $href . '> ' .  $pr_name . '</a>';
       $desc .= $pop_id == $pops_ids[-1] ? '.' : ' and ';

        $c->controller('solGS::solGS')->get_project_owners($c, $pop_id);
        my $project_owner = $c->stash->{project_owners};

        if ($project_owner)
        {
             $projects_owners .= $projects_owners ? ', ' . $project_owner : $project_owner;
        }
    }

    my $marker_args = {'training_pop' => 1, 'training_pop_id' => $combo_pops_id};
    my $markers_no = $c->controller('solGS::solGS')->get_markers_count($c, $marker_args);

    my $trait_abbr = $c->stash->{trait_abbr};
    my $trait_id   = $c->stash->{trait_id};
    my $stocks_no    =  $self->count_combined_trials_lines_count($c, $combo_pops_id, $trait_id);
    my $training_pop_name = "Training population $combo_pops_id";
    my $pop_link   = qq | <a href="/solgs/populations/combined/$combo_pops_id/gp/$protocol_id">$training_pop_name </a>|;

	my $model_link;
	if ($trait_id)
	{
		$model_link   = qq | <a href="/solgs/model/combined/trials//$combo_pops_id/trait/$trait_id/gp/$protocol_id">$training_pop_name -- $trait_abbr</a>|;
	}

    my $protocol = $c->controller('solGS::genotypingProtocol')->create_protocol_url($c);

	$c->controller('solGS::Files')->traits_acronym_file($c, $combo_pops_id);
    my $traits_list_file = $c->stash->{traits_acronym_file};

    my @traits_list = read_file($traits_list_file, {binmode => ':utf8'});
    my $traits_no   = scalar(@traits_list) - 1;

    $c->stash(
	markers_no   => $markers_no,
	stocks_no    => $stocks_no,
	traits_no => $traits_no,
	training_pop_id => $combo_pops_id,
	training_pop_desc => $desc,
	training_pop_name => $training_pop_name,
	training_pop_page => $pop_link,
	owner        => $projects_owners,
	protocol_url => $protocol,
	training_pop_url  => $pop_link,
	model_page_url => $model_link
        );

}


sub cache_combined_pops_data {
    my ($self, $c) = @_;

    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};
    my $combo_pops_id = $c->stash->{combo_pops_id};

    if ($trait_abbr)
    {
	$c->stash->{data_set_type} = 'combined populations';
	$c->stash->{pop_id} =  $combo_pops_id;
	$c->controller('solGS::Files')->model_phenodata_file($c);
	$c->stash->{trait_combined_pheno_file} = $c->stash->{model_phenodata_file};
    }

    $c->controller('solGS::Files')->genotype_file_name($c, $combo_pops_id);
    $c->stash->{trait_combined_geno_file} = $c->stash->{genotype_file_name};

}


sub build_model_combined_trials_trait {
    my ($self, $c) = @_;

    $c->stash->{data_set_type} = 'combined populations';
     $c->stash->{pop_id} = $c->stash->{combo_pops_id};
    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
    my $gebv_file = $c->stash->{rrblup_training_gebvs_file};

    unless  ( -s $gebv_file )
    {

	$self->get_combine_populations_args_file($c);
	my $combine_job_file = $c->stash->{combine_populations_args_file};

	$c->stash->{prerequisite_jobs}  = $c->stash->{combine_populations_args_file};
	$c->stash->{prerequisite_type}  = 'combine_populations';

	$c->controller('solGS::solGS')->get_gs_modeling_jobs_args_file($c);
	$c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};

	$c->controller('solGS::solGS')->run_async($c);
    }
}


sub combine_data_build_multiple_traits_models {
    my ($self, $c) = @_;

    my @selected_traits =  @{$c->stash->{training_traits_ids}};
    my $combo_pops_id = $c->stash->{combo_pops_id};

    if (!@selected_traits)
    {
     croak "No traits to predict: $!\n";
    }

    my @unpredicted_traits;
    foreach my $trait_id (@selected_traits)
    {
	$c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $combo_pops_id, $trait_id);
	my $gebv_file = $c->stash->{rrblup_training_gebvs_file};

	push @unpredicted_traits, $trait_id if !-s $gebv_file;
    }

    if (@unpredicted_traits)
    {
	$c->stash->{training_traits_ids} = \@unpredicted_traits;

	$self->get_combine_populations_args_file($c);
	my $combine_job_file = $c->stash->{combine_populations_args_file};

	$c->stash->{prerequisite_jobs}  = $c->stash->{combine_populations_args_file};
	$c->stash->{prerequisite_type}  = 'combine_populations';

	$c->stash->{training_pop_id} = $combo_pops_id;
	$c->stash->{data_set_type} = 'combined populations';
	$c->controller('solGS::solGS')->get_gs_modeling_jobs_args_file($c);
	$c->stash->{dependent_jobs} =  $c->stash->{gs_modeling_jobs_args_file};

	$c->controller('solGS::solGS')->run_async($c);
    }


}


sub predict_selection_pop_combined_pops_model {
    my ($self, $c) = @_;

    my $data_set_type    = $c->stash->{data_set_type};
    my $training_pop_id  = $c->stash->{training_pop_id} ||  $c->stash->{combo_pops_id} || $c->stash->{model_id};
    my $selection_pop_id = $c->stash->{selection_pop_id};

    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{pop_id} = $training_pop_id;

    my @selected_traits = @{$c->stash->{training_traits_ids}} if $c->stash->{training_traits_ids};
print STDERR "\npredict_selection_pop_combined_pops_model: selected_traits: @selected_traits\n";
    $c->controller('solGS::solGS')->traits_with_valid_models($c);
    my @traits_with_valid_models = @{$c->stash->{traits_ids_with_valid_models}};
print STDERR "\npredict_selection_pop_combined_pops_model: traits_ids_with_valid_models: @traits_with_valid_models\n";
    $c->stash->{training_traits_ids} = \@traits_with_valid_models;

    my @prediction_traits;
    foreach my $trait_id (@selected_traits)
    {
	# my $identifier = $training_pop_id .'_' . $selection_pop_id;
	$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);

     	if (!-s $c->stash->{rrblup_selection_gebvs_file})
	{
	    push @prediction_traits, $trait_id;
	}
    }

    if (@prediction_traits)
    {
	$c->stash->{training_traits_ids} = \@prediction_traits;

	$c->controller('solGS::solGS')->get_selection_pop_query_args_file($c);
	my $pre_req = $c->stash->{selection_pop_query_args_file};

	$c->controller('solGS::Files')->selection_population_file($c, $selection_pop_id);

	$c->controller('solGS::solGS')->get_gs_modeling_jobs_args_file($c);
	my $dep_jobs =  $c->stash->{gs_modeling_jobs_args_file};

	$c->stash->{prerequisite_jobs} = $pre_req;
	$c->stash->{prerequisite_type} = 'selection_pop_download_data';
	$c->stash->{dependent_jobs} =  $dep_jobs;

	$c->controller('solGS::solGS')->run_async($c);
    }
    else
    {
	croak "No traits to predict: $!\n";
    }

}


sub combine_trait_data {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};

    my $solgs_controller = $c->controller('solGS::solGS');
    $solgs_controller->get_trait_details($c, $trait_id);

    $self->cache_combined_pops_data($c);

    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};

    my $geno_cnt  = (split(/\s+/, qx / wc -l $combined_pops_geno_file /))[0];
    my $pheno_cnt = (split(/\s+/, qx / wc -l $combined_pops_pheno_file /))[0];

    unless ( $geno_cnt > 10  && $pheno_cnt > 10 )
    {
	$self->get_combined_pops_list($c);
	my $combined_pops_list = $c->stash->{combined_pops_list};
	$c->stash->{trait_combine_populations} = $combined_pops_list;

	$self->prepare_multi_pops_data($c);

	my $background_job = $c->stash->{background_job};
	my $prerequisite_jobs = $c->stash->{multi_pops_data_jobs};

	if ($background_job)
	{
	    if ($prerequisite_jobs =~ /^:+$/)
	    {
		$prerequisite_jobs = undef;
	    }

	    if ($prerequisite_jobs)
	    {
		###Needs work####
		$c->stash->{prerequisite_jobs}  =  $prerequisite_jobs;
		$c->stash->{prerequisite_type} = 'download_data';

	    }
	}

	$self->r_combine_populations($c);
    }

}


sub combine_data_build_model {
    my ($self, $c) = @_;

    my $trait_id = $c->stash->{trait_id};
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

    $c->stash->{prerequisite_type} = 'combine_populations';

    #$self->r_combine_populations_args($c);
    $self->build_model_combined_trials_trait($c);

}


sub r_combine_populations_args {
    my ($self, $c) = @_;

    $self->combine_trait_data_input($c);
    my $input_files = $c->stash->{combine_input_files};
    my $output_files = $c->stash->{combine_output_files};
    my $temp_file_template =  $c->stash->{combine_r_temp_file};
    my $r_script  =  'R/solGS/combine_populations.r';

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $background_job = $c->stash->{background_job};

    my $cluster_files = $c->controller('solGS::solGS')->create_cluster_accesible_tmp_files($c, $temp_file_template);
    my $out_file      = $cluster_files->{out_file_temp};
    my $err_file      = $cluster_files->{err_file_temp};
    my $in_file       = $cluster_files->{in_file_temp};

    {
        my $r_cmd_file = $c->path_to($r_script);
        copy($r_cmd_file, $in_file)
            or die "could not copy '$r_cmd_file' to '$in_file'";
    }

    my $config_args = {
	'temp_dir' => $temp_dir,
	'out_file' => $out_file,
	'err_file' => $err_file
    };

    my $job_config = $c->controller('solGS::solGS')->create_cluster_config($c, $config_args);

    my $cmd = "Rscript --slave $in_file $out_file --args $input_files $output_files";

    my $args = {
	'cmd' => $cmd,
	'temp_dir' => $temp_dir,
	'config' => $job_config,
	'background_job'  => $background_job,
    };

    $c->stash->{combine_populations_args} = $args;

}


sub get_combine_populations_args_file {
    my ($self, $c) = @_;

    my $traits = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    my $combine_jobs = [];

    $self->get_combined_pops_list($c);
    my $trials = $c->stash->{combo_pops_list};

    $c->controller('solGS::solGS')->training_pop_data_query_job_args($c, $trials, $protocol_id);
    my $query_jobs = $c->stash->{training_pop_data_query_job_args};

    my $preq_jobs = {};

    foreach my $trait_id (@$traits)
    {
	$c->stash->{trait_id} = $trait_id;
	$c->controller('solGS::solGS')->get_trait_details($c);
	$self->r_combine_populations_args($c);
	push @$combine_jobs,  $c->stash->{combine_populations_args};
    }

    if ($query_jobs->[0])
    {
	$preq_jobs->{1} = $query_jobs;
	$preq_jobs->{2} = $combine_jobs;
    }
    else
    {
	$preq_jobs = $combine_jobs;
    }

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $args_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, 'combine_pops_args_file');

    nstore $preq_jobs, $args_file
	or croak "combine pops args file: $! serializing combine pops args  to $args_file ";

    $c->stash->{combine_populations_args_file} = $args_file;

}


sub combined_pops_gs_input_files {
    my ($self, $c) = @_;

    $self->cache_combined_pops_data($c);
    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};

    #$c->controller('solGS::solGS')->save_model_info_file($c);

    my $temp_dir = $c->stash->{solgs_tempfiles_dir};
    my $trait_abbr = $c->stash->{trait_abbr};
    my $trait_id   = $c->stash->{trait_id};

    $c->controller('solGS::Files')->model_info_file($c);
    my $model_info_file = $c->stash->{model_info_file};

    my $dataset_file  = $c->controller('solGS::Files')->create_tempfile($temp_dir, "dataset_info_${trait_id}");
    write_file($dataset_file, {binmode => ':utf8'}, 'combined populations');

    my $selection_pop_id = $c->stash->{selection_pop_id};
    my $selection_population_file;
    if ($selection_pop_id)
    {
	$c->controller('solGS::Files')->selection_population_file($c, $selection_pop_id);
	$selection_population_file = $c->stash->{selection_population_file};
    }

    my $input_files = join("\t",
			   $combined_pops_pheno_file,
			   $combined_pops_geno_file,
			   $model_info_file,
			   $dataset_file,
			   $selection_population_file,
	);



    my $input_file = $c->controller('solGS::Files')->create_tempfile($temp_dir, "input_files_combo_${trait_abbr}");
    write_file($input_file, {binmode => ':utf8'}, $input_files);

    $c->stash->{combined_pops_gs_input_files} = $input_file;

}


sub count_combined_trials_lines_count {
    my ($self, $c, $combo_pops_id, $trait_id) = @_;

    $combo_pops_id = $c->stash->{combo_pops_id} if !$combo_pops_id;
    $trait_id  = $c->stash->{trait_id} if !$trait_id;

    my $genos_cnt;
    my @geno_lines;
    my @genotypes;

    if ($c->req->path =~ /solgs\/model\/combined\/populations\//)
    {

	$self->cache_combined_pops_data($c);
	my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};


	if (-s $combined_pops_geno_file)
	{
	    my $args = {
	    	'training_pop_id' => $combo_pops_id,
	    	'trait_id' => $trait_id
	    };

	    $genos_cnt = $c->controller('solGS::solGS')->predicted_lines_count($c, $args);

	   # my $genos = qx /cut -f 1 $combined_pops_geno_file/;
	   # @genotypes = split(" ", $genos);
	}
    }
    else
    {
	$self->get_combined_pops_list($c);
	my $pops_ids = $c->stash->{combined_pops_list};

	$self->multi_pops_geno_files($c, $pops_ids);
	my $geno_files = $c->stash->{multi_pops_geno_files};

	my @geno_files = split(/\t/, $geno_files);

	foreach my $geno_file (@geno_files)
	{

	    my $genos = qx /cut -f 1 $geno_file/;
	    my @genos = split(" ", $genos);

	    push @genotypes, @genos;
	}

	$genos_cnt = scalar(uniq(@genotypes));
    }

    return $genos_cnt;

}


sub process_trials_list_details {
    my ($self, $c) = @_;

    my $data_str = $c->stash->{data_structure};

    if ($data_str =~ /list/)
    {
	$c->controller('solGS::List')->get_list_trials_ids($c);
    }
    elsif  ($data_str =~ /dataset/)
    {
	$c->controller('solGS::Dataset')->get_dataset_trials_ids($c);
    }

    my $pops_ids = $c->stash->{pops_ids_list} || $c->stash->{trials_ids} ||  [$c->stash->{pop_id}];

    my %pops_names = ();

    if ($pops_ids->[0])
    {
	foreach my $p_id (@$pops_ids)
	{
	    my $pr_rs = $c->controller('solGS::solGS')->get_project_details($c, $p_id);
	    $pops_names{$p_id} = $c->stash->{project_name};
	}

	if (scalar(@$pops_ids) > 1 )
	{
	    $c->stash->{pops_ids_list} = $pops_ids;
	    $c->controller('solGS::combinedTrials')->create_combined_pops_id($c);
	}
    }

    $c->stash->{trials_names} = \%pops_names;

}


sub find_common_traits {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};

    $self->get_combined_pops_list($c);
    my $combined_pops_list = $c->stash->{combined_pops_list};

    my @common_traits;
    foreach my $trial_id (@$combined_pops_list)
    {
#	my $trial_traits = $c->model('solGS::solGS')->trial_traits($pop_id);
#	my $clean_traits = $c->controller('solGS::Utils')->remove_ontology($c, $trial_traits);
	my $trait_names = $c->controller('solGS::Utils')->get_clean_trial_trait_names($c, $trial_id);

	# foreach my $tr (@$clean_traits)
	# {
	#     push @trait_names, $tr->{trait_name};
	# }

        if (@common_traits)
        {
            @common_traits = intersect(@common_traits, @$trait_names);
        }
        else
        {
            @common_traits = @$trait_names;
        }
    }

    $c->stash->{common_traits} = \@common_traits;
}


sub save_common_traits_acronyms {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};

    $self->find_common_traits($c);
    my $common_traits = $c->stash->{common_traits};

    $c->stash->{training_pop_id} = $combo_pops_id;
    $c->controller('solGS::Files')->traits_list_file($c, $combo_pops_id);
    my $traits_file = $c->stash->{traits_list_file};
    my $common_traits = join("\t", @$common_traits);
    write_file($traits_file, {binmode => ':utf8'}, $common_traits) if $traits_file;

}


sub prepare_multi_pops_data {
   my ($self, $c) = @_;

   $self->get_combined_pops_list($c);
   my $combined_pops_list = $c->stash->{combined_pops_list};

   $self->multi_pops_phenotype_data($c, $combined_pops_list);
   $self->multi_pops_genotype_data($c, $combined_pops_list);
   $self->multi_pops_geno_files($c, $combined_pops_list);
   $self->multi_pops_pheno_files($c, $combined_pops_list);

   my @all_jobs = (@{$c->stash->{multi_pops_pheno_jobs_ids}},
   		   @{$c->stash->{multi_pops_geno_jobs_ids}});

   my $prerequisite_jobs;

   if (@all_jobs && scalar(@all_jobs) > 1)
   {
       $prerequisite_jobs = join(':', @all_jobs);

   }
   else
   {
       if (@all_jobs && scalar(@all_jobs) == 1) { $prerequisite_jobs = $all_jobs[0];}
   }

   if ($prerequisite_jobs =~ /^:+$/) {$prerequisite_jobs = undef;}

   #$c->stash->{prerequisite_jobs} = $prerequisite_jobs;
   $c->stash->{multi_pops_data_jobs} = $prerequisite_jobs;
}


sub combine_trait_data_input {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
    my $trait_abbr    = $c->stash->{trait_abbr};

    $self->get_combined_pops_list($c);
    my $combo_pops_list = $c->stash->{combined_pops_list};
    $self->multi_pops_geno_files($c, $combo_pops_list);
    $self->multi_pops_pheno_files($c, $combo_pops_list);
    my $pheno_files = $c->stash->{multi_pops_pheno_files};
    my $geno_files  = $c->stash->{multi_pops_geno_files};

    $self->cache_combined_pops_data($c);
    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};


    # my $trait_info  = $trait_id . "\t" . $trait_abbr;
    # my $trait_file  = $c->controller('solGS::Files')->create_tempfile($temp_dir, "trait_info_${trait_id}");
    # write_file($trait_file, {binmode => ':utf8'}, $trait_info);

    $c->controller('solGS::solGS')->save_model_info_file($c);

    $c->controller('solGS::Files')->model_info_file($c);
    my $model_info_file = $c->stash->{model_info_file};



    my $input_files = join ("\t",
                            $pheno_files,
                            $geno_files,
                            $model_info_file,
        );

    my $output_files = join ("\t",
                             $combined_pops_pheno_file,
                             $combined_pops_geno_file,
        );

    my $temp_dir    = $c->stash->{solgs_tempfiles_dir};
    my $tempfile_input = $c->controller('solGS::Files')->create_tempfile($temp_dir, "input_files_${trait_id}_combine");
    write_file($tempfile_input, {binmode => ':utf8'}, $input_files);

    my $tempfile_output = $c->controller('solGS::Files')->create_tempfile($temp_dir, "output_files_${trait_id}_combine");
    write_file($tempfile_output, {binmode => ':utf8'}, $output_files);

    die "\nCan't call combine populations R script without a trait id." if !$trait_id;
    die "\nCan't call combine populations R script without input files." if !$input_files;
    die "\nCan't call combine populations R script without output files." if !$output_files;

    $c->stash->{combine_input_files}  = $tempfile_input;
    $c->stash->{combine_output_files} = $tempfile_output;
    $c->stash->{combine_r_temp_file}  = "combine-pops-${combo_pops_id}_${trait_id}";
}


sub r_combine_populations  {
    my ($self, $c) = @_;

    $self->combine_trait_data_input($c);
    $c->stash->{r_script}     = 'R/solGS/combine_populations.r';

    $c->controller('solGS::solGS')->run_r_script($c);

}


sub create_combined_pops_id {
    my ($self, $c) = @_;

    $c->stash->{combo_pops_id} = crc(join('', @{$c->stash->{pops_ids_list}}));

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


#####
1;
#####
