
=head1 NAME

CXGN::Location - helper class for locations

=head1 SYNOPSYS

 my $location = CXGN::Location->new( { bcs_schema => $schema } );
 $location->set_altitude(280);
 etc.

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>

=head1 METHODS

=cut

package CXGN::Location;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
	is => 'rw',
    required => 1,
);

has 'location' => (
    isa => 'Bio::Chado::Schema::Result::NaturalDiversity::NdGeolocation',
    is => 'rw',
);

has 'is_new' => (
    isa => 'Bool',
    is => 'rw',
);

has 'nd_geolocation_id' => (
	isa => "Int",
	is => 'rw',
);

has 'name' => (
    isa => 'Str',
	is => 'rw',
);

has 'abbreviation' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'country_name' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'country_code' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'location_type' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'latitude' => (
    isa => 'Maybe[Int]',
	is => 'rw',
);

has 'longitude' => (
    isa => 'Maybe[Int]',
	is => 'rw',
);

has 'altitude' => (
    isa => 'Maybe[Int]',
	is => 'rw',
);

sub BUILD {
    my $self = shift;

    print STDERR "RUNNING BUILD FOR LOCATION.PM...\n";
    my $location;
    if ($self->nd_geolocation_id){
        $location = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id });
    }
    if (defined $location) {
        $self->location($location);
        $self->nd_geolocation_id($location->nd_geolocation_id);
        $self->name($location->description);
        $self->latitude($location->latitude);
        $self->longitude($location->longitude);
        $self->altitude($location->altitude);
        $self->abbreviation($self->_get_ndgeolocationprop('abbreviation'));
        $self->country_name($self->_get_ndgeolocationprop('country_name'));
        $self->country_code($self->_get_ndgeolocationprop('country_code'));
        $self->location_type($self->_get_ndgeolocationprop('location_type'));
    }

    return $self;
}

sub store_location {
	my $self = shift;
    my $schema = $self->bcs_schema();
    my $is_new = $self->is_new();

    my $name = $self->name();
    my $latitude = $self->latitude();
    my $longitude = $self->longitude();
    my $altitude = $self->altitude();

    my $exists = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count();

    if ($is_new && $exists > 0) { # can't add a new location with name that already exists
	    return { error => "The location - $name - already exists. Please choose another name, or use the exisiting location" };
    }
    elsif (!$is_new && $exists > 0) { # editing location
        print STDERR "Editing existing location $name\n";
        my $row = $schema->resultset("NaturalDiversity::NdGeolocation")->find({ stock_id => $self->stock_id() });
        $row->name($self->name());

    }
    elsif ($is_new && !$exists) { # adding new location

    }
    elsif (!$is_new && !$exists) { # can't edit a location that doesn't exist!

    }







    if ( ($latitude && $latitude !~ /^-?[0-9.]+$/) || ($latitude && $latitude < -90) || ($latitude && $latitude > 90)) {
	    return { error => "Latitude (in degrees) must be a number between 90 and -90." };
    }

    if ( ($longitude && $longitude !~ /^-?[0-9.]+$/) || ($longitude && $longitude < -180) || ($longitude && $longitude > 180)) {
	    return { error => "Longitude (in degrees) must be a number between 180 and -180." };
    }

    if ( ($altitude && $altitude !~ /^[0-9.]+$/) || ($altitude && $altitude < -418) || ($altitude && $altitude > 8848) ) {
        return { error => "Altitude (in meters) must be a number between -418 (Dead Sea) and 8,848 (Mt. Everest)." };
    }

    my ($new_row, $error);
	try {
        $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')
          ->new({
    	     description => $name,
    	    });

        if ($longitude) { $new_row->longitude($longitude); }
        if ($latitude) { $new_row->latitude($latitude); }
        if ($altitude) { $new_row->altitude($altitude); }
        $new_row->insert();

        #$self->ndgeolocation_id($new_row->ndgeolocation_id());
        $self->location($new_row);

        if ($self->abbreviation){
            $self->_store_ndgeolocationprop('abbreviation', $self->abbreviation());
        }
        if ($self->country_name){
            $self->_store_ndgeolocationprop('country_name', $self->country_name());
        }
        if ($self->country_code){
            $self->_store_ndgeolocationprop('country_code', $self->country_code());
        }
        if ($self->location_type){
            $self->_store_ndgeolocationprop('location_type', $self->location_type());
        }

    }
    catch {
        $error =  $_;
    };

    if ($error) {
        print STDERR "Error creating location $name: $error\n";
        return { error => $error };
    } else {
        print STDERR "Location $name added successfully\n";
        return { success => "Location $name added successfully\n" };
    }
}

