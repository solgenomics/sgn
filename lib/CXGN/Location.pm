
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

has 'nd_geolocation_id' => (
	isa => 'Maybe[Int]',
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

has 'breeding_program' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'location_type' => (
    isa => 'Maybe[Str]',
	is => 'rw',
);

has 'latitude' => (
    isa => 'Maybe[Num]',
	is => 'rw',
);

has 'longitude' => (
    isa => 'Maybe[Num]',
	is => 'rw',
);

has 'altitude' => (
    isa => 'Maybe[Num]',
	is => 'rw',
);

sub BUILD {
    my $self = shift;

    print STDERR "RUNNING BUILD FOR LOCATION.PM...\n";
    my $location;
    if ($self->nd_geolocation_id){
        $location = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $self->nd_geolocation_id });
        $self->location($location);
    }
    if (defined $location) {
        $self->location( $self->location || $location );
        $self->nd_geolocation_id( $self->nd_geolocation_id || $location->nd_geolocation_id );
        $self->name( $self->name || $location->description );
    }

    return $self;
}

sub store_location {
	my $self = shift;
    my $schema = $self->bcs_schema();
    my $error;

    my $nd_geolocation_id = $self->nd_geolocation_id();
    my $name = $self->name();
    $name =~ s/^\s+|\s+$//g; #trim whitespace from both ends
    my $abbreviation = $self->abbreviation();
    my $country_name = $self->country_name();
    my $country_code = $self->country_code();
    my $breeding_program = $self->breeding_program();
    my $breeding_program_id;
    my $location_type = $self->location_type();
    my $latitude = $self->latitude();
    my $longitude = $self->longitude();
    my $altitude = $self->altitude();

    # Validate properties

    if (!$nd_geolocation_id && !$name) {
        return { error => "Cannot add a new location with an undefined name. A location name is required" };
    }
    elsif (!$nd_geolocation_id && !$self->_is_valid_name($name)) { # can't add a new location with name that already exists
        return { error => "The location - $name - already exists. Please choose another name, or use the existing location" };
    }

    if (!$nd_geolocation_id && $abbreviation && !$self->_is_valid_abbreviation($abbreviation)) {
       return { error => "Abbreviation $abbreviation already exists in the database. Please choose another abbreviation" };
    }

    if ($country_name && $country_name =~ m/[0-9]/) {
       return { error => "Country name $country_name is not a valid ISO standard country name." };
    }
    
    if ($country_code && (($country_code !~ m/^[^a-z]*$/) || (length($country_code) != 3 ))) {
       return { error => "Country code $country_code is not a valid ISO Alpha-3 code." };
    }

    if ($breeding_program && !$self->_is_valid_program($breeding_program)) { # can't use a breeding program that doesn't exist
	    return { error => "Breeding program $breeding_program doesn't exist in the database." };
    } elsif ($breeding_program) {
        $breeding_program_id = $self->bcs_schema->resultset("Project::Project")->search({ name => $breeding_program })->first->project_id();
    }

    if ($location_type && !$self->_is_valid_type($location_type)) {
        return { error => "Location type $location_type must be must be one of the following: Farm, Field, Greenhouse, Screenhouse, Lab, Storage, Other." };
    }

    if ( ($latitude && $latitude !~ /^-?[0-9.]+$/) || ($latitude && $latitude < -90) || ($latitude && $latitude > 90)) {
	    return { error => "Latitude (in degrees) must be a number between 90 and -90." };
    }

    if ( ($longitude && $longitude !~ /^-?[0-9.]+$/) || ($longitude && $longitude < -180) || ($longitude && $longitude > 180)) {
	    return { error => "Longitude (in degrees) must be a number between 180 and -180." };
    }

    if ( ($altitude && $altitude !~ /^-?[0-9.]+$/) || ($altitude && $altitude < -418) || ($altitude && $altitude > 8848) ) {
        return { error => "Altitude (in meters) must be a number between -418 (Dead Sea) and 8,848 (Mt. Everest)." };
    }

    # Add new location if no id supplied
    if (!$nd_geolocation_id) {
        print STDERR "Checks completed, adding new location $name\n";
    	try {
            my $new_row = $schema->resultset('NaturalDiversity::NdGeolocation')
              ->new({
        	     description => $name,
        	    });

            if ($longitude) { $new_row->longitude($longitude); }
            if ($latitude) { $new_row->latitude($latitude); }
            if ($altitude) { $new_row->altitude($altitude); }
            $new_row->insert();

            #$self->ndgeolocation_id($new_row->ndgeolocation_id());
            $self->location($new_row);

            if ($abbreviation){
                $self->_store_ndgeolocationprop('abbreviation', 'geolocation_property', $abbreviation);
            }
            if ($country_name){
                $self->_store_ndgeolocationprop('country_name', 'geolocation_property', $country_name);
            }
            if ($country_code){
                $self->_store_ndgeolocationprop('country_code', 'geolocation_property', $country_code);
            }
            if ($breeding_program_id){
                $self->_store_ndgeolocationprop('breeding_program', 'project_property', $breeding_program_id);
            }
            if ($location_type){
                $self->_store_ndgeolocationprop('location_type', 'geolocation_property', $location_type);
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
            return { success => "Location $name added successfully\n", nd_geolocation_id=>$self->location()->nd_geolocation_id() };
        }
    }
    # Edit existing location if id supplied
    elsif ($nd_geolocation_id) {
        print STDERR "Checks completed, editing existing location $name\n";
        try {
            my $row = $schema->resultset("NaturalDiversity::NdGeolocation")->find({ nd_geolocation_id => $nd_geolocation_id });
            $row->description($name);
            $row->latitude($latitude);
            $row->longitude($longitude);
            $row->altitude($altitude);
            $row->update();
            $self->_update_ndgeolocationprop('abbreviation', 'geolocation_property', $abbreviation);
            $self->_update_ndgeolocationprop('country_name', 'geolocation_property', $country_name);
            $self->_update_ndgeolocationprop('country_code', 'geolocation_property', $country_code);
            $self->_update_ndgeolocationprop('location_type', 'geolocation_property', $location_type);
            $self->_update_ndgeolocationprop('breeding_program', 'project_property', $breeding_program_id);
        }
        catch {
            $error =  $_;
        };

        if ($error) {
            print STDERR "Error editing location $name: $error\n";
            return { error => $error };
        } else {
            print STDERR "Location $name was successfully updated\n";
            return { success => "Location $name was successfully updated\n" };
        }
    }
}

sub delete_location {
    my $self = shift;

    my $row = $self->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find({ nd_geolocation_id=> $self->nd_geolocation_id() });
    my $name = $row->description();
    my @experiments = $row->nd_experiments;
    #print STDERR "Associated experiments: ".Dumper(@experiments)."\n";

    if (@experiments) {
        my $error = "Location $name cannot be deleted because there are ".scalar @experiments." measurements associated with it from at least one trial.\n";
	    print STDERR $error;
        return { error => $error };
	}
	else {
	    $row->delete();
	    return { success => "Location $name was successfully deleted.\n" };
	}
}

sub _get_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $cv = shift;

    my $ndgeolocationprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $type, $cv)->cvterm_id();
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdGeolocationprop")->search({ nd_geolocation_id=> $self->nd_geolocation_id(), type_id => $ndgeolocationprop_type_id }, { order_by => {-asc => 'nd_geolocationprop_id'} });

    my @results;
    while (my $r = $rs->next()){
        push @results, $r->value;
    }
    my $res = join ',', @results;
    return $res;
}

