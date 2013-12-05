#!/usr/bin/perl
#
# Authors:
#      Afuna <coder.dw@afunamatata.com>
#
# Copyright (c) 2013 by Dreamwidth Studios, LLC.
#
# This program is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself. For a copy of the license, please reference
# 'perldoc perlartistic' or 'perldoc perlgpl'.

package DW::Controller::Admin::Subscriptions;

use strict;
use DW::Controller;
use DW::Routing;
use DW::Template;
use DW::Controller::Admin;
use DW::FormErrors;

use LJ::ESN;
use LJ::Comment;
use LJ::Subscription;
use LJ::Event::JournalNewComment;

=head1 NAME

DW::Controller::Admin::subscriptions

=head1 SYNOPSIS

=cut

DW::Routing->register_string( "/admin/subscriptions/index", \&index_controller );
DW::Controller::Admin->register_admin_page( '/',
    path => 'subscriptions/',
    ml_scope => '/admin/subscriptions/index.tt',
    privs => [ 'siteadmin:subscriptions' ]
);

sub index_controller {
    my ( $ok, $rv ) = controller( privcheck => [ "siteadmin:subscriptions" ], form_auth => 1 );
    return $rv unless $ok;

    my $r = $rv->{r};
    my $post = $r->post_args;
    my $errors = DW::FormErrors->new;

    my @subs;
    my $filter_reasons = [];
    if ( $r->did_post ) {
        my $subscriber_u = LJ::load_user( $post->{subscriber} );
        $errors->add( "subscriber", "error.invaliduser" ) unless $subscriber_u;

        my $comment = LJ::Comment->new_from_url( $post->{comment_url} );
        $errors->add( "comment_url", ".form.error.invalid_comment" ) unless $comment;

        # event that would be fired by this comment being posted
        my $evt = LJ::Event::JournalNewComment->new( $comment );

        # get all relevant subscriptions for this user
        @subs = LJ::ESN->subs_matching_event( $evt, \$filter_reasons, $subscriber_u->subscriptions );
    }

    return DW::Template->render_template( 'admin/subscriptions/index.tt', {
            action_url => LJ::create_url( undef ),
            formdata => $post,
            errors => $errors,

            matching_subs    => \@subs,
            nonmatching_subs => [ sort { $a->[0]->id < $b->[0]->id  } @$filter_reasons ],
        } );
}


1;