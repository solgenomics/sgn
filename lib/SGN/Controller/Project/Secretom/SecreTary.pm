package SGN::Controller::Project::Secretom::SecreTary;
use Moose;
use namespace::autoclean;

use Bio::SecreTary::SecreTarySelect;
use Bio::SecreTary::SecreTaryAnalyse;

BEGIN { extends 'Catalyst::Controller'; }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config( namespace => 'secretom/secretary', );

=head1 NAME

SGN::Controller::Project::Secretom::SecreTary - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 ACTIONS

=cut

=head2 index

Just forwards to the the /secretom/secretary.mas template.

=cut

sub index : Path : Args(0) {
	my ( $self, $c ) = @_;
	$c->stash->{template} = '/secretom/secretary.mas';
}

=head2 instructions

Just forwards to the the /secretom/secretary/instructions.mas template.

=cut

sub instructions : Path('instructions') {
	my ( $self, $c ) = @_;
	$c->stash->{template} = '/secretom/secretary/instructions.mas';
}

=head2 run

Takes a GET or POST of data to analyze.

Params:

sequence: text sequence to run
sequence_file: uploaded sequence file to run against
sort: boolean whether to sort the output by score
show_only_sp: boolean whether to show only predicted signal peptides

Output:

HTML SecreTary results.

=cut

sub run : Path('run') {
	my ( $self, $c ) = @_;

	my $input        = $c->req->param("sequence") || '';
	my $sort_it      = $c->req->param("sort");
	my $show_only_sp = $c->req->param("show_only_sp");

	for my $upload ( $c->req->upload('sequence_file') ) {
		$input .= $upload->slurp;
	}

# need to add the programs dir to PATH so secretary code can find tmpred
	local $ENV{PATH} =
		$ENV{PATH} . ':' . $c->path_to( $c->config->{programs_subdir} );

# stash the results of the run
	@{ $c->stash }{qw{ STresults }} =  $self->_run_secretary( $input, $sort_it, $show_only_sp );


# and set the template to use for output
	$c->stash->{template} = '/secretom/secretary/result.mas';
}

############# helper subs ##########

sub _run_secretary {
	my ( $self, $input, $sort_it, $show_only_sp ) = @_;

	my @STAarray;
	my $trunc_length = 100;

	my $tmpred_obj =
#		Bio::SecreTary::TMpred->new( {} ); # use defaults here for min_score, etc.
              Bio::SecreTary::TMpred_Cinline->new( {} );
		my $id_seqs = process_input($input);

#Calculate the necessary quantities for each sequence:
	foreach (@$id_seqs) {
		/^\s*(\S+)\s+(\S+)/;
		my ( $id, $sequence ) = ( $1, $2 );

		my $STAobj =
			Bio::SecreTary::SecreTaryAnalyse->new( $id,
					substr( $sequence, 0, $trunc_length ), $tmpred_obj );
		push @STAarray, $STAobj;
	}


	my $STSobj   = Bio::SecreTary::SecreTarySelect->new();
	my $STApreds = $STSobj->categorize( \@STAarray );

	my $result_string   = "";
#   my $count_pass      = 0;
	my $show_max_length = 62;

	my @sort_STApreds = ($sort_it)
		? sort {
			$b->[1] =~ /^ \s* (\S+) \s+ (-?[0-9.]+) /xms; # 
				my $score_b = $2;
			$a->[1] =~ /^ \s* (\S+) \s+ (-?[0-9.]+) /xms;
			my $score_a = $2;
			return $score_b <=> $score_a;
		} @$STApreds
	: @$STApreds;

	my $STresults = [];
	foreach (@sort_STApreds) {
		my $STA        = $_->[0];
		my $pred_string = $_->[1];

		$pred_string =~ / ^ \s* (\S+) \s+ (\S+) \s*(.*) /xms;
		my $prediction = substr("$1   ", 0, 3); # 'YES' or 'NO '
			my $STscore = $2;
		my $solution = $3;

		next if ( $prediction eq 'NO ' and $show_only_sp );

		my ( $score, $start, $end ) = ( '        ', '      ', '      ' );
		if ( $solution =~ /^ \s* (\S+) \s+ (\S+) \s+ (\S+)/xms ) {
			( $score, $start, $end ) = ( $1, $2, $3 );

		}

		my $id       = padtrunc( $STA->get_sequence_id(), 15 );
		my $sequence = $STA->get_sequence();
		my $cleavage = $STA->get_cleavage();
		my ( $sp_length, $hstart, $cstart, $typical ) = @$cleavage;
		my $hstartp1 = padtrunc( $hstart + 1, 4 );
		my $cstartp1 = padtrunc( $cstart + 1, 4 );
		$sp_length = padtrunc( $sp_length, 4 );
		my $orig_length = length $sequence;

		my $pred_array_ref =
			[ $id, $prediction, $STscore, $sp_length, $sequence, $hstart, $cstart ];
		push @$STresults, $pred_array_ref;
	}

	return ( $STresults);
}

