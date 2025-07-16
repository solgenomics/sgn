package SGN::Controller::solGS::Path;

use Moose;
use namespace::autoclean;

use JSON;

BEGIN { extends 'Catalyst::Controller' }

sub check_page_type : Path('/solgs/check/page/type') Args(0) {
    my ( $self, $c ) = @_;

    my $page_type = $self->page_type( $c, $c->req->param('page') );

    my $ret = { 'page_type' => $page_type };
    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}

sub model_page_url {
    my ( $self, $args ) = @_;

    my $trait_id    = $args->{trait_id};
    my $pop_id      = $args->{training_pop_id};
    my $protocol_id = $args->{genotyping_protocol_id};

    my $path;
    if ( $args->{data_set_type} =~ /combined/ ) {
        $path =
"/solgs/model/combined/trials/$pop_id/trait/$trait_id/gp/$protocol_id";
    }
    else {
        $path = "/solgs/trait/$trait_id/population/$pop_id/gp/$protocol_id";
    }

    return $path;

}

sub training_page_url {
    my ( $self, $args ) = @_;

    my $pop_id      = $args->{training_pop_id};
    my $protocol_id = $args->{genotyping_protocol_id};

    my $path;
    if ( $args->{data_set_type} =~ /combined/ ) {
        $path = "/solgs/populations/combined/$pop_id/gp/$protocol_id";
    }
    else {
        $path = "/solgs/population/$pop_id/gp/$protocol_id";
    }

    return $path;
}

sub multi_models_page_url {
    my ( $self, $args ) = @_;

    my $training_pop_id = $args->{training_pop_id};
    my $protocol_id     = $args->{genotyping_protocol_id};
    my $traits_code     = $args->{traits_selection_id};

    my $path;
    if ( $args->{data_set_type} =~ /combined/ ) {
        $path =
            "/solgs/models/combined/trials/"
          . $training_pop_id
          . '/traits/'
          . $traits_code . '/gp/'
          . $protocol_id;
    }
    else {
        $path =
            "/solgs/traits/all/population/"
          . $training_pop_id
          . '/traits/'
          . $traits_code . '/gp/'
          . $protocol_id;

    }

    return $path;

}

sub trial_page_url {
    my ( $self, $trial_id ) = @_;

    return "/breeders/trial/$trial_id";

}

sub selection_page_url {
    my ( $self, $args ) = @_;

    my $tr_pop_id   = $args->{training_pop_id};
    my $sel_pop_id  = $args->{selection_pop_id};
    my $trait_id    = $args->{trait_id};
    my $protocol_id = $args->{genotyping_protocol_id};

    my $path;
    if ( $args->{data_set_type} =~ /combined_populations/ ) {
        $path =
"/solgs/combined/model/$tr_pop_id/selection/$sel_pop_id/trait/$trait_id/gp/$protocol_id";
    }
    else {
        $path =
"/solgs/selection/$sel_pop_id/model/$tr_pop_id/trait/$trait_id/gp/$protocol_id";
    }

    return $path;

}

sub create_hyperlink {
    my ( $self, $url, $text ) = @_;

    my $link = qq | <a href="$url">$text</a> |;

    return $link;

}

sub page_type {
    my ( $self, $c, $url ) = @_;

    $url = $c->req->path if !$url;

    my $model_pages =
        'solgs/trait'
      . '|solgs/traits/all/'
      . '|solgs/model/combined/trials/'
      . '|solgs/models/combined/trials/';

    my $selection_pop_pages = 'solgs/selection' . '|solgs/combined/model/';

    my $training_pop_pages =
      'solgs/population/' . '|solgs/populations/combined/';

    my $type;
    if ( $url =~ $model_pages ) {
        $type = 'training_model';
    }
    elsif ( $url =~ $selection_pop_pages ) {
        $type = 'selection_prediction';
    }
    elsif ( $url =~ $training_pop_pages ) {
        $type = 'training_population';
    }

    return $type;

}

sub parse_ids {
    my ( $self, $c ) = @_;

    my $page_type = $self->page_type($c);
    my $path      = $c->req->path;

    my $ids = {};
    if ( $page_type =~ /selection/ ) {
        my @parts = split( /\//, $path );
        my @num   = grep( /\d+/, @parts );

        if ( $path =~ /combined/ ) {
            $ids = {
                'training_pop_id'        => $num[0],
                'selection_pop_id'       => $num[1],
                'trait_id'               => $num[2],
                'genotyping_protocol_id' => $num[3]
            };
        }
        else {
            $ids = {
                'training_pop_id'        => $num[1],
                'selection_pop_id'       => $num[0],
                'trait_id'               => $num[2],
                'genotyping_protocol_id' => $num[3]
            };

        }
    }

    return $ids;
}

sub clean_base_name {
    my ( $self, $c ) = @_;

    my $base = $c->req->base;
    $base =~ s/:\d+//;
    $base =~ s/(\/)$//;

    return $base;
}

####
1;
####
