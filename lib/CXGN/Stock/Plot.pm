=head1 NAME

CXGN::Stock::Plot - a class for plots

=head1 DESCRIPTION

CXGN::Stock::Plot inherits from CXGN::Stock. 

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 ACCESSORS & METHODS 

=cut

package CXGN::Stock::Plot;

use Moose;

extends 'CXGN::Stock';

=head2 plants

List of plants, which may be assigned to this plot or subplots within this plot

=cut

has 'plants' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    predicate => 'has_plants'
);

=head2 subplots

List of subplots of this plot

=cut

has 'subplots' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    predicate => 'has_subplots'
);

=head2 accession

The accession contained within this plot

=cut

has 'accessions' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
    predicate => 'has_accessions'
);

sub BUILD {
    my $self = shift;
    my $schema = $self->schema();

    my $q = "SELECT stock.stock_id, stock.name, 
        (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock.type_id) AS stock_type, 
        (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock_relationship.type_id) AS relationship_type
        FROM stock_relationship 
        JOIN stock ON (stock.stock_id=stock_relationship.object_id) 
        WHERE stock_relationship.subject_id=?";

    my $h = $self->schema()->storage()->dbh()->prepare($q);
    $h->execute($self->stock_id());

    my @accessions = ();
    my @subplots = ();
    my @plants = ();    

    while (my ($stock_id, $stock_name, $stock_type, $relationship_type) = $h->fetchrow_array()) {
        if ($stock_type eq "plant") {
            push @plants, {id => $stock_id, name => $stock_name, type => $stock_type};
        }
        if ($stock_type eq "subplot") {
            push @subplots, {id => $stock_id, name => $stock_name, type => $stock_type};
        }
        if ($stock_type eq "accession") {
            push @accessions, {id => $stock_id, name => $stock_name, type => $stock_type};
        }
    }

    $self->accessions(\@accessions);
    $self->subplots(\@subplots);
    $self->plants(\@plants);
}

=head2 get_plot_contents

Retrieves the contents (subplots, plants, accessions, tissue samples, etc) of a plot in a structured hash with stockprops included.
Example:
$plot_data = {
    id => plot_id,
    name => plot_name,
    type => plot,
    attributes => {stockprop_name => {id => x, value => 1}, ...},
    has => {
        subplot_name => {
            id => subplot_id
            type => subplot,
            attributes => {stockprop_name => {id => x, value => 1}, ...},
            has => {
                name => {
                    id => plant_id,
                    type => plant,
                    attributes => {stockprop_name => {id => x, value => 1}},
                    has => {
                        {accession data...},
                        {tissue sample data...}
                    }
                }
            }
        },
        subplot_name => {
            id => subplot_id_2,
            ...as above...
        }
    }
}

The data structure follows plot->(subplot->)(plant->(tissue_sample))accession. If this stock is not a plot, undef is returned. 

=cut

