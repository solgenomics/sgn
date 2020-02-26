package SGN::Controller::solGS::genotypingProtocols;


use Moose;
use namespace::autoclean;


BEGIN { extends 'Catalyst::Controller::REST' }



__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 
		   'text/html' => 'JSON' },
    );


sub get_genotype_protocols: Path('/get/genotyping/protocols/') Args() {
    my ($self, $c) = @_;


    my $default_protocol = $c->model('solGS::solGS')->protocol_detail();
    
    my $all_protocols = $self->genotype_protocols($c);  

    $c->stash->{rest}{default_protocol} = $default_protocol;
    $c->stash->{rest}{all_protocols} = $all_protocols ? $all_protocols : undef;
      
}


sub genotype_protocols {
    my ($self, $c) = @_;

    my $protocol_ids = $c->model('solGS::solGS')->get_all_genotyping_protocols();
    my @protocols_details;

    foreach my $protocol_id (@$protocol_ids)
    {
	my $details = $c->model('solGS::solGS')->protocol_detail($protocol_id);	
	push @protocols_details, $details if %$details;	
    }

   # my $dummy = {'protocol_id'=>2, 'name'=>'dummy protocol'};
   # push @protocols_details, $dummy; 
   
    return \@protocols_details;
    
}


###
1;
###
