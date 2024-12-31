
package SGN::Controller::AJAX::DbStats;

use Moose;
use Data::Dumper;
use CXGN::DbStats;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
        default   => 'application/json',
        stash_key => 'rest',
        map       => { 'application/json' => 'JSON' },
);


# Functions for the page /dbstats/recent_activity
#
sub trial_count_by_breeding_program :Path('/ajax/dbstats/trials_by_breeding_program') Args(0) { 
    my $self = shift;   
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;

    print STDERR "start: $start_date, end: $end_date, include: $include_dateless_items\n";
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });

    my $data = $dbstats->trial_count_by_breeding_program($start_date, $end_date, $include_dateless_items);

    
    print STDERR "trial data: ". Dumper($data);
    $c->stash->{rest} = { data => $data };
}

sub accession_count_by_breeding_program :Path('/ajax/dbstats/accessions_by_breeding_program') Args(0) {
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;
    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
    
    my $data = $dbstats->accession_count_by_breeding_program($start_date, $end_date, $include_dateless_items);
    print STDERR "accession data: ". Dumper($data);
    $c->stash->{rest} = { data => $data };
}

sub plot_count_breeding_program :Path('/ajax/dbstats/plots_by_breeding_program') Args(0) {
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items")  eq "true" ? 1 : 0;

    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
    
    my $data = $dbstats->plot_count_by_breeding_program($start_date, $end_date, $include_dateless_items);

    print STDERR "plot data: ". Dumper($data);
    $c->stash->{rest} = { data => $data };
}



sub phenotype_count_by_breeding_program :Path('/ajax/dbstats/phenotypes_by_breeding_program') Args(0) {
    my $self = shift;
    my $c = shift;
    
    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items")  eq "true" ? 1 : 0 ;
    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
    
    my $data = $dbstats->phenotype_count_by_breeding_program($start_date, $end_date, $include_dateless_items);

    #print STDERR "phenotype data: ". Dumper($data);
    $c->stash->{rest} = { data => $data };
    

}


# Functions to retrieve data for the charts on the /breeders/dbstats page
#

sub trials_by_breeding_program_chart :Path('/ajax/dbstats/trials_by_breeding_program_chart') Args(0) { 
    my $self = shift;   
    my $c = shift;

    print STDERR "Trials by breeding program chart...\n";
    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;
    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
    
    my $tbbp = $dbstats->trial_count_by_breeding_program($start_date, $end_date, $include_dateless_items);

    my $total_trials = 0;
    foreach my $t (@$tbbp) { $total_trials += $t->[1]; }
    
    my %response = $self->format_response( { title => "Trials by Breeding Program", subtitle => "Showing $total_trials Total Trials", data => $tbbp });
 
#    print STDERR Dumper(\%response);
    $c->stash->{rest} = \%response;   
}


sub stocks_chart : Path('/ajax/dbstats/stocks_chart') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;
    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
 
    my $stocks = $dbstats->stocks($start_date, $end_date, $include_dateless_items);

    my $stock_count = 0;
    foreach my $s (@$stocks) { $stock_count += $s->[1]; }

    my %response =  $self->format_response( { title => "Stock Types", subtitle => "Showing total of $stock_count stocks", data => $stocks });
    $c->stash->{rest} = \%response;
}

sub traits_measured_chart :Path('/ajax/dbstats/traits_chart') Args(0)  { 
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;
    
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });

    print STDERR "TRAITS CHART: start date : $start_date, end date $end_date, and $include_dateless_items\n";
    my $traits = $dbstats->traits($start_date, $end_date, $include_dateless_items);
    
    my $total_traits = 0;
    foreach my $t (@$traits) { $total_traits += $t->[1]; }

    my %response = $self->format_response( { title => "Traits", subtitle => "Total trait measurements: $total_traits", data => $traits });
 
    #print STDERR Dumper(\%response);
    $c->stash->{rest} = \%response;   

#   my $q = "select cvterm.name, count(*) from phenotype join cvterm on (observable_id=cvterm_id) 
# group by cvterm.name order by count(*) desc";

}

sub trial_types_chart : Path('/ajax/dbstats/trial_types_chart') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $include_dateless_items = $c->req->param("include_dateless_items") eq "true" ? 1 : 0;

    print STDERR "TRIAL TYPES: start date : $start_date, end date $end_date, and $include_dateless_items\n";
    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
    
    my $trial_types = $dbstats->trial_types($start_date, $end_date, $include_dateless_items);

    my $total_trials = 0;
    foreach my $t (@$trial_types) { $total_trials += $t->[1]; }
    
    my %response = $self->format_response( { title => "Trial Types", subtitle => "Showing $total_trials Total Trials", data => $trial_types });
 
    print STDERR Dumper(\%response);
    $c->stash->{rest} = \%response;   
}

# plot of activity per week for a year
#
sub activity_stats : Path('/ajax/dbstats/activity') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh();
    my $dbstats = CXGN::DbStats->new({ dbh=> $dbh });
 
    my $data = $dbstats->activity();
    
    print STDERR Dumper($data);
    $c->stash->{rest} = $data;
}

sub format_response { 
    my $self = shift;
    my $args = shift;

    my %response = 
	( 
	  header =>  
	  { 
	      title => { 
		  text => $args->{title},
		  fontSize => 14,
		  font => "arial",
	      },
	      subtitle => { 
		  text => $args->{subtitle},
		  fontSize => 12,
		  font => "arial",
	      },
	      titleSubtitlePaddint => 12,
	  },
	  footer => { 
	      text => "",
	      fontSize => 11,
	      font => "arial",
	      location => "bottom-center",
	  },
	  size => { 
	      canvasHeight => 240,
	      canvasWidth => 450,
	    pieOuterRadius => "80%",
	  },
	  data => { 
	      content => [ ],
	  },
	  labels => {
	      outer =>  {
		  pieDistance => 32,
	      },
	      inner => { 
		  hideWhenLessThanPercentage => 3,
	      },
	      mainLabel => {
		  fontSize => 11,
	      },
	      percentage => {
			color => "#ffffff",
			decimalPlaces => 0
		},
		value => {
			color => "#adadad",
			fontSize => 11,
		},
		lines => {
			enabled => "true",
		},
		truncation => {
			enabled => "true",
		}
	  },
	  effects => {
	      pullOutSegmentOnClick => {
		  effect => "linear",
		  speed => 400,
		  size => 8,
	      }
	  }
	);
    #print STDERR Dumper(\%response);
    my $n = 0;
    foreach my $d (@{$args->{data}}) { 
	my ($term, $count) = @$d;
	
	push @{$response{data}->{content}}, 
	{ label => $term , value => $count, color => $self->color($n) };

	$n++;
	
    }
    return %response;
}

sub color { 
    my $self = shift;
    my $ord = shift || 0;
    
    my @colors = ( '#44DD44', '#FF4444', '#4444FF', '#FF44FF', '#44FFFF', '#994444', '#449944', '#444499' );
    
    return $colors[$ord];
}

1;
