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
    Bio::SecreTary::TMpred->new( {} ); # use defaults here for min_score, etc.
 #   Bio::SecreTary::TMpred_pascal->new( {} );
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

    my $min_tmpred_score1 = 1500;
    my $min_tmh_length1   = 17;     #17
    my $max_tmh_length1   = 33;
    my $max_tmh_beg1      = 30;

    my $min_tmpred_score2 = 900;
    my $min_tmh_length2   = 17;
    my $max_tmh_length2   = 33;
    my $max_tmh_beg2      = 17;

    my $min_AI22        = 71.304;
    my $min_Gravy22     = 0.2636;
    my $max_nDRQPEN22   = 8;
    my $max_nNitrogen22 = 34;
    my $max_nOxygen22   = 32;
    my @STSparams       = (
        $min_tmpred_score1, $min_tmh_length1,   $max_tmh_length1,
        $max_tmh_beg1,      $min_tmpred_score2, $min_tmh_length2,
        $max_tmh_length2,   $max_tmh_beg2,      $min_AI22,
        $min_Gravy22,       $max_nDRQPEN22,     $max_nNitrogen22,
        $max_nOxygen22
    );

 #    my %STS_params = (   # These are the default values built into
# the SecreTarySelect constructor. So don't need this hash unless we
# want to use non-default values.
# 	'g1_min_tmpred_score' => 1500,
#     'g1_min_tm_length'    => 17,
#     'g1_max_tm_length'    => 33,
#     'g1_tm_start_by'      => 30,

#     'g2_min_tmpred_score' => 900,
#     'g2_min_tm_length'    => 17,
#     'g2_max_tm_length'    => 33,
#     'g2_tm_start_by'      => 17,

#     'min_AI22'        => 71.304,
#     'min_Gravy22'     => 0.2636,
#     'max_nDRQPEN22'   => 8,
#     'max_nNitrogen22' => 34,
#     'max_nOxygen22'   => 32,
#     'max_tm_nGASDRQPEN' => 9
# );
    my $STSobj   = Bio::SecreTary::SecreTarySelect->new();
    my $STApreds = $STSobj->Categorize( \@STAarray );

    my $result_string   = "";
    my $count_pass      = 0;
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
#my $solution = $1;
my $prediction = substr("$1   ", 0, 3); # 'YES' or 'NO '
my $STscore = $2;
my $solution = $3;

# print "XXX: $1, $2, $3. \n";
# print "prediction: [$prediction]\n";
      
#  $prediction =~ / \( (.*) \) \s* \( (.*) \)/xms;
#        my ( $soln1, $soln2 ) = ( $1, $2 );
#        $prediction = substr( $prediction, 0, 3 );    # 'YES' or 'NO '
        next if ( $prediction eq 'NO ' and $show_only_sp );
        $count_pass++ if ( $prediction eq "YES" );

#        my $solution = $soln1;
#        if ( $soln1 =~ /^ (\S+) , (\S+) , /xms and $1 < $min_tmpred_score1 ) {
#            $solution = $soln2;
#        }
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
       # $sequence = padtrunc( $sequence, $show_max_length );
        my $hl_sequence = "";


my $pred_array_ref =
[ $id, $prediction, $STscore, $sp_length, $sequence, $hstart, $cstart ];
push @$STresults, $pred_array_ref;

        if ( $prediction eq "YES" ) {
            my $bg_color_nc = "#FFDD66";
            my $bg_color_h  = "#AAAAFF";
            $hl_sequence =
                '<FONT style="BACKGROUND-COLOR: '
              . "$bg_color_nc" . '">'
              . substr( $sequence, 0, $hstart )
              . '</FONT>'
              . '<FONT style="BACKGROUND-COLOR: '
              . "$bg_color_h" . '">'
              . substr( $sequence, $hstart, $cstart - $hstart )
              . '</FONT>'
              . '<FONT style="BACKGROUND-COLOR: '
              . "$bg_color_nc" . '">'
              . substr( $sequence, $cstart, $sp_length - $cstart )
              . '</FONT>'
              . substr( $sequence, $sp_length, $show_max_length - $sp_length );
        }
        else {
            $hl_sequence = $sequence;
            $sp_length   = " - ";
           # $score       = "  -";
        }
        $STscore     = padtrunc( $STscore,     8 );
        $sp_length = padtrunc( $sp_length, 3 );
        $hl_sequence .= ( $orig_length > length $sequence ) ? '...' : '   ';
        $result_string .=
          "$id  $prediction    $STscore $sp_length      $hl_sequence\n";
    

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
    my @fastas  = ();
    my $wscount = 0;

    $input =~ s/\r//g;           #remove weird line endings.
    $input =~ s/\A \s*//xms;     # remove initial whitespace
    $input =~ s/ \s* \z//xms;    # remove final whitespace
    if ( $input =~ s/\A ([^>]+) //xms )
    {                            # if >= 1 chars before first > capture them.
        my $fasta = uc $1;
        if ( $fasta =~ /\A [A-Z]{10,} [A-Z\s]* [*]? \s* \z/xms )
        {                        # looks like sequence with no identifier
            $fasta = '>sequence_' . $wscount . "\n" . $fasta . "\n";
            push @fastas, $fasta;
            $wscount++;
        }

        # otherwise stuff ahead of first > is considered junk, discarded
    }
    while ( $input =~ s/ ( > [^>]+ )//xms
      )    # capture and delete initial > and everything up to next >.
    {
        push @fastas, $1;
        last if ( scalar @fastas >= $max_sequences_to_do );
    }

    foreach my $fasta (@fastas) {
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

