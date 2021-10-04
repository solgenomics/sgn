package SGN::Controller::solGS::Path;

use Moose;
use namespace::autoclean;


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


sub selection_page_url {
    my ($self, $args) = @_;

    my $tr_pop_id      = $args->{training_pop_id};
    my $sel_pop_id    = $args->{selection_pop_id};
    my $trait_id           = $args->{trait_id};
    my $protocol_id     = $args->{genotyping_protocol_id};

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

	# my $path = $c->req->path;
	my $type;

    print STDERR "\nurl: $url\n";
    my $model_pages = '/solgs/trait'
    . '|solgs/traits/all/'
    . '|solgs/model/combined/trials/'
    . '|solgs/models/combined/trials/';

    my $selection_pop_pages = '/solgs/selection'
    . '|solgs/combined/model/';

	if ($url =~ $model_pages)
	{
		$type = 'training model';
	}
	elsif ($url =~ $selection_pop_pages)
	{
		$type = 'selection population';
	}

	return $type;

}


sub parse_ids {
	my ($self, $c) = @_;

	my $page_type = $self->page_type($c);
	my $path = $c->req->path;

	my $ids = {};
	if ($page_type =~ /selection/)
	{
		my @parts = split(/\//, $path);
		my @num = grep(/\d+/, @parts);

		if ($path =~ /combined/)
		{
			$ids = {
				'training_pop_id' => $num[0],
				'selection_pop_id' => $num[1],
				'trait_id' => $num[2],
				'genotyping_protocol_id' => $num[3]
			};
		}
		else
		{
			$ids = {
				'training_pop_id' => $num[1],
				'selection_pop_id' => $num[0],
				'trait_id' => $num[2],
				'genotyping_protocol_id' => $num[3]
			};

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