sub delete_location {
    my $self = shift;

    my $rs = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->search({ nd_geolocation_id=> $self->nd_geolocation_id() });
    my $name = $rs->first()->description();
    my @experiments = $rs->first()->nd_experiments;
    #print STDERR "Associated experiments: ".Dumper(@experiments)."\n";

    if (@experiments) {
        my $error = "Location $name cannot be deleted because there are ".scalar @experiments." measurements associated with it from at least one trial.\n";
	    print STDERR $error;
	    return { error => $error };
	}
	else {
	    $rs->first->delete();
	    return { success => "Location $name was successfully deleted.\n" };
	}
}

sub _get_ndgeolocationprop {
    my $self = shift;
    my $type = shift;

    my $ndgeolocationprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'geolocations_property')->cvterm_id();
    my $rs = $self->schema()->resultset("NaturalDiversity::NdGeolocationprop")->search({ nd_geolocation_id=> $self->nd_geolocation_id(), type_id => $ndgeolocationprop_type_id }, { order_by => {-asc => 'nd_geolocationprop_id'} });

    my @results;
    while (my $r = $rs->next()){
        push @results, $r->value;
    }
    my $res = join ',', @results;
    return $res;
}

sub _store_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $ndgeolocationprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'geolocations_property')->name();
    my $stored_ndgeolocationprop = $self->location->create_geolocationprops({ $ndgeolocationprop => $value});
}

sub _remove_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'geolocations_property')->cvterm_id();
    my $rs = $self->schema()->resultset("NaturalDiversity::NdGeolocationprop")->search( { type_id=>$type_id, nd_geolocation_id=> $self->nd_geolocation_id(), value=>$value } );

    if ($rs->count() == 1) {
        $rs->first->delete();
        return 1;
    }
    elsif ($rs->count() == 0) {
        return 0;
    }
    else {
        print STDERR "Error removing ndgeolocationprop from location ".$self->ndgeolocation_id().". Please check this manually.\n";
        return 0;
    }

}

=head2 accessors get_name(), set_name()

 Usage:
 Desc:         retrieve and store location name from/to database
 Ret:
 Args:
 Side Effects: setter modifies the database
 Example:



sub get_name {
    my $self = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });

    if ($row) {
	return $row->description();
    }
}
=cut
sub set_name {
    my $self = shift;
    my $name = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });
    if ($row) {
	    $row->description($name);
	    $row->update();
    }
}

=head2 accessors get_latitude(), set_latitude()

 Usage:
 Desc:         retrieve and store location latitude from/to database
 Ret:
 Args:
 Side Effects: setter modifies the database
 Example:



sub get_latitude {
    my $self = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });

    if ($row) {
	return $row->latitude();
    }
}
=cut
sub set_latitude {
    my $self = shift;
    my $latitude = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });
    if ($row) {
	    $row->latitude($latitude);
	    $row->update();
    }
}

=head2 accessors get_longitude(), set_longitude()

 Usage:
 Desc:         retrieve and store location longitude from/to database
 Ret:
 Args:
 Side Effects: setter modifies the database
 Example:



sub get_longitude {
    my $self = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });

    if ($row) {
	return $row->longitude();
    }
}
=cut
sub set_longitude {
    my $self = shift;
    my $longitude = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });
    if ($row) {
	    $row->longitude($longitude);
	    $row->update();
    }
}

=head2 accessors get_altitude(), set_altitude()

 Usage:
 Desc:         retrieve and store location altitude from/to database
 Ret:
 Args:
 Side Effects: setter modifies the database
 Example:



sub get_altitude {
    my $self = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });

    if ($row) {
	return $row->altitude();
    }
}
=cut
sub set_altitude {
    my $self = shift;
    my $altitude = shift;
    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id() });
    if ($row) {
	    $row->altitude($altitude);
	    $row->update();
    }
}

1;
