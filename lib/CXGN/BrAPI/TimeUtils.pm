package CXGN::BrAPI::TimeUtils;

sub db_time_to_iso {
    my $db_time = shift;
    if ($db_time) {
        return $db_time."Z";
    }
}

sub db_time_to_iso_utc {
    my $db_time = shift;
    my $new_time = $db_time =~ s/ /T/r;
    return $new_time."Z";
}

1;
