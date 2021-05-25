package SGN::Controller::solGS::Download;


use Moose;
use namespace::autoclean;

use Carp qw/ carp confess croak /;
use File::Slurp qw /write_file read_file/;


BEGIN { extends 'Catalyst::Controller::REST' }



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


sub download_prediction_GEBVs :Path('/solgs/download/prediction/model') Args() {
    my ($self, $c, $training_pop_id, $prediction, $selection_pop_id, $trait_id, $gp, $protocol_id) = @_;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    # my $identifier = $training_pop_id . "_" . $selection_pop_id;
    $c->controller('solGS::Files')->rrblup_selection_gebvs_file($c, $training_pop_id, $selection_pop_id, $trait_id);
    my $selection_gebvs_file = $c->stash->{rrblup_selection_gebvs_file};

    unless (!-s $selection_gebvs_file)
    {
	my @selection_gebvs =  read_file($selection_gebvs_file, {binmode => ':utf8'});
	$c->res->content_type("text/plain");
	$c->res->body(join("", @selection_gebvs));
    }

}



sub download_blups :Path('/solgs/download/blups/pop') Args() {
    my ($self, $c, $training_pop_id, $trait, $trait_id, $gp, $protocol_id) = @_;

    $c->stash->{training_pop_id} = $training_pop_id;
    $c->stash->{genotyping_protocol_id} = $protocol_id;

    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
    my $trait_abbr = $c->stash->{trait_abbr};

    my $referer = $c->req->referer;
    if ($referer =~ /combined\/populations\//)
    {
	$c->stash->{data_set_type} = 'combined populations';
	$c->stash->{combo_pops_id} = $training_pop_id;
    }

    $c->controller('solGS::Files')->rrblup_training_gebvs_file($c);
    my $training_gebvs_file = $c->stash->{rrblup_training_gebvs_file};

    unless (!-s $training_gebvs_file)
    {
        my @training_gebvs = read_file($training_gebvs_file, {binmode => ':utf8'});

        $c->res->content_type("text/plain");
        $c->res->body(join("", @training_gebvs));
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
    my $pop_id;
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    no warnings 'uninitialized';

    if ($data_set_type =~ /combined populations/)
    {
        $pop_id = $c->stash->{combo_pops_id};
    }
    else
    {
        $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};
    }

    my $trait_id = $c->stash->{trait_id};

    my $blups_url = qq | <a href="/solgs/download/blups/pop/$pop_id/trait/$trait_id/|
	. qq|gp/$protocol_id">Download all GEBVs</a>|;
    my $marker_url = qq | <a href="/solgs/download/marker/pop/$pop_id/trait/$trait_id/|
	. qq|gp/$protocol_id">Download all marker effects</a>|;

    my $validation_url = qq | <a href="/solgs/download/validation/pop/$pop_id/trait/$trait_id/|
	. qq|gp/$protocol_id">Download model accuracy report</a>|;

    $c->stash(
	blups_download_url          => $blups_url,
	marker_effects_download_url => $marker_url,
	validation_download_url     => $validation_url
	);

}



sub selection_prediction_download_urls {
    my ($self, $c, $training_pop_id, $selection_pop_id) = @_;

    my $selection_traits_ids;
    my $download_url;

    my $selected_model_traits = $c->stash->{training_traits_ids} || [$c->stash->{trait_id}];
    my $protocol_id = $c->stash->{genotyping_protocol_id};

    no warnings 'uninitialized';

    if ($selection_pop_id)
    {
        $c->controller('solGS::solGS')->prediction_pop_analyzed_traits($c, $training_pop_id, $selection_pop_id);
        $selection_traits_ids = $c->stash->{prediction_pop_analyzed_traits_ids};
    }

    my @selection_traits_ids = sort(@$selection_traits_ids) if $selection_traits_ids->[0];
    my @selected_model_traits = sort(@$selected_model_traits) if $selected_model_traits->[0];
	my $page = $c->req->referer;

    if (@selected_model_traits ~~ @selection_traits_ids)
    {
		foreach my $trait_id (@selection_traits_ids)
		{
		    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
		    my $trait_abbr = $c->stash->{trait_abbr};

		    if ($page =~ /solgs\/traits\/all\/|solgs\/models\/combined\//)
		    {
			$download_url .= " | " if $download_url;
		    }

		    if ($page =~ /combined/)
		    {
			$download_url .= qq | <a href="/solgs/combined/model/$training_pop_id/selection/|
			    . qq|$selection_pop_id/trait/$trait_id/gp/$protocol_id">$trait_abbr</a> |;
		    }
		    else
		    {
			$download_url .= qq |<a href="/solgs/selection/$selection_pop_id/model/|
			    . qq|$training_pop_id/trait/$trait_id/gp/$protocol_id">$trait_abbr</a> |;
		    }
		}
    }

    if (!$download_url)
    {
		my $trait_id = $selected_model_traits[0];
		if ($page =~ /combined/)
	    {
	    	$download_url .= qq | <a href="/solgs/combined/model/$training_pop_id/selection/|
	   	 	. qq|$selection_pop_id/trait/$trait_id/gp/$protocol_id"  onclick="solGS.waitPage(this.href); return false;">[ Predict ]</a> |;
	    }
		else
		{
			$download_url = qq | <a href ="/solgs/selection/$selection_pop_id/model/$training_pop_id/|
		    . qq|trait/$trait_id/gp/$protocol_id"  onclick="solGS.waitPage(this.href); return false;">[ Predict ]</a>|;
	    }
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
