package SGN::Controller::solGS::Path;

use Moose;
use namespace::autoclean;

use JSON;

BEGIN { extends 'Catalyst::Controller' }


sub check_page_type :Path('/solgs/check/page/type') Args(0) {
	my ($self, $c) = @_;

	my $page_type = $self->page_type($c, $c->req->param('page'));

	my $ret = {'page_type' => $page_type};
	$ret = to_json($ret);

	$c->res->content_type('application/json');
    $c->res->body($ret);

}


sub model_page_url {
	my ($self, $args) = @_;

	my $trait_id = $args->{trait_id};
	my $pop_id = $args->{training_pop_id};
	my $protocol_id = $args->{genotyping_protocol_id};

	if ($args->{data_set_type} =~ /combined/)
	{
		return "/solgs/model/combined/trials/$pop_id/trait/$trait_id/gp/$protocol_id";
	}
	else
	{
		return "/solgs/trait/$trait_id/population/$pop_id/gp/$protocol_id";
	}

}


sub training_page_url {
	my ($self, $args) = @_;

	my $pop_id = $args->{training_pop_id};
	my $protocol_id = $args->{genotyping_protocol_id};

	if ( $args->{data_set_type} =~ /combined/)
	{
		return "/solgs/populations/combined/$pop_id/gp/$protocol_id";
	}
	else
	{
		return "/solgs/population/$pop_id/gp/$protocol_id";
	}

}


sub trial_page_url {
	my ($self, $trial_id) = @_;

    return "/breeders/trial/$trial_id";

}


sub selection_page_url {
    my ($self, $args) = @_;

    my $tr_pop_id      = $args->{training_pop_id};
    my $sel_pop_id    = $args->{selection_pop_id};
    my $trait_id        = $args->{trait_id};
    my $protocol_id     = $args->{genotyping_protocol_id};
	my $sel_protocol_id = $args->{selection_pop_genotyping_protocol_id};

	$protocol_id .= '-' .$sel_protocol_id if $sel_protocol_id;
	if ($args->{data_set_type} =~ /combined populations/)
	{
	   return "/solgs/combined/model/$tr_pop_id/selection/$sel_pop_id/trait/$trait_id/gp/$protocol_id";
	}
	else
	{
	    return "/solgs/selection/$sel_pop_id/model/$tr_pop_id/trait/$trait_id/gp/$protocol_id";
	}

}


sub create_hyperlink {
	my ($self, $url, $text) = @_;

	my $link = qq | <a href="$url">$text</a> |;

	return $link;

}


sub page_type {
	my ($self, $c, $url) = @_;

	my $base = $c->req->base;
	$url =~ s/$base//;

    my $model_pages = 'solgs/trait'
    . '|solgs/traits/all/'
    . '|solgs/model/combined/trials/'
    . '|solgs/models/combined/trials/';

    my $selection_pop_pages = 'solgs/selection'
    . '|solgs/combined/model/';

	my $training_pop_pages = 'solgs/population/'
	. '|solgs/populations/combined/';

	my $search_page = 'solgs/search'
	. '|solgs'; 

	my $type;
	if ($url =~ $model_pages)
	{
		$type = 'training model';
	}
	elsif ($url =~ $selection_pop_pages)
	{
		$type = 'selection population';
	}
	elsif ($url =~ $training_pop_pages) 
	{
		$type = 'training population';
	}
	elsif ($url =~ /^solgs\/search|^solgs$/) 
	{
		$type = 'home page';
	}

	return $type;

}


sub parse_ids {
	my ($self, $c) = @_;

	my $path = $c->req->path;
	my $page_type = $self->page_type($c, $path);
	
	my $ids = {};
	if ($page_type =~ /selection/)
	{
		my @parts = split(/\//, $path);
		my @num = grep(/\d+/, @parts);
		my $protocol_id = $num[3];

		my ($protocol_id, $sel_pop_protocol_id);
		
		if ($num[3] =~ /-/) {
			($protocol_id, $sel_pop_protocol_id) = split(/-/, $protocol_id);
		} else {
			$protocol_id = $num[3];
		}

		$ids = {
			'genotyping_protocol_id' => $protocol_id,
			'selection_pop_genotyping_protocol_id' => $sel_pop_protocol_id,
			'trait_id' => $num[2]
		};

		if ($path =~ /combined/)
		{
			$ids->{'training_pop_id'} = $num[0];
			$ids->{'selection_pop_id'} = $num[1];
		}
		else
		{
			$ids->{'training_pop_id'} = $num[1];
			$ids->{'selection_pop_id'} = $num[0];
		}
	}

	return $ids;
}


sub clean_base_name {
    my ($self, $c) = @_;

    my $base = $c->req->base;
    $base =~ s/:\d+//;
    $base =~ s/(\/)$//;

   return $base;
}

####
1;
####
