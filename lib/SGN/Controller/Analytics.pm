
package SGN::Controller::Analytics;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;
use JSON::XS;
use Statistics::Descriptive::Full;
use Time::Piece;

BEGIN { extends 'Catalyst::Controller' };

sub view_analytics_protocols :Path('/analytics_protocols') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    $c->stash->{template} = '/analytics_protocols/index.mas';
}

sub analytics_protocol_detail :Path('/analytics_protocols') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analytics_protocol_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user = $c->user();

    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    print STDERR "Viewing analytics protocol with id $analytics_protocol_id\n";

    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_properties', 'protocol_property')->cvterm_id();
    my $protocolprop_results_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_result_summary', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.type_id, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE nd_protocolprop.type_id=$protocolprop_type_cvterm_id AND nd_protocol.nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($analytics_protocol_id);
    my ($nd_protocol_id, $name, $type_id, $description, $create_date, $props_json) = $h->fetchrow_array();

    if (! $name) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested analytics protocol ID does not exist in the database.';
        return;
    }

    my $q2 = "SELECT value
        FROM nd_protocolprop
        WHERE type_id=$protocolprop_results_type_cvterm_id AND nd_protocol_id = ?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute($analytics_protocol_id);
    my ($result_props_json) = $h2->fetchrow_array();

    my %available_types = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_imagery_analytics_env_simulation_protocol', 'protocol_type')->cvterm_id() => 'Drone Imagery Environment Simulation'
    );

    my $result_props_json_array = $result_props_json ? decode_json $result_props_json : [];
    # print STDERR Dumper $result_props_json_array;

    #Retroactively add for analytic protocols saved before this was fixed
    my $analytics_time_object = Time::Piece->strptime($create_date, "%Y-%m-%d %H:%M:%S");
    my $analytics_check_time_object = Time::Piece->strptime("2021-03-10", "%Y-%m-%d");
    if ($analytics_time_object < $analytics_check_time_object) {
        foreach my $a (@$result_props_json_array) {
            my $avg_varcomps = $a->{avg_varcomps};
            my $avg_varcomps_display = $a->{avg_varcomps_display};
            my $trait_name_encoder = $a->{trait_name_map};
            my $trait_to_time_map = $a->{trait_to_time_map};
            # print STDERR Dumper $a->{statistics_select_original};
            # print STDERR Dumper $a->{avg_varcomps};

            my @potential_times;
            #Sommer
            foreach (keys %$trait_name_encoder) {
                push @potential_times, "t$_";
            }
            #ASREML-R
            foreach (values %$trait_name_encoder) {
                push @potential_times, $_;
            }

            while (my($t, $type_obj) = each %$avg_varcomps) {
                while (my($type, $level_obj) = each %$type_obj) {
                    my @h_values;
                    foreach my $time (@potential_times) {
                        #Sommer varcomps
                        if (exists($avg_varcomps->{$t}->{$type}->{"u:id.$time-$time"}) && exists($avg_varcomps->{$t}->{$type}->{"u:units.$time-$time"})) {
                            my $h = $avg_varcomps->{$t}->{$type}->{"u:id.$time-$time"}/($avg_varcomps->{$t}->{$type}->{"u:id.$time-$time"} + $avg_varcomps->{$t}->{$type}->{"u:units.$time-$time"});
                            push @h_values, $h;
                            push @$avg_varcomps_display, {
                                type => $t,
                                type_scenario => $type,
                                level => "h2view-$time",
                                vals => [$h],
                                std => 0,
                                mean => $h
                            };
                        }
                        #ASREML-R varcomps
                        elsif (exists($avg_varcomps->{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}) && exists($avg_varcomps->{$t}->{$type}->{"units:trait!trait_$time:$time"})) {
                            my $h = $avg_varcomps->{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}/($avg_varcomps->{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"} + $avg_varcomps->{$t}->{$type}->{"units:trait!trait_$time:$time"});
                            push @h_values, $h;
                            push @$avg_varcomps_display, {
                                type => $t,
                                type_scenario => $type,
                                level => "h2view-$time",
                                vals => [$h],
                                std => 0,
                                mean => $h
                            };
                        }
                    }
                    #AIREMLF90
                    foreach my $i (1..36) {
                        if (exists($avg_varcomps->{$t}->{$type}->{"genetic_covariance_$i"}) && exists($avg_varcomps->{$t}->{$type}->{"env_covariance_$i"})) {
                            my $h = $avg_varcomps->{$t}->{$type}->{"genetic_covariance_$i"}/($avg_varcomps->{$t}->{$type}->{"genetic_covariance_$i"} + $avg_varcomps->{$t}->{$type}->{"env_covariance_$i"});
                            push @h_values, $h;
                            push @$avg_varcomps_display, {
                                type => $t,
                                type_scenario => $type,
                                level => "h2view-$i",
                                vals => [$h],
                                std => 0,
                                mean => $h
                            };
                        }
                    }
                    if (scalar(@h_values)>0) {
                        my $stat = Statistics::Descriptive::Full->new();
                        $stat->add_data(@h_values);
                        my $std = $stat->standard_deviation();
                        my $mean = $stat->mean();
                        push @$avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => "h2view-avg",
                            vals => \@h_values,
                            std => $std,
                            mean => $mean
                        };
                    }
                }
            }
            $a->{avg_varcomps_display} = $avg_varcomps_display;
        }
    }

    $c->stash->{analytics_protocol_id} = $nd_protocol_id;
    $c->stash->{analytics_protocol_name} = $name;
    $c->stash->{analytics_protocol_description} = $description;
    $c->stash->{analytics_protocol_type_id} = $type_id;
    $c->stash->{analytics_protocol_type_name} = $available_types{$type_id};
    $c->stash->{analytics_protocol_create_date} = $create_date;
    $c->stash->{analytics_protocol_properties} = decode_json $props_json;
    $c->stash->{analytics_protocol_result_summary} = $result_props_json_array;
    $c->stash->{template} = '/analytics_protocols/detail.mas';
}

1;
    
