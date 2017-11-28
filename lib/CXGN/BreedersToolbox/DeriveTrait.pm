
package CXGN::BreedersToolbox::DeriveTrait;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use POSIX;
use List::Util qw(sum);

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
	is => 'rw',
	required => 1,
);

has 'trait_name' => (isa => "Str",
	is => 'rw',
	required => 1,
);

has 'trial_id' => (isa => "Int",
	is => 'rw',
	required => 1,
);

has 'method' => (isa => "Str",
	is => 'rw',
);

has 'rounding' => (isa => "Str",
	is => 'rw',
);

sub generate_plot_phenotypes {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $trait_name = $self->trait_name();
    my $trial_id = $self->trial_id();
    my $method = $self->method();
    my $rounding = $self->rounding();

    my $trait_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $plant_phenotypes_for_trait = $trial->get_stock_phenotypes_for_traits([$trait_id], 'plant', ['plant_of'], 'plot', 'object');

    my %plot_plant_values;
    foreach (@$plant_phenotypes_for_trait) {
        my @value_array;
        my $plot_id = $_->[8];
        if (exists($plot_plant_values{$plot_id})) {
            @value_array = @{$plot_plant_values{$plot_id}};
        }
        push @value_array, $_->[7];
        @value_array = sort @value_array;
        $plot_plant_values{$plot_id} = \@value_array;
    }

    my @return;
    my %store_hash;
    my @plots;
    my @traits;
    push @traits, $trait_name;

    foreach my $plot_id (sort keys %plot_plant_values) {
        my %info;
        my $plot_name = $schema->resultset("Stock::Stock")->find({stock_id=>$plot_id})->uniquename();
        push @plots, $plot_name;
        $info{'plot_name'} = $plot_name;
        $info{'plant_values'} = encode_json($plot_plant_values{$plot_id});
        if ($method eq 'arithmetic_mean') {
            my $average = $self->_get_mean($plot_plant_values{$plot_id});
            $info{'output'} = $average;
            $info{'value_to_store'} = $average;
            $info{'notes'} = '';
        }
        if ($method eq 'mode') {
            my $modes = $self->_get_mode($plot_plant_values{$plot_id});
            $info{'output'} = encode_json($modes);
            if (scalar(@$modes > 1)) {
                $info{'notes'} = 'More than one mode!';
                $info{'value_to_store'} = '';
                $info{'flag_notes'} = 1;
            } else {
                $info{'notes'} = 'A single mode was found!';
                $info{'value_to_store'} = $modes->[0];
            }
        }
        if ($method eq 'maximum') {
            my $maximum = $self->_get_max($plot_plant_values{$plot_id});
            $info{'output'} = $maximum;
            $info{'value_to_store'} = $maximum;
            $info{'notes'} = '';
        }
        if ($method eq 'minimum') {
            my $minimum = $self->_get_min($plot_plant_values{$plot_id});
            $info{'output'} = $minimum;
            $info{'value_to_store'} = $minimum;
            $info{'notes'} = '';
        }
        if ($method eq 'median') {
            my $median = $self->_get_median(@{$plot_plant_values{$plot_id}});
            $info{'output'} = $median;
            $info{'value_to_store'} = $median;
            $info{'notes'} = '';
        }

        if ($rounding eq 'round') {
            $info{'value_to_store'} = ceil($info{'value_to_store'});
        } elsif ($rounding eq 'round_up') {
            my $n = $info{'value_to_store'};
            my $ceiling = ($n == int $n) ? $n : int($n + 1);
            $info{'value_to_store'} = $ceiling;
        } elsif ($rounding eq 'round_down') {
            $info{'value_to_store'} = floor($info{'value_to_store'});
        }

        $store_hash{$plot_name}->{$trait_name} = [$info{'value_to_store'}, ''];
        push @return, \%info;
    }
    return (\@return, \@plots, \@traits, \%store_hash);
}

sub _get_mean {
    my $self = shift;
    my $array = shift;
    my $sum = 0;
    foreach (@$array) {
        $sum += $_;
    }
    my $average = $sum/scalar(@$array);
    return $average;
}

sub _get_max {
    my $self = shift;
    my $array = shift;
    my @sorted = sort {$b <=> $a} @$array; 
    my $max = $sorted[0];
    return $max;
}

sub _get_min {
    my $self = shift;
    my $array = shift;
    my @sorted = sort {$a <=> $b} @$array; 
    my $min = $sorted[0];
    return $min;
}

sub _get_mode {
    my $self = shift;
    my $array = shift;
    my %count;
    my @modes;
    map{ $count{$_}++ } @$array;
    my @values;
    my $top=0;
    for my $k ( sort {$count{$b} <=> $count{$a}} keys %count ) {
        #first element has highest count
        if ($count{$k} >= $top) {
            $top = $count{$k};
            push @modes, $k;
        }
    }
    return \@modes;
}

sub _get_median {
    my $self = shift;
    my $median = sum( ( sort { $a <=> $b } @_ )[ int( $#_/2 ), ceil( $#_/2 ) ] )/2;

    return $median;
}

1;
