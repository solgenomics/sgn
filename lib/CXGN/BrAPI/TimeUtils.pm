package CXGN::BrAPI::TimeUtils;

sub db_time_to_iso {
    my $db_time = shift;
    return $db_time."Z";
}

1;
