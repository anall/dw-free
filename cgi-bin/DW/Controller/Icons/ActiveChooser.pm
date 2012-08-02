#!/usr/bin/perl
#
# DW::Controller::Icons::ActiveChooser
#
# This controller is for choosing which icons to keep active.
#
# Authors:
#     Andrea Nall <anall@andreanall.com>
#
# Copyright (c) 2012 by Dreamwidth Studios, LLC.
#
# This program is free software; you may redistribute it and/or modify it under
# the same terms as Perl itself. For a copy of the license, please reference
# 'perldoc perlartistic' or 'perldoc perlgpl'.
#

package DW::Controller::Icons::ActiveChooser;

use strict;
use warnings;
use DW::Controller;
use DW::Routing;
use DW::Template;

DW::Routing->register_string( "/icons/choose_active", \&handler );

sub handler {
    my ( $opts ) = @_;
    my $r = DW::Request->get;

    my $vars = {};

    # If I try to get it committed like this,
    #  feel free to hit me with a copy of
    #  some hefty Perl book.
    my $u = LJ::load_userid(2);
    my @userpics = LJ::Userpic->load_user_userpics($u);
    my $max      = $u->count_max_userpics;

    $vars->{max} = $max;
    $vars->{icons} = \@userpics;
 
    return DW::Template->render_template( 'icons/choose_active.tt', $vars );
}

1;
