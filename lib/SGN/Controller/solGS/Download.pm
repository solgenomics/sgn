package SGN::Controller::solGS::Download;


use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;


BEGIN { extends 'Catalyst::Controller' }



# __PACKAGE__->config(
#     default   => 'application/json',
#     stash_key => 'rest',
#     map       => { 'application/json' => 'JSON' },
#     );



sub download_validation :Path('/solgs/download/validation/pop') Args() {
    my ($self, $c, $training_pop_id, $trait, $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    $c->controller('solGS::Files')->validation_file($c);
    my $validation_file = $c->stash->{validation_file};

    unless (!-s $validation_file)
    {
        my @validation = read_file($validation_file, {binmode => ':utf8'});

        $c->res->content_type("text/plain");
        $c->res->body(join("", @validation));
    }

}


sub download_gebvs :Path('/solgs/download/gebvs/pop') Args() {
    my ($self, $c, $gebvs_id, $trait, $trait_id, $gp, $protocol_id) = @_;

	my @pops_ids;
	if ($gebvs_id =~ /-/)
	{
		@pops_ids = split(/-/, $gebvs_id);
	}
	else
	{
		@pops_ids = $gebvs_id;
	}

	my $training_pop_id = $pops_ids[0];
	my $selection_pop_id = $pops_ids[1];

    $c->stash->{genotyping_protocol_id} = $protocol_id;
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

	my $gebvs_file;
	if ($selection_pop_id)
	{
		$c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
    	$gebvs_file = $c->stash->{rrblup_selection_gebvs_file};
	}
	else
	{
		$c->controller('solGS::Files')->rrblup_training_gebvs_file($c, $training_pop_id, $trait_id);
		$gebvs_file = $c->stash->{rrblup_training_gebvs_file};
	}

    unless (!-s $gebvs_file)
    {
        my @gebvs = read_file($gebvs_file, {binmode => ':utf8'});

        $c->res->content_type("text/plain");
        $c->res->body(join("", @gebvs));
    }

}


sub download_marker_effects :Path('/solgs/download/marker/pop') Args() {
    my ($self, $c, $training_pop_id, $trait, $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    $c->controller('solGS::Files')->marker_effects_file($c);
    my $markers_file = $c->stash->{marker_effects_file};

    unless (!-s $markers_file)
    {
        my @effects = read_file($markers_file, {binmode => ':utf8'});

        $c->res->content_type("text/plain");
        $c->res->body(join("", @effects));
    }

}


sub training_prediction_download_urls {
    my ($self, $c) = @_;

    my $data_set_type = $c->stash->{data_set_type};
    my $pop_id = $c->stash->{training_pop_id};
    my $protocol_id = $c->stash->{genotyping_protocol_id};
    my $trait_id = $c->stash->{trait_id};

	my $gebvs_url = $self->gebvs_download_url($c);
	my $gebvs_link = $c->controller('solGS::Path')->create_hyperlink($gebvs_url, 'Download GEBVs');

	my $marker_url = $self->marker_effects_download_url($c);
	my $marker_link = $c->controller('solGS::Path')->create_hyperlink($marker_url, 'Download marker effects');

	my $val_url = $self->validation_download_url($c);
	my $val_link = $c->controller('solGS::Path')->create_hyperlink($val_url, 'Download model accuracy');

    $c->stash(
		blups_download_url          => $gebvs_link,
		marker_effects_download_url => $marker_link,
		validation_download_url     => $val_link
	);

}


sub gebvs_download_url {
	my ($self, $c) = @_;

	my $data_set_type = $c->stash->{data_set_type};
	my $protocol_id = $c->stash->{genotyping_protocol_id};
	my $trait_id = $c->stash->{trait_id};
	my $selection_pop_id = $c->stash->{selection_pop_id};
	my $pop_id = $c->stash->{training_pop_id};

	$pop_id .= '-' . $selection_pop_id if $selection_pop_id;

	my $url = "/solgs/download/gebvs/pop/$pop_id/trait/$trait_id/"
	. "gp/$protocol_id";

	return $url;

}


sub marker_effects_download_url {
	my ($self, $c) = @_;

	my $data_set_type = $c->stash->{data_set_type};
	my $protocol_id = $c->stash->{genotyping_protocol_id};
	my $trait_id = $c->stash->{trait_id};
	my $pop_id = $c->stash->{training_pop_id};

	my $url = "/solgs/download/marker/pop/$pop_id/trait/$trait_id/"
	. "gp/$protocol_id";

	return $url;

}

sub validation_download_url {
	my ($self, $c) = @_;

	my $data_set_type = $c->stash->{data_set_type};
	my $protocol_id = $c->stash->{genotyping_protocol_id};
	my $trait_id = $c->stash->{trait_id};
	my $pop_id = $c->stash->{training_pop_id};

	my $url = "/solgs/download/validation/pop/$pop_id/trait/$trait_id/"
   . "gp/$protocol_id";

	return $url;

}


sub selection_prediction_download_urls {
    my ($self, $c, $training_pop_id, $selection_pop_id) = @_;

    my $selected_model_traits = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    no warnings 'uninitialized';

	my $url_args = {
	  'training_pop_id' => $training_pop_id,
	  'selection_pop_id' => $selection_pop_id,
	  'genotyping_protocol_id' => $protocol_id,
	};

	my $selection_traits_ids;

    if ($selection_pop_id)
    {
        $c->controller('solGS::Gebvs')->selection_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        $selection_traits_ids = $c->stash->{selection_pop_analyzed_traits_ids};
    }

    my @selection_traits_ids = sort(@$selection_traits_ids) if $selection_traits_ids->[0];
    my @selected_model_traits = sort(@$selected_model_traits) if $selected_model_traits->[0];

	my $page = $c->req->referer;
	my $data_set_type = $page =~ /combined/ ? 'combined populations' : 'single population';
	$url_args->{data_set_type} = $data_set_type;

	my $sel_pop_page;
 	my $download_url;

    if (@selected_model_traits ~~ @selection_traits_ids)
    {
		foreach my $trait_id (@selection_traits_ids)
		{
			$url_args->{trait_id} = $trait_id;

		    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
		    my $trait_abbr = $c->stash->{trait_abbr};

			$sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);

			if ($page =~ /solgs\/traits\/all\/|solgs\/models\/combined\//)
		    {
				$download_url .= " | " if $download_url;
		    }

			$download_url .= qq |<a href="$sel_pop_page">$trait_abbr</a> |;
		}
    }

    if (!$download_url)
    {
		my $trait_id = $selected_model_traits[0];
		$url_args->{trait_id} = $trait_id;

		$sel_pop_page =  $c->controller('solGS::Path')->selection_page_url($url_args);
		$download_url = qq | <a href ="$sel_pop_page"  onclick="solGS.waitPage(this.href); return false;">[ Predict ]</a>|;
    }

    $c->stash->{selection_prediction_download} = $download_url;

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}

#####
1;
#####
