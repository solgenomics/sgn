package CXGN::TimeUtils;

sub db_time_to_iso {
    my $db_time = shift;

    if ($db_time) {
        # Replace space with 'T' to follow ISO 8601 format
        $db_time =~ s/ /T/;
        return $db_time."Z";
    }

    return $db_time;
}

sub date_to_iso_timestamp {

    #get %Y-%B-%d to 2000-02-29T12:34:56Z
    my $str_date = shift;
    my $date;
    if ($str_date) {
        my  $formatted_time = Time::Piece->strptime($str_date, '%Y-%B-%d');
        $date =  $formatted_time->datetime;
        $date .= "Z";
    }

    return $date;
}

sub db_time_to_iso_utc {
    my $db_time = shift;
    my $new_time = $db_time =~ s/ /T/r;
    return $new_time."Z";
}

1;
