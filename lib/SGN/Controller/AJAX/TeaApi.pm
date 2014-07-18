
package SGN::Controller::AJAX::TeaApi;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSONP', 'text/html' => 'JSONP' },
   );


# check input data, create Bowtie2 input data and run Bowtie2
sub get_gene :Path('/api/tea') :Args(0) { 
    my ($self, $c) = @_;
    
    # to store erros as they happen
    my @errors; 
 	
	my @gene_array;
	my %descriptions;
	my %gene_ids;
	
    # get variables from catalyst object
    my $gene_name = $c->req->param("gene_name");
	
	print STDERR "genes: $gene_name\n";
	
	if ($gene_name =~ /\,/) {
		@gene_array = split(/,/, $gene_name);
	} else {
		push(@gene_array, $gene_name);
	}
	
    # my $gene_arrayref = $c->req->param("genes_array");
	# print STDERR "gene: $gene_name\n";
	# print STDERR "gene: $gene_arrayref\n";
	# push ( @errors , "This is just a test.\n");
	
	foreach my $gene_name (@gene_array) {
		my $schema = $c->dbic_schema("Bio::Chado::Schema");
		my $feature = $schema->resultset("Sequence::Feature")->find( { uniquename=> { like => 'mRNA:'.$gene_name.'%' } });
		my $cv = $schema->resultset("Cv::Cvterm")->find( { name=> 'Note' } );
		my $fp = $schema->resultset("Sequence::Featureprop")->find({
			feature_id=> $feature->feature_id(),
			type_id=>$cv->cvterm_id(),
		});
		
		$gene_ids{$gene_name} = $feature->feature_id();
		$descriptions{$gene_name} = $fp->value();
	}
	
	# print STDERR "res: $feature\n";
	# print STDERR "feature: ".$feature->feature_id()."\n";
	# print STDERR "cv: ".$cv->cvterm_id()."\n";
	# print STDERR "desc: ".$fp->value()."\n";
	
	print STDERR "test: $gene_ids{Solyc04g008460}\n";
	
    # Send error message to the web if something is wrong
	if (scalar (@errors) > 0){
		my $user_errors = join("<br />", @errors);
		$c->stash->{rest} = {error => $user_errors};
		return;
	}
	else {
		$c->stash->{rest} = {
			gene_id=>\%gene_ids,
			description=>\%descriptions
		};
		# $c->stash->{rest} = {
		# 	gene_id=>$feature->feature_id(),
		# 	description=>$fp->value(),
		# 	gene_name=>$feature->name()
		# };
	}
}


1;
