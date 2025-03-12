
=head1 NAME

SGN::Controller::AJAX::Locations - a REST controller class to provide the
backend for managing Locations

=head1 DESCRIPTION

Managing Locations

=cut

package SGN::Controller::AJAX::Locations;

use Moose;
use CXGN::Location;
use CXGN::BreedersToolbox::Projects;
use CXGN::Location::ParseUpload;
use Data::Dumper;
use Try::Tiny;
use JSON;
use CXGN::NOAANCDC;
use File::Temp 'tempfile';
use Time::Piece;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub get_all_locations :Path("/ajax/location/all") Args(0) {
    my $self = shift;
    my $c = shift;

    my $location = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

    my $all_locations = $location->get_location_geojson_data();
    #print STDERR "Returning with all locations: ".$all_locations."\n";
    $c->stash->{rest} = { data => $all_locations };
}

sub store_location :Path("/ajax/location/store") Args(0) {
    my $self = shift;
    my $c = shift;
    my $params = $c->request->parameters();
    my $id = $params->{id} || undef;
    my $name = $params->{name};
    my $abbreviation = $params->{abbreviation};
    my $country_name = $params->{country_name};
    my $country_code = $params->{country_code};
    my $programs = $params->{programs};
    my $type = $params->{type};
    my $latitude = $params->{latitude};
    my $longitude = $params->{longitude};
    my $altitude = $params->{altitude};
    my $noaa_station_id = $params->{noaa_station_id} || undef;

    if (! $c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in to add or edit a location.' };
        return;
    }

    #if (! $c->user->check_roles("submitter") && !$c->user->check_roles("curator")) {
    #    $c->stash->{rest} = { error => 'You do not have the necessary privileges to add or edit locations.' };
    #    return;
    #}

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "write", "locations" )) {
	$c->stash->{rest} = { error => $message };
	$c->detach();
    }

    print STDERR "Creating location object\n";

    my $location = CXGN::Location->new( {
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        nd_geolocation_id => $id,
        name => $name,
        abbreviation => $abbreviation,
        country_name => $country_name,
        country_code => $country_code,
        breeding_programs => $programs,
        location_type => $type,
        latitude => $latitude,
        longitude => $longitude,
        altitude => $altitude,
        noaa_station_id => $noaa_station_id
    });

    my $store = $location->store_location();

    if ($store->{'error'}) {
        $c->stash->{rest} = { error => $store->{'error'} };
    }
    else {
        $c->stash->{rest} = { success => $store->{'success'}, nd_geolocation_id => $store->{'nd_geolocation_id'} };
    }

}

sub delete_location :Path('/ajax/location/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $location_id = shift;

    if (!$c->user) {  # require login
        $c->stash->{rest} = { error => "You need to be logged in to delete a location." };
        return;
    }

    #if (! ($c->user->check_roles('curator') || $c->user->check_roles('submitter'))) { # require curator or submitter roles
    #    $c->stash->{rest} = { error => "You don't have the privileges to delete a location." };
    #    return;
    #}

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "write", "locations" )) {
	$c->stash->{rest} = { error => $message };
	$c->detach();
    }

    my $location_to_delete = CXGN::Location->new( {
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        nd_geolocation_id => $location_id
    } );

    if ($location_to_delete->name() eq '[Computation]') {
	$c->stash->{rest} = { error => "The location [Computation] is needed by the system to store analyses and cannot be deleted." };
	return;
    }
    
    my $delete = $location_to_delete->delete_location();

    if ($delete->{'success'}) {
        $c->stash->{rest} = { success => $delete->{'success'} };
    }
    else {
        $c->stash->{rest} = { error => $delete->{'error'} };
    }
}

sub upload_locations : Path('/ajax/locations/upload') : ActionClass('REST') { }

sub upload_locations_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $upload = $c->req->upload('locations_upload_file');
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my (@errors, %response);


    if (!$c->user()) {
        print STDERR "User not logged in... not uploading locations.\n";
        push @errors, "You need to be logged in to upload locations.";
        $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_role = $c->user->get_object->get_user_type();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => 'location_upload',
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

    ## Store uploaded temporary file in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @errors, "Could not save file $upload_original_name in archive";
        $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
        return;
    }
    unlink $upload_tempfile;

    #parse uploaded file with appropriate plugin
    my $type = 'location generic';
    my $parser = CXGN::Location::ParseUpload->new();
    my $parse_result = $parser->parse($type, $archived_filename_with_path, $schema);

    print STDERR "Dump of parsed result:\t" . Dumper($parse_result) . "\n";

    if (!$parse_result) {
        push @errors, "Error parsing file.";
        $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
        return;
    }
    if ($parse_result->{'error'}) {
        $c->stash->{rest} = {filename => $upload_original_name, error => $parse_result->{'error'}};
        return;
    }

    foreach my $row (@{$parse_result->{'success'}}) {
        #get data from rows one at a time
        my @data = @$row;
        my $location = CXGN::Location->new( {
            bcs_schema => $schema,
            nd_geolocation_id => undef,
            name => $data[0],
            abbreviation => $data[1],
            country_code => $data[2],
            country_name => $data[3],
            breeding_programs => $data[4],
            location_type => $data[5],
            latitude => $data[6],
            longitude => $data[7],
            altitude => $data[8],
            noaa_station_id => $data[9],
        });

        my $store = $location->store_location();

        if ($store->{'error'}) {
            $response{$data[0]} = $store->{'error'};
        }
        else {
            $response{$data[0]} = $store->{'success'};
        }
    }

    $c->stash->{rest} = \%response;
}

