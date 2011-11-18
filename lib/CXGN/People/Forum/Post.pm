
=head1 PACKAGE CXGN::People::Forum::Post

A package that deals with the posts.

=cut


use strict;

package CXGN::People::Forum::Post;

use base qw | CXGN::People::Forum |;

=head2 constructor new()

  Synopsis:     constructor
  Arguments:    an database handle and an id for a post
                or undef as id to create an empty object.
  Returns:      a CXGN::People::Forum::Post object
  Side effects: 
  Description:  

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift;

    my $self = $class->SUPER::new($dbh);
    $self->set_sql();
    if ($id) { 
        $self->set_forum_post_id($id);
        $self->fetch_forum_post();
    }
    return $self;
}


# internal function
#
sub fetch_forum_post {
    my $self = shift;
    my $h = $self->get_sql('fetch');
    $h->execute($self->get_forum_post_id());
    while (my ($forum_post_id, $post_text, $parent_post_id, $person_id, $post_time, $subject)=$h->fetchrow_array()) {
        $post_text = $self->format_post_text($post_text);
        $self->set_post_text($post_text);
        $self->set_parent_post_id($parent_post_id);
        $self->set_person_id($person_id);
        $self->set_post_time($post_time);
        $self->set_subject($subject);
    }
}




=head2 function store()

  Synopsis:	$post->store();
  Arguments:	none
  Returns:	the id of the new object in the database
                if successful, undef otherwise
  Side effects:	stores the post to the database. 
                If an id is already available, an update occurs.
                if an id is not available, an insert occurs.
  Description:	

=cut

sub store {
    my $self = shift;
    my $return_value = 0;
    if ($self->get_forum_post_id()) { 
		my $sth = $self->get_sql('update');
		$sth->execute(
			$self->get_post_text(), $self->get_person_id(), $self->get_forum_post_id(), $self->get_forum_topic_id(), $self->get_subject()
			, $self->get_forum_post_id
		);
    }
    else { 
		
		my $sth = $self->get_sql('insert');
		$sth->execute(
			$self->get_post_text(), 
			$self->get_person_id(), 
			$self->get_forum_topic_id(), 
			$self->get_subject()
		);
	
		$sth = $self->get_sql('currval');
		$sth->execute();
		my ($lid) = $sth->fetchrow_array();

		$self->set_forum_post_id($lid);
		$return_value = $lid;
	}
    
	my $subject="[Forum.pm] New post stored: ".$self->get_subject();
    my $body="New post: \n".$self->get_post_text()."\n\n";
    eval { CXGN::Contact::send_email($subject,$body,'cxgn-devel\@sgn.cornell.edu'); };
    return $return_value;
}    

=head2 function delete()

  Synopsis:	
  Arguments:	none
  Returns:	the number of rows deleted, usually 1 if 
                successful
  Side effects:	the post with the corresponding id is 
                permanently removed from the database.
  Description:	

=cut

sub delete { 
    my $self = shift;
	my $sth = $self->get_sql('delete');
    $sth->execute($self->get_forum_post_id());
    return $sth->rows();
}

=head2 function get_forum_post_id()

  Synopsis:	retrieves the forum_post_id of this object
  Arguments:	
  Returns:	
  Side effects:	
  Description:	Posts with no id are automatically
                treated as inserts in the store() function, and 
                the new id is then available using the accessor.

=cut

sub get_forum_post_id {
    my $self = shift;
    return $self->{forum_post_id};
}

=head2 Other accessor functions

get_subject
set_subject

get_forum_topic_id
set_forum_topic_id

get_person_id
set_person_id

get_post_text
set_post_text

=cut

sub get_subject { 
    my $self = shift;
    return $self->{subject};
}

sub set_subject {
    my $self = shift;
    $self->{subject} = shift;
}
sub set_forum_post_id {
    my $self = shift;
    $self->{forum_post_id} = shift;
}

sub get_forum_topic_id { 
    my $self = shift;
    return $self->{forum_topic_id};
}

sub set_forum_topic_id {
    my $self = shift;
    $self->{forum_topic_id} = shift;
}

sub get_person_id { 
    my $self = shift;
    return $self->{person_id};
}

sub set_person_id {
    my $self = shift;
    $self->{person_id} = shift;
}

sub get_post_text {
    my $self = shift;
    return $self->{post_text};
}

sub set_post_text {
   my $self = shift;
   $self->{post_text} = shift;
}

sub get_parent_post_id {
   my $self = shift;
   return $self->{parent_post_id};
}

sub set_parent_post_id {
    my $self = shift;
    $self->{parent_post_id} = shift;
}

sub get_post_time { 
    my $self = shift;
    return $self->{timestamp};
}

sub get_formatted_post_time { 
    my $self = shift;
    my $posttime = $self->get_post_time();
    if ($posttime =~ m/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/) { 
	$posttime = "$2\/$3\/$1 $4\:$5";
    }
    if ($posttime =~/(.*)(\..*)$/) { 
	$posttime = $1;
    }
    return $posttime;
}

sub set_post_time {
    my $self = shift;
    $self->{timestamp} = shift;
}

sub get_post_level {
    my $self = shift;
    return $self->{post_level};
}

sub set_post_level {
    my $self = shift;
    $self->{post_level}=shift;
}

sub set_sql {
    my $self =shift;
    $self->{queries} = {
		
		fetch =>
			
			"
				SELECT 
					forum_post_id, post_text, parent_post_id, 
					person_id, post_time, subject 
				FROM 
					sgn_people.forum_post 
				WHERE 
					forum_post_id=?
			",

		update =>

			"
				UPDATE sgn_people.forum_post 
				SET 
				(
					post_text=?, person_id=?, forum_post_id=?, 
					forum_topic_id=?, subject=?
				) 
				WHERE forum_post=?	
			",

		insert =>

			"
				INSERT INTO sgn_people.forum_post 
					(post_text, person_id, forum_topic_id, subject) 
				VALUES (?, ?, ?, ?)
			",

		currval =>

			"
				SELECT currval('sgn_people.forum_post_forum_post_id_seq')
			",

		delete =>

			"
				DELETE FROM sgn_people.forum_post 
				WHERE forum_post_id=?
			",

	};

	while(my($k,$v) = each %{$self->{queries}}){
		$self->{query_handles}->{$k}=$self->get_dbh()->prepare($v);
	}

}

sub get_sql {
    my $self =shift;
    my $name = shift;
    return $self->{query_handles}->{$name};
}



return 1;
