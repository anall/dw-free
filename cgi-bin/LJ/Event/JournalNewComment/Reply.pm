#!/usr/bin/perl
#
# LJ::Event::JournalNewComment::Reply - Someone replies to any comment I make
#
# Authors:
#      Andrea Nall <anall@andreanall.com>
#
# Copyright (c) 2013 by Dreamwidth Studios, LLC.
#
# This program is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself. For a copy of the license, please reference
# 'perldoc perlartistic' or 'perldoc perlgpl'.
#
package LJ::Event::JournalNewComment::Reply;
use strict;
use List::MoreUtils qw/uniq/;

use base 'LJ::Event::JournalNewComment';

sub zero_journalid_subs_means { return 'all'; }

sub subscription_as_html {
    my ( $class, $subscr, $key_prefix ) = @_;

    my $key = $key_prefix || 'event.journal_new_comment.reply';
    my $arg2 = $subscr->arg2;

    my %key_suffixes = (
        0 => '.comment',
        1 => '.community',
        2 => '.mycomment',
    );

    return BML::ml( $key . $key_suffixes{$arg2} );
}

sub available_for_user {
    return 1;
}

sub _relevant_userids {
    my $comment = $_[0]->comment;
    return () unless $comment;

    my $entry = $comment->entry;
    return () unless $entry;

    my @prepart;
    push @prepart, $comment->posterid
        if $comment->posterid;

    my $parent = $comment->parent;

    push @prepart, $parent->posterid
        if $parent && $parent->posterid;

    push @prepart, $entry->posterid
        if $entry->journal->is_community;

    return uniq @prepart;
}

sub early_filter_event {
    my @userids = _relevant_userids( $_[1] );
    return scalar @userids ? 1 : 0;
}

sub additional_subscriptions_sql {
    my @userids = _relevant_userids( $_[1] );
    return ('userid IN (' . join(",", map { '?' } @userids) . ')', @userids) if scalar @userids;
    return undef;
}

# override parent class sbuscriptions method to
# convert opt_gettalkemail to a subscription
sub raw_subscriptions {
    my ($class, $self, %args) = @_;
    my $cid   = delete $args{'cluster'};
    croak("Cluser id (cluster) must be provided") unless defined $cid;

    my $scratch = delete $args{'scratch'}; # optional

    croak("Unknown options: " . join(', ', keys %args)) if %args;
    croak("Can't call in web context") if LJ::is_web_context();

    my @userids = _relevant_userids( $_[1] );

    foreach my $userid ( @userids ) {
        my $u = LJ::load_userid($userid);
        next unless $u;
        next unless ( $cid == $u->clusterid );

        my @pending_subscriptions;
        if ( $u->prop('opt_gettalkemail') ne 'X' ) {
            if ( $u->prop('opt_gettalkemail') eq 'Y' ) {
                push @pending_subscriptions, map { (
                    # FIXME(dre): Remove when ESN can bypass inbox
                    LJ::Subscription::Pending->new($u,
                        event => 'JournalNewComment::Reply',
                        method => 'Inbox',
                        arg2 => $_,
                    ),
                    LJ::Subscription::Pending->new($u,
                        event => 'JournalNewComment::Reply',
                        method => 'Email',
                        arg2 => $_,
                    ),
                ) } ( 0, 1 );
            }
            $u->update_self( { 'opt_gettalkemail' => 'X' } );
        }
        if ( $u->prop('opt_getselfemail') ne 'X' ) {
            if ( $u->prop('opt_getselfemail') eq '1' ) {
                push @pending_subscriptions, (
                    # FIXME(dre): Remove when ESN can bypass inbox
                    LJ::Subscription::Pending->new($u,
                        event => 'JournalNewComment::Reply',
                        method => 'Inbox',
                        arg2 => 2,
                    ),
                    LJ::Subscription::Pending->new($u,
                        event => 'JournalNewComment::Reply',
                        method => 'Email',
                        arg2 => 2,
                    ),
                );
            }
            $u->set_prop( 'opt_getselfemail' => 'X' );
        }
        $_->commit foreach @pending_subscriptions;
    }

    return eval { LJ::Event::raw_subscriptions($class, $self,
        cluster => $cid, scratch => $scratch ) } unless scalar @userids;

    my @rows = eval { LJ::Event::raw_subscriptions($class, $self,
        cluster => $cid, scratch => $scratch ) };

    return @rows;
}

sub matches_filter {
    my ( $self, $subscr, $filter_reason_ref ) = @_;

    my $filter = sub {
        my $msg = $_[0];
        $$filter_reason_ref = "[JournalNewComment::Reply matches_filter] $msg" if $filter_reason_ref;
        return 0;
    };

    my $sjid = $subscr->journalid;
    my $ejid = $self->event_journal->{userid};
    my $watcher = $subscr->owner;
    my $arg2 = $subscr->arg2;

    my $comment = $self->comment;

    # Do not send on own comments
    return $filter->( "Comment not visible to watcher" ) unless $comment->visible_to( $watcher );

    # Do not send if opt_noemail applies
    return $filter->( "opt_noemail applies" ) if $self->apply_noemail( $watcher, $comment, $subscr->method );

    my $parent = $comment->parent;

    if ( $arg2 == 0 ) {
        # Someone replies to my comment
        return $filter->( "sub is for someone replies to my comment; this comment has no parent" )
            unless $parent;
        return $filter->( "sub is for someone replies to my comment; this comment is a reply to someone else's comment")
            unless $parent->posterid == $watcher->id;

        # Make sure we didn't post the comment
        return 1 unless $comment->posterid == $watcher->id;
    } elsif ( $arg2 == 1 ) {
        # Someone replies to my entry in a community
        my $entry = $comment->entry;
        return $filter->( "sub is for someone replies to my entry in a community; this comment has no entry" )
            unless $entry;

        # Make sure the entry is posted by the watcher
        return $filter->( "sub is for someone replies to my entry in a community; this entry is not mine" )
            unless $entry->posterid == $watcher->id;

        # Make sure we didn't post the comment
        return 1 unless $comment->posterid == $watcher->id;
    } elsif ( $arg2 == 2 ) {
        # I comment on any entry in someone else's journal
        my $entry = $comment->entry;
        return $filter->( "sub is for I comment to any entry in someone else's journal; this comment has no entry")
            unless $entry;

        # Make sure we posted the comment
        return 1 if $comment->posterid == $watcher->id;
    }

    my $arg1 = $subscr->arg1;
    return $filter->( "does not match any relevant cases: arg1=$arg1 arg2=$arg2" );
}

1;

