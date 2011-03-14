package SGN::Controller::Project::Secretom::SecreTary;
use Moose;
use namespace::autoclean;

use Bio::SecreTary::SecreTarySelect;
use Bio::SecreTary::SecreTaryAnalyse;

BEGIN {extends 'Catalyst::Controller'; }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    namespace => 'secretom/secretary',
   );

=head1 NAME

SGN::Controller::Project::Secretom::SecreTary - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 ACTIONS

=cut


=head2 index

Just forwards to the the /secretom/secretary.mas template.

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = '/secretom/secretary.mas';
}

=head2 instructions

Just forwards to the the /secretom/secretary/instructions.mas template.

=cut

sub instructions :Path('instructions') {
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

sub run :Path('run') {
    my ( $self, $c ) = @_;

    my $input        = $c->req->param("sequence") || '';
    my $sort_it      = $c->req->param("sort");
    my $show_only_sp = $c->req->param("show_only_sp");

    for my $upload ( $c->req->upload('sequence_file') ) {
        $input .= $upload->slurp;
    }

    # need to add the programs dir to PATH so secretary code can find tmpred
    local $ENV{PATH} = $ENV{PATH}.':'.$c->path_to( $c->config->{programs_subdir} );

    # stash the results of the run
    @{ $c->stash }{qw{  result_string  STApreds  count_pass  }} =
        $self->_run_secretary( $input, $sort_it, $show_only_sp );

    # and set the template to use for output
    $c->stash->{template} = '/secretom/secretary/result.mas';
}

############# helper subs ##########

sub _run_secretary {
    my ( $self, $input, $sort_it, $show_only_sp ) = @_;

    my @STAarray;
    my $trunc_length = 100;
    my $id_seqs = process_input($input); # $id_seqs is ref to array of "$id $sequence"

    #Calculate the necessary quantities for each sequence:
    foreach ( @$id_seqs ) {
        /^\s*(\S+)\s+(\S+)/;
        my ($id, $sequence) = ($1, $2); 
    #    my $sequence = $id_seqs->{$id};
        my $STAobj =
          Bio::SecreTary::SecreTaryAnalyse->new( $id, substr( $sequence, 0, $trunc_length ) );
        push @STAarray, $STAobj;
    }

    my $min_tmpred_score1 = 1500;
    my $min_tmh_length1   = 17; #17
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
    my $STSobj   = Bio::SecreTary::SecreTarySelect->new(@STSparams);
    my $STApreds = $STSobj->Categorize( \@STAarray );

    my $result_string   = "";
    my $count_pass      = 0;
    my $show_max_length = 62;
    my @sort_STApreds = @$STApreds;
    if($sort_it){
        @sort_STApreds = sort {$b->[2] <=> $a->[2]} @$STApreds;
    }
    foreach ( @sort_STApreds ) {
        my $STA = $_->[0];
        my $prediction = $_->[1];
        $prediction =~ /\((.*)\)\((.*)\)/;
        my ($soln1, $soln2) = ($1, $2);
        $prediction = substr($prediction, 0, 3 ); # 'YES' or 'NO '
        next if($prediction eq 'NO ' and $show_only_sp);
        $count_pass++ if ( $prediction eq "YES" );

      my $solution = $soln1;
        if($soln1 =~ /^(.*)?,/ and $1 < $min_tmpred_score1){ $solution = $soln2; }
        my ($score, $start, $end) = ('        ','      ','      ');
        if($solution =~ /^(.*),(.*),(.*)/){
    	($score, $start, $end) = ($1, $2, $3);

        }

        my $id = padtrunc( $STA->get_sequence_id(), 15);
        my $sequence = $STA->get_sequence();
        my $cleavage = $STA->get_cleavage();
        my ($sp_length, $hstart, $cstart, $typical) = @$cleavage;
        my $hstartp1 = padtrunc($hstart+1, 4);
    my $cstartp1 = padtrunc($cstart+1, 4);
     $sp_length = padtrunc($sp_length, 4);
        my $orig_length = length $sequence;
        $sequence = padtrunc($sequence, $show_max_length);
        my $hl_sequence = "";
        if($prediction eq "YES"){
    my $bg_color_nc = "#FFDD66"; 
    my $bg_color_h = "#AAAAFF";
    $hl_sequence = '<FONT style="BACKGROUND-COLOR: ' . "$bg_color_nc" . '">' 
        . substr($sequence, 0, $hstart) . '</FONT>'
        . '<FONT style="BACKGROUND-COLOR: ' . "$bg_color_h" . '">'  
        . substr($sequence, $hstart, $cstart-$hstart) . '</FONT>' 
        . '<FONT style="BACKGROUND-COLOR: ' . "$bg_color_nc" . '">' 
        . substr($sequence, $cstart, $sp_length-$cstart) . '</FONT>'
        . substr($sequence, $sp_length, $show_max_length-$sp_length);
        }else{
    	$hl_sequence = $sequence;
    	$sp_length = " - ";
    	$score = "  -";
    }
      $score = padtrunc($score, 8);
    	$sp_length = padtrunc($sp_length, 3);
        $hl_sequence .= ($orig_length > length $sequence)? '...': '   ';
        $result_string .= "$id  $prediction    $score $sp_length      $hl_sequence\n";
    }

    return ( $result_string, $STApreds, $count_pass );
}

sub process_input {

    my $max_sequences_to_analyze = 3000;

# process fasta input to get hash with ids for keys, sequences for values.
# split on >. Then for each element of result,
# 1) if empty string, skip, 2) get id from 1st line; if looks like seq, not id,
# then id is "web_sequence", 3) look at rest of lines and append any that look
# like sequence (i.e. alphabetic characters only plus possible whitespace at ends)
    my $input            = shift;
    my @id_sequence_array;
    my $wscount          = 0;
    $input =~ s/\r//g;    #remove weird line endings.
         #    $input =~ s/\A(.*)?>//; # remove everything before first '>'.
    $input =~ s/\A\s+|\s+\Z//g;    # trim whitespace from ends.
    $input =~ s/\*\Z//;            # trim asterisk from end if present.
    my @fastas = split( ">", $input );

    #    print "number of fastas: ", scalar @fastas, "\n";
    foreach my $fasta (@fastas) {
        next if ( $fasta =~ /^$/ );

        #	print "fasta $wscount: [", $fasta, "]\n";
        $fasta =~ s/\A\s+|\s+\Z//g;    #< trim whitespace from ends.
        $fasta =~ s/\*\Z//;
        my @lines = split( "\n", $fasta );
        my $id = shift @lines;
        if ( $id =~ /^\s*([a-zA-Z]+)\s*$/ ) {  # see if line looks like sequence
            unshift @lines, $1;
            $id = "sequence_" . $wscount;
            $wscount++;
        }
        else {
            if ( $id =~ /^\s*(\S+)/ ) {
                $id = $1;
            }
            else {
                $id = "sequence_" . $wscount;
                $wscount++;
            }
        }
        my $sequence;
        foreach (@lines) {
            s/\A\s+|\s+\Z//g;    # trim whitespace from ends.
            if (/^[a-zA-Z]+$/) {
                $sequence .= $_;    # append the line
            }
        }
        push @id_sequence_array, "$id $sequence";
        return \@id_sequence_array if(scalar @id_sequence_array == $max_sequences_to_analyze);
    }

    return \@id_sequence_array;
}

sub padtrunc{ #return a string of length $length, truncating or
    # padding with spaces as necessary
    my $str = shift;
    my $length = shift;
    while(length $str < $length){ $str .= "                    "; }
    return substr($str, 0, $length);
}

1;
