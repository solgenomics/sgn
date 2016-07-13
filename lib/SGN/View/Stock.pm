package SGN::View::Stock;
use base 'Exporter';
use strict;
use warnings;

our @EXPORT_OK = qw/
    stock_link organism_link cvterm_link
    stock_table related_stats
    stock_organisms stock_types breeding_programs
/;
our @EXPORT = ();


sub stock_link {
    my ($stock) = @_;
    my $name = $stock->uniquename;
    my $id = $stock->stock_id;
    return qq{<a href="/stock/$id/view">$name</a>};
}

sub organism_link {
    my ($organism) = @_;
    my $id      = $organism->organism_id;
    my $species = $organism->species;
    return <<LINK;
<span class="species_binomial">
<a href="/chado/organism.pl?organism_id=$id">$species</a>
LINK
}

sub cvterm_link {
    my ($cvterm) = @_;
    my $name = $cvterm->name;
    my $id   = $cvterm->cvterm_id;
    return qq{<a href="/cvterm/$id/view">$name</a>};
}

sub stock_table {
    my ($stocks) = @_;
    my $data = [];
    for my $s (@$stocks) {
        # Add a row for every stock
        push @$data, [
            cvterm_link($s->type),
            stock_link($s),

        ];
    }
    return $data;
}


sub related_stats {
    my ($stocks) = @_;
    my $stats = { };
    my $total = scalar @$stocks;
    for my $s (@$stocks) {
            $stats->{cvterm_link($s->type)}++;
    }
    my $data = [ ];
    for my $k (sort keys %$stats) {
        push @$data, [ $stats->{$k}, $k ];
    }
    if( 1 < scalar keys %$stats ) {
        push @$data, [ $total, "<b>Total</b>" ];
    }
    return $data;
}

sub breeding_programs {
    my ($schema) = @_;
    return [
        [ 0, '' ],
        map [ $_->project_id, $_->name ],
        $schema
             ->resultset('Project::Project')->search(
	    { 'type.name' => 'breeding_program',
	    }, 
	    {
		join      => { 'projectprops' => 'type' },
		select   => [qw[ me.project_id me.name ]],
		distinct => 1,
		order_by => 'me.name',
	    })
	];
}


sub stock_organisms {
    my ($schema) = @_;
    return [
        [ 0, '' ],
        map [ $_->organism_id, $_->species ],
        $schema
             ->resultset('Stock::Stock')
             ->search_related('organism' , {}, {
                 select   => [qw[ organism.organism_id species ]],
                 distinct => 1,
                 order_by => 'species',
               })
    ];
}

sub stock_types {
    my ($schema) = @_;

    my $ref = [
        map [$_->cvterm_id,$_->name],
        $schema
    ->resultset('Stock::Stock')
    ->search_related(
        'type',
        {},
        { select => [qw[ cvterm_id type.name ]],
          group_by => [qw[ cvterm_id type.name ]],
          order_by => 'type.name',
        },
    )
    ];
    # add an empty option 
    unshift @$ref , ['0', ''];
    return $ref;
}

sub stock_dbxrefprops {
    my $stock_dbxref = shift;
    my $props = $stock_dbxref->stock_dbxrefprops;
    while (my $p = $props->next ) {
        my $value = $p->value ;
        my $type = $p->type->name;
        my $accession = $p->type->dbxref->accession;
        my $db_name = $p->type->dbxref->db->name;

    }
}

######
1;
######
