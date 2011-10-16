#! /usr/bin/env perl

package Sendmail::QidTrace;

use strict;
use warnings;

use Exporter ();

our @ISA       = qw/Exporter/;
our @EXPORT_OK = qw/match_line/;

# given an email address, and a sendmail log line,
#  return a pair ($email, $qid) from the line where:
#   the email matches if it is found any where in the line.
#   the qid is extracted from several common log lines that have been found with qids
# if either field is not found '' is returned in its place.

sub match_line {
    my $email = shift;
    my $line  = shift;
    my $qid;

    #TBR our @matching_qids;
    return ( '', '' ) unless $line;
    if ( $line !~ m/<$email>/ ) {
        $email = '';
    }
    else {

        # The current line will be saved in %_seen, when the caller gets this
        # email addr returned to it, and runs add_match().
        # Also save the qid found on the line w/ the matching $email.
        if ( $line =~ m/.*:? ([a-zA-Z\d]{14}).? ?.*/ ) {
            $qid = $1;
            push @Main::matching_qids, $qid;
            return ( $email, $qid );
        }
    }

#TBD: Compare current qid to saved qid's in @matching_qids, ie,
# in the current buffer.
# If a match, return the qid so it will be added to %_seen by caller.
# If no match, return ''.
#TBD: Rewrite as grep?: if (grep $current_qid, @Main::matching_qids ) {return...};
    if ( $line =~ m/.*:? ([a-zA-Z\d]{14}).? ?.*/ ) {
        my $current_qid = $1;
        foreach my $qid (@Main::matching_qids) {
            if ( $current_qid eq $qid ) {
                return ( $email, $qid );
            }
        }
        $qid = '';
    }
    else {
        $qid = '';
    }
    #TBD: Remove the two assignments to $qid above, & add it here only.
    return ( $email, $qid );
}

package Sendmail::QidTrace::Queue;

use strict;

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $queue = {
        _leading  => [],    # winsize matching lines before
        _trailing => [],    #                        and after
        _seen     => {},    # track which lines we have already emitted
    };
    my $args = shift || {};
    while ( my ( $k, $v ) = each(%$args) ) {
        $queue->{$k} = $v;
    }
    return bless $queue, $class;
}

#
# expects a ref to a hash containing the canonical form for a matched line:
#  match => the match string, in this case, an email.  possibly the empty string.
#  qid   => the qid.  should not normally be the empty string, but could be.
#  line  => the log line, sans newlines
#  num   => the line number of the log line
#
sub add_match {
    my ( $self, $mo ) = @_;

    #TBD: Verify i/p is OK.
    # If not, print error & exit or return.
    #
    # Add the line to save to the _seen hash,
    # using qid as key.
    # Store a ref to that hash in an array.
    my $key   = "$mo->{qid}";
    my $value = $mo;
    push @{ $self->{_seen}{$key} }, $value;
}

#
# drain the window of all remaining matches.
#  should be called after the end of the input stream
#  to flush out the queue.
sub drain_queue {
    my ($self) = @_;

}

#
# Accessors to get & set the queue.
sub push_onto_leading_array {
    my $self = shift;
    my $line = shift;
    push @{ $self->{_leading} }, $line;
}

sub shift_off_leading_array {
    my $self = shift;
    return shift @{ $self->{_leading} };
}

sub shift_off_trailing_array {
    my $self = shift;
    return shift @{ $self->{_trailing} };
}

sub push_onto_trailing_array {
    my $self = shift;
    my $line = shift;
    push @{ $self->{_trailing} }, $line;
}

sub get_leading_array {
    my $self = shift;
    return @{ $self->{_leading} };
}

sub get_trailing_array {
    my $self = shift;
    return @{ $self->{_trailing} };
}

sub size_of_leading_array {
    my $self = shift;
    return scalar @{ $self->{_leading} };
}

sub size_of_trailing_array {
    my $self = shift;
    return scalar @{ $self->{_trailing} };
}

sub get_seen_qids {
    my $self = shift;
    return keys %{ $self->{_seen} };
}

sub get_seen_hash {
    my $self = shift;
    return $self->{_seen};
}

sub erase_seen_hash {
    my $self = shift;

    #TBR? return $self->{_seen} = ();
    $self->{_seen} = ();
}

1;
