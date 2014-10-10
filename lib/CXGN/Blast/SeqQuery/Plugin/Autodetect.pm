
package CXGN::Blast::SeqQuery::Plugin::Autodetect;

use Moose;


sub name { 
    return 'autodetect';
}

sub type { 
    return 'autodetect';
}

sub example { 
    return ">nucleotide_fasta_example\nAAAAGGATAATGTTATTATTGGAAGTACATTCATTTTAAGCCCCTTTGAACCAAAGTCATGTACATATATCCCACT
TGGAGAAATAATCTAAAGCCTCAATAATTACATTGTCTCATAAGATGCCTGTCACAGCTCACTATCATTCATATTTTTTCTATTCATGAA
TATAAATATAGGCAAACCCCACAAGTAGAAAAGGGAGGGGTAAATTGGATGGCCTGATGATCAATAAACTAACCTCATAGAT";

}

sub validate { 
	return "OK";
}

sub process { 
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
	
	my $final_seq;
	
	if ($sequence =~ />/) {
	    my @final_sequence;
		my @lines = split("\n",$sequence);
		
		foreach my $line (@lines) {
			if ($line !~ />/) {
				$line=~ s/[\s\d\.\-\_\:\;\(\)\[\]\=\#\,\*]+//g;
				push(@final_sequence, $line);
			} else {
				push(@final_sequence, $line);
			}
		}
		$final_seq = join("\n",@final_sequence);
	} else {
		$sequence=~ s/[\s\d\.\-\_\:\;\(\)\[\]\=\#\,\*]+//g;
		$final_seq = ">Untitled_sequence\n$sequence\n";
	}
	
	# print STDERR "accessing the autodetect process function\n";
	
    return $final_seq;
}

sub autodetect_seq_type {
    my $self = shift;
    my $c = shift;
    my $sequence = shift;
	
	my $seq_type = 'nucleotide';
	my $valid_nt = 0;
	
	if ($sequence =~ />/) {
		my @lines = split("\n",$sequence);
		
		foreach my $line (@lines) {
			if ($line !~ />/) {
				$valid_nt += $sequence=~ tr/acgtACGTNn /acgtACGTNn /;
			}
		}
	} else {
		$valid_nt += $sequence=~ tr/acgtACGTNn /acgtACGTNn /;
	}
	
	if ($valid_nt >= length($sequence)*0.9) {
		$seq_type = 'nucleotide';
	} else {
		$seq_type = 'protein';
	}
	
	# print STDERR "accessing the autodetect_seq_type function\n";
	
	return $seq_type;
}

1;