sub process_input {

# process fasta input to get hash with ids for keys, sequences for values.
# expects fasta format, but can handle just sequence with no >id line, for first
# sequence only.

	my $max_sequences_to_do = 10000;
	my $input               = shift;
	my @id_sequence_array;
	my $min_sequence_length = 8; # this is the minimal length of sequence string which will be recognized as a sequence if no fasta idline is present.
	my @fastas  = ();
	my $wscount = 0;

	$input =~ s/\r//g;           #remove weird line endings.
		$input =~ s/\A \s*//xms;     # remove initial whitespace
		$input =~ s/ \s* \z//xms;    # remove final whitespace
		if ( $input =~ s/\A ([^>]+) //xms )
		{                            # if >= 1 chars before first > capture them.
			my $fasta = uc $1;
			# if letters and spaces optionally with * as last non whitespace char,
			# and starts with at least $min_sequence_length letters, treat as sequence
			if ( $fasta =~ /\A [A-Z]{$min_sequence_length,} [A-Z\s]* [*]? \s* \z/xms )
			{                        # looks like sequence with no identifier
				$fasta = '>sequence_' . $wscount . "\n" . $fasta . "\n";
				push @fastas, $fasta;
				$wscount++;
			}

# otherwise stuff ahead of first > is considered junk, discarded ($1 not used)
		}
# if(0){
# 	while ( $input =~ s/ ( > [^>]+ )//xms
# 	      )    # capture and delete initial > and everything up to next >.
# 	{
# 		push @fastas, $1;
# 		last if ( scalar @fastas >= $max_sequences_to_do );
# 	}
# }
# else{
$input =~ s/\A > //xms; # eliminate initial >
@fastas = split(">", $input);

        @fastas = @fastas[0..$max_sequences_to_do-1] if(scalar @fastas > $max_sequences_to_do); # keep just the first $max_sequence_to_do
#}

	foreach my $fasta (@fastas) {
		$fasta = '>' . $fasta;
		next if ( $fasta =~ /\A\z/xms );

		my $id;
		$fasta =~ s/\A \s+ //xms;    # delete initial whitespace
			if ( $fasta =~ s/\A > (\S+) [^\n]* \n //xms ) {    # line starts with >
				$id = $1;
	}
			else {
				$fasta =~ s/\A > \s*//xms;   # handles case of > not followed by id.
					$id = 'sequence_' . $wscount;
				$wscount++;
			}
		$fasta =~ s/\s//xmsg;            # remove whitespace from sequence;
		$fasta =~ s/\* \z//xms;          # remove final * if present.
			$fasta = uc $fasta;
		push @id_sequence_array, "$id $fasta";
	}
	return \@id_sequence_array;
}

sub padtrunc {    #return a string of length $length, truncating or
# padding on right with spaces as necessary
	my $str    = shift;
	my $length = shift;
	while ( length $str < $length ) { $str .= "                    "; }
	return substr( $str, 0, $length );
}

1;

