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
#   the qid is extracted from several common log lines that have
#   been found with qids
# if either field is not found '' is returned in its place.

sub match_line {
    my $email = shift;
    my $line  = shift;
    my $qid;

    return ( '', '' ) unless $line;
    if ( $line !~ m/<$email>/ ) {
        $email = '';
    }
    else {

        ## The current line will be saved in %_seen, when the caller gets this
        ## email addr returned to it, and runs add_match().
        ## Also save the qid found on the line w/ the matching $email.
        if ( $line =~ m/.*:? ([a-zA-Z\d]{14}).? ?.*/ ) {
            $qid = $1;
            push @main::matching_qids, $qid;
            return ( $email, $qid );
        }
    }

    ## TBD: Compare current qid to saved qid's in @matching_qids, ie,
    ## in the current buffer.
    ## If a match, return the qid so it will be added to %_seen by caller.
    ## If no match, return ''.
    ## TBD: Rewrite as grep?: if (grep $current_qid, @main::matching_qids ) {return...};
    if ( $line =~ m/.*:? ([a-zA-Z\d]{14}).? ?.*/ ) {
        my $current_qid = $1;
        foreach my $qid (@main::matching_qids) {
            if ( $current_qid eq $qid ) {
                return ( $email, $qid );
            }
        }
        $qid = '';
    }
    else {
        $qid = '';
    }

    ## TBD: Remove the two assignments to $qid above, & add it here only.
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
        _seen => {},  # track which lines we have already emitted
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
    my ($self)              = shift;
    my $output_start_column = shift;
    my $output_length       = shift;  # default to the whole line
    my $emit_line_numbers   = shift;
    my $eref                = shift;
    my @emitted = @$eref;

    my %lh;
    my $ltdref;
    my @lines_to_drain;
    push @lines_to_drain, $self->get_leading_array,
        $self->get_trailing_array;
    foreach $ltdref (@lines_to_drain) {

        %lh = %$ltdref;
        my $ln   = $lh{line};
        my $lnum = $lh{num};

        # Check for desired email addr in the current line.
        if ( $ln =~ m/<$self->{match}>/ ) {

            # Get email & qid from current line.
            my ( $match_email, $match_qid )
                = Sendmail::QidTrace::match_line( $self->{match},
                $ln );

            ##DBG print "DBG.drain__email_match_found: \$lnum: ,$lnum,\n"
            ##DBG if ($DEBUG);
            ## Add line from buffer w/ matching email addr to the "seen" hash.
            $self->add_match(
                {   match => $match_email,
                    qid   => $match_qid,
                    line  => (
                        $output_length
                        ? substr(
                            $ln,
                            $output_start_column,
                            $output_length
                            )
                        : substr( $ln, $output_start_column )
                    ),
                    num => $lnum
                }
            );
            push @emitted, $lnum;

            # Check for lines w/ matching qid's in the buffer.
            foreach my $ltd_from_buf (@lines_to_drain) {

                %lh = %$ltd_from_buf;
                my $ln_from_buf   = $lh{line};
                my $lnum_from_buf = $lh{num};

                ## The third clause eliminates dupes of $match_email;
                ## The fourth clause eliminates dupes that match $match_qid:
                if (   defined $ln_from_buf
                    && ( $ln_from_buf =~ /$match_qid/ )
                    && ( $ln_from_buf ne $ln )
                    && ( !grep ( /$lnum_from_buf/, @emitted ) ) )
                {
                    my ( $match_email, $match_qid )
                        = Sendmail::QidTrace::match_line(
                        $self->{match}, $ln_from_buf );

                    ## If current line has the matching email addr and a matching qid,
                    ## skip it to avoid adding a duplicate line in o/p.
                    ## Only add this line to the o/p when it is shifted off the
                    ## leading array to check its email addr.
                    ## TBD: This creates a problem (p.6.) when lines
                    ## with same qid have "from" uid = "to" uid:
                    ## the second line is not indented below the
                    ## first line.
                    next if ( $match_email eq $self->{match} );

                    ##DBG print
                    ##DBG "DBG.drain__qid_match_found: \$lnum_from_buf: ,$lnum_from_buf,\n"
                    ##DBG if ($DEBUG);
                    $self->add_match(
                        {   match => $match_email,
                            qid   => $match_qid,
                            line  => (
                                $output_length
                                ? substr(
                                    $ln_from_buf,
                                    $output_start_column,
                                    $output_length
                                    )
                                : substr(
                                    $ln_from_buf,
                                    $output_start_column
                                )
                            ),
                            num => $lnum_from_buf
                        }
                    );
                    push @emitted, $lnum_from_buf;
                } # End block that adds a matching line to %_seen.

            } # End inner loop: check for matching qid's in buffer.

            # Print all the lines stored in %_seen.
            #TMP.1 print_matching_lines($emit_line_numbers, $self)
            #TMP.1 if ( $self->get_seen_hash );

                #TBD: testing. Wed2011_1019_13:30 
                #OK main::print_matching_lines_2($self) if ( $self->get_seen_hash );
                #OK main::print_matching_lines_2() if ( $self->get_seen_hash );
                main::print_matching_lines() if ( $self->get_seen_hash );

            # Erase content of %_seen.
            $self->erase_seen_hash();

            next;
        }    # End loop to check for email addr in current line.
    } # End outer loop: read every line in buffer.
}    # End sub drain_queue.

#

# Print all matching lines from the %_seen hash.
sub print_matching_lines {
    my $emit_line_numbers = shift;
    my $self = shift;
    foreach my $k ( sort keys %{ $self->get_seen_hash } ) {

        ##TBF: Specifying cmd line param '-s' can affect the sorted o/p.  Fix this.
        my $h = shift( @{ ${ $self->get_seen_hash }{$k} } );
        print "${$h}{num}; " if ($emit_line_numbers);
        print "${$h}{line}\n";

        foreach ( @{ ${ $self->get_seen_hash }{$k} } ) {
            print "**** ";
            print "${$_}{num}; " if ($emit_line_numbers);
            print "${$_}{line}\n";
        }
    }
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
    $self->{_seen} = ();
}

1;
