
package CXGN::List::Validate::Plugin::Locations;

use Moose;
use SGN::Model::Cvterm;

sub name {
    return "locations";
}

sub validate {
    my $self   = shift;
    my $schema = shift;
    my $list   = shift || [];

    my %seen;
    my @unique = grep { defined && length && !$seen{$_}++ } @$list;

    my %is_exact;
    my @wrong_case;
    my @multiple_wrong_case;
    my @codes;

    if (@unique) {
        my $location_code_type_id = SGN::Model::Cvterm
            ->get_cvterm_row($schema, 'abbreviation', 'geolocation_property')->cvterm_id();

        # 1. exact matches
        %is_exact = map { $_ => 1 }
            $schema->resultset("NaturalDiversity::NdGeolocation")
                   ->search({ description => { in => \@unique } })
                   ->get_column('description')->all();

        my @not_exact = grep { !$is_exact{$_} } @unique;

        if (@not_exact) {
            # 2. case-insensitive description matches - one query
            my %ci;   # lc(name) => [ descriptions ]
            my $ci_rs = $schema->resultset("NaturalDiversity::NdGeolocation")->search(
                { 'lower(description)' => { in => [ map { lc } @not_exact ] } }
            );
            while ( my $row = $ci_rs->next ) {
                push @{ $ci{ lc $row->description } }, $row->description;
            }

            # 3. location-code matches - one query
            my %by_code;   # lc(code) => [ descriptions ]
            my $code_rs = $schema->resultset("NaturalDiversity::NdGeolocationprop")->search(
                {
                    'me.type_id'      => $location_code_type_id,
                    'lower(me.value)' => { in => [ map { lc } @not_exact ] },
                },
                {
                    join      => 'nd_geolocation',
                    '+select' => [ 'me.value', 'nd_geolocation.description' ],
                    '+as'     => [ 'code_value', 'description' ],
                },
            );
            while ( my $row = $code_rs->next ) {
                push @{ $by_code{ lc $row->get_column('code_value') } },
                     $row->get_column('description');
            }

            foreach my $item (@not_exact) {
                my $ci_hits   = $ci{ lc $item }      || [];
                my $code_hits = $by_code{ lc $item } || [];

                if ( @$ci_hits == 1 && $ci_hits->[0] ne $item ) {
                    push @wrong_case, [ $item, $ci_hits->[0] ];
                }
                elsif ( @$ci_hits > 1 ) {
                    push @multiple_wrong_case, [ $item, $_ ] for @$ci_hits;
                }

                # only substitute an unambiguous code match
                if ( @$code_hits == 1 ) {
                    push @codes, [ $item, $code_hits->[0] ];
                }
            }
        }
    }

    # Report against the original list so blank/undef/duplicate entries are still surfaced
    my @missing = grep { !defined($_) || $_ eq '' || !$is_exact{$_} } @$list;

    return {
        missing             => \@missing,
        wrong_case          => \@wrong_case,
        multiple_wrong_case => \@multiple_wrong_case,
        codes               => \@codes,
    };
}

1;