sub get_plot_contents {
    my $self = shift;

    my $plot_id = $self->stock_id();

    my $plot_structure = {};

    if ($self->type() ne "plot") {
        return $plot_structure;
    }

    $plot_structure->{type} = $self->type();
    $plot_structure->{name} = $self->name();
    $plot_structure->{id} = $plot_id;

    my $relationship_q = "SELECT stock.stock_id, stock.name, 
        (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock.type_id) AS stock_type, 
        (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock_relationship.type_id) AS relationship_type
        FROM stock_relationship 
        JOIN stock ON (stock.stock_id=stock_relationship.object_id) 
        WHERE stock_relationship.subject_id=?"; #For plots, this returns accessions, subplots, and plants. For subplots, this returns accessions. For plants, this returns parent subplot and accessions. 
    my $stockprops_q = "SELECT cvterm.name, cvterm_id, value FROM stockprop
        JOIN cvterm ON (cvterm.cvterm_id=stockprop.type_id)
        WHERE stockprop.stock_id=?"; #gets all stockprops for any stock. 

    my $tissue_sample_q = "SELECT * FROM 
    (SELECT stock.stock_id, stock.name, 
    (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock.type_id) AS stock_type, 
    (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock_relationship.type_id) AS relationship_type
    FROM stock_relationship 
    JOIN stock ON (stock.stock_id=stock_relationship.subject_id) 
    WHERE stock_relationship.object_id=?) AS tissue_samples_subquery
    WHERE stock_type='tissue_sample'"; #only useful for plants, where it gives tissue samples. 
    
    my $h = $self->schema()->storage()->dbh()->prepare($stockprops_q);
    $h->execute($plot_id);

    while (my ($stockprop, $stockprop_id, $value) = $h->fetchrow_array()) { #get plot stockprops
        $plot_structure->{attributes}->{$stockprop} = {
            id => $stockprop_id,
            value => $value
        };
    }

    $h = $self->schema()->storage()->dbh()->prepare($relationship_q);
    $h->execute($plot_id);

    my @stocks = (@{$self->plants()}, @{$self->accessions()}, @{$self->subplots()});

    foreach my $plant (@{$self->plants()}) { #does not necessarily execute, need this for tissue samples
        $h = $self->schema()->storage()->dbh()->prepare($tissue_sample_q);
        $h->execute($plant->{id});

        while (my ($tissue_sample_id, $tissue_sample_name, $stock_type, $relationship_type) = $h->fetchrow_array()) {
            my $tissue_sample_data = {
                name => $tissue_sample_name,
                id => $tissue_sample_id,
                type => $stock_type
            };

            $plant->{has}->{$tissue_sample_name} = 1;
            
            push @stocks, $tissue_sample_data;
        }
    }

    foreach my $stock (@stocks) { # get stockprops of all child stocks
        $h = $self->schema()->storage()->dbh()->prepare($stockprops_q);
        $h->execute($stock->{id});

        while (my ($stockprop, $stockprop_id, $value) = $h->fetchrow_array()) {
            $stock->{attributes}->{$stockprop} = {
                id => $stockprop_id,
                value => $value
            };
        }
    }

    # we get these like this because we grabbed stockprops.
    my @accessions = grep {$_->{type} eq "accession"} @stocks;
    my @subplots = grep {$_->{type} eq "subplot"} @stocks;
    my @plants = grep {$_->{type} eq "plant"} @stocks;
    my @tissue_samples = grep {$_->{type} eq "tissue_sample"} @stocks;

    unless ( (@subplots) || (@plants) ) { #if no subplots or plants, just add accession

        foreach my $accession (@accessions) {
            my $accession_name = $accession->{name};
            delete $accession->{name};
            $plot_structure->{has}->{$accession_name} = $accession;
        }

        return $plot_structure;
    }

    foreach my $subplot (@{$self->subplots()}) { #does not necessarily execute

        unless (@plants) { #if no plants, enter accession to subplot
            $h = $self->schema()->storage()->dbh()->prepare($relationship_q); # need to run query to future proof for multiple accessions in future
            $h->execute($subplot->{id});

            while (my ($accession_id, $accession_name, $stock_type, $relationship_type) = $h->fetchrow_array()) {
                my $accession = (grep {$_->{id} == $accession_id} @accessions)[0]; #grabs the stockprop data too, since we already have that
                my $accession_name = $accession->{name};
                delete $accession->{name};
                $subplot->{has}->{$accession_name} = $accession;
            }
        }

        my $subplot_name = $subplot->{name};
        delete $subplot->{name};
        $plot_structure->{has}->{$subplot_name} = $subplot;
    }

    foreach my $plant (@plants) { #does not necessarily execute
        $h = $self->schema()->storage()->dbh()->prepare($relationship_q);
        $h->execute($plant->{id});

        foreach my $tissue_sample (@tissue_samples) {
            if ($plant->{has}->{$tissue_sample->{name}}) {
                my $tissue_sample_name = $tissue_sample->{name};
                delete $tissue_sample->{name};
                $plant->{has}->{$tissue_sample_name} = $tissue_sample;
            }
        }

        while (my ($stock_id, $stock_name, $stock_type, $relationship_type) = $h->fetchrow_array()) { #gets parent subplot and accessions
            if ($stock_type eq "accession") {
                my $accession = (grep {$_->{id} == $stock_id} @accessions)[0];
                delete $accession->{name};
                $plant->{has}->{$stock_name} = $accession;
            } elsif ($stock_type eq "subplot") {
                my $plant_name = $plant->{name};
                delete $plant->{name};
                $plot_structure->{has}->{$stock_name}->{has}->{$plant_name} = $plant;
            } 
        }

        unless (@subplots) { #if there are no subplots, we assign the plant directly to the plot
            my $plant_name = $plant->{name};
            delete $plant->{name};
            $plot_structure->{has}->{$plant_name} = $plant;
        }
    }

    return $plot_structure;
}

=head2 get_tissue_samples

Returns a listref of tissue samples associated with this plot

=cut

sub get_tissue_samples {
    my $self = shift;
    my $schema = shift;

    my @tissue_samples;

    my $tissue_sample_q = "SELECT * FROM 
    (SELECT stock.stock_id, stock.name, 
    (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock.type_id) AS stock_type, 
    (SELECT cvterm.name FROM cvterm WHERE cvterm_id=stock_relationship.type_id) AS relationship_type
    FROM stock_relationship 
    JOIN stock ON (stock.stock_id=stock_relationship.subject_id) 
    WHERE stock_relationship.object_id=?) AS tissue_samples_subquery
    WHERE stock_type='tissue_sample'";

    foreach my $plant (@{$self->plants()}) {
        my $h = $self->schema()->storage()->dbh()->prepare($tissue_sample_q);
        $h->execute($plant->{id});

        while (my ($tissue_sample_id, $tissue_sample_name, $stock_type, $relationship_type) = $h->fetchrow_array()) {
            my $tissue_sample_data = {
                name => $tissue_sample_name,
                id => $tissue_sample_id,
                type => $stock_type
            };

            push @tissue_samples, $tissue_sample_data;
        }
    }

    return \@tissue_samples;
}

1;