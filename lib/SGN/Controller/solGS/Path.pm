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


####
1;
####
