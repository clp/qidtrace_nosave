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
    my $line = shift;
    my $qid;
    return ( '', '' ) unless $line;
    if ( $line !~ m/<$email>/ ) { 
        $email = '' 
    }
    else {
        #TBD Save qid and check buffer for any matching lines w/ same qid.
        # $email = '' 
    }
    if ( $line =~ m/.*:? ([a-zA-Z\d]{14}).? ?.*/ ) {
        $qid = $1;
    }
    else {
        $qid = '';
    }
    return ( $email, $qid );
}


package Sendmail::QidTrace::Queue;

use strict;

sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;

    my $queue = { _leading  => [],  # winsize matching lines before
                  _trailing => [],  #                        and after
                  _seen     => {},  # track which lines we have already emitted
    };
    my $args = shift || {};
    while (my ($k, $v) = each(%$args)) {
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
    my ($self, $mo) = @_;

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


1;
