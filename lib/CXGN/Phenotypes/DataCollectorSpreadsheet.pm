package CXGN::Phenotypes::DataCollectorSpreadsheet;

=head1 NAME

CXGN::Phenotypes::CreateSpreadsheet - an object to create a spreadsheet for collecting phenotypes

=head1 USAGE

 my $phenotype_spreadsheet = CXGN::Phenotypes::CreateSpreadsheet->new({schema => $schema, trial_id => $trial_id, trait_list => \$trait_list} );
 $create_spreadsheet->create();

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial::TrialLayout;
use Spreadsheet::WriteExcel;
use CXGN::Trait;
use CXGN::List::Transform;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 required => 1,
		);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', required => 1);
has 'trait_list' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_trait_list', required => 1);
has 'filename' => (isa => 'Str', is => 'ro',
		   predicate => 'has_filename',
		   reader => 'get_filename',
		   writer => 'set_filename',
		   required => 1,
		  );
has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');


sub _verify {
    my $self = shift;

    my $trial_id = $self->get_trial_id();
    my @trait_list = @{$self->get_trait_list()};

    return 1;
}


sub create {
    my $self = shift;
    my $schema = $self->get_schema();
    my $trial_id = $self->get_trial_id();
    my @trait_list = @{$self->get_trait_list()};
    my $spreadsheet_metadata = $self->get_file_metadata();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout'} );
    my %design = %{$trial_layout->get_design()};
    my @plot_names = @{$trial_layout->get_plot_names};

    my $workbook = Spreadsheet::WriteExcel->new($self->get_filename());
    my $ws = $workbook->add_worksheet();
	

    # generate worksheet headers
    #
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    #$ws->write(0, '0', 'Spreadsheet ID'); $ws->write('0', '1', );#$unique_id);
    $ws->write(1, 0, 'Trial name'); $ws->write(1, 1, $trial->get_name());
    $ws->write(2, 0, 'Description'); $ws->write(2, 1, $trial->get_description());
    #$ws->write(3, 0, "Plants per plot");  $ws->write(3, 1, "unknown");
    $ws->write(4, 0, 'Operator');       $ws->write(4, '1', "");
    $ws->write(5, 0, 'Date');           $ws->write(5, '1', "");
    
    my @ordered_plots = sort { $a cmp $b} keys(%design);
    for(my $n=0; $n<@ordered_plots; $n++) { 
	my %design_info = %{$design{$ordered_plots[$n]}};
	    
	$ws->write($n+6, 0, $ordered_plots[$n]);
	$ws->write($n+6, 1, $design_info{accession_name});
	$ws->write($n+6, 2, $design_info{plot_number});
	$ws->write($n+6, 3, $design_info{block_number});
	$ws->write($n+6, 4, $design_info{is_a_control});
	$ws->write($n+6, 5, $design_info{rep_number});
    }

    # write traits and format trait columns
    #
    my $lt = CXGN::List::Transform->new();
    
    my $transform = $lt->transform($schema, "traits_2_trait_ids", \@trait_list);

    if (@{$transform->{missing}}>0) { 
	print STDERR "Warning: Some traits could not be found. ".join(",",@{$transform->{missing}})."\n";
    }
    my @trait_ids = @{$transform->{transform}};
    
    my %cvinfo = ();
    foreach my $t (@trait_ids) { 
	my $trait = CXGN::Trait->new( { bcs_schema=> $schema, cvterm_id => $t });
	$cvinfo{$trait->display_name()} = $trait;
    }
									       
    for (my $i = 0; $i < @trait_list; $i++) { 
	if (exists($cvinfo{$trait_list[$i]})) { 
	    $ws->write(6, $i+6, $cvinfo{$trait_list[$i]}->display_name());
	}
	else { 
	    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
	}
    
	my $plot_count = scalar(keys(%design));

	for (my $n = 0; $n < $plot_count; $n++) { 
	    my $format = $cvinfo{$trait_list[$i]}->format();
	    if ($format eq "numeric") { 
		$ws->data_validation($n+6, $i+6, { validate => "any" });
	    }
	    else { 
		$ws->data_validation($n+6, $i+6, 
				     { 
					 validate => 'list',
					 value    => [ split ",", $format ]
				     });
	    }
	}
    }

    $workbook->close();

    return 1;
}



###
1;
###
