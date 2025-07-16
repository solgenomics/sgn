
package CXGN::List::Validate::Plugin::Locations;

use Moose;
use Data::Dumper;

sub name { 
    return "locations";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift || [];

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);

   my $location_code_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'abbreviation', 'geolocation_property')->cvterm_id();

   my @missing;
   my @wrong_case;
   my @multiple_wrong_case;
   my @codes;

    # First filter out exact matches
    my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({
        description => {
            in => $list
        }
    });
    my @exact = $rs->get_column('description')->all();
    my %exact_map = map { $_=>1 } @exact;
    my @missing = grep { !exists $exact_map{$_} } @$list;

    # Now do more searches on the non-exact matches
    foreach my $item (@missing) {

        # find case-insensitive matches
        my $rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search({
            'lower(description)' => lc($item)
        });
        if ( $rs->count() == 1 ) {
            my $row = $rs->next();
            if ($row->description ne $item) {
                push @wrong_case, [ $item, $row->description() ];
            }
        }
        elsif ($rs->count() > 1) {
            while(my $row = $rs->next()) { 
                push @multiple_wrong_case, [ $item, $row->description() ];
            }
        }

        # find location codes
        my $rs = $schema->resultset("NaturalDiversity::NdGeolocationprop")->search(
            {
                type_id => $location_code_type_id,
                value => $item
            },
            {
                join => "nd_geolocation",
                '+select' => [ "nd_geolocation.description" ],
                '+as' => "description"
            });
        if ( $rs->count() == 1 ) {
            my $row = $rs->next();
            push @codes, [ $item, $row->get_column('description') ];
        }

    }

    return { 
        missing => \@missing,
        wrong_case => \@wrong_case,
        multiple_wrong_case => \@multiple_wrong_case,
        codes => \@codes
    };

}

1;
