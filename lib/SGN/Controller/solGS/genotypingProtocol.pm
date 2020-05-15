package SGN::Controller::solGS::genotypingProtocol;


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


sub create_protocol_url {
    my ($self, $c, $protocol) = @_;
   
    my $protocol_detail = $c->model('solGS::solGS')->protocol_detail($protocol);
    my $protocol_id = $protocol_detail->{protocol_id};
    my $name        = $protocol_detail->{name};
    my $protocol_url = '<a href="/breeders_toolbox/protocol/' . $protocol_id . '">' . $name . '</a>';
  
    return $protocol_url;
}


sub stash_protocol_id {
    my ($self, $c, $protocol_id) = @_;

    if (!$protocol_id || $protocol_id =~ /undefined/)
    {
	my $protocol_detail= $c->model('solGS::solGS')->protocol_detail(); 
	$protocol_id = $protocol_detail->{protocol_id};
    }

    $c->stash->{genotyping_protocol_id} = $protocol_id;
    
   # return $protocol_id;
}


###
1;
###
