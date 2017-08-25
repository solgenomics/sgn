
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
        $self->latitude( $self->latitude || $location->latitude );
        $self->longitude( $self->longitude || $location->longitude );
        $self->altitude( $self->altitude || $location->altitude );
        $self->abbreviation( $self->abbreviation || $self->_get_ndgeolocationprop('abbreviation', 'geolocation_property') );
        $self->country_name( $self->country_name || $self->_get_ndgeolocationprop('country_name', 'geolocation_property') );
        $self->country_code( $self->country_code || $self->_get_ndgeolocationprop('country_code', 'geolocation_property') );
        $self->breeding_program( $self->breeding_program || $self->_get_ndgeolocationprop('breeding_program', 'project_property') );
        $self->location_type( $self->location_type || $self->_get_ndgeolocationprop('location_type', 'geolocation_property') );
    }

    return $self;
}

sub store_location {
	my $self = shift;
    my $schema = $self->bcs_schema();
    my $nd_geolocation_id = $self->nd_geolocation_id();
    my $name = $self->name();
    my $latitude = $self->latitude();
    my $longitude = $self->longitude();
    my $altitude = $self->altitude();
    my $breeding_program = $self->breeding_program();
    my $location_type = $self->location_type();
    my ($new_row, $error);

    my $nd_geolocation_exists = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count();

    my $breeding_program_type_id = $schema->resultset('Cv::Cvterm')->find( { name => 'breeding_program' } )->cvterm_id();

    my $breeding_program_rs = $self->bcs_schema->resultset("Project::Project")->search({ name => $breeding_program });
    my $breeding_program_exists = $breeding_program_rs->search_related('projectprops', {'projectprops.type_id'=>$breeding_program_type_id});

    # $self->bcs_schema->resultset("Project::Projectprop")->search({ 'me.type_id' => $breeding_program_type_id })->search_related('project', { 'project.name' => $breeding_program });

    my $program_id = $breeding_program_exists->first->project_id();

    if (!$nd_geolocation_id && $nd_geolocation_exists > 0) { # can't add a new location with name that already exists
	    return { error => "The location - $name - already exists. Please choose another name, or use the exisiting location" };
    }

    if ($breeding_program && !$breeding_program_exists) { # can't add a new location with a breeding program that doesn't exist
	    return { error => "Breeding program $breeding_program doesn't exist in the database. Please store this location with an existing program" };
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

    my %valid_types = (
        Farm => 1,
        Field => 1,
        Greenhouse => 1,
        Screenhouse => 1,
        Lab => 1,
        Storage => 1,
        Other => 1
    );

    if (!$valid_types{$location_type}) {
        return { error => "Location type $location_type must be must be one of the following: Farm, Field, Greenhouse, Screenhouse, Lab, Storage, Other." };
    }

    if (!$nd_geolocation_id && !$nd_geolocation_exists) { # adding new location
        print STDERR "Checks completed, adding new location $name\n";
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
                $self->_store_ndgeolocationprop('abbreviation', 'geolocation_property', $self->abbreviation());
            }
            if ($self->country_name){
                $self->_store_ndgeolocationprop('country_name', 'geolocation_property', $self->country_name());
            }
            if ($self->country_code){
                $self->_store_ndgeolocationprop('country_code', 'geolocation_property', $self->country_code());
            }
            if ($self->breeding_program){
                $self->_store_ndgeolocationprop('breeding_program', 'project_property', $program_id);
            }
            if ($self->location_type){
                $self->_store_ndgeolocationprop('location_type', 'geolocation_property', $self->location_type());
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
    elsif ($nd_geolocation_id) { # editing location
        print STDERR "Checks completed, editing existing location $name\n";
        try {
            my $row = $schema->resultset("NaturalDiversity::NdGeolocation")->find({ nd_geolocation_id => $nd_geolocation_id });
            $row->description($self->name);
            $row->latitude($self->latitude);
            $row->longitude($self->longitude);
            $row->altitude($self->altitude);
            $row->update();

            if ($self->abbreviation){
                $self->_store_ndgeolocationprop('abbreviation', 'geolocation_property', $self->abbreviation());
            }
            if ($self->country_name){
                $self->_store_ndgeolocationprop('country_name', 'geolocation_property', $self->country_name());
            }
            if ($self->country_code){
                $self->_store_ndgeolocationprop('country_code', 'geolocation_property', $self->country_code());
            }
            if ($self->breeding_program){
                $self->_store_ndgeolocationprop('breeding_program', 'project_property', $program_id);
            }
            if ($self->location_type){
                $self->_store_ndgeolocationprop('location_type', 'geolocation_property', $self->location_type());
            }
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

sub _store_ndgeolocationprop {
    my $self = shift;
    my $type = shift;
    my $cv = shift;
    my $value = shift;
    print STDERR " Storing value $value with type $type\n";
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

1;