sub _update_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $cv = shift;
    my $value = shift;
    my $existing_prop = $self->_get_ndgeolocationprop($type, $cv);

    if ($value) {
        $self->_store_ndgeolocationprop($type, $cv, $value);
    } elsif ($existing_prop) {
        $self->_remove_ndgeolocationprop($type, $cv, $existing_prop);
    }
}

sub _store_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $cv = shift;
    my $value = shift;
    #print STDERR " Storing value $value with type $type\n";
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $type, $cv)->cvterm_id();
    my $row = $self->bcs_schema()->resultset("NaturalDiversity::NdGeolocationprop")->find( { type_id=>$type_id, nd_geolocation_id=> $self->nd_geolocation_id() } );

    if (defined $row) {
        $row->value($value);
        $row->update();
    } else {
        my $stored_ndgeolocationprop = $self->location->create_geolocationprops({ $type => $value}, {cv_name => $cv });
    }
}

sub _remove_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $cv = shift;
    my $value = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $type, $cv)->cvterm_id();
    my $rs = $self->bcs_schema()->resultset("NaturalDiversity::NdGeolocationprop")->search( { type_id=>$type_id, nd_geolocation_id=> $self->nd_geolocation_id(), value=>$value } );

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

sub _is_valid_name {
    my $self = shift;
    my $name = shift;
    my $schema = $self->bcs_schema();
    my $existing_name_count = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count();
    if ($existing_name_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_abbreviation {
    my $self = shift;
    my $abbreviation = shift;
    my $schema = $self->bcs_schema();
    my $existing_abbreviation_count = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { value => $abbreviation } )->count();
    if ($existing_abbreviation_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_program {
    my $self = shift;
    my $program = shift;
    my $schema = $self->bcs_schema();
    my $existing_program_count = $schema->resultset('Project::Project')->search(
        {
            'type.name'=> 'breeding_program',
            'me.name' => $program
        },
        {
            join => {
                'projectprops' =>
                'type'
            }
        }
    )->count();
    if ($existing_program_count < 1) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_type {
    my $self = shift;
    my $type = shift;
    my %valid_types = (
        Farm => 1,
        Field => 1,
        Greenhouse => 1,
        Screenhouse => 1,
        Lab => 1,
        Storage => 1,
        Other => 1
    );
    if (!$valid_types{$type}) {
        return 0;
    }
    else {
        return 1;
    }
}

1;