sub get_noaa_station_id :Path("/ajax/location/get_noaa_station_id") Args(1) {
    my $self = shift;
    my $c = shift;
    my $location_id = shift;

    if (! $c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in to add or edit a location.' };
        return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $location = CXGN::Location->new({
        bcs_schema => $schema,
        nd_geolocation_id => $location_id
    });
    my $noaa_station_id = $location->noaa_station_id();

    $c->stash->{rest} = { noaa_station_id => $noaa_station_id };
}

sub noaa_ncdc_analysis :Path("/ajax/location/noaa_ncdc_analysis") Args(0) {
    my $self = shift;
    my $c = shift;
    # print STDERR Dumper $c->req->params;
    my $location_id = $c->req->param('location_id');
    my $station_id = $c->req->param('station_id');
    my $start_date = $c->req->param('start_date');
    my $end_date = $c->req->param('end_date');
    my $analysis_type = $c->req->param('analysis_type');
    my $window_start = $c->req->param('w_start');
    my $window_end = $c->req->param('w_end');
    my $cumulative_year = $c->req->param('cumul_year') eq 'yes' ? 1 : 0;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (! $c->user()) {
        $c->stash->{rest} = { error => 'You must be logged in to add or edit a location.' };
        return;
    }

    my $location = CXGN::Location->new({
        bcs_schema => $schema,
        nd_geolocation_id => $location_id
    });

    my $noaa_ncdc_access_token = $c->config->{noaa_ncdc_access_token};

    my $dir = $c->tempfiles_subdir('/tmp_noaa_ncdc_weather');
    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_noaa_ncdc_weather";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($stats_tempfile_temp_fh, $stats_tempfile_temp) = tempfile("weather_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_prcp_fh, $stats_tempfile_prcp) = tempfile("weather_XXXXX", DIR=> $tmp_stats_dir);
    my $stats_tempfile_plot_string = $c->tempfile( TEMPLATE => 'tmp_noaa_ncdc_weather/figureXXXX');
    $stats_tempfile_plot_string .= '.png';
    my $stats_tempfile_plot = $c->config->{basepath}."/".$stats_tempfile_plot_string;
    my $stats_tempfile_plot_string2 = $c->tempfile( TEMPLATE => 'tmp_noaa_ncdc_weather/figureXXXX');
    $stats_tempfile_plot_string2 .= '.png';
    my $stats_tempfile_plot2 = $c->config->{basepath}."/".$stats_tempfile_plot_string2;

    if ($analysis_type eq 'daily_temp_prec') {
        my $noaa = CXGN::NOAANCDC->new({
            bcs_schema => $schema,
            data_types => ['TMIN', 'TMAX', 'PRCP'],
            start_date => $start_date, #YYYY-MM-DD
            end_date => $end_date, #YYYY-MM-DD
            noaa_station_id => $station_id,
            noaa_ncdc_access_token => $noaa_ncdc_access_token
        });
        my ($weather_hash, $sorted_dates) = $noaa->get_daily_values();
        # print STDERR Dumper $weather_hash;
        # print STDERR Dumper $sorted_dates;

        my %years_groups;
        foreach my $date (@$sorted_dates) {
            my $year = substr($date, 0, 4);
            push @{$years_groups{$year}}, $date;
        }

        my $window_start_epoch;
        my $window_end_epoch;
        if ($window_start) {
            my $time_object = Time::Piece->strptime($window_start, "%Y-%m-%d");
            $window_start_epoch = $time_object->yday;
        }
        if ($window_end) {
            my $time_object = Time::Piece->strptime($window_end, "%Y-%m-%d");
            $window_end_epoch = $time_object->yday;
        }

        open(my $F, ">", $stats_tempfile_temp) || die "Can't open file ".$stats_tempfile_temp;
            print $F "day,date,value,variable,year\n";

            while (my($year, $dates) = each %years_groups) {
                my $tmax_rep = 0;
                my $tmin_rep = 0;
                my $tavg_rep = 0;
                my $increment = 1;
                foreach my $d (@$dates) {
                    my $time_object = Time::Piece->strptime($d, "%Y-%m-%dT%H:%M:%S");
                    my $epoch_seconds = $time_object->yday;
                    my $date = $time_object->strftime("%m-%d");

                    my $tmax = $weather_hash->{$d}->{TMAX};
                    if ($cumulative_year) {
                        $tmax_rep = $tmax_rep + $tmax;
                    }
                    else {
                        $tmax_rep = $tmax;
                    }

                    my $tmin = $weather_hash->{$d}->{TMIN};
                    if ($cumulative_year) {
                        $tmin_rep = $tmin_rep + $tmin;
                    }
                    else {
                        $tmin_rep = $tmin;
                    }

                    my $tavg = 0.5*($tmax + $tmin);
                    if ($cumulative_year) {
                        $tavg_rep = $tavg_rep + $tavg;
                    }
                    else {
                        $tavg_rep = $tavg;
                    }

                    if ($window_start_epoch) {
                        if ($epoch_seconds < $window_start_epoch) {
                            next;
                        }
                    }
                    if ($window_end_epoch) {
                        if ($epoch_seconds > $window_end_epoch) {
                            next;
                        }
                    }

                    print $F "$increment,$date,$tmax_rep,TMAX,$year\n";
                    print $F "$increment,$date,$tmin_rep,TMIN,$year\n";
                    print $F "$increment,$date,$tavg_rep,TAVG,$year\n";
                    $increment++;
                }
            }
        close($F);

        my $cmd = 'R -e "library(data.table); library(ggplot2); library(dplyr);
        data <- data.frame(fread(\''.$stats_tempfile_temp.'\', header=TRUE, sep=\',\'));
        data\$date <- as.Date(as.character(data\$date), tryFormats = c(\'%m-%d\'));
        data\$day <- as.numeric(as.character(data\$day));
        data\$year <- as.factor(as.character(data\$year));
        sp <- ggplot(data, aes(x = date, y = value)) +
        geom_line(aes(color = year), size = 0.1) +
        theme(axis.text.x=element_text(angle=90,hjust=1,vjust=0.5));
        sp <- sp + facet_wrap(~variable);
        sp <- sp + ggtitle(\'Daily Weather\');

        ggsave(\''.$stats_tempfile_plot.'\', sp, device=\'png\', width=10, height=6, limitsize = FALSE, units=\'in\');
        "';
        print STDERR $cmd;
        my $status = system($cmd);

        open(my $F, ">", $stats_tempfile_prcp) || die "Can't open file ".$stats_tempfile_prcp;
            print $F "day,date,value,variable,year\n";

            while (my($year, $dates) = each %years_groups) {
                my $prcp_rep = 0;
                my $increment = 1;
                foreach my $d (@$dates) {
                    my $time_object = Time::Piece->strptime($d, "%Y-%m-%dT%H:%M:%S");
                    my $epoch_seconds = $time_object->yday;
                    my $date = $time_object->strftime("%m-%d");

                    my $prcp = $weather_hash->{$d}->{PRCP};
                    if ($cumulative_year) {
                        $prcp_rep = $prcp_rep + $prcp;
                    }
                    else {
                        $prcp_rep = $prcp;
                    }

                    if ($window_start_epoch) {
                        if ($epoch_seconds < $window_start_epoch) {
                            next;
                        }
                    }
                    if ($window_end_epoch) {
                        if ($epoch_seconds > $window_end_epoch) {
                            next;
                        }
                    }

                    print $F "$increment,$date,$prcp_rep,PRCP,$year\n";
                    $increment++;
                }
            }
        close($F);

        my $cmd = 'R -e "library(data.table); library(ggplot2); library(dplyr);
        data <- data.frame(fread(\''.$stats_tempfile_prcp.'\', header=TRUE, sep=\',\'));
        data\$date <- as.Date(as.character(data\$date), tryFormats = c(\'%m-%d\'));
        data\$day <- as.numeric(as.character(data\$day));
        data\$year <- as.factor(as.character(data\$year));
        sp <- ggplot(data, aes(x = date, y = value)) +
        geom_line(aes(color = year), size = 0.1) +
        theme(axis.text.x=element_text(angle=90,hjust=1,vjust=0.5));
        sp <- sp + facet_wrap(~variable);
        sp <- sp + ggtitle(\'Daily Weather\');

        ggsave(\''.$stats_tempfile_plot2.'\', sp, device=\'png\', width=10, height=6, limitsize = FALSE, units=\'in\');
        "';
        print STDERR $cmd;
        my $status = system($cmd);
    }

    $c->stash->{rest} = { noaa_station_id => $station_id, plot => $stats_tempfile_plot_string, plot2 => $stats_tempfile_plot_string2 };
}


1;
