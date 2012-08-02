/*
 * htdocs/js/widgets/importer.js
 *
 * JavaScript bells and whistles for the importer and importer components (htdocs/tools/importer)
 *
 * Authors:
 *     Afuna <coder.dw@afunamatata.com>
 *
 * Copyright (c) 2009 by Dreamwidth Studios, LLC.
 *
 * This program is free software; you may redistribute it and/or modify it under
 * the same terms as Perl itself.  For a copy of the license, please reference
 * 'perldoc perlartistic' or 'perldoc perlgpl'.
 */


var Icons = {
    init: function() {
        $("#icons_num_chosen").text( $(".icon_import input:checked").size() );
        $(".icon_import input:checked").parents(".icon_container")
            .addClass("selected");

        this.display = document.createElement("span");
        $(this.display).addClass("display");
    },
    
    updateStatus: function(clicked) {

        // update the number at the top
        $("#icons_num_chosen").text( $(".icon_import input:checked").size() );
    
        // update the text beside the checkbox
        $(this.display).text( $("#icons_num_chosen").text() + " / " + $("#icons_num_unused").text() );

        // add class so we can highlight it if we're over the limit
        if( parseInt($("#icons_num_chosen").text()) > parseInt($("#icons_num_unused").text()) )
            $(this.display).addClass("over_limit");
        else
            $(this.display).removeClass("over_limit");

        // display the number of icon slots used / free
        $(this.display).css("display", "none");
        $(clicked).siblings("label").append(this.display);
        $(this.display).fadeIn();
        $(clicked).parents(".icon_container").toggleClass("selected");
    },
}

$(document).ready(function() {

    Icons.init();

    $(".icon_import input").bind( "click", function(event) {
        Icons.updateStatus(this);
    });
    
    $(".importer form").bind( "submit", function(event) {
        if(parseInt($("#icons_num_chosen").text()) > parseInt($("#icons_num_unused").text())) {

            alert(ml.error_too_many);
            return false;
        }
    });

})
